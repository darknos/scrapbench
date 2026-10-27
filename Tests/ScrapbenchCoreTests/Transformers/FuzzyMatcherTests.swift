import Testing
@testable import ScrapbenchCore

@Suite struct FuzzyMatcherTests {
    @Test func subsequenceAndNoMatch() {
        #expect(FuzzyMatcher.score(query: "b64", candidate: "Base64 decode") != nil)
        #expect(FuzzyMatcher.score(query: "xyz", candidate: "Base64 decode") == nil)
        #expect(FuzzyMatcher.score(query: "", candidate: "anything") != nil)
    }

    @Test func ranking() {
        let names = ["Sort lines unique", "Split by comma", "Sort lines", "Unique lines"]
        #expect(FuzzyMatcher.rank(names, query: "sort", name: { $0 }) == ["Sort lines unique", "Sort lines"])
        #expect(FuzzyMatcher.rank(names, query: "uniq", name: { $0 }).first == "Unique lines")
        #expect(FuzzyMatcher.rank(names, query: "", name: { $0 }) == names)
    }
}
