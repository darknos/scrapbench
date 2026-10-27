import KeyboardShortcuts

final class HotkeyController {
    init(toggle: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .togglePanel, action: toggle)
    }
}
