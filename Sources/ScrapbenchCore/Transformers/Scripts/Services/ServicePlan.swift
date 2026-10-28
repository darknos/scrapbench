import Foundation

/// A workflow bundle in `~/Library/Services` that carries our script id.
public struct InstalledService: Equatable, Sendable {
    public let id: String
    public let url: URL
    public init(id: String, url: URL) {
        self.id = id
        self.url = url
    }
}

/// What `Register services` would do: the scripts with `@service` against
/// the bundles already installed, matched by transformer id.
public struct ServicePlan {
    public struct Refresh: Equatable {
        public let script: ScriptTransformer
        public let installed: InstalledService
    }

    public let add: [ScriptTransformer]
    public let refresh: [Refresh]
    public let remove: [InstalledService]

    public init(scripts: [ScriptTransformer], installed: [InstalledService]) {
        let wanted = scripts.filter(\.service)
        let byID = Dictionary(installed.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let wantedIDs = Set(wanted.map(\.id))
        add = wanted.filter { byID[$0.id] == nil }
        refresh = wanted.compactMap { script in byID[script.id].map { Refresh(script: script, installed: $0) } }
        remove = installed.filter { !wantedIDs.contains($0.id) }
    }

    public var isEmpty: Bool { add.isEmpty && refresh.isEmpty && remove.isEmpty }

    /// `add 2, refresh 1, remove 1`, non-zero parts only; empty when nothing to do.
    public var summary: String {
        [("add", add.count), ("refresh", refresh.count), ("remove", remove.count)]
            .filter { $0.1 > 0 }
            .map { "\($0.0) \($0.1)" }
            .joined(separator: ", ")
    }
}
