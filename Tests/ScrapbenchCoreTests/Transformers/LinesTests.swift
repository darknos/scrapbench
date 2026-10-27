import Testing
@testable import ScrapbenchCore

@Suite struct LinesTests {
    @Test func splitsAndKeepsTrailingNewline() {
        let l = Lines("a\nb\n")
        #expect(l.lines == ["a", "b"])
        #expect(l.trailingNewline)
        #expect(l.joined() == "a\nb\n")
    }

    @Test func noTrailingNewline() {
        let l = Lines("a\nb")
        #expect(l.lines == ["a", "b"])
        #expect(!l.trailingNewline)
        #expect(l.joined(["x"]) == "x")
    }

    @Test func normalisesCRLF() {
        #expect(Lines("a\r\nb\r\n").joined() == "a\nb\n")
    }

    @Test func emptyText() {
        let l = Lines("")
        #expect(l.lines == [""])
        #expect(l.joined() == "")
    }
}
