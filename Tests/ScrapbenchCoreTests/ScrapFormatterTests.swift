import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct ScrapFormatterTests {
    let d1 = localDate(2026, 10, 26, 14, 35)
    let d2 = localDate(2026, 10, 26, 14, 40)
    var sep1: String { Separator.make(date: d1) }
    var sep2: String { Separator.make(date: d2) }

    @Test func openOnEmptyText() {
        var f = ScrapFormatter()
        let r = f.open(text: "", date: d1)
        #expect(r.text == "\(sep1)\n")
        #expect(r.cursor == r.text.utf16.count)
        #expect(f.sessionSeparators == [sep1])
    }

    @Test func openOnTextWithTrailingNewline() {
        var f = ScrapFormatter()
        #expect(f.open(text: "a\n", date: d1).text == "a\n\(sep1)\n")
    }

    @Test func openOnTextWithoutTrailingNewline() {
        var f = ScrapFormatter()
        #expect(f.open(text: "a", date: d1).text == "a\n\(sep1)\n")
    }

    @Test func finalizeRemovesEmptySessionSeparator() {
        var f = ScrapFormatter()
        let t = f.open(text: "a\n", date: d1).text
        #expect(f.finalize(text: t) == "a\n")
    }

    @Test func finalizeOnEmptyFileYieldsEmpty() {
        var f = ScrapFormatter()
        let t = f.open(text: "", date: d1).text
        #expect(f.finalize(text: t) == "")
    }

    @Test func finalizeKeepsSeparatorWithContent() {
        var f = ScrapFormatter()
        let t = f.open(text: "a\n", date: d1).text + "hello\n"
        #expect(f.finalize(text: t) == t)
    }

    @Test func finalizeAddsTrailingNewlineToContent() {
        var f = ScrapFormatter()
        let t = f.open(text: "a\n", date: d1).text + "hello"
        #expect(f.finalize(text: t) == t + "\n")
    }

    @Test func finalizeTreatsWhitespaceAsEmpty() {
        var f = ScrapFormatter()
        let t = f.open(text: "a\n", date: d1).text + "  \n\n"
        #expect(f.finalize(text: t) == "a\n")
    }

    @Test func finalizeKeepsForeignSeparators() {
        let sep0 = Separator.make(date: localDate(2026, 10, 25, 9, 0))
        let original = "x\n\n\(sep0)\n"
        var f = ScrapFormatter()
        let t = f.open(text: original, date: d1).text
        #expect(f.finalize(text: t) == original)
    }

    @Test func newScrapOnEmptyScrapReplacesTimestamp() {
        var f = ScrapFormatter()
        let t1 = f.open(text: "a\n", date: d1).text
        let r = f.newScrap(text: t1, date: d2)
        #expect(r.text == "a\n\(sep2)\n")
        #expect(!r.text.contains(sep1))
        #expect(f.sessionSeparators == [sep2])
        #expect(r.cursor == r.text.utf16.count)
    }

    @Test func newScrapOnNonEmptyScrapAppends() {
        var f = ScrapFormatter()
        let t1 = f.open(text: "a\n", date: d1).text + "hi\n"
        let r = f.newScrap(text: t1, date: d2)
        #expect(r.text == "a\n\(sep1)\nhi\n\(sep2)\n")
        #expect(r.cursor == r.text.utf16.count)
        #expect(f.sessionSeparators == [sep1, sep2])
    }

    @Test func newScrapWithoutTrailingNewlineAppends() {
        var f = ScrapFormatter()
        let t1 = f.open(text: "a\n", date: d1).text + "hi"
        #expect(f.newScrap(text: t1, date: d2).text == "a\n\(sep1)\nhi\n\(sep2)\n")
    }

    @Test func finalizeRemovesMultipleTrailingEmptySessionSeparators() {
        var f = ScrapFormatter()
        var t = f.open(text: "a\n", date: d1).text + "hi\n"
        t = f.newScrap(text: t, date: d2).text
        // Simulate a separator that was appended by the session and then left empty, twice.
        let sep3 = Separator.make(date: localDate(2026, 10, 26, 15, 0))
        f.sessionSeparators.append(sep3)
        t += "\(sep3)\n"
        #expect(f.finalize(text: t) == "a\n\(sep1)\nhi\n")
    }

    @Test func appendChunkToEmptyText() {
        #expect(ScrapFormatter.append(chunk: "hello", to: "") == "hello\n")
    }

    @Test func appendChunkStartsOnNewLine() {
        #expect(ScrapFormatter.append(chunk: "b", to: "a") == "a\nb\n")
        #expect(ScrapFormatter.append(chunk: "b", to: "a\n") == "a\nb\n")
    }

    @Test func appendChunkNormalisesTrailingNewlines() {
        #expect(ScrapFormatter.append(chunk: "b\n\n\n", to: "a\n") == "a\nb\n")
        #expect(ScrapFormatter.append(chunk: "x\r\ny\r\n", to: "") == "x\ny\n")
    }

    @Test func appendBlankChunkChangesNothing() {
        #expect(ScrapFormatter.append(chunk: "  \n", to: "a\n") == "a\n")
        #expect(ScrapFormatter.append(chunk: "", to: "a") == "a")
    }

    @Test func finalizePreservesEditsAbove() {
        var f = ScrapFormatter()
        let t = f.open(text: "a\n", date: d1).text.replacingOccurrences(of: "a\n", with: "b\n")
        #expect(f.finalize(text: t) == "b\n")
    }
}

@Suite struct ScrapFormatterFenceTests {
    let d1 = localDate(2026, 10, 26, 14, 35)
    let d2 = localDate(2026, 10, 26, 14, 40)
    var sep1: String { Separator.make(date: d1) }
    var sep2: String { Separator.make(date: d2) }

    @Test func finalizeClosesUnclosedFenceInSessionScrap() {
        var f = ScrapFormatter()
        let t = f.open(text: "", date: d1).text + "```sh\nls -la\n"
        #expect(f.finalize(text: t) == t + "```\n")
    }

    @Test func finalizeClosesFenceWithoutTrailingNewline() {
        var f = ScrapFormatter()
        let t = f.open(text: "", date: d1).text + "```sh\nls -la"
        #expect(f.finalize(text: t) == t + "\n```\n")
    }

    @Test func finalizeLeavesClosedFenceAlone() {
        var f = ScrapFormatter()
        let t = f.open(text: "", date: d1).text + "```sh\nls\n```\n"
        #expect(f.finalize(text: t) == t)
    }

    @Test func finalizeIgnoresUnclosedFenceFromOlderScraps() {
        var f = ScrapFormatter()
        let t = f.open(text: "```sh\nold\n", date: d1).text + "new\n"
        #expect(f.finalize(text: t) == t)
    }

    @Test func finalizeStripsEmptySeparatorBeforeClosingFence() {
        var f = ScrapFormatter()
        var t = f.open(text: "", date: d1).text + "```\nx\n"
        t = f.newScrap(text: t, date: d2).text
        // The ⌘N separator is empty and goes; the fence it was appended after still gets closed.
        #expect(f.finalize(text: t).hasSuffix("```\nx\n```\n"))
    }

    @Test func newScrapClosesFenceBeforeAppendingSeparator() {
        var f = ScrapFormatter()
        let t = f.open(text: "", date: d1).text + "```\nx\n"
        #expect(f.newScrap(text: t, date: d2).text == t + "```\n" + sep2 + "\n")
    }

    @Test func bodyOfChunkIsWhatAppendAdds() {
        let chunk = "a\r\nb\n\n"
        #expect(ScrapFormatter.body(of: chunk) == "a\nb")
        #expect(ScrapFormatter.append(chunk: chunk, to: "x") == "x\na\nb\n")
        #expect(ScrapFormatter.body(of: "  \n") == "")
    }
}
