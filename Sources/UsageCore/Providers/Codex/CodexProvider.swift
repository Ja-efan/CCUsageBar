import Foundation

/// Asks `codex app-server` for the account's rate limits over stdio JSON-RPC.
/// Codex handles its own login; `~/.codex/auth.json` is never read, and
/// `account/read` isn't called because it returns the email address.
public struct CodexProvider: UsageProvider {
    public let id = ProviderID("codex")
    public let displayName = "Codex"
    public let symbolName = "hexagon"
    public let monogram = "X"
    /// A read is one small request, so it can poll more often than Claude.
    public let refreshInterval: Duration = .seconds(120)
    public var timeout: TimeInterval = 20
    public var workDirectory: String

    public init(workDirectory: String = NSHomeDirectory() + "/Library/Application Support/Noonchi") {
        self.workDirectory = workDirectory
    }

    public func locateExecutable() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            ProcessInfo.processInfo.environment["NOONCHI_CODEX_PATH"],
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func fetch() async throws -> ProviderUsage {
        // The read blocks; keep it off the cooperative thread pool.
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(with: read())
            }
        }
    }

    func read() -> Result<ProviderUsage, ProviderFailure> {
        guard let codex = locateExecutable() else { return .failure(ProviderFailure(.notInstalled)) }
        try? FileManager.default.createDirectory(atPath: workDirectory, withIntermediateDirectories: true)

        let home = NSHomeDirectory()
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = home
        // GUI apps get a minimal PATH; an npm-installed codex is a node script and needs node.
        env["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        let deadline = Date().addingTimeInterval(timeout)
        do {
            let rpc = try JSONRPCProcess(executable: codex, arguments: ["app-server"], environment: env,
                                         directory: workDirectory)
            defer { rpc.finish() }
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
            _ = try rpc.request("initialize", params: ["clientInfo": ["name": "noonchi", "version": version]],
                                timeout: deadline.timeIntervalSinceNow)
            try rpc.notify("initialized")
            // Reset-credit details aren't shown; skip that extra lookup.
            let result = try rpc.request("account/rateLimits/read", params: ["excludeResetCreditDetails": true],
                                         timeout: deadline.timeIntervalSinceNow)
            return Self.usage(from: result)
        } catch let error as JSONRPCError {
            return .failure(ProviderFailure(ProviderError(error)))
        } catch {
            return .failure(ProviderFailure(.failed(String(describing: error))))
        }
    }

    /// Decodes an `account/rateLimits/read` result.
    static func usage(from result: Data, at date: Date = Date()) -> Result<ProviderUsage, ProviderFailure> {
        let raw = redacted(result)
        guard let response = try? JSONDecoder().decode(RateLimitsResponse.self, from: result) else {
            return .failure(ProviderFailure(.unparsable, raw: raw))
        }
        let windows = response.windows
        guard !windows.isEmpty else { return .failure(ProviderFailure(.unparsable, raw: raw)) }
        return .success(ProviderUsage(plan: response.planName, windows: windows, fetchedAt: date, raw: raw))
    }

    /// Pretty JSON for the raw output window: only the rate limit fields, so the
    /// account ID and anything Codex adds later stay out.
    static func redacted(_ result: Data) -> String {
        let kept = ["rateLimits", "rateLimitsByLimitId", "rateLimitResetCredits"]
        guard let obj = try? JSONSerialization.jsonObject(with: result) as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: obj.filter { kept.contains($0.key) },
                                                     options: [.prettyPrinted, .sortedKeys])
        else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

extension ProviderError {
    init(_ e: JSONRPCError) {
        switch e {
        case .launchFailed: self = .launchFailed
        case .timeout: self = .timeout
        // -32600 "codex account authentication required to read rate limits"
        case .remote(_, let message) where message.localizedCaseInsensitiveContains("authentication"):
            self = .notLoggedIn
        case .remote(_, let message): self = .failed(message)
        case .closed: self = .failed("codex app-server exited")
        case .malformed: self = .unparsable
        }
    }
}
