import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

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
            Section("Font") {
                Picker("Family", selection: $settings.fontName) {
                    ForEach(monospacedFonts, id: \.self) { Text($0).tag($0) }
                }
                Stepper("Size: \(Int(settings.fontSize))", value: $settings.fontSize, in: 9...32)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
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
