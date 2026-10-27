import Testing
@testable import ScrapbenchCore

@Suite struct CaseTransformersTests {
    @Test func upperLower() throws {
        #expect(try UpperCaseTransformer().apply("aB c") == "AB C")
        #expect(try LowerCaseTransformer().apply("aB c") == "ab c")
    }

    @Test func titleCaseKeepsGraphemes() throws {
        #expect(try TitleCaseTransformer().apply("héllo 👋 wörld") == "Héllo 👋 Wörld")
        #expect(try TitleCaseTransformer().apply("fooBAR") == "FooBAR")
    }

    @Test func identifierWordsSplitsBoundaries() {
        #expect(IdentifierWords.split("fooBar") == ["foo", "bar"])
        #expect(IdentifierWords.split("HTTPServer") == ["http", "server"])
        #expect(IdentifierWords.split("my_var-name two") == ["my", "var", "name", "two"])
        #expect(IdentifierWords.split("  ") == [])
    }

    @Test func identifierStyles() throws {
        #expect(try IdentifierCaseTransformer.camel.apply("HTTP server_name") == "httpServerName")
        #expect(try IdentifierCaseTransformer.snake.apply("httpServerName") == "http_server_name")
        #expect(try IdentifierCaseTransformer.kebab.apply("HTTPServerName") == "http-server-name")
        #expect(try IdentifierCaseTransformer.constant.apply("http-server") == "HTTP_SERVER")
    }

    @Test func identifierPerLineKeepsIndentAndTrailingNewline() throws {
        #expect(try IdentifierCaseTransformer.snake.apply("  fooBar\n\nbazQux\n") == "  foo_bar\n\nbaz_qux\n")
    }

    @Test func idsAndNames() {
        #expect(IdentifierCaseTransformer.camel.id == "case.camel")
        #expect(IdentifierCaseTransformer.constant.name == "CONSTANT_CASE")
        #expect(UpperCaseTransformer().group == .case)
    }
}
