import Testing
@testable import ScrapbenchCore

@Suite struct CalculatorTests {
    let t = CalculateTransformer()

    @Test func evaluateAndFormat() throws {
        #expect(Calculator.format(try Calculator.evaluate("3+4")) == "7")
        #expect(Calculator.format(try Calculator.evaluate("10/4")) == "2.5")
        #expect(Calculator.format(try Calculator.evaluate("1/3")) == "0.3333333333")
        #expect(Calculator.format(try Calculator.evaluate("pow(2, 10) + sqrt(16) - 7 % 4")) == "1025")
        #expect(Calculator.format(try Calculator.evaluate("-(2.5 * 2)")) == "-5")
    }

    @Test func errors() {
        #expect(throws: TransformError("division by zero")) { try Calculator.evaluate("1/0") }
        #expect(throws: TransformError("not a number")) { try Calculator.evaluate("sqrt(-1)") }
        #expect(throws: TransformError.self) { try Calculator.evaluate("2 +") }
    }

    @Test func transformerAppendsResults() throws {
        #expect(try t.apply("3+4") == "3+4 = 7")
        #expect(try t.apply("2*3\n10/4\n") == "2*3 = 6\n10/4 = 2.5\n")
    }

    @Test func recomputesExistingResultsAndKeepsBlankLines() throws {
        #expect(try t.apply("3+4 = 5\n\n2*2 = 4") == "3+4 = 7\n\n2*2 = 4")
    }

    @Test func belongsToMathGroup() {
        #expect(t.group == .math)
        #expect(TransformerGroup.math.name == "Math")
    }

    @Test func applicability() {
        #expect(t.canApply(to: "3+4"))
        #expect(t.canApply(to: "3+4 = 7\n(1+2)*3"))
        #expect(!t.canApply(to: "42"))
        #expect(!t.canApply(to: "hello + world"))
        #expect(!t.canApply(to: "3+4\nabc"))
    }
}
