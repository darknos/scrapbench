import AppKit
import ScrapbenchCore

/// Opens and closes the quick pick inside the panel and turns its keys and clicks into picks.
final class PaletteController: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var onPick: (any Transformer) -> Void = { _ in }
    var onPickLast: () -> Void = {}
    var onClose: () -> Void = {}
    /// Esc only: the pick was abandoned, not just closed.
    var onCancel: () -> Void = {}
    private(set) var isOpen = false

    private let view = PaletteView()
    private weak var host: NSView?
    private weak var editor: NSResponder?
    private var items: [any Transformer] = []
    private var byID: [String: any Transformer] = [:]
    private var lastID: String?
    private var rows: [PaletteRow] = []

    init(host: NSView, anchorTo header: NSView, returnFocusTo editor: NSResponder) {
        self.host = host
        self.editor = editor
        super.init()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(view, positioned: .above, relativeTo: nil)
        // Both below NSLayoutPriorityWindowSizeStayPut (500), or the hidden palette widens the window to 700 pt.
        let preferred = view.widthAnchor.constraint(equalTo: host.widthAnchor, multiplier: 0.6)
        preferred.priority = .init(490)
        let minimum = view.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        minimum.priority = .init(495)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            view.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            preferred, minimum,
            view.widthAnchor.constraint(lessThanOrEqualTo: host.widthAnchor, constant: -32),
        ])
        view.field.delegate = self
        view.field.onCommandK = { [weak self] in self?.pickLast() }
        view.table.dataSource = self
        view.table.delegate = self
        view.table.target = self
        view.table.action = #selector(rowClicked)
    }

    func open(items: [any Transformer], lastID: String?) {
        self.items = items
        self.byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.lastID = lastID
        view.field.stringValue = ""
        reload()
        isOpen = true
        view.isHidden = false
        host?.window?.makeFirstResponder(view.field)
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        view.isHidden = true
        host?.window?.makeFirstResponder(editor)
        onClose()
    }

    /// Closes on a click outside the palette and returns true; the click then goes on to its target.
    func handleMouseDown(at pointInWindow: NSPoint) -> Bool {
        guard isOpen, let host else { return false }
        let point = host.convert(pointInWindow, from: nil)
        if view.frame.contains(point) { return false }
        close()
        return true
    }

    // MARK: - Rows

    private func reload() {
        rows = PaletteRows.build(items: items, query: view.field.stringValue, lastID: lastID)
        view.setVisibleRows(rows.count)
        view.table.reloadData()
        if let first = itemRows.first { select(first) }
    }

    private var itemRows: [Int] {
        rows.indices.filter { if case .item = rows[$0] { return true } else { return false } }
    }

    private func select(_ row: Int) {
        view.table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        view.table.scrollRowToVisible(row)
    }

    private func moveSelection(by delta: Int) {
        let candidates = itemRows
        guard !candidates.isEmpty else { return }
        let current = candidates.firstIndex(of: view.table.selectedRow) ?? 0
        select(candidates[max(0, min(candidates.count - 1, current + delta))])
    }

    private func pickSelected() {
        let selected = view.table.selectedRow
        guard selected >= 0, case .item(let id) = rows[selected], let transformer = byID[id] else { return }
        close()
        onPick(transformer)
    }

    private func pickLast() {
        guard let lastID, byID[lastID] != nil else { return }
        close()
        onPickLast()
    }

    @objc private func rowClicked() {
        let clicked = view.table.clickedRow
        guard clicked >= 0, case .item = rows[clicked] else { return }
        select(clicked)
        pickSelected()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) { reload() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.insertBacktab(_:)): moveSelection(by: -1)
        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.insertTab(_:)): moveSelection(by: 1)
        case #selector(NSResponder.insertNewline(_:)): pickSelected()
        case #selector(NSResponder.cancelOperation(_:)): close(); onCancel()
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
        PaletteView.cell(for: rows[row], name: { [byID] in byID[$0]?.name ?? $0 }, first: row == 0)
    }
}
