import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct ScriptRegistryTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scripts-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func cleanup() { try? FileManager.default.removeItem(at: dir) }

    func write(_ name: String, _ body: String, executable: Bool = true, in folder: URL? = nil) throws {
        let url = (folder ?? dir).appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: url.path)
    }

    @Test func executableFilesWithHeadersBecomeTransformers() throws {
        defer { cleanup() }
        try write("improve.sh", "#!/bin/sh\n# @name Improve text\n# @group AI\ncat\n")
        let scan = ScriptRegistry.scan(directory: dir)
        let (scripts, problems) = (scan.scripts, scan.problems)
        #expect(problems.isEmpty)
        #expect(scripts.count == 1)
        #expect(scripts.first?.id == "script.improve")
        #expect(scripts.first?.name == "Improve text")
        #expect(scripts.first?.group == TransformerGroup("AI"))
        #expect(scripts.first?.timeout == 30)
        #expect(scripts.first?.url.lastPathComponent == "improve.sh")
        #expect(scripts.first?.canApply(to: "") == true)
        #expect(throws: TransformError("runs through the app")) { try scripts.first?.apply("x") }
    }

    @Test func nonExecutableIsReported() throws {
        defer { cleanup() }
        try write("x.py", "# @name X\n", executable: false)
        let scan = ScriptRegistry.scan(directory: dir)
        let (scripts, problems) = (scan.scripts, scan.problems)
        #expect(scripts.isEmpty)
        #expect(problems == [ScriptProblem(file: "x.py", reason: "not executable")])
    }

    @Test func missingNameIsReported() throws {
        defer { cleanup() }
        try write("x.sh", "#!/bin/sh\ncat\n")
        #expect(ScriptRegistry.scan(directory: dir).problems == [ScriptProblem(file: "x.sh", reason: "no @name")])
    }

    @Test func dotFilesSubfoldersAndNonRegularAreSkipped() throws {
        defer { cleanup() }
        try write(".hidden.sh", "# @name Hidden\n")
        let sub = dir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try write("inner.sh", "# @name Inner\n", in: sub)
        let scan = ScriptRegistry.scan(directory: dir)
        let (scripts, problems) = (scan.scripts, scan.problems)
        #expect(scripts.isEmpty)
        #expect(problems.isEmpty)
    }

    @Test func duplicateStemReportsSecond() throws {
        defer { cleanup() }
        try write("a.py", "# @name Py\n")
        try write("a.sh", "# @name Sh\n")
        let scan = ScriptRegistry.scan(directory: dir)
        let (scripts, problems) = (scan.scripts, scan.problems)
        #expect(scripts.map(\.name) == ["Py"])
        #expect(problems == [ScriptProblem(file: "a.sh", reason: "duplicate id")])
    }

    @Test func orderIsGroupNameThenFileName() throws {
        defer { cleanup() }
        try write("z.sh", "# @name Z\n# @group AI\n")
        try write("b.sh", "# @name B\n# @group Text\n")
        try write("a.sh", "# @name A\n")
        #expect(ScriptRegistry.scan(directory: dir).scripts.map(\.id) == ["script.z", "script.a", "script.b"])
    }

    @Test func symlinkToAScriptIsListedUnderTheLinkName() throws {
        defer { cleanup() }
        let outside = dir.appendingPathComponent("real-improve.sh")
        try write("real-improve.sh", "#!/bin/sh\n# @name Improve\ncat\n")
        let links = dir.appendingPathComponent("links")
        try FileManager.default.createDirectory(at: links, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: links.appendingPathComponent("improve.sh"), withDestinationURL: outside)
        let scan = ScriptRegistry.scan(directory: links)
        let (scripts, problems) = (scan.scripts, scan.problems)
        #expect(problems.isEmpty)
        #expect(scripts.map(\.id) == ["script.improve"])
        #expect(scripts.first?.url.lastPathComponent == "improve.sh")
    }

    @Test func missingDirectoryYieldsNothing() {
        cleanup()
        let scan = ScriptRegistry.scan(directory: dir.appendingPathComponent("nope"))
        let (scripts, problems) = (scan.scripts, scan.problems)
        #expect(scripts.isEmpty)
        #expect(problems.isEmpty)
    }

    @Test func promptFilesNeedNoExecutableBit() throws {
        defer { cleanup() }
        try write("improve.prompt", "# @name Improve\nFix.\n", executable: false)
        let scan = ScriptRegistry.scan(directory: dir)
        #expect(scan.problems.isEmpty)
        #expect(scan.prompts.map(\.id) == ["prompt.improve"])
    }

    @Test func promptAndScriptShareAStem() throws {
        defer { cleanup() }
        try write("improve.sh", "#!/bin/sh\n# @name Improve script\n# @group AI\ncat\n")
        try write("improve.prompt", "# @name Improve prompt\nFix.\n", executable: false)
        let scan = ScriptRegistry.scan(directory: dir)
        #expect(scan.problems.isEmpty)
        #expect(scan.transformers.map(\.id) == ["prompt.improve", "script.improve"])
    }

    @Test func transformersAreMergedByGroupThenFileName() throws {
        defer { cleanup() }
        try write("z.prompt", "# @name Z\nx\n", executable: false)
        try write("b.sh", "# @name B\n# @group AI\n")
        try write("a.sh", "# @name A\n")
        #expect(ScriptRegistry.scan(directory: dir).transformers.map(\.id) == ["script.b", "prompt.z", "script.a"])
    }

    @Test func scriptsCanBeSwitchedOff() throws {
        defer { cleanup() }
        try write("x.sh", "#!/bin/sh\n# @name X\ncat\n")
        try write("y.py", "# @name Y\n", executable: false)
        try write("p.prompt", "# @name P\nx\n", executable: false)
        let scan = ScriptRegistry.scan(directory: dir, scripts: false)
        #expect(scan.scripts.isEmpty && scan.problems.isEmpty)
        #expect(scan.prompts.map(\.id) == ["prompt.p"])
    }

    @Test func promptProblemsAreReported() throws {
        defer { cleanup() }
        try write("e.prompt", "# @name E\n", executable: false)
        #expect(ScriptRegistry.scan(directory: dir).problems == [ScriptProblem(file: "e.prompt", reason: "empty prompt")])
    }
}
