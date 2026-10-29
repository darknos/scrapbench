import Foundation

/// Appends timestamped separators for one editing session and removes the
/// ones that were left empty when the session ends. Separators that were
/// already in the file (previous sessions, or typed by hand) are never touched.
public struct ScrapFormatter {
    public var sessionSeparators: [String] = []

    public init() {}

    /// Called when the panel opens: appends a fresh separator at the end of
    /// the text. An empty separator already at the end (left by a session that
    /// never closed) is replaced instead, so separators do not pile up.
    public mutating func open(text: String, date: Date) -> (text: String, cursor: Int) {
        let separator = Separator.make(date: date)
        if let orphan = Self.emptyTrailingSeparator(in: text) {
            let result = text[..<orphan.lowerBound] + separator + "\n"
            sessionSeparators.append(separator)
            return (String(result), result.utf16.count)
        }
        return append(separator: separator, to: text)
    }

    /// The range of a separator that is the last non-blank line of `text`.
    static func emptyTrailingSeparator(in text: String) -> Range<String.Index>? {
        let trimmed = Substring(text).trimmingSuffix(while: \.isWhitespace)
        let lineStart = trimmed.lastIndex(of: "\n").map { trimmed.index(after: $0) } ?? trimmed.startIndex
        let line = trimmed[lineStart...]
        guard Separator.isSeparatorLine(line) else { return nil }
        return lineStart..<trimmed.endIndex
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
        var text = result.hasSuffix("\n") ? String(result) : String(result) + "\n"
        if let last = sessionSeparators.last(where: { text.contains($0) }),
           let scrap = textAfterLast(separator: last, in: text), Self.hasUnclosedFence(scrap) {
            text += "```\n"
        }
        return text
    }

    /// Appends a piece of text taken from elsewhere (the "Take to Scrapbench"
    /// service) on its own line, ending with exactly one newline. Blank
    /// chunks leave the text unchanged.
    public static func append(chunk: String, to text: String) -> String {
        let body = self.body(of: chunk)
        guard !body.isEmpty else { return text }
        var result = text
        if !result.isEmpty, !result.hasSuffix("\n") { result += "\n" }
        return result + body + "\n"
    }

    /// What `append(chunk:)` adds before its final newline: CRLF normalised,
    /// trailing newlines dropped; empty for a blank chunk.
    public static func body(of chunk: String) -> String {
        let normalised = chunk.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalised.contains(where: { !$0.isWhitespace }) else { return "" }
        var body = Substring(normalised)
        while body.last == "\n" { body = body.dropLast() }
        return String(body)
    }

    private mutating func append(separator: String, to text: String) -> (text: String, cursor: Int) {
        var result = text
        if !result.isEmpty, !result.hasSuffix("\n") { result += "\n" }
        if let last = sessionSeparators.last, let scrap = textAfterLast(separator: last, in: result),
           Self.hasUnclosedFence(scrap) {
            result += "```\n"
        }
        result += separator + "\n"
        sessionSeparators.append(separator)
        return (result, result.utf16.count)
    }

    private func textAfterLast(separator: String, in text: String) -> Substring? {
        guard let range = text.range(of: separator, options: .backwards) else { return nil }
        return text[range.upperBound...]
    }

    /// Same fence rule as `CodeBlockMap`: a line starting with ``` at column 0.
    static func hasUnclosedFence(_ text: Substring) -> Bool {
        var open = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) where line.hasPrefix("```") {
            open.toggle()
        }
        return open
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
