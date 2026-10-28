import AppKit

/// Spotlight-style floating panel. Non-activating, so the previously active
/// app keeps its menu bar and gets focus back when the panel hides.
final class BenchPanel: NSPanel {
    let editor: EditorTextView
    let header = HeaderView()
    let banner = BannerView()
    private(set) var palette: PaletteController!
    var onClose: () -> Void = {}
    var onFocusLost: () -> Void = {}

    init() {
        let (scroll, editor) = EditorTextView.make()
        self.editor = editor
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .nonactivatingPanel, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Scrapbench"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        stayOnTop = Settings.shared.stayOnTop
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 400, height: 240 + HeaderView.height)
        backgroundColor = .windowBackgroundColor

        let container = NSView()
        let stack = NSStackView(views: [header, banner, scroll])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack, positioned: .below, relativeTo: nil)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        banner.isHidden = true
        // After the stack is in place, so the palette's constraints to the header have a common ancestor.
        palette = PaletteController(host: container, anchorTo: header, returnFocusTo: editor)
        contentView = container

        setFrameAutosaveName("BenchPanel")
        if !setFrameUsingName("BenchPanel") { center() }
    }

    /// Floating keeps the bench over every window; off, it is an ordinary window that other apps can cover.
    var stayOnTop: Bool = true {
        didSet { level = stayOnTop ? .floating : .normal }
    }

    override var canBecomeKey: Bool { true }

    /// The close button behaves like Esc: save and hide, never destroy the panel.
    override func close() {
        onClose()
    }

    /// A click outside the open palette closes it and then lands where it was aimed,
    /// except on the Transform button, whose action would reopen the palette.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown,
           palette.handleMouseDown(at: event.locationInWindow),
           header.isTransformControl(contentView?.superview?.hitTest(event.locationInWindow)) {
            return
        }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        palette.close()
        // The panel stays up when focus moves elsewhere; guard against the
        // resign that our own orderOut triggers.
        if isVisible { onFocusLost() }
    }

    func show() {
        palette.close()
        banner.isHidden = true
        makeKeyAndOrderFront(nil)
        makeFirstResponder(editor)
    }
}
