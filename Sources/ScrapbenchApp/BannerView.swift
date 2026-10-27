import AppKit

/// One-line status strip above the editor for load/save problems.
final class BannerView: NSView {
    private let label = NSTextField(wrappingLabelWithString: "")
    private let button = NSButton(title: "Open Settings", target: nil, action: nil)
    var onButton: (() -> Void)?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.25).cgColor
        label.font = .systemFont(ofSize: 12)
        button.bezelStyle = .inline
        button.controlSize = .small
        button.target = self
        button.action = #selector(tapped)
        let stack = NSStackView(views: [label, button])
        stack.orientation = .horizontal
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private struct Message {
        let text: String
        let buttonTitle: String?
        let action: (() -> Void)?
    }

    private var persistent: Message?
    private var flashTimer: Timer?
    private var isFlash = false

    /// Hiding the banner from outside (after a successful save) also
    /// forgets the persistent message, so a later flash does not revive it.
    override var isHidden: Bool {
        didSet { if isHidden, !isFlash { persistent = nil } }
    }

    /// A persistent message (load/save problems): stays until hidden explicitly.
    func show(_ message: String, buttonTitle: String? = nil, action: (() -> Void)? = nil) {
        flashTimer?.invalidate()
        isFlash = false
        persistent = Message(text: message, buttonTitle: buttonTitle, action: action)
        render(persistent!)
    }

    /// A transient message: gone after 4 s or on the next key press. A
    /// persistent message underneath comes back when the flash ends.
    func flash(_ message: String) {
        flashTimer?.invalidate()
        isFlash = true
        render(Message(text: message, buttonTitle: nil, action: nil))
        flashTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
            self?.dismissFlash()
        }
    }

    func dismissFlash() {
        guard isFlash else { return }
        flashTimer?.invalidate()
        isFlash = false
        if let persistent { render(persistent) } else { isHidden = true }
    }

    private func render(_ message: Message) {
        label.stringValue = message.text
        button.isHidden = message.buttonTitle == nil
        button.title = message.buttonTitle ?? ""
        onButton = message.action
        isHidden = false
    }

    @objc private func tapped() { onButton?() }
}
