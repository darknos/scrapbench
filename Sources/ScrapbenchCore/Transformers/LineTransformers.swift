import Foundation

/// A transformer defined on the array of lines; `Lines` supplies the
/// trailing-newline and CRLF rules.
public struct LineTransformer: Transformer, LineAware {
    public let id: String
    public let name: String
    public let group: TransformerGroup
    private let canApplyLines: @Sendable ([String]) -> Bool
    private let transform: @Sendable ([String]) -> [String]

    public init(id: String, name: String, group: TransformerGroup = .lines,
                canApply: @escaping @Sendable ([String]) -> Bool,
                transform: @escaping @Sendable ([String]) -> [String]) {
        self.id = id
        self.name = name
        self.group = group
        self.canApplyLines = canApply
        self.transform = transform
    }

    public func canApply(to text: String) -> Bool { canApply(lines: Lines(text)) }

    func canApply(lines: Lines) -> Bool {
        lines.byteCount > transformerParseLimit || canApplyLines(lines.lines)
    }

    public func apply(_ text: String) throws -> String {
        let lines = Lines(text)
        return lines.joined(transform(lines.lines))
    }
}

extension LineTransformer {
    public static let sort = LineTransformer(id: "lines.sort", name: "Sort lines",
                                             canApply: { $0.count > 1 }, transform: sortedBytewise)

    public static let sortUnique = LineTransformer(id: "lines.sortUnique", name: "Sort lines unique",
                                                   canApply: { $0.count > 1 }) { lines in
        var result: [String] = []
        for line in sortedBytewise(lines) where result.last != line { result.append(line) }
        return result
    }

    public static let reverse = LineTransformer(id: "lines.reverse", name: "Reverse lines",
                                                canApply: { $0.count > 1 }) { $0.reversed() }

    public static let unique = LineTransformer(id: "lines.unique", name: "Unique lines",
                                               canApply: { $0.count > 1 }) { lines in
        var seen = Set<String>()
        return lines.filter { seen.insert($0).inserted }
    }

    public static let removeBlank = LineTransformer(id: "lines.removeBlank", name: "Remove blank lines",
                                                    canApply: { $0.contains(where: isBlank) }) { $0.filter { !isBlank($0) } }

    public static let trimTrailing = LineTransformer(id: "lines.trimTrailing", name: "Trim trailing whitespace",
                                                     canApply: { $0.contains { $0.last?.isWhitespace == true } }) {
        $0.map { String($0.reversed().drop(while: \.isWhitespace).reversed()) }
    }

    public static let trim = LineTransformer(id: "lines.trim", name: "Trim each line",
                                             canApply: { $0.contains { $0.first?.isWhitespace == true || $0.last?.isWhitespace == true } }) {
        $0.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    public static let indent = LineTransformer(id: "lines.indent", name: "Indent", canApply: { _ in true }) { lines in
        let unit = lines.contains { $0.hasPrefix("\t") } ? "\t" : "    "
        return lines.map { $0.isEmpty ? $0 : unit + $0 }
    }

    public static let dedent = LineTransformer(id: "lines.dedent", name: "Dedent",
                                               canApply: { lines in
        let content = lines.filter { !isBlank($0) }
        return !content.isEmpty && content.allSatisfy { $0.first?.isWhitespace == true }
    }) { lines in
        let prefixes = lines.filter { !isBlank($0) }.map { Array($0.prefix(while: \.isWhitespace)) }
        guard var common = prefixes.first else { return lines }
        for prefix in prefixes.dropFirst() {
            let shared = zip(common, prefix).prefix { $0 == $1 }.count
            common = Array(common.prefix(shared))
        }
        return lines.map { isBlank($0) ? $0 : String($0.dropFirst(common.count)) }
    }

    public static let joinSpace = LineTransformer(id: "lines.joinSpace", name: "Join lines with space",
                                                  canApply: { $0.count > 1 }) { [$0.map(trimmed).joined(separator: " ")] }

    public static let joinComma = LineTransformer(id: "lines.joinComma", name: "Join lines with \", \"",
                                                  canApply: { $0.count > 1 }) { [$0.map(trimmed).joined(separator: ", ")] }

    public static let splitComma = LineTransformer(id: "lines.splitComma", name: "Split by comma",
                                                   canApply: { $0.contains { $0.contains(",") } }) { lines in
        lines.flatMap { $0.split(separator: ",", omittingEmptySubsequences: false).map { trimmed(String($0)) } }
    }

    public static let splitSpace = LineTransformer(id: "lines.splitSpace", name: "Split by whitespace",
                                                   canApply: { $0.count == 1 && $0[0].trimmingCharacters(in: .whitespaces).contains(where: \.isWhitespace) }) { lines in
        lines.flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
    }
}

private func isBlank(_ line: String) -> Bool { line.allSatisfy(\.isWhitespace) }

private func trimmed(_ line: String) -> String { line.trimmingCharacters(in: .whitespaces) }

/// Byte-wise order with the original index as tie-break, so equal lines keep their order.
private func sortedBytewise(_ lines: [String]) -> [String] {
    lines.enumerated().sorted { a, b in
        if a.element.utf8.elementsEqual(b.element.utf8) { return a.offset < b.offset }
        return a.element.utf8.lexicographicallyPrecedes(b.element.utf8)
    }.map(\.element)
}
