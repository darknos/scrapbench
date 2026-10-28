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

/// What `Register` would do: the scripts with `@service` against
/// the bundles already installed, matched by transformer id.
public struct ServicePlan {
    public struct Refresh: Equatable {
        public let script: ScriptTransformer
        public let installed: InstalledService
    }

    public let add: [ScriptTransformer]
    public let refresh: [Refresh]
    public let remove: [InstalledService]
    /// Scripts whose bundle name is already taken by an earlier script
    /// (`@name` compared case-insensitively, as APFS compares folder
    /// names). They are left out; `problem` names them.
    public let conflicts: [ScriptTransformer]

    public init(scripts: [ScriptTransformer], installed: [InstalledService]) {
        var wanted: [ScriptTransformer] = []
        var conflicts: [ScriptTransformer] = []
        var names: Set<String> = []
        for script in scripts where script.service {
            if names.insert(ServiceWorkflow(script: script).bundleName.lowercased()).inserted {
                wanted.append(script)
            } else {
                conflicts.append(script)
            }
        }
        var firstByID: [String: InstalledService] = [:]
        var extras: [InstalledService] = []
        for item in installed {
            if firstByID[item.id] == nil { firstByID[item.id] = item } else { extras.append(item) }
        }
        let wantedIDs = Set(wanted.map(\.id))
        add = wanted.filter { firstByID[$0.id] == nil }
        refresh = wanted.compactMap { script in firstByID[script.id].map { Refresh(script: script, installed: $0) } }
        remove = installed.filter { !wantedIDs.contains($0.id) } + extras.filter { wantedIDs.contains($0.id) }
        self.conflicts = conflicts
    }

    public var isEmpty: Bool { add.isEmpty && refresh.isEmpty && remove.isEmpty }

    /// `add 2, refresh 1, remove 1`, non-zero parts only; empty when nothing to do.
    public var summary: String {
        [("add", add.count), ("refresh", refresh.count), ("remove", remove.count)]
            .filter { $0.1 > 0 }
            .map { "\($0.0) \($0.1)" }
            .joined(separator: ", ")
    }

    /// `same @name in a.sh, b.sh; only a.sh is registered`, or nil.
    public var problem: String? {
        guard let first = conflicts.first else { return nil }
        let winnerName = ServiceWorkflow(script: first).bundleName.lowercased()
        let all = add + refresh.map(\.script)
        let winner = all.first { ServiceWorkflow(script: $0).bundleName.lowercased() == winnerName }
        let files = ([winner].compactMap { $0 } + conflicts).map(\.url.lastPathComponent)
        return "same @name in \(files.joined(separator: ", ")); only \(winner?.url.lastPathComponent ?? "the first") is registered"
    }
}
