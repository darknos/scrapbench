import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct PromptFileTests {
    func parse(_ s: String) -> Result<PromptFile.Parsed, ScriptProblem> { PromptFile.parse(s, file: "x.prompt") }

    @Test func headerLinesAreRemovedAndBodyTrimmed() {
        let p = try? parse("# @name Improve\n# @group AI\n\nFix the text.\nKeep the tone.\n\n").get()
        #expect(p?.header.name == "Improve")
        #expect(p?.body == "Fix the text.\nKeep the tone.")
    }

    @Test func markdownHeadingAndLateKeyStayInBody() {
        let late = "# @name A\n# Heading\n" + String(repeating: "line\n", count: 19) + "# @model x\n"
        let p = try? parse(late).get()
        #expect(p?.body.hasPrefix("# Heading") == true)
        #expect(p?.body.hasSuffix("# @model x") == true)
        #expect(p?.header.model == nil)
    }

    @Test func defaultsForPrompts() {
        let p = try? parse("# @name A\nbody\n").get()
        #expect(p?.header.group == .ai)
        #expect(p?.header.timeout == 60)
    }

    @Test func crlfFilesParse() {
        let p = try? parse("# @name A\r\n# @group AI\r\n\r\nFix.\r\nKeep.\r\n").get()
        #expect(p?.header.name == "A")
        #expect(p?.header.group == TransformerGroup("AI"))
        #expect(p?.body == "Fix.\nKeep.")
    }

    @Test func emptyBodyIsAProblem() {
        #expect(parse("# @name A\n\n  \n") == .failure(ScriptProblem(file: "x.prompt", reason: "empty prompt")))
    }

    @Test func noNameIsAProblem() {
        #expect(parse("Just a prompt\n") == .failure(ScriptProblem(file: "x.prompt", reason: "no @name")))
    }

    @Test func transformerFromFile() throws {
        let p = try parse("# @name Improve text\n# @service\nFix.\n").get()
        let t = PromptTransformer(header: p.header, body: p.body, url: URL(fileURLWithPath: "/t/improve-text.prompt"))
        #expect(t.id == "prompt.improve-text")
        #expect(t.name == "Improve text")
        #expect(t.group == .ai)
        #expect(t.timeout == 60)
        #expect(t.systemPrompt == "Fix.")
        #expect(t.service)
        #expect(t.canApply(to: ""))
        #expect(throws: TransformError("runs through the app")) { try t.apply("x") }
    }
}
