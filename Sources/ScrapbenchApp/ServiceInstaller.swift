import AppKit
import ScrapbenchCore

struct ServiceInstallError: LocalizedError {
    let bundle: String
    let underlying: Error
    var errorDescription: String? { "\(bundle): \(underlying.localizedDescription)" }
}

/// Writes and removes the workflow bundles in `~/Library/Services` that
/// offer `@service` scripts as macOS Services. Only bundles whose
/// `Info.plist` carries `ServiceWorkflow.scriptIDKey` are ever touched.
@MainActor
final class ServiceInstaller {
    static let servicesDirectory = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Services")

    private let fileManager = FileManager.default

    func installed() -> [InstalledService] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: Self.servicesDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        return entries
            .filter { $0.pathExtension == ServiceWorkflow.bundleExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in scriptID(of: url).map { InstalledService(id: $0, url: url) } }
    }

    func plan() -> ServicePlan {
        let scripts = ScriptRegistry.scan(directory: Settings.transformersDirectory).scripts
        return ServicePlan(scripts: scripts, installed: installed())
    }

    func register(_ plan: ServicePlan) throws {
        defer { NSUpdateDynamicServices() }
        try fileManager.createDirectory(at: Self.servicesDirectory, withIntermediateDirectories: true)
        let workflows = (plan.add + plan.refresh.map(\.script)).map(ServiceWorkflow.init)
        for workflow in workflows {
            try write(workflow)
        }
        // Old folders go last: a renamed script's new bundle may have taken the
        // name another refresh is about to vacate.
        let written = Set(workflows.map { $0.bundleName.lowercased() })
        for item in plan.refresh where !written.contains(item.installed.url.lastPathComponent.lowercased()) {
            try remove(item.installed)
        }
        for item in plan.remove {
            try remove(item)
        }
    }

    func removeAll() throws {
        defer { NSUpdateDynamicServices() }
        for item in installed() {
            try remove(item)
        }
    }

    private func write(_ workflow: ServiceWorkflow) throws {
        let target = Self.servicesDirectory.appendingPathComponent(workflow.bundleName)
        do {
            let exists = fileManager.fileExists(atPath: target.path)
            if exists, !isOurs(target) {
                throw ServiceInstallError(bundle: workflow.bundleName, underlying: NotOurs())
            }
            let staging = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                              appropriateFor: Self.servicesDirectory, create: true)
            defer { try? fileManager.removeItem(at: staging) }
            let bundle = staging.appendingPathComponent(workflow.bundleName)
            let contents = bundle.appendingPathComponent("Contents")
            try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: workflow.infoPlist, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
            try PropertyListSerialization.data(fromPropertyList: workflow.document, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("document.wflow"))
            if exists {
                _ = try fileManager.replaceItemAt(target, withItemAt: bundle)
            } else {
                try fileManager.moveItem(at: bundle, to: target)
            }
        } catch let error as ServiceInstallError {
            throw error
        } catch {
            throw ServiceInstallError(bundle: workflow.bundleName, underlying: error)
        }
    }

    private func isOurs(_ bundle: URL) -> Bool { scriptID(of: bundle) != nil }

    private func scriptID(of bundle: URL) -> String? {
        let plist = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return dict[ServiceWorkflow.scriptIDKey] as? String
    }

    private struct NotOurs: LocalizedError {
        var errorDescription: String? { "a workflow with this name exists and is not from Scrapbench" }
    }

    private func remove(_ item: InstalledService) throws {
        do {
            try fileManager.removeItem(at: item.url)
        } catch {
            throw ServiceInstallError(bundle: item.url.lastPathComponent, underlying: error)
        }
    }
}
