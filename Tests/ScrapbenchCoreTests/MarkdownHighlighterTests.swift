import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct MarkdownHighlighterTests {
    let h = MarkdownHighlighter()

    func all(_ src: String) -> [(TokenKind, String)] {
        let ns = src as NSString
        return h.tokens(in: ns, range: NSRange(location: 0, length: ns.length))
            .sorted { ($0.range.location, $0.range.length) < ($1.range.location, $1.range.length) }
            .map { ($0.kind, ns.substring(with: $0.range)) }
    }

    @Test func headings() {
        expectKinds(all("# Title\n## Sub\n#notatag"), [(.heading, "# Title"), (.heading, "## Sub")])
    }

    @Test func inlineStyles() {
        expectKinds(all("a **b** *c* `d` e"), [(.bold, "**b**"), (.italic, "*c*"), (.inlineCode, "`d`")])
    }

    @Test func links() {
        expectKinds(all("see [x](https://a.io) or https://b.io/p?q=1 now"), [
            (.link, "[x](https://a.io)"), (.link, "https://b.io/p?q=1"),
        ])
    }

    @Test func listsAndQuotes() {
        expectKinds(all("- a\n* b\n1. c\n> q"), [
            (.listMarker, "-"), (.listMarker, "*"), (.listMarker, "1."), (.quote, "> q"),
        ])
    }

    @Test func checkboxes() {
        expectKinds(all("- [ ] todo\n- [x] done"), [
            (.listMarker, "-"), (.checkboxDone, "- [x] done"),
        ])
    }

    @Test func separator() {
        let sep = Separator.make(date: localDate(2026, 10, 26, 14, 35))
        expectKinds(all("a\n\n\(sep)\nb"), [
            (.separatorDashes, Separator.dashes), (.separatorDate, "< 2026-10-26 14:35 >"), (.separatorDashes, Separator.dashes),
        ])
    }

    @Test func codeBlockGetsBackgroundFencesAndGrammar() {
        let src = "x\n```json\n{\"a\": 1}\n```\ny"
        expectKinds(all(src), [
            (.codeFence, "```json"), (.codeBlockBackground, "```json\n{\"a\": 1}\n```"),
            (.key, "\"a\""), (.number, "1"), (.codeFence, "```"),
        ])
    }

    @Test func unknownLanguageGetsBackgroundOnly() {
        expectKinds(all("```foo\n# not heading\n```"), [
            (.codeFence, "```foo"), (.codeBlockBackground, "```foo\n# not heading\n```"), (.codeFence, "```"),
        ])
    }

    @Test func markdownRulesDoNotApplyInsideCodeBlock() {
        let got = all("```json\n# not heading **x**\n```")
        #expect(!got.map(\.0).contains(.heading))
        #expect(!got.map(\.0).contains(.bold))
    }

    @Test func unclosedBlockRunsToEnd() {
        expectKinds(all("```sql\nselect 1"), [
            (.codeFence, "```sql"), (.codeBlockBackground, "```sql\nselect 1"), (.keyword, "select"), (.number, "1"),
        ])
    }

    @Test func partialRangeReturnsOnlyIntersectingTokens() {
        let src = "# one\ntext\n# two\n"
        let ns = src as NSString
        let twoRange = ns.range(of: "# two")
        let got = h.tokens(in: ns, range: twoRange).map { ns.substring(with: $0.range) }
        #expect(got == ["# two"])
    }

    @Test func partialRangeInsideCodeBlockStillHighlightsCode() {
        let src = "```json\n{\"a\": 1}\n```\n"
        let ns = src as NSString
        let got = h.tokens(in: ns, range: ns.range(of: "1")).map { $0.kind }
        #expect(got.contains(.number))
        #expect(got.contains(.codeBlockBackground))
    }
}
