import AppKit
import DailyNotesCore

/// Keeps `NSTextStorage` attributes in sync with the highlighter: whole
/// paragraphs on edit, the enclosing code block when a fence is touched,
/// and the full document in chunks after a load.
final class HighlightCoordinator: NSObject, NSTextStorageDelegate {
    static let syncTail = 20_000
    static let chunk = 50_000

    private let storage: NSTextStorage
    private let highlighter: SyntaxHighlighter
    private let theme: Theme
    var baseFont: NSFont
    private(set) var codeBlocks = CodeBlockMap(text: "")
    private var version = 0

    init(storage: NSTextStorage, highlighter: SyntaxHighlighter, theme: Theme, baseFont: NSFont) {
        self.storage = storage
        self.highlighter = highlighter
        self.theme = theme
        self.baseFont = baseFont
        super.init()
        storage.delegate = self
    }

    func highlightAll() {
        version += 1
        let v = version
        let length = storage.length
        codeBlocks = CodeBlockMap(text: storage.string as NSString)
        let tailStart = max(0, length - Self.syncTail)
        apply(NSRange(location: tailStart, length: length - tailStart))
        highlightChunk(upTo: tailStart, version: v)
    }

    private func highlightChunk(upTo end: Int, version v: Int) {
        guard end > 0 else { return }
        let start = max(0, end - Self.chunk)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.version == v, end <= self.storage.length else { return }
            self.apply(NSRange(location: start, length: end - start))
            self.highlightChunk(upTo: start, version: v)
        }
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        version += 1
        let text = textStorage.string as NSString
        var dirty = text.paragraphRange(for: editedRange)
        let map = CodeBlockMap(text: text)
        codeBlocks = map
        let touchesFence = text.substring(with: dirty).contains("```")
        if touchesFence {
            // A fence change can re-pair every fence below it; re-highlight to the end.
            dirty = NSRange(location: dirty.location, length: text.length - dirty.location)
        }
        for block in map.blocks(intersecting: dirty) {
            dirty = NSUnionRange(dirty, block.whole)
        }
        apply(dirty, map: map)
    }

    private func apply(_ range: NSRange, map: CodeBlockMap? = nil) {
        guard range.length > 0 else { return }
        let text = storage.string as NSString
        let base: [NSAttributedString.Key: Any] = [.font: baseFont, .foregroundColor: theme.text]
        storage.beginEditing()
        storage.setAttributes(base, range: range)
        for token in highlighter.tokens(in: text, range: range) {
            let r = NSIntersectionRange(token.range, range)
            guard r.length > 0 else { continue }
            storage.addAttributes(theme.attributes(for: token.kind, baseFont: baseFont), range: r)
        }
        storage.endEditing()
    }
}
