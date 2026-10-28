import AppKit
import ScrapbenchCore

/// A one-line field that reports ⌘K instead of letting the menu take it,
/// and keeps ⌘Z from reaching the editor behind the palette.
final class PaletteField: NSTextField {
    var onCommandK: () -> Void = {}

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if mods == .command, event.keyCode == 40 {
            onCommandK()
            return true
        }
        if mods.contains(.command), event.keyCode == 6, stringValue.isEmpty { return true }
        return super.performKeyEquivalent(with: event)
    }
}

/// The quick pick: a field, a hairline and a list, drawn inside the panel.
final class PaletteView: NSView {
    static let rowHeight: CGFloat = 24
    static let maxVisibleRows = 8

    let field = PaletteField()
    let table = NSTableView()
    private var heightConstraint: NSLayoutConstraint!

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        self.shadow = shadow

        field.font = Settings.shared.font
        field.placeholderString = "Transform…"
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none

        let rule = NSBox()
        rule.boxType = .separator

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = Self.rowHeight
        // The default (inset) style pads the table by 10 pt above the first
        // row, which clipped the last row of short lists.
        table.style = .plain
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.refusesFirstResponder = true

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        for view in [field, rule, scroll] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        // The list height is the only fixed part; the field, the rule and the
        // insets add their real heights, so no row is ever clipped by a
        // formula that guesses them. Below NSLayoutPriorityWindowSizeStayPut,
        // so a tall list shrinks instead of growing the window.
        heightConstraint = scroll.heightAnchor.constraint(equalToConstant: Self.rowHeight)
        heightConstraint.priority = .init(490)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rule.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 10),
            rule.leadingAnchor.constraint(equalTo: leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: rule.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            heightConstraint,
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Colours are resolved per appearance here, so a light/dark switch repaints the long-lived view.
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = Theme.default.faint.cgColor
    }

    /// Takes the current editor font so the field follows Settings, then sizes the list to the rows.
    func prepare(visibleRows count: Int) {
        field.font = Settings.shared.font
        let rows = CGFloat(min(max(count, 1), Self.maxVisibleRows))
        heightConstraint.constant = rows * Self.rowHeight
    }

    // MARK: - Cells

    static func cell(for row: PaletteRow, name: (String) -> String, detail: (String) -> String, first: Bool) -> NSView {
        let theme = Theme.default
        let cell = NSView()
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        let shortcut = NSTextField(labelWithString: "")
        shortcut.alignment = .right
        shortcut.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        shortcut.textColor = theme.muted
        switch row {
        case .header(let title):
            label.stringValue = title
            label.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
            label.textColor = theme.muted
            if !first {
                let rule = NSBox()
                rule.boxType = .separator
                rule.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(rule)
                NSLayoutConstraint.activate([
                    rule.topAnchor.constraint(equalTo: cell.topAnchor),
                    rule.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    rule.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                ])
            }
        case .item(let id):
            label.stringValue = name(id)
            label.font = Settings.shared.font
            label.textColor = theme.text
            shortcut.stringValue = detail(id)
            shortcut.lineBreakMode = .byTruncatingTail
        case .empty:
            label.stringValue = "No transformers apply to this text"
            label.font = Settings.shared.font
            label.textColor = theme.muted
        }
        for view in [label, shortcut] {
            view.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: shortcut.leadingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            shortcut.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            shortcut.widthAnchor.constraint(lessThanOrEqualTo: cell.widthAnchor, multiplier: 0.5),
            shortcut.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            shortcut.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}

final class PaletteRowView: NSTableRowView {
    private var hovered = false { didSet { needsDisplay = true } }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        guard hovered, !isSelected else { return }
        Theme.default.faint.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        Theme.default.accent.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
    }
}
