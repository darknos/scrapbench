import AppKit

final class StatusItemController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    /// The bundled template image; the symbol is the fallback for `swift run` without a bundle.
    private static var menuIcon: NSImage? {
        if let image = Bundle.main.image(forResource: "MenuIcon") {
            image.isTemplate = true
            image.accessibilityDescription = "Scrapbench"
            return image
        }
        return NSImage(systemSymbolName: "text.append", accessibilityDescription: "Scrapbench")
    }

    init(open: Selector, about: Selector, settings: Selector, help: Selector, target: AnyObject) {
        item.button?.image = Self.menuIcon
        let menu = NSMenu()
        let openItem = menu.addItem(withTitle: "Open Bench", action: open, keyEquivalent: "")
        openItem.target = target
        menu.addItem(.separator())
        let aboutItem = menu.addItem(withTitle: "About Scrapbench", action: about, keyEquivalent: "")
        aboutItem.target = target
        let settingsItem = menu.addItem(withTitle: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        let helpItem = menu.addItem(withTitle: "Help", action: help, keyEquivalent: "")
        helpItem.target = target
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Scrapbench", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }
}
