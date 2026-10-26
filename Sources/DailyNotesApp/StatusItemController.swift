import AppKit

final class StatusItemController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(open: Selector, settings: Selector, target: AnyObject) {
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Daily Notes")
        let menu = NSMenu()
        let openItem = menu.addItem(withTitle: "Open Notes", action: open, keyEquivalent: "")
        openItem.target = target
        let settingsItem = menu.addItem(withTitle: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit DailyNotes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }
}
