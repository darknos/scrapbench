import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController!
    private var hotkey: HotkeyController!
    private var session: SessionController!
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build(settings: #selector(openSettings), target: self)
        session = SessionController()
        statusItem = StatusItemController(open: #selector(openNotes), settings: #selector(openSettings), target: self)
        hotkey = HotkeyController { [weak self] in self?.session.toggle() }
        if CommandLine.arguments.contains("--open") { session.open() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        session.close()
        return .terminateNow
    }

    @objc func openNotes() { session.open() }

    @objc func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController() }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
