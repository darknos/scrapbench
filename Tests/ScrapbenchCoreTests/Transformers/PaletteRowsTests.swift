import Testing
@testable import ScrapbenchCore

struct PaletteStub: Transformer {
    let id: String
    let name: String
    let group: TransformerGroup
    func canApply(to text: String) -> Bool { true }
    func apply(_ text: String) throws -> String { text }
}

@Suite struct PaletteRowsTests {
    let upper = PaletteStub(id: "case.upper", name: "UPPER CASE", group: .case)
    let sort = PaletteStub(id: "lines.sort", name: "Sort lines", group: .lines)
    let sortUnique = PaletteStub(id: "lines.sortUnique", name: "Sort lines unique", group: .lines)
    var all: [any Transformer] { [upper, sort, sortUnique] }

    @Test func emptyQueryGroupsInRegistryOrder() {
        let rows = PaletteRows.build(items: all, query: "", lastID: nil)
        #expect(rows == [.header("Case"), .item(id: "case.upper"), .header("Lines"),
                         .item(id: "lines.sort"), .item(id: "lines.sortUnique")])
    }

    @Test func emptyQueryPutsRecentFirst() {
        let rows = PaletteRows.build(items: all, query: "", lastID: "lines.sort")
        #expect(Array(rows.prefix(2)) == [.header("Recent"), .item(id: "lines.sort")])
        #expect(Array(rows.dropFirst(2)) == PaletteRows.build(items: all, query: "", lastID: nil))
    }

    @Test func recentOnlyWhenApplicable() {
        let rows = PaletteRows.build(items: [upper, sortUnique], query: "", lastID: "lines.sort")
        #expect(!rows.contains(.header("Recent")))
    }

    @Test func unknownLastIDIsIgnored() {
        #expect(PaletteRows.build(items: all, query: "", lastID: "gone")
                == PaletteRows.build(items: all, query: "", lastID: nil))
    }

    @Test func customGroupsAreHeadersToo() {
        let ai = PaletteStub(id: "script.improve", name: "Improve text", group: TransformerGroup("AI"))
        let rows = PaletteRows.build(items: [upper, ai], query: "", lastID: nil)
        #expect(rows == [.header("Case"), .item(id: "case.upper"), .header("AI"), .item(id: "script.improve")])
    }

    @Test func queryIsFlatAndRanked() {
        let rows = PaletteRows.build(items: all, query: "sort", lastID: nil)
        #expect(rows == [.item(id: "lines.sort"), .item(id: "lines.sortUnique")])
    }

    @Test func queryTieBreakPrefersLast() {
        let rows = PaletteRows.build(items: all, query: "sort", lastID: "lines.sortUnique")
        #expect(rows == [.item(id: "lines.sortUnique"), .item(id: "lines.sort")])
    }

    @Test func noMatchGivesEmptyRow() {
        #expect(PaletteRows.build(items: all, query: "zzz", lastID: nil) == [.empty])
        #expect(PaletteRows.build(items: [], query: "", lastID: nil) == [.empty])
    }
}
