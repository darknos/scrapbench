import Foundation

public struct UpperCaseTransformer: Transformer {
    public let id = "case.upper"
    public let name = "UPPER CASE"
    public let group = TransformerGroup.case
    public init() {}
    public func canApply(to text: String) -> Bool { true }
    public func apply(_ text: String) throws -> String { text.uppercased() }
}

public struct LowerCaseTransformer: Transformer {
    public let id = "case.lower"
    public let name = "lower case"
    public let group = TransformerGroup.case
    public init() {}
    public func canApply(to text: String) -> Bool { true }
    public func apply(_ text: String) throws -> String { text.lowercased() }
}

public struct TitleCaseTransformer: Transformer {
    public let id = "case.title"
    public let name = "Title Case"
    public let description = "first letter of each word"
    public let group = TransformerGroup.case
    public init() {}
    public func canApply(to text: String) -> Bool { true }

    public func apply(_ text: String) throws -> String {
        var result = ""
        var atWordStart = true
        for character in text {
            if character.isWhitespace {
                atWordStart = true
                result.append(character)
            } else if atWordStart {
                atWordStart = false
                result += character.uppercased()
            } else {
                result.append(character)
            }
        }
        return result
    }
}

public enum IdentifierWords {
    /// Lower-cased words of one identifier or phrase: splits on `_`, `-`,
    /// whitespace, lower→upper boundaries and acronym ends (`HTTPServer`).
    public static func split(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { words.append(current.lowercased()) }
            current = ""
        }
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            if character == "_" || character == "-" || character.isWhitespace {
                flush()
                continue
            }
            if character.isUppercase, !current.isEmpty {
                let previous = characters[index - 1]
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                if previous.isLowercase || previous.isNumber {
                    flush()
                } else if previous.isUppercase, let next, next.isLowercase {
                    flush()
                }
            }
            current.append(character)
        }
        flush()
        return words
    }
}

/// camelCase, snake_case, kebab-case and CONSTANT_CASE share everything
/// but the join; each line is one identifier and keeps its surrounding whitespace.
public struct IdentifierCaseTransformer: Transformer {
    public let id: String
    public let name: String
    public let description = "per line, any identifier style"
    public let group = TransformerGroup.case
    private let join: @Sendable ([String]) -> String

    public init(id: String, name: String, join: @escaping @Sendable ([String]) -> String) {
        self.id = id
        self.name = name
        self.join = join
    }

    public func canApply(to text: String) -> Bool { true }

    public func apply(_ text: String) throws -> String {
        let lines = Lines(text)
        return lines.joined(lines.lines.map { line in
            let leading = line.prefix(while: \.isWhitespace)
            let trailing = line.reversed().prefix(while: \.isWhitespace)
            let words = IdentifierWords.split(line)
            guard !words.isEmpty else { return line }
            return leading + join(words) + String(trailing.reversed())
        })
    }
}

extension IdentifierCaseTransformer {
    public static let camel = IdentifierCaseTransformer(id: "case.camel", name: "camelCase") { words in
        words.enumerated().map { $0.offset == 0 ? $0.element : $0.element.capitalizedFirst }.joined()
    }
    public static let snake = IdentifierCaseTransformer(id: "case.snake", name: "snake_case") { $0.joined(separator: "_") }
    public static let kebab = IdentifierCaseTransformer(id: "case.kebab", name: "kebab-case") { $0.joined(separator: "-") }
    public static let constant = IdentifierCaseTransformer(id: "case.constant", name: "CONSTANT_CASE") {
        $0.joined(separator: "_").uppercased()
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
