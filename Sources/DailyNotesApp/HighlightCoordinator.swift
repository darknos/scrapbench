import AppKit
import DailyNotesCore

/// Keeps `NSTextStorage` attributes in sync with the highlighter: whole
/// paragraphs on edit, the enclosing code block when a fence is touched,
/// and otherwise only the regions that have been scrolled into view.
/// Attribute runs in NSTextStorage are an array with O(n) inserts, so
/// colouring a multi-megabyte file eagerly is quadratic; lazy is the only
/// way to keep opening instant.
final class HighlightCoordinator: NSObject, NSTextStorageDelegate {
    static let syncTail = 20_000

    private let storage: NSTextStorage
    private let highlighter: SyntaxHighlighter
    private let theme: Theme
    var baseFont: NSFont
    private(set) var codeBlocks = CodeBlockMap(text: "")
    /// Character offsets whose attributes are current.
    private var covered = IndexSet()
    /// Set while a whole document is being replaced; `highlightAll()` follows.
    var isLoading = false

    init(storage: NSTextStorage, highlighter: SyntaxHighlighter, theme: Theme, baseFont: NSFont) {
        self.storage = storage
        self.highlighter = highlighter
        self.theme = theme
        self.baseFont = baseFont
        super.init()
        storage.delegate = self
    }

    /// Resets after a document load: only the tail is coloured now, the rest on demand.
    func highlightAll() {
        covered = IndexSet()
        let length = storage.length
        codeBlocks = CodeBlockMap(text: storage.string as NSString)
        let tailStart = max(0, length - Self.syncTail)
        ensureHighlighted(NSRange(location: tailStart, length: length - tailStart))
    }

    /// Colours whatever part of `range` has not been coloured yet.
    func ensureHighlighted(_ range: NSRange) {
        let text = storage.string as NSString
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: text.length))
        guard clamped.length > 0 else { return }
        var missing = IndexSet(integersIn: clamped.location..<clamped.upperBound)
        missing.subtract(covered)
        for gap in missing.rangeView {
            var dirty = text.paragraphRange(for: NSRange(location: gap.lowerBound, length: gap.count))
            for block in codeBlocks.blocks(intersecting: dirty) {
                dirty = NSUnionRange(dirty, block.whole)
            }
            apply(dirty)
        }
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters), !isLoading else { return }
        let text = textStorage.string as NSString
        if delta < 0 {
            covered.remove(integersIn: editedRange.location..<(editedRange.location - delta))
            covered.shift(startingAt: editedRange.location - delta, by: delta)
        } else if delta > 0 {
            covered.shift(startingAt: editedRange.location, by: delta)
        }
        var dirty = text.paragraphRange(for: editedRange)
        let replaced = NSRange(location: editedRange.location, length: max(0, editedRange.length - delta))
        let touchesFence = codeBlocks.fenceIntersects(replaced) || text.substring(with: dirty).contains("```")
        if touchesFence {
            // A fence change can re-pair every fence below it: rebuild the map and re-highlight to the end.
            codeBlocks = CodeBlockMap(text: text)
            dirty = NSRange(location: dirty.location, length: text.length - dirty.location)
        } else {
            codeBlocks = codeBlocks.shifted(after: editedRange.location, by: delta)
        }
        for block in codeBlocks.blocks(intersecting: dirty) {
            dirty = NSUnionRange(dirty, block.whole)
        }
        apply(dirty)
    }

    private func apply(_ range: NSRange) {
        guard range.length > 0 else { return }
        let text = storage.string as NSString
        let base: [NSAttributedString.Key: Any] = [.font: baseFont, .foregroundColor: theme.text]
        storage.beginEditing()
        storage.setAttributes(base, range: range)
        for token in highlighter.tokens(in: text, range: range, codeBlocks: codeBlocks) {
            let r = NSIntersectionRange(token.range, range)
            guard r.length > 0 else { continue }
            storage.addAttributes(theme.attributes(for: token.kind, baseFont: baseFont), range: r)
        }
        storage.endEditing()
        covered.insert(integersIn: range.location..<range.upperBound)
    }
}
