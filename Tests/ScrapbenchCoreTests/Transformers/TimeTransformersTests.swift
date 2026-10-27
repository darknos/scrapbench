import Testing
@testable import ScrapbenchCore

@Suite struct TimeTransformersTests {
    let t = EpochISOTransformer()

    @Test func epochSecondsToISO() throws {
        #expect(try t.apply("1793127120") == "2026-10-27T18:52:00Z")
        #expect(try t.apply(" 1793127120 \n") == "2026-10-27T18:52:00Z")
    }

    @Test func epochMillisKeepsFraction() throws {
        #expect(try t.apply("1793127120123") == "2026-10-27T18:52:00.123Z")
    }

    @Test func isoToEpoch() throws {
        #expect(try t.apply("2026-10-27T18:52:00Z") == "1793127120")
        #expect(try t.apply("2026-10-27T18:52:00.500Z") == "1793127120")
    }

    @Test func isoWithOffsetToEpoch() throws {
        #expect(try t.apply("2026-10-27T20:52:00+02:00") == "1793127120")
    }

    @Test func applicability() {
        #expect(t.canApply(to: "1793127120"))
        #expect(t.canApply(to: "2026-10-27T18:52:00Z"))
        #expect(!t.canApply(to: "123"))
        #expect(!t.canApply(to: "2026-10-27"))
        #expect(throws: TransformError("not a timestamp")) { try t.apply("hello") }
    }
}
