import Foundation

/// Appends timestamped separators for one editing session and removes the
/// ones that were left empty when the session ends. Separators that were
/// already in the file (previous sessions, or typed by hand) are never touched.
public struct ScrapFormatter {
    public var sessionSeparators: [String] = []

    public init() {}

    /// Called when the panel opens: appends a fresh separator at the end of the text.
    public mutating func open(text: String, date: Date) -> (text: String, cursor: Int) {
        append(separator: Separator.make(date: date), to: text)
    }

    /// Called on ⌘N. If the current session scrap is still empty, only the
    /// timestamp is refreshed instead of stacking another separator.
    public mutating func newScrap(text: String, date: Date) -> (text: String, cursor: Int) {
        let separator = Separator.make(date: date)
        if let last = sessionSeparators.last,
           let tail = textAfterLast(separator: last, in: text),
           tail.allSatisfy(\.isWhitespace) {
            let head = text.dropLast(tail.count + last.count)
            let result = head + separator + "\n"
            sessionSeparators[sessionSeparators.count - 1] = separator
            return (String(result), result.utf16.count)
        }
        return append(separator: separator, to: text)
    }

    /// Called when the panel closes: strips trailing session separators with no content.
    public func finalize(text: String) -> String {
        var result = Substring(text)
        var trailing = result.trimmingSuffix(while: \.isWhitespace)
        while let sep = sessionSeparators.last(where: { trailing.hasSuffix($0) }),
              isWholeLine(sep, endingAt: trailing) {
            trailing = trailing.dropLast(sep.count).trimmingSuffix(while: \.isWhitespace)
            result = trailing
        }
        if result.isEmpty { return "" }
        return result.hasSuffix("\n") ? String(result) : String(result) + "\n"
    }

    /// Appends a piece of text taken from elsewhere (the "Take to Scrapbench"
    /// service) on its own line, ending with exactly one newline. Blank
    /// chunks leave the text unchanged.
    public static func append(chunk: String, to text: String) -> String {
        let normalised = chunk.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalised.contains(where: { !$0.isWhitespace }) else { return text }
        var body = Substring(normalised)
        while body.last == "\n" { body = body.dropLast() }
        var result = text
        if !result.isEmpty, !result.hasSuffix("\n") { result += "\n" }
        return result + body + "\n"
    }

    private mutating func append(separator: String, to text: String) -> (text: String, cursor: Int) {
        var result = text
        if !result.isEmpty, !result.hasSuffix("\n") { result += "\n" }
        result += separator + "\n"
        sessionSeparators.append(separator)
        return (result, result.utf16.count)
    }

    private func textAfterLast(separator: String, in text: String) -> Substring? {
        guard let range = text.range(of: separator, options: .backwards) else { return nil }
        return text[range.upperBound...]
    }

    private func isWholeLine(_ sep: String, endingAt s: Substring) -> Bool {
        let before = s.dropLast(sep.count)
        return before.isEmpty || before.hasSuffix("\n")
    }
}

private extension Substring {
    func trimmingSuffix(while predicate: (Character) -> Bool) -> Substring {
        var s = self
        while let last = s.last, predicate(last) { s = s.dropLast() }
        return s
    }
}
