import Testing
@testable import ScrapbenchCore

@Suite struct IndentationTests {
    @Test func indentAddsFourSpacesToEachNonBlankLine() {
        #expect(Indentation.indent("a\n\nb") == "    a\n\n    b")
    }

    @Test func indentUsesTabsWhenAnyLineStartsWithOne() {
        #expect(Indentation.indent("\ta\nb") == "\t\ta\n\tb")
    }

    @Test func indentKeepsTrailingNewline() {
        #expect(Indentation.indent("a\n") == "    a\n")
    }

    @Test func outdentRemovesOneLevelOfSpaces() {
        #expect(Indentation.outdent("        a\n    b\n  c\nd") == "    a\nb\nc\nd")
    }

    @Test func outdentRemovesOneTab() {
        #expect(Indentation.outdent("\t\ta\n\tb") == "\ta\nb")
    }

    @Test func outdentLeavesUnindentedTextAlone() {
        #expect(Indentation.outdent("a\nb\n") == "a\nb\n")
    }
}
