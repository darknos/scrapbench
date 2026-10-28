import Testing
@testable import ScrapbenchCore

@Suite struct IndentationTests {
    @Test func indentAddsTheUnitToEachNonBlankLine() {
        #expect(Indentation.indent("a\n\nb", unit: "  ") == "  a\n\n  b")
        #expect(Indentation.indent("a", unit: "\t") == "\ta")
    }

    @Test func indentKeepsTrailingNewline() {
        #expect(Indentation.indent("a\n", unit: "    ") == "    a\n")
    }

    @Test func outdentRemovesUpToOneUnitOfSpaces() {
        #expect(Indentation.outdent("    a\n  b\n c\nd", unit: "  ") == "  a\nb\nc\nd")
        #expect(Indentation.outdent("        a\n   b", unit: "    ") == "    a\nb")
    }

    @Test func outdentRemovesOneTabWhateverTheUnit() {
        #expect(Indentation.outdent("\t\ta\n\tb", unit: "  ") == "\ta\nb")
    }

    @Test func outdentWithTabUnitStillRemovesSpaces() {
        #expect(Indentation.outdent("    a", unit: "\t") == "a")
    }

    @Test func outdentLeavesUnindentedTextAlone() {
        #expect(Indentation.outdent("a\nb\n", unit: "  ") == "a\nb\n")
    }
}
