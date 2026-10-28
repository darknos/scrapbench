import AppKit
import ScrapbenchCore

final class EditorTextView: NSTextView {
    static let topPadding: CGFloat = 12
    static let sidePadding: CGFloat = 40

    var onEscape: () -> Void = {}
    var onNewScrap: () -> Void = {}
    var onSave: () -> Void = {}
    var onKeyDown: () -> Void = {}
    var onTransform: () -> Void = {}
    var onRepeatTransform: () -> Void = {}
    var onToggleWrap: () -> Void = {}

    /// Off: the container is unbounded and the scroll view scrolls sideways;
    /// on: the container follows the view width, as a plain text view does.
    var wrapsLines = true {
        didSet {
            guard wrapsLines != oldValue, let container = textContainer, let scroll = enclosingScrollView else { return }
            let huge = CGFloat.greatestFiniteMagnitude
            if wrapsLines {
                container.widthTracksTextView = true
                isHorizontallyResizable = false
                autoresizingMask = [.width]
                scroll.hasHorizontalScroller = false
                let width = scroll.contentView.bounds.width
                container.size = NSSize(width: width - 2 * textContainerInset.width, height: huge)
                setFrameSize(NSSize(width: width, height: frame.height))
            } else {
                container.widthTracksTextView = false
                container.size = NSSize(width: huge, height: huge)
                isHorizontallyResizable = true
                maxSize = NSSize(width: huge, height: huge)
                autoresizingMask = []
                scroll.hasHorizontalScroller = true
            }
            textLayoutManager?.textViewportLayoutController.layoutViewport()
            needsLayout = true
            needsDisplay = true
            scrollRangeToVisible(selectedRange())
        }
    }
    private(set) var highlight: HighlightCoordinator!
    /// True from open until the first interaction: the end of the document is
    /// kept centred through layout changes that happen after the first show.
    private var anchorsEnd = false

    /// Empty space below the text, part of the view itself. Scroll view
    /// `contentInsets` would do the same, but AppKit then routes mouse events
    /// in the inset area to a private background view and breaks selection.
    var bottomPadding: CGFloat = 0 {
        didSet {
            guard bottomPadding != oldValue else { return }
            textContainerInset = NSSize(width: Self.sidePadding, height: (Self.topPadding + bottomPadding) / 2)
        }
    }

    /// `textContainerInset` is symmetric; shifting the origin up puts the
    /// whole surplus below the text.
    override var textContainerOrigin: NSPoint {
        NSPoint(x: textContainerInset.width, y: Self.topPadding)
    }

    /// Minimal auto-scroll: the caret stops at the real bottom edge. The
    /// default keeps extra space below it, so typing after a centred open
    /// jumps the view before the caret has reached the bottom.
    override func scrollToVisible(_ rect: NSRect) -> Bool {
        guard let scroll = enclosingScrollView else { return super.scrollToVisible(rect) }
        let clip = scroll.contentView
        let visible = clip.bounds
        var origin = visible.origin
        if rect.maxY > visible.maxY {
            origin.y = rect.maxY - visible.height
        } else if rect.minY < visible.minY {
            origin.y = rect.minY
        }
        if rect.maxX > visible.maxX {
            origin.x = rect.maxX - visible.width + Self.sidePadding
        } else if rect.minX < visible.minX {
            origin.x = max(0, rect.minX - Self.sidePadding)
        }
        if origin == visible.origin { return false }
        clip.scroll(to: clip.constrainBoundsRect(NSRect(origin: origin, size: visible.size)).origin)
        scroll.reflectScrolledClipView(clip)
        return true
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        guard let rect = rect(for: range) else { return super.scrollRangeToVisible(range) }
        _ = scrollToVisible(rect)
    }

    /// Rect of `range` in view coordinates, laying the text out first.
    /// `firstRect(forCharacterRange:)` returns a zero rect right after an
    /// edit whose line is not laid out yet, which made auto-scroll jump.
    private func rect(for range: NSRange) -> NSRect? {
        guard let layoutManager = textLayoutManager, let contentManager = layoutManager.textContentManager else { return nil }
        let docStart = contentManager.documentRange.location
        guard let start = contentManager.location(docStart, offsetBy: range.location),
              let end = contentManager.location(start, offsetBy: range.length),
              let textRange = NSTextRange(location: start, end: end) else { return nil }
        layoutManager.ensureLayout(for: textRange)
        var result: NSRect?
        layoutManager.enumerateTextSegments(in: textRange, type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
            result = frame
            return false
        }
        if result == nil, let fragment = layoutManager.textLayoutFragment(for: start) {
            result = fragment.layoutFragmentFrame
        }
        guard var rect = result else { return nil }
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    /// `centresEnd` reserves half a view below the text so the document end
    /// can sit at the centre on open (the bench panel); off for plain viewers.
    static func make(centresEnd: Bool = true) -> (scroll: NSScrollView, editor: EditorTextView) {
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
        editor.textContainerInset = NSSize(width: sidePadding, height: topPadding)
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
        if centresEnd {
            scroll.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: scroll, queue: .main) { [weak editor] _ in
                editor?.bottomPadding = scroll.contentView.bounds.height / 2
            }
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
            r.origin.x = visibleRect.minX
            r.size.width = visibleRect.width
            r.origin.y += origin.y
            r.insetBy(dx: 0, dy: -2).fill()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }

    override func keyDown(with event: NSEvent) {
        anchorsEnd = false
        onKeyDown()
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 40 || event.charactersIgnoringModifiers == "k" {
            if mods == .command { onTransform(); return }
            if mods == [.command, .shift] { onRepeatTransform(); return }
        }
        // keyCode 45 is "n" on every layout; charactersIgnoringModifiers is not under Cyrillic.
        if mods == .command, event.keyCode == 45 || event.charactersIgnoringModifiers == "n" {
            onNewScrap()
            return
        }
        if mods == .command, event.keyCode == 1 || event.charactersIgnoringModifiers == "s" {
            onSave()
            return
        }
        if mods == [.command, .option], event.keyCode == 0 || event.charactersIgnoringModifiers == "a" {
            selectScrap()
            return
        }
        if mods == [.command, .option], event.keyCode == 13 || event.charactersIgnoringModifiers == "w" {
            onToggleWrap()
            return
        }
        super.keyDown(with: event)
    }

    /// Tab with a selection indents the selected lines; Shift-Tab outdents the
    /// current or selected lines. A bare Tab inserts one indent unit from Settings.
    override func insertTab(_ sender: Any?) {
        let unit = Settings.shared.indentUnit.text
        if selectedRange().length > 0 {
            shiftLines { Indentation.indent($0, unit: unit) }
        } else if unit == "\t" {
            super.insertTab(sender)
        } else {
            insertText(unit, replacementRange: selectedRange())
        }
    }

    override func insertBacktab(_ sender: Any?) {
        let unit = Settings.shared.indentUnit.text
        shiftLines { Indentation.outdent($0, unit: unit) }
    }

    private func shiftLines(by transform: (String) -> String) {
        let storage = string as NSString
        var lines = storage.lineRange(for: selectedRange())
        if lines.length > 0, storage.character(at: lines.upperBound - 1) == 0x0A { lines.length -= 1 }
        let result = transform(storage.substring(with: lines))
        guard result != storage.substring(with: lines) else { return }
        replace(lines, with: result)
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

    /// The selection, or the current scrap selected in place; nil when
    /// there is nothing to transform.
    func transformTarget() -> (range: NSRange, text: String)? {
        let storage = string as NSString
        var range = selectedRange()
        if range.length == 0 {
            range = Separator.scrap(containing: range.location, in: storage)
            guard range.length > 0 else { return nil }
            setSelectedRange(range)
        }
        return (range, storage.substring(with: range))
    }

    /// One undoable replacement; the new text becomes the selection. With
    /// `select: false` the caret stays where it was (moved past the edit if
    /// it sat after it) and nothing scrolls, for results that land while
    /// the user is typing elsewhere.
    func replace(_ range: NSRange, with text: String, select: Bool = true) {
        let caret = selectedRange()
        guard shouldChangeText(in: range, replacementString: text) else { return }
        textStorage?.replaceCharacters(in: range, with: text)
        didChangeText()
        let length = (text as NSString).length
        if select {
            setSelectedRange(NSRange(location: range.location, length: length))
            scrollRangeToVisible(NSRange(location: range.location, length: 0))
        } else if caret.location >= range.upperBound {
            setSelectedRange(NSRange(location: caret.location + length - range.length, length: caret.length))
        } else if caret.location > range.location {
            setSelectedRange(NSRange(location: range.location + length, length: 0))
        }
    }

    /// Selects the scrap (text between separators) around the cursor.
    func selectScrap() {
        let range = Separator.scrap(containing: selectedRange().location, in: string as NSString)
        setSelectedRange(range)
        scrollRangeToVisible(NSRange(location: range.location, length: 0))
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
        endY += textContainerOrigin.y
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
