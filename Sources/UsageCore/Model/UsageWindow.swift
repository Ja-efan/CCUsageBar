import Foundation

/// One usage limit of a service, e.g. Claude's 5-hour session or Codex's 30-day window.
/// Services and plans have different windows, so a reading is a list of these.
public struct UsageWindow: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// A rolling window: 300 = 5 hours, 10080 = a week, 43200 = 30 days.
        case rolling(minutes: Int)
        /// A cap scoped to one model, e.g. Claude "Current week (Fable)".
        case model(name: String, minutes: Int?)
    }

    /// Stable key used in settings: "5h", "week", "model:Fable", "30d".
    public let id: String
    public let kind: Kind
    public let usedPercent: Double
    /// Nil when the service only gives text that couldn't be parsed.
    public let resetsAt: Date?
    /// The service's own reset wording, shown when `resetsAt` is nil.
    public let resetText: String?

    /// Settings key for a rolling window: "5h", "week", "30d".
    public static func rollingID(minutes: Int) -> String {
        if minutes == 10080 { return "week" }
        if minutes % 1440 == 0 { return "\(minutes / 1440)d" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }

    public init(id: String, kind: Kind, usedPercent: Double, resetsAt: Date? = nil, resetText: String? = nil) {
        self.id = id
        self.kind = kind
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.resetText = resetText
    }
}
