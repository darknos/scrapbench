import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct ServicePlanTests {
    func script(_ stem: String, service: Bool = true) -> ServiceEntry {
        ScriptTransformer(header: ScriptHeader(name: stem, service: service), url: URL(fileURLWithPath: "/t/\(stem).sh")).serviceEntry
    }
    func installed(_ stem: String) -> InstalledService {
        InstalledService(id: "script.\(stem)", url: URL(fileURLWithPath: "/s/Scrapbench - \(stem).workflow"))
    }

    @Test func addWhenNotInstalled() {
        let plan = ServicePlan(entries: [script("a")], installed: [])
        #expect(plan.add == [script("a")])
        #expect(plan.refresh.isEmpty && plan.remove.isEmpty)
    }

    @Test func refreshWhenBothExist() {
        let plan = ServicePlan(entries: [script("a")], installed: [installed("a")])
        #expect(plan.add.isEmpty && plan.remove.isEmpty)
        #expect(plan.refresh.count == 1)
        #expect(plan.refresh[0].entry == script("a"))
        #expect(plan.refresh[0].installed == installed("a"))
    }

    @Test func removeWhenScriptGoneOrNotService() {
        let b = ScriptTransformer(header: ScriptHeader(name: "b", service: false), url: URL(fileURLWithPath: "/t/b.sh"))
        let plan = ServicePlan(entries: ServicePlan.serviceEntries(scripts: [b], prompts: [], executable: "/x"), installed: [installed("a"), installed("b")])
        #expect(plan.remove == [installed("a"), installed("b")])
        #expect(plan.add.isEmpty && plan.refresh.isEmpty)
    }

    @Test func scriptsWithoutServiceAreIgnored() {
        let a = ScriptTransformer(header: ScriptHeader(name: "a", service: false), url: URL(fileURLWithPath: "/t/a.sh"))
        #expect(ServicePlan.serviceEntries(scripts: [a], prompts: [], executable: "/x").isEmpty)
    }

    @Test func promptWithServiceIsAnAdd() {
        let p = PromptTransformer(header: ScriptHeader(name: "P", service: true), body: "x", url: URL(fileURLWithPath: "/t/p.prompt"))
        let entries = ServicePlan.serviceEntries(scripts: [], prompts: [p], executable: "/x")
        #expect(ServicePlan(entries: entries, installed: []).add.map(\.id) == ["prompt.p"])
    }

    @Test func entriesFollowPaletteOrder() {
        let s = ScriptTransformer(header: ScriptHeader(name: "S", group: TransformerGroup("Zed"), service: true), url: URL(fileURLWithPath: "/t/s.sh"))
        let p = PromptTransformer(header: ScriptHeader(name: "P", service: true), body: "x", url: URL(fileURLWithPath: "/t/p.prompt"))
        #expect(ServicePlan.serviceEntries(scripts: [s], prompts: [p], executable: "/x").map(\.id) == ["prompt.p", "script.s"])
    }

    @Test func summaryStrings() {
        let all = ServicePlan(entries: [script("a"), script("b"), script("c")], installed: [installed("c"), installed("d")])
        #expect(all.summary == "add 2, refresh 1, remove 1")
        #expect(ServicePlan(entries: [script("a")], installed: [installed("a")]).summary == "refresh 1")
        #expect(ServicePlan(entries: [], installed: []).summary == "")
    }
}

@Suite struct ServicePlanConflictTests {
    func script(_ stem: String, name: String) -> ServiceEntry {
        ScriptTransformer(header: ScriptHeader(name: name, service: true), url: URL(fileURLWithPath: "/t/\(stem).sh")).serviceEntry
    }
    func installed(_ stem: String, folder: String = "x") -> InstalledService {
        InstalledService(id: "script.\(stem)", url: URL(fileURLWithPath: "/s/\(folder).workflow"))
    }

    @Test func sameBundleNameKeepsTheFirstAndReportsTheRest() {
        let a = script("a", name: "Fix"), b = script("b", name: "fix"), c = script("c", name: "Fix")
        let plan = ServicePlan(entries: [a, b, c], installed: [])
        #expect(plan.add == [a])
        #expect(plan.conflicts == [b, c])
        #expect(plan.summary == "add 1")
        #expect(plan.problem == "same @name in a.sh, b.sh, c.sh; only a.sh is registered")
    }

    @Test func noConflictsNoProblem() {
        #expect(ServicePlan(entries: [script("a", name: "A")], installed: []).problem == nil)
    }

    @Test func extraBundlesWithTheSameIDAreRemoved() {
        let a = script("a", name: "A")
        let first = installed("a", folder: "one"), second = installed("a", folder: "two")
        let plan = ServicePlan(entries: [a], installed: [first, second])
        #expect(plan.refresh.map(\.installed) == [first])
        #expect(plan.remove == [second])
    }
}
