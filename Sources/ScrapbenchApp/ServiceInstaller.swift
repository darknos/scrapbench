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
            .compactMap { url in
                let plist = url.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: plist),
                      let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let id = dict[ServiceWorkflow.scriptIDKey] as? String else { return nil }
                return InstalledService(id: id, url: url)
            }
    }

    func plan() -> ServicePlan {
        let scripts = ScriptRegistry.scan(directory: Settings.transformersDirectory).transformers
        return ServicePlan(scripts: scripts, installed: installed())
    }

    func register(_ plan: ServicePlan) throws {
        defer { NSUpdateDynamicServices() }
        try fileManager.createDirectory(at: Self.servicesDirectory, withIntermediateDirectories: true)
        for script in plan.add {
            try write(ServiceWorkflow(script: script))
        }
        for item in plan.refresh {
            let workflow = ServiceWorkflow(script: item.script)
            if item.installed.url.lastPathComponent != workflow.bundleName {
                try remove(item.installed)
            }
            try write(workflow)
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
            let staging = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let contents = staging.appendingPathComponent("Contents")
            try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: workflow.infoPlist, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
            try PropertyListSerialization.data(fromPropertyList: workflow.document, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("document.wflow"))
            if fileManager.fileExists(atPath: target.path) {
                _ = try fileManager.replaceItemAt(target, withItemAt: staging)
            } else {
                try fileManager.moveItem(at: staging, to: target)
            }
        } catch {
            throw ServiceInstallError(bundle: workflow.bundleName, underlying: error)
        }
    }

    private func remove(_ item: InstalledService) throws {
        do {
            try fileManager.removeItem(at: item.url)
        } catch {
            throw ServiceInstallError(bundle: item.url.lastPathComponent, underlying: error)
        }
    }
}
