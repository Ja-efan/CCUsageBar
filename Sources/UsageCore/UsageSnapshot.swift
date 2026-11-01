import Foundation

/// A model-scoped weekly cap, e.g. "Current week (Fable)".
public struct ModelLimit: Equatable, Sendable, Identifiable {
    public var name: String
    public var percent: Int?
    public var reset: String?
    public var id: String { name }

    public init(name: String, percent: Int? = nil, reset: String? = nil) {
        self.name = name
        self.percent = percent
        self.reset = reset
    }
}

/// One reading of Claude Code plan usage.
public struct UsageSnapshot: Equatable, Sendable {
    public var sessionPercent: Int?
    public var sessionReset: String?
    public var weekPercent: Int?
    public var weekReset: String?
    public var modelLimits: [ModelLimit]
    public var error: UsageError?
    public var raw: String
    public var updatedAt: Date

    public init(sessionPercent: Int? = nil, sessionReset: String? = nil,
                weekPercent: Int? = nil, weekReset: String? = nil,
                modelLimits: [ModelLimit] = [],
                error: UsageError? = nil, raw: String = "", updatedAt: Date = Date()) {
        self.sessionPercent = sessionPercent
        self.sessionReset = sessionReset
        self.weekPercent = weekPercent
        self.weekReset = weekReset
        self.modelLimits = modelLimits
        self.error = error
        self.raw = raw
        self.updatedAt = updatedAt
    }

    public var hasUsage: Bool { sessionPercent != nil || weekPercent != nil }

    public func modelLimit(named name: String) -> ModelLimit? {
        modelLimits.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

public enum UsageError: Equatable, Sendable {
    case claudeNotFound
    case launchFailed
    case noResponse
    case notLoggedIn
    case apiBilling
    case unparsable
}
