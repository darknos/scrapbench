import Foundation

/// The timestamped line that opens every scrap in the scrap file.
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

    /// The scrap around `offset`: from the line after the previous separator
    /// (or the start of text) to the last non-blank line before the next
    /// separator (or the end). A cursor on a separator line selects the scrap
    /// below it. Walks line by line, so cost is proportional to the scrap, not the file.
    public static func scrap(containing offset: Int, in text: NSString) -> NSRange {
        let length = text.length
        let offset = min(max(offset, 0), length)
        func line(at position: Int) -> (start: Int, end: Int, contentsEnd: Int) {
            var start = 0, end = 0, contentsEnd = 0
            text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd,
                              for: NSRange(location: min(position, length), length: 0))
            return (start, end, contentsEnd)
        }
        func isSeparator(_ l: (start: Int, end: Int, contentsEnd: Int)) -> Bool {
            isSeparatorLine(Substring(text.substring(with: NSRange(location: l.start, length: l.contentsEnd - l.start))))
        }

        let current = line(at: offset)
        var start: Int
        if isSeparator(current) {
            start = current.end
        } else {
            start = 0
            var probe = current
            while probe.start > 0 {
                probe = line(at: probe.start - 1)
                if isSeparator(probe) { start = probe.end; break }
            }
        }

        var end = length
        var position = start
        while position < length {
            let l = line(at: position)
            if isSeparator(l) { end = l.start; break }
            // The last line of a text without a trailing newline ends at `length`.
            if l.end <= position { break }
            position = l.end
        }

        // Drop blank lines between the scrap and the next separator.
        while end > start, text.character(at: end - 1) == 0x0A || text.character(at: end - 1) == 0x0D {
            end -= 1
        }
        return NSRange(location: start, length: end - start)
    }

    /// Match of a separator line within `text`, split into dashes / date / dashes ranges (UTF-16).
    public static func matches(in text: NSString, range: NSRange) -> [(dashesLeft: NSRange, date: NSRange, dashesRight: NSRange)] {
        lineRegex.matches(in: text as String, options: [.withTransparentBounds], range: range).map {
            ($0.range(at: 1), $0.range(at: 2), $0.range(at: 3))
        }
    }
}
