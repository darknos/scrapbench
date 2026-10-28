import Foundation

/// One level of indentation at a time, as Tab and Shift-Tab do in editors.
/// Tabs are used when any line already starts with one, otherwise four spaces.
public enum Indentation {
    public static let spaces = "    "

    public static func indent(_ text: String) -> String {
        map(text) { lines in
            let unit = lines.contains { $0.hasPrefix("\t") } ? "\t" : spaces
            return lines.map { $0.isEmpty ? $0 : unit + $0 }
        }
    }

    public static func outdent(_ text: String) -> String {
        map(text) { lines in
            lines.map { line in
                if line.hasPrefix("\t") { return String(line.dropFirst()) }
                let leading = line.prefix(while: { $0 == " " }).count
                return String(line.dropFirst(min(leading, spaces.count)))
            }
        }
    }

    private static func map(_ text: String, _ transform: ([String]) -> [String]) -> String {
        let trailing = text.hasSuffix("\n")
        var lines = text.components(separatedBy: "\n")
        if trailing { lines.removeLast() }
        return transform(lines).joined(separator: "\n") + (trailing ? "\n" : "")
    }
}
