import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "Scrapbench Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }
}
