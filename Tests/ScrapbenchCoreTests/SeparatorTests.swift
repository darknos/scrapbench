import Foundation
import Testing
@testable import ScrapbenchCore

func localDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c)!
}

@Suite struct SeparatorTests {
    @Test func makeFormatsFixedWidth() {
        let s = Separator.make(date: localDate(2026, 10, 26, 14, 35))
        #expect(s == "--------------------< 2026-10-26 14:35 >--------------------")
    }

    @Test func recognisesSeparatorLine() {
        #expect(Separator.isSeparatorLine("--------------------< 2026-10-26 14:35 >--------------------"))
        #expect(!Separator.isSeparatorLine("---"))
        #expect(!Separator.isSeparatorLine("--------------------< not a date >--------------------"))
    }
}

@Suite struct ScrapRangeTests {
    let sep1 = Separator.make(date: localDate(2026, 10, 26, 14, 35))
    let sep2 = Separator.make(date: localDate(2026, 10, 26, 14, 40))
    var text: NSString { "head\n\(sep1)\nfoo\nbar\n\n\(sep2)\nbaz\n" as NSString }

    func range(of s: String) -> NSRange { text.range(of: s) }

    @Test func middleScrapExcludesSeparatorsAndTrailingBlankLines() {
        let inBar = range(of: "bar").location + 1
        #expect(Separator.scrap(containing: inBar, in: text) == range(of: "foo\nbar"))
    }

    @Test func cursorOnSeparatorSelectsScrapBelow() {
        let onSep = range(of: sep1).location + 5
        #expect(Separator.scrap(containing: onSep, in: text) == range(of: "foo\nbar"))
    }

    @Test func lastScrapRunsToEndWithoutTrailingNewline() {
        let inBaz = range(of: "baz").location
        #expect(Separator.scrap(containing: inBaz, in: text) == range(of: "baz"))
    }

    @Test func textBeforeFirstSeparatorStartsAtZero() {
        #expect(Separator.scrap(containing: 2, in: text) == range(of: "head"))
    }

    @Test func emptyScrapIsZeroLengthAfterSeparator() {
        let t = "x\n\(sep1)\n" as NSString
        #expect(Separator.scrap(containing: t.length, in: t) == NSRange(location: t.length, length: 0))
    }

    @Test func textWithoutTrailingNewline() {
        let t = "x\n\(sep1)\ntyping" as NSString
        #expect(Separator.scrap(containing: t.length, in: t) == t.range(of: "typing"))
        #expect(Separator.scrap(containing: 0, in: t) == t.range(of: "x"))
    }

    @Test func cursorAtEndOfText() {
        #expect(Separator.scrap(containing: text.length, in: text) == range(of: "baz"))
    }
}
