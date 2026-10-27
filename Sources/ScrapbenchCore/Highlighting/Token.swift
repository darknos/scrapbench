import Foundation

public enum TokenKind: Sendable, Hashable {
    // Markdown
    case heading, bold, italic, inlineCode, link, listMarker, quote, checkboxDone
    case separatorDashes, separatorDate
    // Fenced code
    case codeFence, codeBlockBackground
    case keyword, string, number, comment, literal, key
}

/// A highlighted span. Ranges are UTF-16 offsets so they map directly onto `NSTextStorage`.
public struct Token: Equatable, Sendable {
    public let range: NSRange
    public let kind: TokenKind

    public init(range: NSRange, kind: TokenKind) {
        self.range = range
        self.kind = kind
    }
}

public protocol SyntaxHighlighter {
    /// Tokens intersecting `range`. Tokens may extend beyond the range.
    /// `codeBlocks` is the caller-maintained fence map for `text`.
    func tokens(in text: NSString, range: NSRange, codeBlocks: CodeBlockMap) -> [Token]
}

public extension SyntaxHighlighter {
    func tokens(in text: NSString, range: NSRange) -> [Token] {
        tokens(in: text, range: range, codeBlocks: CodeBlockMap(text: text))
    }
}
