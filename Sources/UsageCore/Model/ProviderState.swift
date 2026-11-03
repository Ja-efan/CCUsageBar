import Foundation

/// What the app knows about one service: the last good reading and the latest problem.
public struct ProviderState: Equatable, Sendable {
    /// Kept when a later read fails, so a transient timeout doesn't blank the numbers.
    public private(set) var usage: ProviderUsage?
    /// The latest read's problem; nil after a success.
    public private(set) var error: ProviderError?
    /// The latest read's output, good or not.
    public private(set) var raw = ""
    public private(set) var lastAttempt: Date?
    public var isLoading = false

    public init() {}

    /// Showing an older reading because the latest one failed.
    public var isStale: Bool { usage != nil && error != nil }

    public mutating func apply(_ result: Result<ProviderUsage, ProviderFailure>, at date: Date = Date()) {
        lastAttempt = date
        switch result {
        case .success(let new):
            usage = new
            error = nil
            raw = new.raw
        case .failure(let failure):
            error = failure.error
            raw = failure.raw
        }
    }
}
