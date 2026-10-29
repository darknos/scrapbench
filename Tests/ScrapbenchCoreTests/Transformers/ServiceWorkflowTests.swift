import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct ServiceWorkflowTests {
    func script(name: String = "Improve text", path: String = "/Users/me/Transformers/improve-text.sh") -> ServiceEntry {
        ScriptTransformer(header: ScriptHeader(name: name, service: true), url: URL(fileURLWithPath: path)).serviceEntry
    }

    @Test func titleAndBundleName() {
        let w = ServiceWorkflow(entry: script())
        #expect(w.title == "Scrapbench: Improve text")
        #expect(w.bundleName == "Scrapbench - Improve text.workflow")
        let odd = ServiceWorkflow(entry: script(name: "AI: fix/improve"))
        #expect(odd.title == "Scrapbench: AI: fix/improve")
        #expect(odd.bundleName == "Scrapbench - AI- fix-improve.workflow")
    }

    @Test func commandQuotesThePath() {
        let w = ServiceWorkflow(entry: script(path: "/Users/me/Application Support/it's.sh"))
        let lines = w.command.split(separator: "\n").map(String.init)
        #expect(lines.first?.hasPrefix("export PATH=") == true)
        #expect(lines.contains("export LANG=en_US.UTF-8"))
        #expect(lines.last == "exec '/Users/me/Application Support/it'\\''s.sh'")
    }

    @Test func infoPlistKeys() throws {
        let w = ServiceWorkflow(entry: script())
        let plist = w.infoPlist
        let services = try #require(plist["NSServices"] as? [[String: Any]])
        #expect(services.count == 1)
        let s = services[0]
        #expect((s["NSMenuItem"] as? [String: String])?["default"] == "Scrapbench: Improve text")
        #expect(s["NSMessage"] as? String == "runWorkflowAsService")
        #expect(s["NSSendTypes"] as? [String] == ["public.utf8-plain-text"])
        #expect(s["NSReturnTypes"] as? [String] == ["public.utf8-plain-text"])
        #expect(plist[ServiceWorkflow.scriptIDKey] as? String == "script.improve-text")
        #expect(plist[ServiceWorkflow.scriptPathKey] as? String == "/Users/me/Transformers/improve-text.sh")
    }

    @Test func documentHasOneRunShellScriptAction() throws {
        let w = ServiceWorkflow(entry: script())
        let doc = w.document
        let actions = try #require(doc["actions"] as? [[String: Any]])
        #expect(actions.count == 1)
        let action = try #require(actions[0]["action"] as? [String: Any])
        #expect(action["BundleIdentifier"] as? String == "com.apple.RunShellScript")
        let params = try #require(action["ActionParameters"] as? [String: Any])
        #expect(params["COMMAND_STRING"] as? String == w.command)
        #expect(params["shell"] as? String == "/bin/sh")
        #expect(params["inputMethod"] as? Int == 0)
        let meta = try #require(doc["workflowMetaData"] as? [String: Any])
        #expect(meta["workflowTypeIdentifier"] as? String == "com.apple.Automator.servicesMenu")
        #expect(meta["serviceInputTypeIdentifier"] as? String == "com.apple.Automator.text")
    }

    @Test func bothSerialize() throws {
        let w = ServiceWorkflow(entry: script())
        _ = try PropertyListSerialization.data(fromPropertyList: w.infoPlist, format: .xml, options: 0)
        _ = try PropertyListSerialization.data(fromPropertyList: w.document, format: .xml, options: 0)
    }

    @Test func promptEntryRunsTheApp() {
        let p = PromptTransformer(header: ScriptHeader(name: "Improve text", service: true), body: "x",
                                  url: URL(fileURLWithPath: "/t/improve-text.prompt"))
        let e = p.serviceEntry(executable: "/Applications/Scrap's.app/Contents/MacOS/Scrapbench")
        #expect(e.id == "prompt.improve-text")
        #expect(e.path == "/t/improve-text.prompt")
        #expect(e.command == "export LANG=en_US.UTF-8\nexec '/Applications/Scrap'\\''s.app/Contents/MacOS/Scrapbench' --transform prompt.improve-text")
        #expect(ServiceWorkflow(entry: e).infoPlist[ServiceWorkflow.scriptIDKey] as? String == "prompt.improve-text")
    }
}
