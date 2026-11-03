import Foundation

/// A service whose plan usage the app shows. Adding one is a new type here,
/// a line in `Providers.all`, and a fixture test for its parser.
public protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }
    /// SF Symbol shown next to the name. Placeholder until each service has its own glyph.
    var symbolName: String { get }
    /// One letter for the monogram and ring icon styles.
    var monogram: String { get }
    var refreshInterval: Duration { get }
    /// Nil means the service's CLI isn't installed.
    func locateExecutable() -> String?
    /// Throws `ProviderFailure`.
    func fetch() async throws -> ProviderUsage
}

public enum Providers {
    public static let all: [any UsageProvider] = [ClaudeCodeProvider(), CodexProvider()]
}
