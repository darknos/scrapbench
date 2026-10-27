import Testing
@testable import ScrapbenchCore

@Suite struct LineTransformersTests {
    @Test func sortVariants() throws {
        #expect(try LineTransformer.sort.apply("b\na\nB\na\n") == "B\na\na\nb\n")
        #expect(try LineTransformer.sortUnique.apply("b\na\nb") == "a\nb")
        #expect(try LineTransformer.reverse.apply("1\n2\n3") == "3\n2\n1")
        #expect(try LineTransformer.unique.apply("x\ny\nx\nz") == "x\ny\nz")
        #expect(!LineTransformer.sort.canApply(to: "one line"))
    }

    @Test func blankAndWhitespace() throws {
        #expect(try LineTransformer.removeBlank.apply("a\n \n\nb\n") == "a\nb\n")
        #expect(LineTransformer.removeBlank.canApply(to: "a\n \nb"))
        #expect(!LineTransformer.removeBlank.canApply(to: "a\nb"))
        #expect(try LineTransformer.trimTrailing.apply("a  \n b \t\n") == "a\n b\n")
        #expect(try LineTransformer.trim.apply("  a \n\tb") == "a\nb")
        #expect(!LineTransformer.trim.canApply(to: "a\nb"))
    }

    @Test func indentDedent() throws {
        #expect(try LineTransformer.indent.apply("a\n\nb") == "    a\n\n    b")
        #expect(try LineTransformer.indent.apply("\ta\nb") == "\t\ta\n\tb")
        #expect(try LineTransformer.dedent.apply("    a\n\n      b\n") == "a\n\n  b\n")
        #expect(try LineTransformer.dedent.apply("\t a\n\t\tb") == " a\n\tb")
        #expect(!LineTransformer.dedent.canApply(to: "  a\nb"))
    }

    @Test func joinSplit() throws {
        #expect(try LineTransformer.joinSpace.apply(" a \nb\n") == "a b\n")
        #expect(try LineTransformer.joinComma.apply("a\nb\nc") == "a, b, c")
        #expect(try LineTransformer.splitComma.apply("a, b ,c") == "a\nb\nc")
        #expect(try LineTransformer.splitSpace.apply("a  b\tc") == "a\nb\nc")
        #expect(!LineTransformer.splitSpace.canApply(to: "a b\nc"))
        #expect(!LineTransformer.splitComma.canApply(to: "a b"))
    }

    @Test func crlfNormalised() throws {
        #expect(try LineTransformer.reverse.apply("a\r\nb\r\n") == "b\na\n")
    }
}
