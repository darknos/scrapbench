import AppKit

/// The app never shows its menu bar (it is an accessory app behind a
/// non-activating panel), but AppKit routes ⌘-shortcuts through the main
/// menu, so one has to exist for Copy/Paste/Undo/Find to work.
enum MainMenu {
    static func build(settings: Selector, help: Selector, target: AnyObject) -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let prefs = NSMenuItem(title: "Settings…", action: settings, keyEquivalent: ",")
        prefs.target = target
        appMenu.addItem(prefs)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Scrapbench", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let findItem = NSMenuItem()
        let find = NSMenu(title: "Find")
        for (title, tag, key, mods) in [
            ("Find…", NSTextFinder.Action.showFindInterface, "f", NSEvent.ModifierFlags.command),
            ("Find Next", .nextMatch, "g", .command),
            ("Find Previous", .previousMatch, "g", [.command, .shift]),
            ("Use Selection for Find", .setSearchString, "e", .command),
        ] as [(String, NSTextFinder.Action, String, NSEvent.ModifierFlags)] {
            let item = find.addItem(withTitle: title, action: #selector(NSTextView.performTextFinderAction(_:)), keyEquivalent: key)
            item.keyEquivalentModifierMask = mods
            item.tag = tag.rawValue
        }
        findItem.submenu = find
        main.addItem(findItem)

        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        let helpEntry = helpMenu.addItem(withTitle: "Scrapbench Help", action: help, keyEquivalent: "?")
        helpEntry.target = target
        helpItem.submenu = helpMenu
        main.addItem(helpItem)
        return main
    }
}
