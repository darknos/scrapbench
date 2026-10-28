// Drives the app for the README demo: layout-independent typing through CGEvent.
// Usage: demo-driver backdrop:x,y,w,h (stays up until killed)
//        demo-driver open | esc | enter | cmd:<key> | clip:<text> | type:<text> | sleep:<s> ... type:<text> | esc | sleep:<seconds> ...
import AppKit
import Foundation

func post(_ key: CGKeyCode, flags: CGEventFlags = []) {
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)!
        e.flags = flags
        e.post(tap: .cgSessionEventTap)
        usleep(12_000)
    }
}

// US layout key codes, so apps that look at keyCode see something sensible.
let usKeys: [Character: CGKeyCode] = {
    var m: [Character: CGKeyCode] = [:]
    let rows: [(String, [CGKeyCode])] = [
        ("asdfhgzxcv", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
        ("bqweryt123465=97-80]ou[ip", [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35]),
        ("l;'", [37, 41, 39]), ("kj,/nm.", [40, 38, 43, 44, 45, 46, 47]), ("`", [50]),
        (" \n\t", [49, 36, 48]),
    ]
    for (chars, codes) in rows { for (c, k) in zip(chars, codes) { m[c] = k } }
    return m
}()

let source = CGEventSource(stateID: .combinedSessionState)

func type(_ text: String) {
    for ch in text {
        var units = Array(String(ch).utf16)
        let key = usKeys[Character(ch.lowercased())] ?? 0
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)!
            e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            e.flags = []
            e.post(tap: .cgSessionEventTap)
            usleep(12_000)
        }
        usleep(ch == "\n" ? 180_000 : UInt32.random(in: 35_000...85_000))
    }
}

/// A plain window under the panel so the recording does not show the desktop. It never takes key focus.
final class Backdrop: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

func showBackdrop(_ spec: String) {
    let v = spec.split(separator: ",").compactMap { Double($0) }
    guard v.count == 4 else { return }
    let screenHeight = NSScreen.screens[0].frame.height
    let rect = NSRect(x: v[0], y: screenHeight - v[1] - v[3], width: v[2], height: v[3])
    let w = Backdrop(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    w.backgroundColor = NSColor(calibratedWhite: 0.93, alpha: 1)
    w.level = .normal
    w.hasShadow = false
    w.orderFrontRegardless()
}

let args = Array(CommandLine.arguments.dropFirst())
if let spec = args.first(where: { $0.hasPrefix("backdrop:") }) {
    // Backdrop mode: show the window and stay alive until killed; no key events are sent.
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    showBackdrop(String(spec.dropFirst(9)))
    app.run()
} else {
    run(args)
}

func run(_ args: [String]) {
for arg in args {
    switch arg {
    case "open":
        let script = """
        tell application "System Events" to tell process "Scrapbench"
            click menu bar item 1 of menu bar 2
            click menu item "Open Bench" of menu 1 of menu bar item 1 of menu bar 2
        end tell
        """
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); p.arguments = ["-e", script]
        try? p.run(); p.waitUntilExit()
    case "esc": post(53)
    case "enter": post(36)
    case let s where s.hasPrefix("move:"):
        let v = s.dropFirst(5).split(separator: ",").compactMap { Double($0) }
        guard v.count == 2 else { break }
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: v[0], y: v[1]), mouseButton: .left)?.post(tap: .cgSessionEventTap)
    case let s where s.hasPrefix("click:"):
        let v = s.dropFirst(6).split(separator: ",").compactMap { Double($0) }
        guard v.count == 2 else { break }
        let p = CGPoint(x: v[0], y: v[1])
        for (type, button) in [(CGEventType.leftMouseDown, CGMouseButton.left), (.leftMouseUp, .left)] {
            CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: button)?.post(tap: .cgSessionEventTap)
            usleep(40_000)
        }
    case let s where s.hasPrefix("cmd-opt:"):
        post(usKeys[Character(String(s.dropFirst(8)))] ?? 0, flags: [.maskCommand, .maskAlternate])
    case let s where s.hasPrefix("cmd:"):
        post(usKeys[Character(String(s.dropFirst(4)))] ?? 0, flags: .maskCommand)
    case let s where s.hasPrefix("clip:"):
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(s.dropFirst(5)).replacingOccurrences(of: "\\n", with: "\n"), forType: .string)
    case "up": post(126)
    case "down": post(125)
    case "home": post(115)
    case "tab": post(48)
    case "shift-tab": post(48, flags: .maskShift)
    case let s where s.hasPrefix("type:"): type(String(s.dropFirst(5)).replacingOccurrences(of: "\\n", with: "\n"))
    case let s where s.hasPrefix("sleep:"): usleep(UInt32((Double(s.dropFirst(6)) ?? 1) * 1_000_000))
    case let s where s.hasPrefix("backdrop:"): break
    default: FileHandle.standardError.write("unknown: \(arg)\n".data(using: .utf8)!)
    }
}
}
