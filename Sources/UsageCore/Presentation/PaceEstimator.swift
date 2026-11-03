import Foundation

/// Predicts when a window reaches its limit. The store holds one; a better
/// model can replace `PaceEstimator` without touching the UI.
public protocol PaceModel: Sendable {
    /// When `window` would reach 100%, or nil if not before it resets.
    func projectedLimit(for window: UsageWindow, provider: ProviderID, now: Date) -> Date?
}

/// Assumes the rest of the window goes like the part so far. Needs no history:
/// the window started `length` before its reset.
public struct PaceEstimator: PaceModel {
    /// Too early in a window, one burst looks like a fast pace.
    public var minimumElapsedFraction = 0.1

    public init() {}

    public func projectedLimit(for window: UsageWindow, provider: ProviderID, now: Date) -> Date? {
        guard let reset = window.resetsAt, let minutes = window.kind.minutes,
              window.usedPercent > 0, window.usedPercent < 100 else { return nil }
        let length = TimeInterval(minutes * 60)
        let start = reset.addingTimeInterval(-length)
        let elapsed = now.timeIntervalSince(start)
        guard elapsed >= length * minimumElapsedFraction, elapsed < length else { return nil }
        let hit = start.addingTimeInterval(elapsed * 100 / window.usedPercent)
        return hit < reset ? hit : nil
    }
}

/// Told about every good reading. Lets features like history recording plug in
/// with one registration line.
@MainActor
public protocol UsageObserver: AnyObject {
    func usageDidUpdate(_ usage: ProviderUsage, provider: ProviderID)
}

extension UsageWindow.Kind {
    /// Window length; nil for a model cap of unknown length.
    public var minutes: Int? {
        switch self {
        case .rolling(let m): return m
        case .model(_, let m): return m
        }
    }
}
