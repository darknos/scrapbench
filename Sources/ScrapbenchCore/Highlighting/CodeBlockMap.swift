import Foundation

public struct CodeBlock: Equatable, Sendable {
    public init(fenceOpen: NSRange, body: NSRange, fenceClose: NSRange?, language: String?, cut: NSRange? = nil) {
        self.fenceOpen = fenceOpen
        self.body = body
        self.fenceClose = fenceClose
        self.language = language
        self.cut = cut
    }

    /// The opening fence line, without its line terminator.
    public let fenceOpen: NSRange
    /// Everything between the fences, line terminators included; extends to end of text when unclosed.
    public let body: NSRange
    /// The closing fence line, without its line terminator; nil when the block is unclosed.
    public let fenceClose: NSRange?
    public let language: String?
    /// The separator line that ended an unclosed block, without its line terminator; nil otherwise.
    public let cut: NSRange?

    /// From the start of the opening fence to the end of the closing fence (or end of text).
    public var whole: NSRange {
        let end = fenceClose.map(\.upperBound) ?? body.upperBound
        return NSRange(location: fenceOpen.location, length: end - fenceOpen.location)
    }
}

/// Locates fenced code blocks (``` at column 0) with one pass over the lines.
/// A separator line ends an unclosed block, so a scrap left open never swallows the next one.
public struct CodeBlockMap: Sendable {
    public let blocks: [CodeBlock]

    private init(blocks: [CodeBlock]) {
        self.blocks = blocks
    }

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
            if content.length >= 3, text.character(at: lineStart) == 0x60,
               text.character(at: lineStart + 1) == 0x60, text.character(at: lineStart + 2) == 0x60 {
                let line = text.substring(with: content)
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
            } else if let o = open, content.length > 0, text.character(at: lineStart) == 0x2D,
                      Separator.isSeparatorLine(Substring(text.substring(with: content))) {
                blocks.append(CodeBlock(
                    fenceOpen: o.fence,
                    body: NSRange(location: bodyStart, length: lineStart - bodyStart),
                    fenceClose: nil,
                    language: o.language,
                    cut: content))
                open = nil
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
        let i = firstIndex(endingAfter: offset)
        guard i < blocks.count, NSLocationInRange(offset, blocks[i].whole) else { return nil }
        return blocks[i]
    }

    /// Blocks overlapping `range` (a zero-length range inside a block counts).
    public func blocks(intersecting range: NSRange) -> [CodeBlock] {
        var result: [CodeBlock] = []
        var i = firstIndex(endingAfter: range.location)
        while i < blocks.count, blocks[i].whole.location <= range.upperBound {
            let b = blocks[i]
            if NSIntersectionRange(b.whole, range).length > 0 || NSLocationInRange(range.location, b.whole) {
                result.append(b)
            }
            i += 1
        }
        return result
    }

    /// Whether any fence line, or a separator line that cut a block, overlaps `range` (pre-edit coordinates).
    public func fenceIntersects(_ range: NSRange) -> Bool {
        func touches(_ r: NSRange) -> Bool { NSIntersectionRange(r, range).length > 0 || NSLocationInRange(range.location, r) }
        let lo = firstIndex(endingAfter: range.location)
        var i = max(0, lo - 1)
        while i < blocks.count, blocks[i].fenceOpen.location <= range.upperBound {
            let b = blocks[i]
            if touches(b.fenceOpen) || b.fenceClose.map(touches) == true || b.cut.map(touches) == true { return true }
            i += 1
        }
        return false
    }

    /// The same map after an edit that did not touch any fence: ranges at or
    /// after `location` move by `delta`.
    public func shifted(after location: Int, by delta: Int) -> CodeBlockMap {
        guard delta != 0 else { return self }
        func move(_ r: NSRange) -> NSRange {
            if r.location >= location { return NSRange(location: r.location + delta, length: r.length) }
            if r.upperBound > location { return NSRange(location: r.location, length: r.length + delta) }
            return r
        }
        return CodeBlockMap(blocks: blocks.map {
            CodeBlock(fenceOpen: move($0.fenceOpen), body: move($0.body), fenceClose: $0.fenceClose.map(move),
                      language: $0.language, cut: $0.cut.map(move))
        })
    }

    /// Index of the first block whose end is after `offset` (blocks are sorted and disjoint).
    private func firstIndex(endingAfter offset: Int) -> Int {
        var lo = 0, hi = blocks.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if blocks[mid].whole.upperBound <= offset { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}
