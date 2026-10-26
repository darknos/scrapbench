import Foundation
import Testing
@testable import DailyNotesCore

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
