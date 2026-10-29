import AppKit
import KeyboardShortcuts
import ScrapbenchCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var servicePlan = ServicePlan(entries: [], installed: [])
    @State private var installedServices = 0
    @State private var serviceError: String?
    @State private var keyDraft = ""
    @State private var keyHint: String?
    @State private var keyError: String?
    @State private var customAnthropicModel = false
    @State private var testStatus: String?
    @State private var testFailed = false
    @State private var testRunner: PromptRunner?
    private let installer = ServiceInstaller()

    private let monospacedFonts = Settings.monospacedFamilies

    var body: some View {
        TabView {
            generalTab.tabItem { Text("General") }
            editorTab.tabItem { Text("Editor") }
            transformersTab.tabItem { Text("Transformers") }
            aiTab.tabItem { Text("AI") }
        }
        .padding(.top, 8)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: refreshServices)
        .onAppear(perform: refreshKey)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            guard (note.object as? NSWindow)?.title == "Scrapbench Settings" else { return }
            refreshServices()
            refreshKey()
        }
    }

    private var generalTab: some View {
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
            Section {
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
        }
        .formStyle(.grouped)
    }

    private var editorTab: some View {
        Form {
            Section("Font") {
                Picker("Family", selection: $settings.fontName) {
                    ForEach(monospacedFonts, id: \.self) { Text($0).tag($0) }
                }
                Stepper("Size: \(Int(settings.fontSize))", value: $settings.fontSize, in: 9...32)
            }
            Section("Indent") {
                Picker("Indent", selection: $settings.indentUnit) {
                    ForEach(IndentUnit.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
    }

    private var transformersTab: some View {
        Form {
            Section(Distribution.isSandboxed ? "Prompts" : "Scripts") {
                HStack {
                    Text(Distribution.isSandboxed
                         ? "Prompt files (.prompt) in the folder appear in the palette."
                         : "Executable files and .prompt files in the folder appear in the palette.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open folder", action: openTransformersFolder)
                }
            }
            if !Distribution.isSandboxed { servicesSection }
        }
        .formStyle(.grouped)
    }

    private var servicesSection: some View {
            Section("Services") {
                HStack {
                    Text(servicePlan.isEmpty ? "No scripts with @service" : "Services: \(servicePlan.summary)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Register", action: registerServices)
                        .disabled(servicePlan.isEmpty)
                    Button(installedServices > 0 ? "Remove \(installedServices)" : "Remove", action: removeAllServices)
                        .disabled(installedServices == 0)
                }
                if let problem = serviceError ?? servicePlan.problem {
                    Text(problem).font(.caption).foregroundStyle(.red)
                }
                Text("Transformers with @service run from the Services menu of any app, on the selection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - AI

    private var keyAccount: String {
        settings.aiProvider == .anthropic ? Settings.anthropicKeyAccount : Settings.otherKeyAccount
    }

    private var aiTab: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: $settings.aiProvider) {
                    Text("Anthropic").tag(PromptProvider.anthropic)
                    Text("Other server").tag(PromptProvider.other)
                }
                .onChange(of: settings.aiProvider) { _, _ in
                    keyDraft = ""
                    testStatus = nil
                    refreshKey()
                }
                if settings.aiProvider == .other {
                    Text("Chat Completions API: Ollama, LM Studio, OpenRouter, OpenAI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section(settings.aiProvider == .anthropic ? "Anthropic" : "Other server") {
                SecureField("API key", text: $keyDraft)
                    .onSubmit(saveKey)
                HStack {
                    Text(keyError ?? keyHint ?? (settings.aiProvider == .anthropic ? "No key stored" : "No key stored, optional for local servers"))
                        .font(.caption)
                        .foregroundStyle(keyError == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    Spacer()
                    if !keyDraft.isEmpty {
                        Button("Save", action: saveKey)
                    } else if keyHint != nil {
                        Button("Remove", action: removeKey)
                    }
                }
                if settings.aiProvider == .anthropic {
                    Picker("Model", selection: anthropicModelSelection) {
                        Text("Claude Opus 5.5").tag("claude-opus-5-5")
                        Text("Claude Sonnet 5.5").tag("claude-sonnet-5-5")
                        Text("Claude Haiku 5.5").tag("claude-haiku-5-5")
                        Text("Other…").tag("")
                    }
                    if customAnthropicModel {
                        TextField("Model id", text: $settings.aiAnthropicModel)
                    }
                } else {
                    TextField("Model", text: $settings.aiOtherModel)
                    TextField("Base URL", text: $settings.aiOtherBaseURL)
                }
            }
            Section {
                HStack {
                    Text(testStatus ?? "")
                        .font(.caption)
                        .foregroundStyle(testFailed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .textSelection(.enabled)
                    Spacer()
                    Button("Test", action: testConnection)
                        .disabled(testRunner != nil)
                }
                Text("Prompt transformers send the scrap to this provider with your key. Keys live in the Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// The picker shows a known model, or `Other…` with a text field for anything else.
    private var anthropicModelSelection: Binding<String> {
        Binding(
            get: { customAnthropicModel || !AISettings.anthropicModels.contains(settings.aiAnthropicModel) ? "" : settings.aiAnthropicModel },
            set: { picked in
                customAnthropicModel = picked.isEmpty
                if !picked.isEmpty { settings.aiAnthropicModel = picked }
            })
    }

    private func refreshKey() {
        keyError = nil
        if let key = Keychain.read(account: keyAccount), !key.isEmpty {
            keyHint = "Key ends in …" + String(key.suffix(4))
        } else {
            keyHint = nil
        }
        customAnthropicModel = !AISettings.anthropicModels.contains(settings.aiAnthropicModel)
    }

    private func saveKey() {
        let value = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        do {
            try Keychain.write(value, account: keyAccount)
            keyDraft = ""
            refreshKey()
        } catch {
            keyError = error.localizedDescription
        }
    }

    private func removeKey() {
        Keychain.delete(account: keyAccount)
        refreshKey()
    }

    private func testConnection() {
        saveKey()
        let endpoint: PromptEndpoint
        switch PromptEndpoint.resolve(provider: nil, model: nil, effort: nil, settings: settings.aiSettings()) {
        case .failure(let error):
            testStatus = error.message
            testFailed = true
            return
        case .success(let resolved):
            endpoint = resolved
        }
        let request = PromptRequest.build(endpoint: endpoint, systemPrompt: "You are a connectivity test.",
                                          input: "Reply with OK.", maxTokens: 16)
        let runner = PromptRunner(request: request, provider: endpoint.provider, timeout: 15)
        let started = ContinuousClock.now
        testRunner = runner
        testStatus = "Testing…"
        testFailed = false
        runner.start { result in
            guard testRunner === runner else { return }
            testRunner = nil
            let seconds = Double((ContinuousClock.now - started).components.seconds)
                + Double((ContinuousClock.now - started).components.attoseconds) / 1e18
            switch result {
            case .success:
                testStatus = String(format: "OK · %@ · %.1f s", endpoint.model, seconds)
                testFailed = false
            case .failure(let error):
                testStatus = error.message
                testFailed = true
            }
        }
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
