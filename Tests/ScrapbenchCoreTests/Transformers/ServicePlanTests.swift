import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct ServicePlanTests {
    func script(_ stem: String, service: Bool = true) -> ScriptTransformer {
        ScriptTransformer(header: ScriptHeader(name: stem, service: service), url: URL(fileURLWithPath: "/t/\(stem).sh"))
    }
    func installed(_ stem: String) -> InstalledService {
        InstalledService(id: "script.\(stem)", url: URL(fileURLWithPath: "/s/Scrapbench - \(stem).workflow"))
    }

    @Test func addWhenNotInstalled() {
        let plan = ServicePlan(scripts: [script("a")], installed: [])
        #expect(plan.add == [script("a")])
        #expect(plan.refresh.isEmpty && plan.remove.isEmpty)
    }

    @Test func refreshWhenBothExist() {
        let plan = ServicePlan(scripts: [script("a")], installed: [installed("a")])
        #expect(plan.add.isEmpty && plan.remove.isEmpty)
        #expect(plan.refresh.count == 1)
        #expect(plan.refresh[0].script == script("a"))
        #expect(plan.refresh[0].installed == installed("a"))
    }

    @Test func removeWhenScriptGoneOrNotService() {
        let plan = ServicePlan(scripts: [script("b", service: false)], installed: [installed("a"), installed("b")])
        #expect(plan.remove == [installed("a"), installed("b")])
        #expect(plan.add.isEmpty && plan.refresh.isEmpty)
    }

    @Test func scriptsWithoutServiceAreIgnored() {
        let plan = ServicePlan(scripts: [script("a", service: false)], installed: [])
        #expect(plan.isEmpty)
    }

    @Test func summaryStrings() {
        let all = ServicePlan(scripts: [script("a"), script("b"), script("c")], installed: [installed("c"), installed("d")])
        #expect(all.summary == "add 2, refresh 1, remove 1")
        #expect(ServicePlan(scripts: [script("a")], installed: [installed("a")]).summary == "refresh 1")
        #expect(ServicePlan(scripts: [], installed: []).summary == "")
    }
}

@Suite struct ServicePlanConflictTests {
    func script(_ stem: String, name: String) -> ScriptTransformer {
        ScriptTransformer(header: ScriptHeader(name: name, service: true), url: URL(fileURLWithPath: "/t/\(stem).sh"))
    }
    func installed(_ stem: String, folder: String = "x") -> InstalledService {
        InstalledService(id: "script.\(stem)", url: URL(fileURLWithPath: "/s/\(folder).workflow"))
    }

    @Test func sameBundleNameKeepsTheFirstAndReportsTheRest() {
        let a = script("a", name: "Fix"), b = script("b", name: "fix"), c = script("c", name: "Fix")
        let plan = ServicePlan(scripts: [a, b, c], installed: [])
        #expect(plan.add == [a])
        #expect(plan.conflicts == [b, c])
        #expect(plan.summary == "add 1")
        #expect(plan.problem == "same @name in a.sh, b.sh, c.sh; only a.sh is registered")
    }

    @Test func noConflictsNoProblem() {
        #expect(ServicePlan(scripts: [script("a", name: "A")], installed: []).problem == nil)
    }

    @Test func extraBundlesWithTheSameIDAreRemoved() {
        let a = script("a", name: "A")
        let first = installed("a", folder: "one"), second = installed("a", folder: "two")
        let plan = ServicePlan(scripts: [a], installed: [first, second])
        #expect(plan.refresh.map(\.installed) == [first])
        #expect(plan.remove == [second])
    }
}
