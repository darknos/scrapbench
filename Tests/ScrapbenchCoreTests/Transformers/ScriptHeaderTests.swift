import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct ScriptHeaderTests {
    func parse(_ s: String) -> Result<ScriptHeader, ScriptProblem> { ScriptHeader.parse(s, file: "x.sh") }

    @Test func fullHeaderWithHashComments() {
        let h = try? parse("#!/bin/bash\n# @name Improve text\n# @group AI\n# @description Fixes mistakes\n# @timeout 60\n").get()
        #expect(h == ScriptHeader(name: "Improve text", group: TransformerGroup("AI"), description: "Fixes mistakes", timeout: 60))
    }

    @Test func slashAndDashCommentsAndIndent() {
        #expect((try? parse("// @name A\n").get())?.name == "A")
        #expect((try? parse("  -- @name  B  \n").get())?.name == "B")
    }

    @Test func defaults() {
        let h = try? parse("# @name A\n").get()
        #expect(h?.group == .scripts)
        #expect(h?.description == "")
        #expect(h?.timeout == 30)
    }

    @Test func missingNameIsAProblem() {
        #expect(parse("#!/bin/sh\necho hi\n") == .failure(ScriptProblem(file: "x.sh", reason: "no @name")))
        #expect(parse("# @name   \n") == .failure(ScriptProblem(file: "x.sh", reason: "no @name")))
    }

    @Test func badTimeoutIsAProblem() {
        #expect(parse("# @name A\n# @timeout soon\n") == .failure(ScriptProblem(file: "x.sh", reason: "bad @timeout")))
        #expect(parse("# @name A\n# @timeout 0\n") == .failure(ScriptProblem(file: "x.sh", reason: "bad @timeout")))
    }

    @Test func keysAfterLine20AreIgnored() {
        let late = String(repeating: "#\n", count: 20) + "# @name Late\n"
        #expect(parse(late) == .failure(ScriptProblem(file: "x.sh", reason: "no @name")))
    }

    @Test func nonCommentLinesAndUnknownKeysAreIgnored() {
        #expect((try? parse("@name Not a comment\n# @name A\n# @colour red\n").get())?.name == "A")
    }

    @Test func firstOccurrenceWins() {
        #expect((try? parse("# @name A\n# @name B\n").get())?.name == "A")
    }
}

@Suite struct ScriptHeaderServiceTests {
    func parse(_ s: String) -> ScriptHeader? { try? ScriptHeader.parse(s, file: "x.sh").get() }

    @Test func serviceKeyIsAFlag() {
        #expect(parse("# @name A\n# @service\n")?.service == true)
        #expect(parse("# @name A\n# @service yes please\n")?.service == true)
        #expect(parse("# @name A\n")?.service == false)
    }

    @Test func serviceReachesTheTransformer() {
        let header = parse("# @name A\n# @service\n")!
        #expect(ScriptTransformer(header: header, url: URL(fileURLWithPath: "/t/a.sh")).service)
    }
}
