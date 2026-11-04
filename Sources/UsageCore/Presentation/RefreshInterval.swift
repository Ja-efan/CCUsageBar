import Foundation

/// How often the app reads each service, in whole minutes.
public struct RefreshInterval: Equatable, Sendable {
    public static let range = 1...120
    public static let standard = RefreshInterval(minutes: 5)

    public let minutes: Int
    public var seconds: TimeInterval { TimeInterval(minutes * 60) }

    /// Anything typed outside the range lands on its nearest end.
    public init(minutes: Int) {
        self.minutes = min(max(minutes, Self.range.lowerBound), Self.range.upperBound)
    }

    /// A missing saved value means the default.
    public init(saved: Int?) {
        self = saved.map(RefreshInterval.init(minutes:)) ?? .standard
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
