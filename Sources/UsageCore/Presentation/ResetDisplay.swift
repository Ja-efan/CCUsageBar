import Foundation

/// How a reset time is shown in the panel; the app turns it into text.
public enum ResetDisplay: Equatable, Sendable {
    /// Within an hour: "42분 후". Zero when the time has already passed.
    case inMinutes(Int)
    /// Later today: "3:59 PM".
    case time(Date)
    /// Tomorrow to six days from now: "토 8:59 AM".
    case weekdayTime(Date)
    /// A week or more from now: "11월 19일".
    case date(Date)

    public init(_ resetsAt: Date, now: Date = Date(), calendar: Calendar = .current) {
        let seconds = resetsAt.timeIntervalSince(now)
        if seconds < 3600 {
            self = .inMinutes(max(0, Int((seconds / 60).rounded(.up))))
            return
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: resetsAt)).day ?? 0
        switch days {
        case ..<1: self = .time(resetsAt)
        case ..<7: self = .weekdayTime(resetsAt)
        default: self = .date(resetsAt)
        }
    }

    /// Reset wording without the time zone, for windows whose date couldn't be read:
    /// "Nov 8 at 9am (Asia/Seoul)" → "Nov 8 at 9am".
    public static func trimmed(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
    }
}
