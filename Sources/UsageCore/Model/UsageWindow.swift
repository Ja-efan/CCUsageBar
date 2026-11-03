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

    public init(id: String, kind: Kind, usedPercent: Double, resetsAt: Date? = nil, resetText: String? = nil) {
        self.id = id
        self.kind = kind
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.resetText = resetText
    }
}
