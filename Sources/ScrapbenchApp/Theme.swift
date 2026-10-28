import AppKit
import ScrapbenchCore

/// Muted light/dark palette in the spirit of the Claude desktop app:
/// near-black text, grey code pills, restrained token colours.
struct Theme {
    static let `default` = Theme()

    let text = dynamic(light: 0x1F1F1F, dark: 0xE6E6E3)
    let muted = dynamic(light: 0x8A8A86, dark: 0x8B8B88)
    let faint = dynamic(light: 0xC9C9C5, dark: 0x4A4A48)
    let accent = dynamic(light: 0xC98A1E, dark: 0xE0A030)   // amber, docs/brand.md
    let link = dynamic(light: 0x2A62CC, dark: 0x7FA7F2)
    let codeBackground = dynamic(light: 0xF0F0EE, dark: 0x2B2B29)
    let codeBlockBackground = dynamic(light: 0xF5F5F3, dark: 0x262624)
    let keyword = dynamic(light: 0x9A3FB3, dark: 0xC792EA)
    let string = dynamic(light: 0x2E7D32, dark: 0x9ECE6A)
    let number = dynamic(light: 0x0B5FBF, dark: 0x7DCFFF)
    let comment = dynamic(light: 0x8A8A86, dark: 0x6F6F6C)
    let literal = dynamic(light: 0xB35C00, dark: 0xFFB86C)
    let key = dynamic(light: 0x1F6F8B, dark: 0x89DDFF)

    func attributes(for kind: TokenKind, baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        switch kind {
        case .heading:
            return [.font: bold(baseFont)]
        case .bold:
            return [.font: bold(baseFont)]
        case .italic:
            return [.font: italic(baseFont)]
        case .inlineCode:
            return [.backgroundColor: codeBackground]
        case .link:
            return [.foregroundColor: link, .underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: faint]
        case .listMarker:
            return [.foregroundColor: accent]
        case .quote:
            return [.foregroundColor: muted]
        case .checkboxDone:
            return [.foregroundColor: muted, .strikethroughStyle: NSUnderlineStyle.single.rawValue, .strikethroughColor: faint]
        case .separatorDashes:
            return [.foregroundColor: faint]
        case .separatorDate:
            return [.foregroundColor: faint, .font: bold(baseFont)]
        case .codeFence:
            return [.foregroundColor: muted]
        case .codeBlockBackground:
            return [:]  // drawn full-width by EditorTextView.drawBackground
        case .keyword:
            return [.foregroundColor: keyword]
        case .string:
            return [.foregroundColor: string]
        case .number:
            return [.foregroundColor: number]
        case .comment:
            return [.foregroundColor: comment]
        case .literal:
            return [.foregroundColor: literal]
        case .key:
            return [.foregroundColor: key]
        }
    }

    private func bold(_ f: NSFont) -> NSFont { NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask) }
    private func italic(_ f: NSFont) -> NSFont { NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask) }

    private static func dynamic(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return rgb(isDark ? dark : light)
        }
    }

    private static func rgb(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}
