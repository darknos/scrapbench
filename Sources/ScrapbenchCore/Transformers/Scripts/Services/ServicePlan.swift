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

/// What `Register` would do: the transformers with `@service` against
/// the bundles already installed, matched by transformer id.
public struct ServicePlan {
    public struct Refresh: Equatable {
        public let entry: ServiceEntry
        public let installed: InstalledService
    }

    public let add: [ServiceEntry]
    public let refresh: [Refresh]
    public let remove: [InstalledService]
    /// Entries whose bundle name is already taken by an earlier entry
    /// (`@name` compared case-insensitively, as APFS compares folder
    /// names). They are left out; `problem` names them.
    public let conflicts: [ServiceEntry]

    /// The scripts and prompts marked `@service`, in palette order.
    /// `executable` is the app binary a prompt's bundle runs.
    public static func serviceEntries(scripts: [ScriptTransformer], prompts: [PromptTransformer], executable: String) -> [ServiceEntry] {
        ScanResult(scripts: scripts, prompts: prompts, problems: []).transformers.compactMap { item in
            if let script = item as? ScriptTransformer, script.service { return script.serviceEntry }
            if let prompt = item as? PromptTransformer, prompt.service { return prompt.serviceEntry(executable: executable) }
            return nil
        }
    }

    public init(entries: [ServiceEntry], installed: [InstalledService]) {
        var wanted: [ServiceEntry] = []
        var conflicts: [ServiceEntry] = []
        var names: Set<String> = []
        for entry in entries {
            if names.insert(ServiceWorkflow(entry: entry).bundleName.lowercased()).inserted {
                wanted.append(entry)
            } else {
                conflicts.append(entry)
            }
        }
        var firstByID: [String: InstalledService] = [:]
        var extras: [InstalledService] = []
        for item in installed {
            if firstByID[item.id] == nil { firstByID[item.id] = item } else { extras.append(item) }
        }
        let wantedIDs = Set(wanted.map(\.id))
        add = wanted.filter { firstByID[$0.id] == nil }
        refresh = wanted.compactMap { entry in firstByID[entry.id].map { Refresh(entry: entry, installed: $0) } }
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
        let winnerName = ServiceWorkflow(entry: first).bundleName.lowercased()
        let all = add + refresh.map(\.entry)
        let winner = all.first { ServiceWorkflow(entry: $0).bundleName.lowercased() == winnerName }
        let file = { (e: ServiceEntry) in (e.path as NSString).lastPathComponent }
        let files = ([winner].compactMap { $0 } + conflicts).map(file)
        return "same @name in \(files.joined(separator: ", ")); only \(winner.map(file) ?? "the first") is registered"
    }
}
