import Foundation

public enum PaletteRow: Equatable, Sendable {
    /// A group name, or "Recent" for the last applied transformer.
    case header(String)
    case item(id: String)
    case empty
}

/// Builds the rows the palette shows for an already filtered list of transformers.
public enum PaletteRows {
    public static let recentHeader = "Recent"

    /// Empty query: an optional Recent block, then the groups in `items` order.
    /// Otherwise a flat list ranked by `FuzzyMatcher`, the last applied first on ties.
    public static func build(items: [any Transformer], query: String, lastID: String?) -> [PaletteRow] {
        let last = lastID.flatMap { id in items.first { $0.id == id } }
        if query.isEmpty {
            var rows: [PaletteRow] = []
            if let last {
                rows.append(.header(recentHeader))
                rows.append(.item(id: last.id))
            }
            var group: TransformerGroup?
            for item in items {
                if item.group != group {
                    rows.append(.header(item.group.rawValue))
                    group = item.group
                }
                rows.append(.item(id: item.id))
            }
            return rows.isEmpty ? [.empty] : rows
        }
        let ranked = items.enumerated()
            .compactMap { offset, item in
                FuzzyMatcher.score(query: query, candidate: item.name).map { (offset, item.id, $0) }
            }
            .sorted { a, b in
                if a.2 != b.2 { return a.2 > b.2 }
                if (a.1 == last?.id) != (b.1 == last?.id) { return a.1 == last?.id }
                return a.0 < b.0
            }
            .map { PaletteRow.item(id: $0.1) }
        return ranked.isEmpty ? [.empty] : ranked
    }
}
