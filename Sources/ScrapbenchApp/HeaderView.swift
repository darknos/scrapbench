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
        set { button.state = newValue ? .on : .off }
    }
    var onTransform: () -> Void = {}

    private let nameLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let button = NSButton(title: "Transform  ⌘K", target: nil, action: nil)

    init() {
        super.init(frame: .zero)
        let theme = Theme.default
        nameLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = theme.text
        nameLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = theme.muted

        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        button.setButtonType(.pushOnPushOff)
        button.target = self
        button.action = #selector(transformTapped)

        let labels = NSStackView(views: [nameLabel, statusLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let row = NSStackView(views: [labels, spacer, button])
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

    @objc private func transformTapped() {
        // The button toggles itself; the controller decides the real state.
        button.state = .off
        onTransform()
    }
}
