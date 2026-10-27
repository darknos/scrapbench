import AppKit

/// Read-only editor showing `HelpText`, so the examples render with real highlighting.
final class HelpWindowController: NSWindowController {
    init() {
        let (scroll, editor) = EditorTextView.make(centresEnd: false)
        editor.isEditable = false
        editor.load(HelpText.markdown)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DailyNotes Help"
        window.contentView = scroll
        window.minSize = NSSize(width: 400, height: 300)
        window.center()
        super.init(window: window)
        editor.onEscape = { [weak window] in window?.close() }
    }

    required init?(coder: NSCoder) { fatalError() }
}
