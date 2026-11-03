import Foundation

/// Turns Claude Code's reset wording into a date.
///
/// Seen in 2.1.x: "3pm (Asia/Seoul)", "12am (Asia/Seoul)", "Nov 6, 10am (Asia/Seoul)",
/// "Nov 8 at 9am (Asia/Seoul)". The time is the next one after `now`; a date without
/// a year is this year's unless that's already well past.
enum ResetTimeParser {
    private static let pattern = try! NSRegularExpression(
        pattern: #"^(?:([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2})(?:,\s*(\d{4}))?(?:,|\s+at)?\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\s*(?:\(([^)]+)\))?$"#,
        options: .caseInsensitive)
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    static func parse(_ text: String, now: Date) -> Date? {
        let s = text.trimmingCharacters(in: .whitespaces)
        guard let m = pattern.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func group(_ i: Int) -> String? { Range(m.range(at: i), in: s).map { String(s[$0]) } }

        guard var hour = group(4).flatMap(Int.init), (1...12).contains(hour) else { return nil }
        let minute = group(5).flatMap(Int.init) ?? 0
        if hour == 12 { hour = 0 }
        if group(6)?.lowercased() == "pm" { hour += 12 }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = group(7).flatMap(TimeZone.init(identifier:)) ?? .current

        guard let monthName = group(1) else {
            // Time only: the next occurrence.
            return calendar.nextDate(after: now.addingTimeInterval(-1),
                                     matching: DateComponents(hour: hour, minute: minute, second: 0),
                                     matchingPolicy: .nextTime)
        }
        guard let month = months.firstIndex(of: monthName.lowercased()).map({ $0 + 1 }),
              let day = group(2).flatMap(Int.init) else { return nil }
        var parts = DateComponents(month: month, day: day, hour: hour, minute: minute)
        if let year = group(3).flatMap(Int.init) {
            parts.year = year
            return calendar.date(from: parts)
        }
        parts.year = calendar.component(.year, from: now)
        guard let date = calendar.date(from: parts) else { return nil }
        // "Jan 2" read in late December is next year.
        if date < now.addingTimeInterval(-86400) {
            parts.year! += 1
            return calendar.date(from: parts)
        }
        return date
    }
}
