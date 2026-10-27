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

    func show(_ message: String, buttonTitle: String? = nil, action: (() -> Void)? = nil) {
        label.stringValue = message
        button.isHidden = buttonTitle == nil
        button.title = buttonTitle ?? ""
        onButton = action
        isHidden = false
    }

    @objc private func tapped() { onButton?() }
}
