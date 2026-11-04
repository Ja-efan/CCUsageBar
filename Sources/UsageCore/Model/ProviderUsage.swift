import Foundation

public struct ProviderID: Hashable, Codable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

/// One successful reading from a service.
public struct ProviderUsage: Equatable, Sendable {
    /// Plan name if the service reports it ("Max", "Free").
    public var plan: String?
    public var windows: [UsageWindow]
    public var fetchedAt: Date
    /// Original output, for the raw output window.
    public var raw: String
    /// The service couldn't report its model caps this time; they may still exist.
    public var modelWindowsUnavailable: Bool

    public init(plan: String? = nil, windows: [UsageWindow], fetchedAt: Date = Date(), raw: String = "",
                modelWindowsUnavailable: Bool = false) {
        self.plan = plan
        self.windows = windows
        self.fetchedAt = fetchedAt
        self.raw = raw
        self.modelWindowsUnavailable = modelWindowsUnavailable
    }

    public func window(id: String) -> UsageWindow? { windows.first { $0.id == id } }
}

public enum ProviderError: Error, Equatable, Sendable {
    case notInstalled
    case launchFailed
    case notLoggedIn
    case timeout
    /// The account has no plan limits to show (e.g. API billing).
    case unsupportedPlan
    case unparsable
    case failed(String)
}

/// What `UsageProvider.fetch()` throws. Keeps the output so a failed read can still
/// be inspected in the raw output window.
public struct ProviderFailure: Error, Equatable, Sendable {
    public var error: ProviderError
    public var raw: String

    public init(_ error: ProviderError, raw: String = "") {
        self.error = error
        self.raw = raw
    }
}
