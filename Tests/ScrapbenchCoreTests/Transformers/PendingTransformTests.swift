import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct PendingTransformTests {
    let p = PendingTransform(id: "script.x", name: "X", range: NSRange(location: 10, length: 5), text: "hello")

    @Test func intactWhenTextMatches() {
        #expect(p.isIntact(in: "0123456789hello!"))
    }

    @Test func editBeforeShifts() {
        var p = p
        p.shift(edited: NSRange(location: 0, length: 2), delta: 3)
        #expect(p.range == NSRange(location: 13, length: 5))
    }

    @Test func editAfterKeeps() {
        var p = p
        p.shift(edited: NSRange(location: 15, length: 0), delta: 4)
        #expect(p.range == NSRange(location: 10, length: 5))
    }

    @Test func typingAtEndIsOutside() {
        var p = p
        p.shift(edited: NSRange(location: 15, length: 0), delta: 1)
        #expect(p.isIntact(in: "0123456789hello!x"))
    }

    @Test func overlapInvalidates() {
        var p = p
        p.shift(edited: NSRange(location: 12, length: 1), delta: 0)
        #expect(p.range == nil)
        #expect(!p.isIntact(in: "0123456789hello"))
    }

    @Test func changedTextIsNotIntact() {
        #expect(!p.isIntact(in: "0123456789HELLO"))
    }

    @Test func rangeBeyondStorageIsNotIntact() {
        #expect(!p.isIntact(in: "short"))
    }
}
