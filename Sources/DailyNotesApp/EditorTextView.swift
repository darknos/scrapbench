import AppKit
import DailyNotesCore

final class EditorTextView: NSTextView {
    var onEscape: () -> Void = {}
    var onNewEntry: () -> Void = {}
    private(set) var highlight: HighlightCoordinator!
    /// True from open until the first interaction: the end of the document is
    /// kept centred through layout changes that happen after the first show.
    private var anchorsEnd = false

    /// Auto-scroll that treats the bottom inset as usable space, so typing
    /// flows down to the real bottom edge instead of stopping at the middle.
    override func scrollToVisible(_ rect: NSRect) -> Bool {
        guard let scroll = enclosingScrollView else { return super.scrollToVisible(rect) }
        let clip = scroll.contentView
        let visible = clip.bounds
        var origin = visible.origin
        if rect.maxY > visible.maxY {
            origin.y = rect.maxY - visible.height
        } else if rect.minY < visible.minY {
            origin.y = rect.minY
        } else {
            return false
        }
        clip.scroll(to: clip.constrainBoundsRect(NSRect(origin: origin, size: visible.size)).origin)
        scroll.reflectScrolledClipView(clip)
        return true
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        guard let window else { return super.scrollRangeToVisible(range) }
        let rect = convert(window.convertFromScreen(firstRect(forCharacterRange: range, actualRange: nil)), from: nil)
        _ = scrollToVisible(rect)
    }

    static func make() -> (scroll: NSScrollView, editor: EditorTextView) {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = false
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
        scroll.contentView.postsBoundsChangedNotifications = true
        var clipWidth = scroll.contentView.bounds.width
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak editor] _ in
            guard let editor else { return }
            let width = scroll.contentView.bounds.width
            if width != clipWidth {
                clipWidth = width
                // The scroller style (and so the text width) is only settled
                // after the first display; everything reflows when it changes.
                if editor.anchorsEnd { DispatchQueue.main.async { editor.centerEnd() }; return }
            }
            DispatchQueue.main.async { editor.highlightViewport() }
        }
        // A bottom inset of half a view lets the last line sit at the centre on open.
        scroll.automaticallyAdjustsContentInsets = false
        scroll.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: scroll, queue: .main) { _ in
            let inset = scroll.contentView.bounds.height / 2
            scroll.contentInsets.bottom = inset
            scroll.scrollerInsets.bottom = -inset   // keep the scroller full height
        }
        return (scroll, editor)
    }

    override func didChangeText() {
        super.didChangeText()
        anchorsEnd = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        anchorsEnd = false
        super.mouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        anchorsEnd = false
        super.scrollWheel(with: event)
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
        anchorsEnd = false
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // keyCode 45 is "n" on every layout; charactersIgnoringModifiers is not under Cyrillic.
        if mods == .command, event.keyCode == 45 || event.charactersIgnoringModifiers == "n" {
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
        highlight.isLoading = true
        string = text
        highlight.isLoading = false
        highlight.baseFont = font ?? Settings.shared.font
        highlight.highlightAll()
        undoManager?.removeAllActions()
    }

    /// Replaces only the part that differs from the current text, as one
    /// undoable edit, so layout and highlighting above it stay valid.
    func replaceTail(with text: String) {
        let old = string as NSString
        let new = text as NSString
        let common = old.commonPrefix(with: text, options: .literal).utf16.count
        let range = NSRange(location: common, length: old.length - common)
        let replacement = new.substring(from: common)
        guard range.length > 0 || !replacement.isEmpty,
              shouldChangeText(in: range, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
    }

    /// Puts the cursor at the end and scrolls just enough to show it.
    func revealEnd() {
        let end = NSRange(location: textStorage?.length ?? 0, length: 0)
        setSelectedRange(end)
        scrollRangeToVisible(end)
    }

    func applyFont(_ newFont: NSFont) {
        font = newFont
        highlight.baseFont = newFont
        highlight.highlightAll()
    }

    /// Colours the visible region plus a margin; cheap when already done.
    func highlightViewport() {
        guard let layoutManager = textLayoutManager, let contentManager = layoutManager.textContentManager,
              let viewport = layoutManager.textViewportLayoutController.viewportRange else { return }
        let docStart = contentManager.documentRange.location
        let start = contentManager.offset(from: docStart, to: viewport.location)
        let length = contentManager.offset(from: viewport.location, to: viewport.endLocation)
        let margin = 10_000
        highlight.ensureHighlighted(NSRange(location: max(0, start - margin), length: length + 2 * margin))
    }

    func moveToEnd() {
        let end = textStorage?.length ?? 0
        setSelectedRange(NSRange(location: end, length: 0))
        anchorsEnd = true
        DispatchQueue.main.async { [weak self] in self?.centerEnd() }
    }

    /// Scrolls so the end of the document sits in the middle of the view.
    /// TextKit 2 lays out lazily and estimates the height of everything else,
    /// so the end keeps moving while the viewport around it settles; the
    /// position is re-checked over a few run loop passes.
    private func centerEnd(pass: Int = 0) {
        guard let scroll = enclosingScrollView, let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager else { return }
        let doc = layoutManager.documentRange
        if pass == 0 {
            let length = contentManager.offset(from: doc.location, to: doc.endLocation)
            if let tailStart = contentManager.location(doc.endLocation, offsetBy: -min(4000, length)),
               let tail = NSTextRange(location: tailStart, end: doc.endLocation) {
                layoutManager.ensureLayout(for: tail)
            }
        }
        layoutManager.textViewportLayoutController.layoutViewport()
        var endY = layoutManager.usageBoundsForTextContainer.maxY
        if let fragment = layoutManager.textLayoutFragment(for: doc.endLocation) {
            endY = fragment.layoutFragmentFrame.maxY
        }
        endY += textContainerInset.height
        let clip = scroll.contentView
        let visible = clip.bounds
        let target = endY - visible.height / 2
        let moved = abs(visible.origin.y - target) > 0.5
        if moved {
            let origin = NSPoint(x: visible.origin.x, y: target)
            clip.scroll(to: clip.constrainBoundsRect(NSRect(origin: origin, size: visible.size)).origin)
            scroll.reflectScrolledClipView(clip)
            layoutManager.textViewportLayoutController.layoutViewport()
        }
        highlightViewport()
        needsDisplay = true
        guard pass < 6, moved || pass < 2 else { return }
        DispatchQueue.main.async { [weak self] in self?.centerEnd(pass: pass + 1) }
    }
}
