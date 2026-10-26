import Foundation
import Testing
@testable import DailyNotesCore

/// Kinds in source order with the matched text, for golden assertions.
func kinds(_ lang: String, _ src: String) -> [(TokenKind, String)] {
    let ns = src as NSString
    let g = CodeGrammar.named(lang)!
    return g.tokens(in: ns, range: NSRange(location: 0, length: ns.length))
        .sorted { $0.range.location < $1.range.location }
        .map { ($0.kind, ns.substring(with: $0.range)) }
}

func expectKinds(_ got: [(TokenKind, String)], _ want: [(TokenKind, String)],
                 sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(got.map(\.0) == want.map(\.0), sourceLocation: sourceLocation)
    #expect(got.map(\.1) == want.map(\.1), sourceLocation: sourceLocation)
}

@Suite struct GrammarTests {
    @Test func lookupIsCaseInsensitiveWithAliases() {
        #expect(CodeGrammar.named("JSON") != nil)
        #expect(CodeGrammar.named("sh") != nil)
        #expect(CodeGrammar.named("zsh") != nil)
        #expect(CodeGrammar.named("ts") != nil)
        #expect(CodeGrammar.named("golang") != nil)
        #expect(CodeGrammar.named("html") != nil)
        #expect(CodeGrammar.named("yml") != nil)
        #expect(CodeGrammar.named("cobol") == nil)
    }

    @Test func json() {
        expectKinds(kinds("json", #"{"a": 1, "b": "x", "c": null}"#), [
            (.key, #""a""#), (.number, "1"), (.key, #""b""#), (.string, #""x""#), (.key, #""c""#), (.literal, "null"),
        ])
    }

    @Test func sqlKeywordsCaseInsensitive() {
        expectKinds(kinds("sql", "select id from t where x = 'a' -- note\nAND y = 2"), [
            (.keyword, "select"), (.keyword, "from"), (.keyword, "where"), (.string, "'a'"),
            (.comment, "-- note"), (.keyword, "AND"), (.number, "2"),
        ])
    }

    @Test func goCommentBeatsString() {
        expectKinds(kinds("go", #"x := "s" // "not" a string"#), [
            (.string, #""s""#), (.comment, #"// "not" a string"#),
        ])
    }

    @Test func goKeywordsAndLiterals() {
        expectKinds(kinds("go", "func f() error { return nil }"), [
            (.keyword, "func"), (.keyword, "error"), (.keyword, "return"), (.literal, "nil"),
        ])
    }

    @Test func shell() {
        expectKinds(kinds("bash", "export X=\"$HOME/x\" # c\nif [ -f $Y ]; then echo 1; fi"), [
            (.keyword, "export"), (.string, "\"$HOME/x\""), (.comment, "# c"),
            (.keyword, "if"), (.key, "$Y"), (.keyword, "then"), (.keyword, "echo"), (.number, "1"), (.keyword, "fi"),
        ])
    }

    @Test func yaml() {
        expectKinds(kinds("yaml", "name: app # c\nport: 8080\nflag: true\nmsg: \"hi\""), [
            (.key, "name:"), (.comment, "# c"), (.key, "port:"), (.number, "8080"),
            (.key, "flag:"), (.literal, "true"), (.key, "msg:"), (.string, "\"hi\""),
        ])
    }

    @Test func javascript() {
        expectKinds(kinds("ts", "const x = `t ${1}`; /* c */ return x ?? null;"), [
            (.keyword, "const"), (.string, "`t ${1}`"), (.comment, "/* c */"), (.keyword, "return"), (.literal, "null"),
        ])
    }

    @Test func xml() {
        expectKinds(kinds("xml", #"<!-- c --><a href="x">1</a>"#), [
            (.comment, "<!-- c -->"), (.keyword, "<a"), (.key, "href"), (.string, #""x""#), (.keyword, ">"), (.keyword, "</a"), (.keyword, ">"),
        ])
    }

    @Test func numbersInsideStringsAreNotTokens() {
        expectKinds(kinds("json", #""v1.2""#), [(.string, #""v1.2""#)])
    }
}
