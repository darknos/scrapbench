import AppKit
import ScrapbenchCore

/// Borderless child window of the bench panel: a search field over the list
/// of transformers that apply to the current target.
final class CommandPalette: NSPanel, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private enum Row {
        case header(TransformerGroup)
        case item(any Transformer)
        case empty
    }

    private let items: [any Transformer]
    private let onPick: (any Transformer) -> Void
    private let onClose: () -> Void
    private weak var bench: NSWindow?
    private var rows: [Row] = []
    private var closed = false

    private let field = NSTextField()
    private let table = NSTableView()

    init(parent: NSWindow, items: [any Transformer],
         onPick: @escaping (any Transformer) -> Void, onClose: @escaping () -> Void) {
        self.items = items
        self.onPick = onPick
        self.onClose = onClose
        self.bench = parent
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = parent.level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 1
        container.layer?.borderColor = Theme.default.faint.cgColor

        field.font = Settings.shared.font
        field.placeholderString = "Transform…"
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self

        let rule = NSBox()
        rule.boxType = .separator

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 24
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked)
        table.refusesFirstResponder = true

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        for view in [field, rule, scroll] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            rule.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 10),
            rule.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: rule.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
        contentView = container
    }

    override var canBecomeKey: Bool { true }

    func show() {
        guard let parent = bench else { return }
        let origin = NSPoint(x: parent.frame.midX - frame.width / 2, y: parent.frame.maxY - frame.height - 48)
        setFrameOrigin(origin)
        parent.addChildWindow(self, ordered: .above)
        reload()
        makeKeyAndOrderFront(nil)
        makeFirstResponder(field)
    }

    override func resignKey() {
        super.resignKey()
        dismiss()
    }

    private func dismiss() {
        guard !closed else { return }
        closed = true
        bench?.removeChildWindow(self)
        orderOut(nil)
        bench?.makeKey()
        onClose()
    }

    // MARK: - Rows

    /// Grouped with headers for an empty query; a flat ranked list otherwise.
    private func reload() {
        let query = field.stringValue
        let matching = FuzzyMatcher.rank(items, query: query, name: \.name)
        if matching.isEmpty {
            rows = [.empty]
        } else if query.isEmpty {
            rows = []
            var lastGroup: TransformerGroup?
            for item in matching {
                if item.group != lastGroup {
                    rows.append(.header(item.group))
                    lastGroup = item.group
                }
                rows.append(.item(item))
            }
        } else {
            rows = matching.map(Row.item)
        }
        table.reloadData()
        if let first = itemRows.first { select(first) }
    }

    private var itemRows: [Int] {
        rows.indices.filter { if case .item = rows[$0] { return true } else { return false } }
    }

    private func select(_ row: Int) {
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    private func moveSelection(by delta: Int) {
        let candidates = itemRows
        guard !candidates.isEmpty else { return }
        let current = candidates.firstIndex(of: table.selectedRow) ?? 0
        select(candidates[max(0, min(candidates.count - 1, current + delta))])
    }

    private func pickSelected() {
        guard table.selectedRow >= 0, case .item(let transformer) = rows[table.selectedRow] else { return }
        dismiss()
        onPick(transformer)
    }

    @objc private func rowClicked() {
        guard table.clickedRow >= 0, case .item = rows[table.clickedRow] else { return }
        select(table.clickedRow)
        pickSelected()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) { reload() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)): moveSelection(by: -1)
        case #selector(NSResponder.moveDown(_:)): moveSelection(by: 1)
        case #selector(NSResponder.insertNewline(_:)): pickSelected()
        case #selector(NSResponder.cancelOperation(_:)): dismiss()
        default: return false
        }
        return true
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .item = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PaletteRowView() }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        let theme = Theme.default
        switch rows[row] {
        case .header(let group):
            label.stringValue = group.rawValue
            label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
            label.textColor = theme.muted
        case .item(let transformer):
            label.stringValue = transformer.name
            label.font = Settings.shared.font
            label.textColor = theme.text
        case .empty:
            label.stringValue = "No transformers apply to this text"
            label.font = Settings.shared.font
            label.textColor = theme.muted
        }
        let cell = NSView()
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}

private final class PaletteRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        Theme.default.accent.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
    }
}
