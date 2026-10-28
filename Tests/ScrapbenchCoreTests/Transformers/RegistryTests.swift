import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct RegistryTests {
    @Test func allBuiltInsPresentOnceInSpecOrder() {
        let ids = TransformerRegistry.builtIn.map(\.id)
        #expect(ids.count == 35)
        #expect(ids.firstIndex(of: "lines.unwrap")! < ids.firstIndex(of: "cli.split")!)
        #expect(Set(ids).count == ids.count)
        #expect(ids.first == "case.upper")
        #expect(ids.last == "calc.evaluate")
        #expect(ids.firstIndex(of: "json.pretty")! < ids.firstIndex(of: "lines.sort")!)
    }

    @Test func extrasComeAfterBuiltInsAndResolveByID() {
        let s = ScriptTransformer(id: "script.x", name: "X", group: .scripts, description: "",
                                  url: URL(fileURLWithPath: "/x"), timeout: 30)
        let ids = TransformerRegistry.applicable(to: "abc", extra: [s]).map(\.id)
        #expect(ids.last == "script.x")
        #expect(TransformerRegistry.transformer(id: "script.x", extra: [s])?.name == "X")
        #expect(TransformerRegistry.transformer(id: "script.x") == nil)
    }

    @Test func builtInDescriptionsAreShortAndLowerCase() {
        let described = TransformerRegistry.builtIn.filter { !$0.description.isEmpty }
        #expect(described.count >= 10)
        for t in TransformerRegistry.builtIn {
            #expect(t.description.count <= 40, "\(t.id)")
            #expect(!t.description.hasSuffix("."), "\(t.id)")
            #expect(t.description.first.map { !$0.isUppercase } ?? true, "\(t.id)")
        }
        #expect(TransformerRegistry.transformer(id: "lines.unwrap")?.description == "undo terminal hard wraps")
    }

    @Test func applicableFilters() {
        let ids = TransformerRegistry.applicable(to: "3+4").map(\.id)
        #expect(ids.contains("calc.evaluate"))
        #expect(!ids.contains("lines.sort"))
        #expect(!ids.contains("json.pretty"))
    }

    /// Opening the palette runs every canApply on the main thread; a big
    /// selection must stay far from a visible stall even in a debug build.
    @Test func applicableIsFastOnTwoMegabytes() {
        let paragraph = "The quick brown fox jumps over the lazy dog - 12 times, then rests.\n"
        let prose = String(repeating: paragraph, count: 2_000_000 / paragraph.utf8.count)
        let numbers = String(repeating: "12345\n", count: 350_000)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            _ = TransformerRegistry.applicable(to: prose)
            _ = TransformerRegistry.applicable(to: numbers)
        }
        #expect(elapsed < .seconds(3), "\(elapsed)")
    }

    @Test func lookupById() {
        #expect(TransformerRegistry.transformer(id: "cli.split")?.name == "Split command")
        #expect(TransformerRegistry.transformer(id: "nope") == nil)
    }
}
