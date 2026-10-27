import Foundation

public enum CommandSplitter {
    /// Whitespace-separated tokens; single and double quotes group and are kept as written.
    public static func tokens(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false
        for character in line {
            if escaped {
                current.append(character)
                escaped = false
            } else if let open = quote {
                current.append(character)
                if character == "\\", open == "\"" { escaped = true }
                if character == open { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
                current.append(character)
            } else if character.isWhitespace {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static let connectors: Set<String> = ["|", "||", "&&", ";"]

    /// One line per flag (with its values) or connector, ` \` continuations,
    /// continuation lines indented two spaces.
    public static func split(_ line: String) -> String {
        var lines: [[String]] = []
        for token in tokens(line) {
            let startsLine = token.hasPrefix("-") || connectors.contains(token)
            if lines.isEmpty || (startsLine && !lines[lines.count - 1].isEmpty) {
                lines.append([token])
            } else {
                lines[lines.count - 1].append(token)
            }
        }
        return lines.enumerated().map { index, tokens in
            (index == 0 ? "" : "  ") + tokens.joined(separator: " ") + (index == lines.count - 1 ? "" : " \\")
        }.joined(separator: "\n")
    }

    public static func join(_ text: String) -> String {
        joinLines(Lines(text).lines)
    }

    static func joinLines(_ lines: [String]) -> String {
        lines.map { line in
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("\\") { trimmed = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces) }
            return trimmed
        }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

public struct SplitCommandTransformer: Transformer, LineAware {
    public let id = "cli.split"
    public let name = "Split command"
    public let group = TransformerGroup.cli
    public init() {}

    public func canApply(to text: String) -> Bool { canApply(lines: Lines(text)) }

    func canApply(lines: Lines) -> Bool {
        if lines.byteCount > transformerParseLimit { return true }
        let content = lines.lines.filter { !$0.allSatisfy(\.isWhitespace) }
        guard content.count == 1 else { return false }
        return content[0].trimmingCharacters(in: .whitespaces).contains(where: \.isWhitespace)
    }

    public func apply(_ text: String) throws -> String {
        let lines = Lines(text)
        return lines.joined([CommandSplitter.split(text.trimmingCharacters(in: .whitespacesAndNewlines))])
    }
}

public enum CLITransformers {
    public static let split = SplitCommandTransformer()

    public static let join = LineTransformer(id: "cli.join", name: "Join command", group: .cli,
                                             canApply: { $0.count > 1 }) { [CommandSplitter.joinLines($0)] }

    public static let comment = LineTransformer(id: "cli.comment", name: "Comment lines", group: .cli,
                                                canApply: { $0.contains { !$0.isEmpty && !isCommented($0) } }) {
        $0.map { $0.isEmpty ? $0 : "# " + $0 }
    }

    public static let uncomment = LineTransformer(id: "cli.uncomment", name: "Uncomment lines", group: .cli,
                                                  canApply: { lines in
        let content = lines.filter { !$0.isEmpty }
        return !content.isEmpty && content.allSatisfy(isCommented)
    }) {
        $0.map { line in
            let indent = line.prefix(while: \.isWhitespace)
            var rest = line.dropFirst(indent.count)
            guard rest.hasPrefix("#") else { return line }
            rest = rest.dropFirst()
            if rest.hasPrefix(" ") { rest = rest.dropFirst() }
            return String(indent + rest)
        }
    }
}

private func isCommented(_ line: String) -> Bool {
    line.drop(while: \.isWhitespace).hasPrefix("#")
}
