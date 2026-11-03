import Foundation

/// Bridges `ClaudeCodeProvider` results to the snapshot the current UI reads.
/// Goes away when the panel and menu bar read `ProviderUsage` directly.
extension UsageSnapshot {
    public init(_ usage: ProviderUsage) {
        func percent(_ w: UsageWindow?) -> Int? { w.map { Int($0.usedPercent.rounded()) } }
        let session = usage.window(id: "5h")
        let week = usage.window(id: "week")
        let models: [ModelLimit] = usage.windows.compactMap { w in
            guard case .model(let name, _) = w.kind else { return nil }
            return ModelLimit(name: name, percent: percent(w), reset: w.resetText)
        }
        self.init(sessionPercent: percent(session), sessionReset: session?.resetText,
                  weekPercent: percent(week), weekReset: week?.resetText,
                  modelLimits: models, raw: usage.raw, updatedAt: usage.fetchedAt)
    }

    public init(_ failure: ProviderFailure, at date: Date = Date()) {
        self.init(error: UsageError(failure.error), raw: failure.raw, updatedAt: date)
    }
}

extension UsageError {
    init(_ e: ProviderError) {
        switch e {
        case .notInstalled:    self = .claudeNotFound
        case .launchFailed:    self = .launchFailed
        case .timeout:         self = .noResponse
        case .notLoggedIn:     self = .notLoggedIn
        case .unsupportedPlan: self = .apiBilling
        case .unparsable, .failed: self = .unparsable
        }
    }
}
