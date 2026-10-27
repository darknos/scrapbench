import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct EntryFormatterTests {
    let d1 = localDate(2026, 10, 26, 14, 35)
    let d2 = localDate(2026, 10, 26, 14, 40)
    var sep1: String { Separator.make(date: d1) }
    var sep2: String { Separator.make(date: d2) }

    @Test func openOnEmptyText() {
        var f = EntryFormatter()
        let r = f.open(text: "", date: d1)
        #expect(r.text == "\(sep1)\n")
        #expect(r.cursor == r.text.utf16.count)
        #expect(f.sessionSeparators == [sep1])
    }

    @Test func openOnTextWithTrailingNewline() {
        var f = EntryFormatter()
        #expect(f.open(text: "a\n", date: d1).text == "a\n\(sep1)\n")
    }

    @Test func openOnTextWithoutTrailingNewline() {
        var f = EntryFormatter()
        #expect(f.open(text: "a", date: d1).text == "a\n\(sep1)\n")
    }

    @Test func finalizeRemovesEmptySessionSeparator() {
        var f = EntryFormatter()
        let t = f.open(text: "a\n", date: d1).text
        #expect(f.finalize(text: t) == "a\n")
    }

    @Test func finalizeOnEmptyFileYieldsEmpty() {
        var f = EntryFormatter()
        let t = f.open(text: "", date: d1).text
        #expect(f.finalize(text: t) == "")
    }

    @Test func finalizeKeepsSeparatorWithContent() {
        var f = EntryFormatter()
        let t = f.open(text: "a\n", date: d1).text + "hello\n"
        #expect(f.finalize(text: t) == t)
    }

    @Test func finalizeAddsTrailingNewlineToContent() {
        var f = EntryFormatter()
        let t = f.open(text: "a\n", date: d1).text + "hello"
        #expect(f.finalize(text: t) == t + "\n")
    }

    @Test func finalizeTreatsWhitespaceAsEmpty() {
        var f = EntryFormatter()
        let t = f.open(text: "a\n", date: d1).text + "  \n\n"
        #expect(f.finalize(text: t) == "a\n")
    }

    @Test func finalizeKeepsForeignSeparators() {
        let sep0 = Separator.make(date: localDate(2026, 10, 25, 9, 0))
        let original = "x\n\n\(sep0)\n"
        var f = EntryFormatter()
        let t = f.open(text: original, date: d1).text
        #expect(f.finalize(text: t) == original)
    }

    @Test func newEntryOnEmptyEntryReplacesTimestamp() {
        var f = EntryFormatter()
        let t1 = f.open(text: "a\n", date: d1).text
        let r = f.newEntry(text: t1, date: d2)
        #expect(r.text == "a\n\(sep2)\n")
        #expect(!r.text.contains(sep1))
        #expect(f.sessionSeparators == [sep2])
        #expect(r.cursor == r.text.utf16.count)
    }

    @Test func newEntryOnNonEmptyEntryAppends() {
        var f = EntryFormatter()
        let t1 = f.open(text: "a\n", date: d1).text + "hi\n"
        let r = f.newEntry(text: t1, date: d2)
        #expect(r.text == "a\n\(sep1)\nhi\n\(sep2)\n")
        #expect(r.cursor == r.text.utf16.count)
        #expect(f.sessionSeparators == [sep1, sep2])
    }

    @Test func newEntryWithoutTrailingNewlineAppends() {
        var f = EntryFormatter()
        let t1 = f.open(text: "a\n", date: d1).text + "hi"
        #expect(f.newEntry(text: t1, date: d2).text == "a\n\(sep1)\nhi\n\(sep2)\n")
    }

    @Test func finalizeRemovesMultipleTrailingEmptySessionSeparators() {
        var f = EntryFormatter()
        var t = f.open(text: "a\n", date: d1).text + "hi\n"
        t = f.newEntry(text: t, date: d2).text
        // Simulate a separator that was appended by the session and then left empty, twice.
        let sep3 = Separator.make(date: localDate(2026, 10, 26, 15, 0))
        f.sessionSeparators.append(sep3)
        t += "\(sep3)\n"
        #expect(f.finalize(text: t) == "a\n\(sep1)\nhi\n")
    }

    @Test func finalizePreservesEditsAbove() {
        var f = EntryFormatter()
        let t = f.open(text: "a\n", date: d1).text.replacingOccurrences(of: "a\n", with: "b\n")
        #expect(f.finalize(text: t) == "b\n")
    }
}
