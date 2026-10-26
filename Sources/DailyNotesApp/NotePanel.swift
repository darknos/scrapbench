import AppKit

/// Spotlight-style floating panel. Non-activating, so the previously active
/// app keeps its menu bar and gets focus back when the panel hides.
final class NotePanel: NSPanel {
    let editor: EditorTextView
    let banner = BannerView()
    var onClose: () -> Void = {}

    init() {
        let (scroll, editor) = EditorTextView.make()
        self.editor = editor
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .nonactivatingPanel, .resizable, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 400, height: 240)
        backgroundColor = .windowBackgroundColor

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView(views: [banner, scroll])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        banner.isHidden = true
        contentView = container

        setFrameAutosaveName("NotePanel")
        if !setFrameUsingName("NotePanel") { center() }
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        // Clicking outside behaves like Esc. Guard against the resign that
        // our own orderOut triggers.
        if isVisible { onClose() }
    }

    func show() {
        banner.isHidden = true
        makeKeyAndOrderFront(nil)
        makeFirstResponder(editor)
    }
}
