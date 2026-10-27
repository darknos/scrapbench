import Testing
@testable import ScrapbenchCore

@Suite struct JSONFormatterTests {
    let nested = #"{"b":[1,{"a":null}],"a":"x}"}"#

    @Test func prettyKeepsOrderAndNumbers() throws {
        #expect(try JSONFormatter.pretty(#"{"z":1e3,"a":-0.50,"e":[],"o":{}}"#) ==
            "{\n  \"z\": 1e3,\n  \"a\": -0.50,\n  \"e\": [],\n  \"o\": {}\n}")
    }

    @Test func prettyNested() throws {
        #expect(try JSONFormatter.pretty(nested) ==
            "{\n  \"b\": [\n    1,\n    {\n      \"a\": null\n    }\n  ],\n  \"a\": \"x}\"\n}")
    }

    @Test func minifyRoundTrip() throws {
        #expect(try JSONFormatter.minify(try JSONFormatter.pretty(nested)) == nested)
        #expect(try JSONFormatter.minify("\"a \\\" b\"  ") == "\"a \\\" b\"")
    }

    @Test func errorPosition() {
        #expect(throws: TransformError("unexpected token at 2:6")) { try JSONFormatter.pretty("{\n \"a\" 1}") }
        #expect(throws: TransformError("unexpected end of input")) { try JSONFormatter.pretty("[1,") }
        #expect(throws: TransformError("unexpected token at 1:8")) { try JSONFormatter.pretty("{\"a\":1}x") }
    }

    @Test func transformersKeepTrailingNewline() throws {
        #expect(try JSONPrettyTransformer().apply("[1]\n") == "[\n  1\n]\n")
        #expect(JSONMinifyTransformer().canApply(to: "{}"))
        #expect(!JSONMinifyTransformer().canApply(to: "{"))
    }

    @Test func canApplySkipsParseOverOneMegabyte() {
        let big = String(repeating: "x", count: transformerParseLimit + 1)
        #expect(JSONPrettyTransformer().canApply(to: big))
        #expect(throws: TransformError.self) { try JSONPrettyTransformer().apply(big) }
    }
}
