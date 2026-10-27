import AppKit

final class StatusItemController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(open: Selector, settings: Selector, help: Selector, target: AnyObject) {
        item.button?.image = NSImage(systemSymbolName: "text.append", accessibilityDescription: "Scrapbench")
        let menu = NSMenu()
        let openItem = menu.addItem(withTitle: "Open Bench", action: open, keyEquivalent: "")
        openItem.target = target
        let settingsItem = menu.addItem(withTitle: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        let helpItem = menu.addItem(withTitle: "Help", action: help, keyEquivalent: "")
        helpItem.target = target
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Scrapbench", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }
}
