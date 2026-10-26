import AppKit
import DailyNotesCore

final class EditorTextView: NSTextView {
    var onEscape: () -> Void = {}
    var onNewEntry: () -> Void = {}
    private(set) var highlight: HighlightCoordinator!
    var extraBottomSpace: CGFloat = 0 {
        didSet { if extraBottomSpace != oldValue { setFrameSize(frame.size) } }
    }

    override func setFrameSize(_ newSize: NSSize) {
        // Grow the document past the text so the view can scroll beyond the last line.
        let textHeight = (textLayoutManager?.usageBoundsForTextContainer.height ?? 0) + textContainerInset.height * 2
        super.setFrameSize(NSSize(width: newSize.width, height: max(newSize.height, textHeight + extraBottomSpace)))
    }

    static func make() -> (scroll: NSScrollView, editor: EditorTextView) {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor

        let editor = EditorTextView(usingTextLayoutManager: true)
        editor.autoresizingMask = [.width]
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 12, height: 12)
        editor.drawsBackground = true
        editor.backgroundColor = .textBackgroundColor
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.isContinuousSpellCheckingEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.smartInsertDeleteEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.font = Settings.shared.font
        editor.textColor = Theme.default.text
        editor.insertionPointColor = Theme.default.accent
        editor.highlight = HighlightCoordinator(storage: editor.textStorage!, highlighter: MarkdownHighlighter(),
                                                theme: .default, baseFont: editor.font!)
        scroll.documentView = editor
        // Blank space of half a view below the text lets the last line sit at the centre on open.
        scroll.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: scroll, queue: .main) { _ in
            editor.extraBottomSpace = scroll.contentView.bounds.height / 2
        }
        return (scroll, editor)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    /// Scrolls so the caret sits in the middle of the view.
    private func centerCaret() {
        guard let scroll = enclosingScrollView, let window else { return }
        let caret = convert(window.convertFromScreen(firstRect(forCharacterRange: selectedRange(), actualRange: nil)), from: nil)
        let clip = scroll.contentView
        let visible = clip.bounds
        var origin = visible.origin
        origin.y += caret.midY - visible.midY
        clip.scroll(to: clip.constrainBoundsRect(NSRect(origin: origin, size: visible.size)).origin)
        scroll.reflectScrolledClipView(clip)
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager,
              let viewport = layoutManager.textViewportLayoutController.viewportRange else { return }
        let docStart = contentManager.documentRange.location
        let visible = NSRange(location: contentManager.offset(from: docStart, to: viewport.location),
                              length: contentManager.offset(from: viewport.location, to: viewport.endLocation))
        let origin = textContainerOrigin
        Theme.default.codeBlockBackground.setFill()
        for block in highlight.codeBlocks.blocks(intersecting: visible) {
            guard let start = contentManager.location(docStart, offsetBy: block.whole.location),
                  let end = contentManager.location(docStart, offsetBy: block.whole.upperBound),
                  let range = NSTextRange(location: start, end: end) else { continue }
            var union: NSRect?
            layoutManager.enumerateTextSegments(in: range, type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
                union = union.map { $0.union(frame) } ?? frame
                return true
            }
            guard var r = union else { continue }
            r.origin.x = 0
            r.size.width = bounds.width
            r.origin.y += origin.y
            r.insetBy(dx: 0, dy: -2).fill()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == .command, event.charactersIgnoringModifiers == "n" {
            onNewEntry()
            return
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    /// Replaces the whole document and re-highlights it.
    func load(_ text: String) {
        string = text
        highlight.baseFont = font ?? Settings.shared.font
        highlight.highlightAll()
        undoManager?.removeAllActions()
    }

    func applyFont(_ newFont: NSFont) {
        font = newFont
        highlight.baseFont = newFont
        highlight.highlightAll()
    }

    func moveToEnd() {
        let end = textStorage?.length ?? 0
        setSelectedRange(NSRange(location: end, length: 0))
        scrollRangeToVisible(NSRange(location: end, length: 0))
        centerCaret()
    }
}
