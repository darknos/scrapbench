import AppKit
import KeyboardShortcuts
import ScrapbenchCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var servicePlan = ServicePlan(scripts: [], installed: [])
    @State private var installedServices = 0
    @State private var serviceError: String?
    private let installer = ServiceInstaller()

    private let monospacedFonts = Settings.monospacedFamilies

    var body: some View {
        Form {
            Section("Scrap file") {
                HStack {
                    Text(settings.fileURL.path)
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Choose…", action: chooseFile)
                }
            }
            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Toggle panel:", name: .togglePanel)
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Stay on top of other windows", isOn: $settings.stayOnTop)
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Editor") {
                Picker("Indent", selection: $settings.indentUnit) {
                    ForEach(IndentUnit.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Transformers") {
                HStack {
                    Text("Scripts in the transformers folder appear in the palette.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open transformers folder", action: openTransformersFolder)
                }
                HStack {
                    Text(servicePlan.isEmpty ? "No scripts with @service" : "Services: \(servicePlan.summary)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Register services", action: registerServices)
                        .disabled(servicePlan.isEmpty)
                }
                HStack {
                    Text("Scripts with @service work in any app through the Services menu.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(installedServices > 0 ? "Remove \(installedServices) \(installedServices == 1 ? "service" : "services")" : "Remove all services",
                           action: removeAllServices)
                        .disabled(installedServices == 0)
                }
                if let serviceError {
                    Text(serviceError).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Font") {
                Picker("Family", selection: $settings.fontName) {
                    ForEach(monospacedFonts, id: \.self) { Text($0).tag($0) }
                }
                Stepper("Size: \(Int(settings.fontSize))", value: $settings.fontSize, in: 9...32)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshServices)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            guard (note.object as? NSWindow)?.title == "Scrapbench Settings" else { return }
            refreshServices()
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func openTransformersFolder() {
        let url = Settings.transformersDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func refreshServices() {
        servicePlan = installer.plan()
        installedServices = installer.installed().count
    }

    private func registerServices() {
        do {
            try installer.register(installer.plan())
            serviceError = nil
        } catch {
            serviceError = error.localizedDescription
        }
        refreshServices()
    }

    private func removeAllServices() {
        do {
            try installer.removeAll()
            serviceError = nil
        } catch {
            serviceError = error.localizedDescription
        }
        refreshServices()
    }

    private func chooseFile() {
        let panel = NSSavePanel()
        panel.title = "Choose scrap file"
        panel.message = "Pick an existing file or type a new name"
        panel.directoryURL = settings.fileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = settings.fileURL.lastPathComponent
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            settings.fileURL = url
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
