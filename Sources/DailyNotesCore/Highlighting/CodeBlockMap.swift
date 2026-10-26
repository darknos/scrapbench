import Foundation

public struct CodeBlock: Equatable, Sendable {
    /// The opening fence line, without its line terminator.
    public let fenceOpen: NSRange
    /// Everything between the fences, line terminators included; extends to end of text when unclosed.
    public let body: NSRange
    /// The closing fence line, without its line terminator; nil when the block is unclosed.
    public let fenceClose: NSRange?
    public let language: String?

    /// From the start of the opening fence to the end of the closing fence (or end of text).
    public var whole: NSRange {
        let end = fenceClose.map(\.upperBound) ?? body.upperBound
        return NSRange(location: fenceOpen.location, length: end - fenceOpen.location)
    }
}

/// Locates fenced code blocks (``` at column 0) with one pass over the lines.
public struct CodeBlockMap: Sendable {
    public let blocks: [CodeBlock]

    public init(text: NSString) {
        var blocks: [CodeBlock] = []
        var open: (fence: NSRange, language: String?)?
        var bodyStart = 0
        var index = 0
        let length = text.length
        while index < length {
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd,
                              for: NSRange(location: index, length: 0))
            let content = NSRange(location: lineStart, length: contentsEnd - lineStart)
            let line = text.substring(with: content)
            if line.hasPrefix("```") {
                if let o = open {
                    blocks.append(CodeBlock(
                        fenceOpen: o.fence,
                        body: NSRange(location: bodyStart, length: lineStart - bodyStart),
                        fenceClose: content,
                        language: o.language))
                    open = nil
                } else {
                    let lang = line.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased()
                    open = (content, lang.isEmpty ? nil : lang)
                    bodyStart = lineEnd
                }
            }
            index = lineEnd
        }
        if let o = open {
            blocks.append(CodeBlock(
                fenceOpen: o.fence,
                body: NSRange(location: bodyStart, length: length - bodyStart),
                fenceClose: nil,
                language: o.language))
        }
        self.blocks = blocks
    }

    public func block(containing offset: Int) -> CodeBlock? {
        blocks.first { NSLocationInRange(offset, $0.whole) }
    }

    /// Blocks overlapping `range`.
    public func blocks(intersecting range: NSRange) -> [CodeBlock] {
        blocks.filter { NSIntersectionRange($0.whole, range).length > 0 || NSLocationInRange(range.location, $0.whole) }
    }
}
