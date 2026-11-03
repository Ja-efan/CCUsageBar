import Foundation

/// How a reset time is shown in the panel; the app turns it into text.
public enum ResetDisplay: Equatable, Sendable {
    /// Within an hour: "42분 후". Zero when the time has already passed.
    case inMinutes(Int)
    /// Within a day: "3:59 PM".
    case time(Date)
    /// Within a week: "토 8:59 AM".
    case weekdayTime(Date)
    /// Later: "11월 19일".
    case date(Date)

    public init(_ resetsAt: Date, now: Date = Date()) {
        let seconds = resetsAt.timeIntervalSince(now)
        switch seconds {
        case ..<3600: self = .inMinutes(max(0, Int((seconds / 60).rounded(.up))))
        case ..<86400: self = .time(resetsAt)
        case ..<(7 * 86400): self = .weekdayTime(resetsAt)
        default: self = .date(resetsAt)
        }
    }

    /// Reset wording without the time zone, for windows whose date couldn't be read:
    /// "Nov 8 at 9am (Asia/Seoul)" → "Nov 8 at 9am".
    public static func trimmed(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
    }
}
