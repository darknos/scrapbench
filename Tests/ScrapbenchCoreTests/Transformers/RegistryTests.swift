import Testing
@testable import ScrapbenchCore

@Suite struct RegistryTests {
    @Test func allBuiltInsPresentOnceInSpecOrder() {
        let ids = TransformerRegistry.builtIn.map(\.id)
        #expect(ids.count == 34)
        #expect(Set(ids).count == ids.count)
        #expect(ids.first == "case.upper")
        #expect(ids.last == "calc.evaluate")
        #expect(ids.firstIndex(of: "json.pretty")! < ids.firstIndex(of: "lines.sort")!)
    }

    @Test func applicableFilters() {
        let ids = TransformerRegistry.applicable(to: "3+4").map(\.id)
        #expect(ids.contains("calc.evaluate"))
        #expect(!ids.contains("lines.sort"))
        #expect(!ids.contains("json.pretty"))
    }

    @Test func lookupById() {
        #expect(TransformerRegistry.transformer(id: "cli.split")?.name == "Split command")
        #expect(TransformerRegistry.transformer(id: "nope") == nil)
    }
}
