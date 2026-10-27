import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController!
    private var hotkey: HotkeyController!
    private var session: SessionController!
    private var settingsWindow: SettingsWindowController?
    private var helpWindow: HelpWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build(settings: #selector(openSettings), help: #selector(openHelp),
                                        transform: #selector(openTransformPalette),
                                        repeatTransform: #selector(repeatTransform), target: self)
        session = SessionController()
        statusItem = StatusItemController(open: #selector(openBench), settings: #selector(openSettings),
                                          help: #selector(openHelp), target: self)
        hotkey = HotkeyController { [weak self] in self?.session.toggle() }
        NSApp.servicesProvider = self
        if CommandLine.arguments.contains("--open") { session.open() }
    }

    /// "Take to Scrapbench" service; the selector name must match `NSMessage` in Info.plist.
    @objc func takeToBench(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let text = pasteboard.string(forType: .string) else {
            error.pointee = "No text selected"
            return
        }
        session.take(text: text)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        session.close()
        return .terminateNow
    }

    @objc func openBench() { session.open() }

    @objc func openTransformPalette() { session.transform.openPalette() }

    @objc func repeatTransform() { session.transform.repeatLast() }

    @objc func openHelp() {
        if helpWindow == nil { helpWindow = HelpWindowController() }
        helpWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController() }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
