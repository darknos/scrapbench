import AppKit
import Combine
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.control, .option]))
}

enum Appearance: String, CaseIterable {
    case system, light, dark

    var label: String { rawValue.capitalized }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum IndentUnit: String, CaseIterable {
    case twoSpaces, fourSpaces, tab

    var label: String {
        switch self {
        case .twoSpaces: return "2 spaces"
        case .fourSpaces: return "4 spaces"
        case .tab: return "Tab"
        }
    }

    var text: String {
        switch self {
        case .twoSpaces: return "  "
        case .fourSpaces: return "    "
        case .tab: return "\t"
        }
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()

    static let defaultFileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("scrapbench.md")
    static let supportDirectory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Scrapbench")

    @Published var fileURL: URL { didSet { defaults.set(fileURL.path, forKey: "filePath") } }
    @Published var fontName: String { didSet { defaults.set(fontName, forKey: "fontName") } }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: "fontSize") } }
    @Published var wordWrap: Bool { didSet { defaults.set(wordWrap, forKey: "wordWrap") } }
    @Published var indentUnit: IndentUnit { didSet { defaults.set(indentUnit.rawValue, forKey: "indentUnit") } }
    @Published var appearance: Appearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        fileURL = defaults.string(forKey: "filePath").map { URL(fileURLWithPath: $0) } ?? Self.defaultFileURL
        fontName = defaults.string(forKey: "fontName") ?? "Menlo"
        let size = defaults.double(forKey: "fontSize")
        fontSize = size > 0 ? size : 14
        appearance = defaults.string(forKey: "appearance").flatMap(Appearance.init) ?? .system
        wordWrap = defaults.object(forKey: "wordWrap") as? Bool ?? true
        indentUnit = defaults.string(forKey: "indentUnit").flatMap(IndentUnit.init) ?? .twoSpaces
    }

    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    /// Pseudo family for the system monospaced font, which has no public family name.
    static let systemMonoFamily = "System Mono"

    static let monospacedFamilies: [String] = {
        let manager = NSFontManager.shared
        let families = manager.availableFontFamilies.filter { family in
            guard let font = manager.font(withFamily: family, traits: [], weight: 5, size: 12) else { return false }
            return font.isFixedPitch && !family.hasPrefix(".")
        }
        return [systemMonoFamily] + families.sorted()
    }()

    var font: NSFont {
        if fontName == Self.systemMonoFamily { return .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
        return NSFontManager.shared.font(withFamily: fontName, traits: [], weight: 5, size: fontSize)
            ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
}
