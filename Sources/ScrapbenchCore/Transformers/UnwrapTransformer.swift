import Foundation

/// Removes hard wraps from text copied out of a terminal: continuation lines
/// join their paragraph with one space, indentation goes, blank lines stay
/// (collapsed to one), list items, headings, quotes, tables and fenced code
/// keep their structure.
public struct UnwrapTransformer: Transformer, LineAware {
    public let id = "lines.unwrap"
    public let name = "Unwrap lines"
    public let group = TransformerGroup.lines
    public init() {}

    public func canApply(to text: String) -> Bool { canApply(lines: Lines(text)) }

    func canApply(lines: Lines) -> Bool {
        lines.byteCount > transformerParseLimit || Self.unwrap(lines.lines) != lines.lines
    }

    public func apply(_ text: String) throws -> String {
        let lines = Lines(text)
        return lines.joined(Self.unwrap(lines.lines))
    }

    private static let orderedItem = try! NSRegularExpression(pattern: "^\\d+[.)] ")
    private static let blockPrefixes = ["- ", "* ", "+ ", "• ", "> ", "#", "|", "---"]

    static func unwrap(_ lines: [String]) -> [String] {
        var out: [String] = []
        var inFence = false
        var lastWasBlank = false
        var joinable = false
        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                out.append(trimmed)
                inFence.toggle()
                joinable = false
                lastWasBlank = false
                continue
            }
            if inFence {
                out.append(raw)
                continue
            }
            if trimmed.isEmpty {
                if !lastWasBlank { out.append("") }
                lastWasBlank = true
                joinable = false
                continue
            }
            lastWasBlank = false
            if joinable, !startsBlock(trimmed) {
                out[out.count - 1] += " " + trimmed
            } else {
                out.append(trimmed)
            }
            // A heading or table row is one line by nature; nothing wraps onto it.
            joinable = !(trimmed.hasPrefix("#") || trimmed.hasPrefix("|"))
        }
        return out
    }

    private static func startsBlock(_ line: String) -> Bool {
        if blockPrefixes.contains(where: { line.hasPrefix($0) }) { return true }
        return orderedItem.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil
    }
}
