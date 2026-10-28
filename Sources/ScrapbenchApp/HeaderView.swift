import AppKit

/// Strip at the top of the panel: file name, save status and the Transform button.
final class HeaderView: NSView {
    static let height: CGFloat = 52
    /// Room for the system close button that sits over the transparent title bar.
    private static let leadingInset: CGFloat = 16 + 24

    var fileName: String {
        get { nameLabel.stringValue }
        set { nameLabel.stringValue = newValue }
    }
    var status: String {
        get { statusLabel.stringValue }
        set { statusLabel.stringValue = newValue }
    }
    var isPaletteOpen: Bool {
        get { button.state == .on }
        set { Self.set(button, on: newValue) }
    }
    var onTransform: () -> Void = {}
    var isWrapOn: Bool {
        get { wrapButton.state == .on }
        set { Self.set(wrapButton, on: newValue) }
    }
    var onToggleWrap: () -> Void = {}

    private let nameLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let button = NSButton(title: "Transform  ⌘K", target: nil, action: nil)
    private let wrapButton = NSButton(title: "", target: nil, action: nil)

    init() {
        super.init(frame: .zero)
        let theme = Theme.default
        nameLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = theme.text
        nameLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = theme.muted

        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        button.setButtonType(.pushOnPushOff)
        button.target = self
        button.action = #selector(transformTapped)
        wrapButton.bezelStyle = .rounded
        wrapButton.controlSize = .regular
        wrapButton.image = NSImage(systemSymbolName: "arrow.turn.down.left", accessibilityDescription: "Word wrap")
        wrapButton.imagePosition = .imageOnly
        wrapButton.setButtonType(.pushOnPushOff)
        wrapButton.toolTip = "Word wrap  ⌘⌥W"
        wrapButton.target = self
        wrapButton.action = #selector(wrapTapped)

        let labels = NSStackView(views: [nameLabel, statusLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let row = NSStackView(views: [labels, spacer, wrapButton, button])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 0, left: Self.leadingInset, bottom: 0, right: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: Self.height),
        ])
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Whether `view` (from a hit test) is the Transform button or part of it.
    func isTransformControl(_ view: NSView?) -> Bool {
        view?.isDescendant(of: button) == true
    }

    /// On-state in the app's accent instead of the system accent colour.
    private static func set(_ button: NSButton, on: Bool) {
        button.state = on ? .on : .off
        button.bezelColor = on ? Theme.default.accent : nil
        button.contentTintColor = on ? .white : nil
    }

    @objc private func wrapTapped() {
        // The button toggled itself; the setting is the source of truth and sets it back.
        Self.set(wrapButton, on: wrapButton.state != .on)
        onToggleWrap()
    }

    @objc private func transformTapped() {
        // The button toggles itself; the controller decides the real state.
        Self.set(button, on: false)
        onTransform()
    }
}
