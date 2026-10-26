import Foundation

/// The timestamped line that opens every entry in the notes file.
public enum Separator {
    public static let dashes = String(repeating: "-", count: 20)

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static let lineRegex = try! NSRegularExpression(
        pattern: "^(-{20})(< \\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2} >)(-{20})$",
        options: [.anchorsMatchLines]
    )

    public static func make(date: Date, timeZone: TimeZone = .current) -> String {
        formatter.timeZone = timeZone
        return "\(dashes)< \(formatter.string(from: date)) >\(dashes)"
    }

    public static func isSeparatorLine(_ line: Substring) -> Bool {
        let s = String(line) as NSString
        return lineRegex.firstMatch(in: String(line), range: NSRange(location: 0, length: s.length)) != nil
    }

    /// Match of a separator line within `text`, split into dashes / date / dashes ranges (UTF-16).
    public static func matches(in text: NSString, range: NSRange) -> [(dashesLeft: NSRange, date: NSRange, dashesRight: NSRange)] {
        lineRegex.matches(in: text as String, options: [.withTransparentBounds], range: range).map {
            ($0.range(at: 1), $0.range(at: 2), $0.range(at: 3))
        }
    }
}
