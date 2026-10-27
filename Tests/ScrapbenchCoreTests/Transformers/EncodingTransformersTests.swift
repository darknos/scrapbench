import Testing
@testable import ScrapbenchCore

@Suite struct EncodingTransformersTests {
    @Test func base64RoundTrip() throws {
        #expect(try Base64EncodeTransformer().apply("hi there") == "aGkgdGhlcmU=")
        #expect(try Base64DecodeTransformer().apply("aGkgdGhlcmU=") == "hi there")
        #expect(try Base64DecodeTransformer().apply("aGkg\ndGhlcmU") == "hi there")
    }

    @Test func base64DecodeErrors() {
        #expect(throws: TransformError("not valid Base64")) { try Base64DecodeTransformer().apply("@@@@") }
        #expect(throws: TransformError("decoded bytes are not UTF-8 text")) { try Base64DecodeTransformer().apply("/w==") }
    }

    @Test func decodeDoesNotApplyToPlainWords() {
        #expect(!Base64DecodeTransformer().canApply(to: "Hello world"))
        #expect(!Base64DecodeTransformer().canApply(to: "abcd"))
        for word in ["Hi", "OK", "No", "The", "And", "Fix", "Idea", "   ", ""] {
            #expect(!Base64DecodeTransformer().canApply(to: word), "\(word)")
        }
        #expect(!Base64DecodeTransformer().canApply(to: "AAAAAAAAAAAA"))   // decodes to NUL bytes
        #expect(Base64DecodeTransformer().canApply(to: "aGkgdGhlcmU="))
        #expect(Base64DecodeTransformer().canApply(to: "bGluZTEKbGluZTIK"))  // "line1\nline2\n"
    }

    @Test func decodeSkipsCheckOverParseLimit() {
        let big = String(repeating: "A", count: transformerParseLimit + 4)
        #expect(Base64DecodeTransformer().canApply(to: big))
        #expect(JSONUnescapeTransformer().canApply(to: "\"" + big + "\""))
    }

    @Test func urlEncodeDecode() throws {
        #expect(try URLEncodeTransformer().apply("a b/c?d=é~") == "a%20b%2Fc%3Fd%3D%C3%A9~")
        #expect(try URLDecodeTransformer().apply("a%20b+c") == "a b+c")
        #expect(URLDecodeTransformer().canApply(to: "a%2Fb"))
        #expect(!URLDecodeTransformer().canApply(to: "a+b"))
        #expect(throws: TransformError("invalid percent escape")) { try URLDecodeTransformer().apply("%zz") }
    }

    @Test func jsonEscapeUnescape() throws {
        #expect(try JSONEscapeTransformer().apply("say \"hi\"\n") == "\"say \\\"hi\\\"\\n\"")
        #expect(try JSONUnescapeTransformer().apply("\"a\\tb\"") == "a\tb")
        #expect(JSONUnescapeTransformer().canApply(to: " \"x\" "))
        #expect(!JSONUnescapeTransformer().canApply(to: "x"))
        #expect(throws: TransformError("not a JSON string literal")) { try JSONUnescapeTransformer().apply("\"unterminated") }
    }
}
