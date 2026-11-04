import Foundation

/// How often the app reads each service. A closed set: anything shorter makes Claude Code
/// hide the model caps (rate limited in 5 of 30 reads at 2 minutes), so don't go below it.
public enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case two = 2, five = 5, ten = 10, fifteen = 15, thirty = 30

    public static let standard = RefreshInterval.five

    public var id: Int { rawValue }
    public var minutes: Int { rawValue }
    public var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    /// Missing or unknown saved value means the default.
    public init(saved: Int?) {
        self = saved.flatMap(RefreshInterval.init(rawValue:)) ?? .standard
    }
}

/// Whether a scheduled read is worth its CPU. Warnings only exist on screen, so nobody
/// misses a read while the screen is off; the read when it comes back catches up.
public enum ScheduledRead {
    /// The lock and display notifications can be missed, so never hold longer than this.
    public static let longestHold: TimeInterval = 3600

    public static func isDue(screenOff: Bool, lastAttempt: Date?, now: Date) -> Bool {
        guard screenOff, let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= longestHold
    }
}
