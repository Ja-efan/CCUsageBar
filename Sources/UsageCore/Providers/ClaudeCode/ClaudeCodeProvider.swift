import Foundation

/// Runs the `claude` CLI in a pseudo-terminal, sends `/usage`, and reads the screen.
/// No model call is made, so no tokens are used. Keychain is never read directly.
public struct ClaudeCodeProvider: UsageProvider {
    public let id = ProviderID("claude")
    public let displayName = "Claude Code"
    public let symbolName = "asterisk"
    public let monogram = "C"
    /// Without this, every read starts the user's MCP servers: 9 processes instead of 2,
    /// and 3.1 s of CPU instead of 2.6 s.
    static let launchArguments = ["--strict-mcp-config"]
    public var timeout: TimeInterval = 25
    public var workDirectory: String

    public init(workDirectory: String = NSHomeDirectory() + "/Library/Application Support/Noonchi") {
        self.workDirectory = workDirectory
    }

    public func locateExecutable() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            ProcessInfo.processInfo.environment["NOONCHI_CLAUDE_PATH"],
            ProcessInfo.processInfo.environment["CCUSAGEBAR_CLAUDE_PATH"], // old name
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func fetch() async throws -> ProviderUsage {
        // The read blocks for seconds; keep it off the cooperative thread pool.
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(with: Self.usage(from: readSnapshot()))
            }
        }
    }

    static func usage(from snap: UsageSnapshot) -> Result<ProviderUsage, ProviderFailure> {
        guard snap.hasUsage else {
            return .failure(ProviderFailure(ProviderError(snap.error ?? .unparsable), raw: snap.raw))
        }
        func reset(_ text: String?) -> Date? { text.flatMap { ResetTimeParser.parse($0, now: snap.updatedAt) } }
        var windows: [UsageWindow] = []
        if let p = snap.sessionPercent {
            windows.append(UsageWindow(id: "5h", kind: .rolling(minutes: 300), usedPercent: Double(p),
                                       resetsAt: reset(snap.sessionReset), resetText: snap.sessionReset))
        }
        if let p = snap.weekPercent {
            windows.append(UsageWindow(id: "week", kind: .rolling(minutes: 10080), usedPercent: Double(p),
                                       resetsAt: reset(snap.weekReset), resetText: snap.weekReset))
        }
        for m in snap.modelLimits {
            guard let p = m.percent else { continue }
            windows.append(UsageWindow(id: "model:\(m.name)", kind: .model(name: m.name, minutes: 10080),
                                       usedPercent: Double(p), resetsAt: reset(m.reset), resetText: m.reset))
        }
        return .success(ProviderUsage(plan: snap.plan, windows: windows, fetchedAt: snap.updatedAt, raw: snap.raw,
                                      modelWindowsUnavailable: snap.modelLimitsUnavailable))
    }

    func readSnapshot() -> UsageSnapshot {
        guard let claude = locateExecutable() else { return UsageSnapshot(error: .claudeNotFound) }
        var (raw, err) = capture(claudePath: claude, arguments: Self.launchArguments)
        // A CLI that no longer knows the flag must still give a reading.
        if Self.rejectedArguments(raw) { (raw, err) = capture(claudePath: claude, arguments: []) }
        // Read the final screen; fall back to the stream if the view scrolled off.
        let screen = TerminalScreen.render(raw, columns: Self.columns, rows: Self.rows).text
        var snap = UsageParser.parse(screen)
        if !snap.hasUsage {
            let fromStream = UsageParser.parse(TerminalText.clean(raw))
            if fromStream.hasUsage { snap = fromStream }
        }
        // The banner may have scrolled off the final screen.
        if snap.plan == nil { snap.plan = UsageParser.plan(in: TerminalText.clean(raw)) }
        snap.raw = UsageParser.withoutLocalStats(snap.raw)
        saveDebug(cleaned: snap.raw)
        if let err { snap.error = err }
        return snap
    }

    /// The key that moves the folder trust prompt toward "Yes, I trust this folder":
    /// Enter when it's selected, otherwise Down. Nil when the prompt isn't on screen.
    /// 2.1.310 selects "No, exit" first, so a bare Enter would quit.
    static func trustPromptKey(_ screen: String) -> String? {
        let lines = screen.components(separatedBy: "\n")
        guard lines.contains(where: { $0.lowercased().contains("trust this folder") }) else { return nil }
        let selected = lines.first { $0.hasPrefix("❯") } ?? ""
        return selected.lowercased().contains("trust this folder") ? "\r" : "\u{1b}[B"
    }

    static let columns = 140
    static let rows = 50

    /// Last captured screen, for troubleshooting parser issues.
    public var debugFile: String { workDirectory + "/last-output.txt" }

    func saveDebug(cleaned: String) {
        try? cleaned.write(toFile: debugFile, atomically: true, encoding: .utf8)
        // v0.3 also kept the unfiltered PTY stream.
        try? FileManager.default.removeItem(atPath: workDirectory + "/last-output.raw.txt")
    }

    static func rejectedArguments(_ output: String) -> Bool {
        output.range(of: "unknown option", options: .caseInsensitive) != nil
    }

    func capture(claudePath: String, arguments: [String]) -> (String, UsageError?) {
        try? FileManager.default.createDirectory(atPath: workDirectory, withIntermediateDirectories: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workDirectory, isDirectory: &isDirectory), isDirectory.boolValue
        else { return ("", .launchFailed) }

        let home = NSHomeDirectory()
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["HOME"] = home
        env["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        guard let pty = PTYSession.spawn(executable: claudePath, arguments: arguments, environment: env, directory: workDirectory,
                                         columns: Self.columns, rows: Self.rows)
        else { return ("", .launchFailed) }

        let start = Date()
        var sentUsage = false
        var sentAt = Date()
        var trustKeys = 0

        while Date().timeIntervalSince(start) < timeout {
            pty.drain()
            usleep(100_000)
            let t = TerminalText.clean(pty.text)
            let elapsed = Date().timeIntervalSince(start)

            if !sentUsage {
                // Accept "trust this folder" for the app's private work dir. Bounded so an
                // unexpected prompt layout can't loop.
                if trustKeys < 4, let key = Self.trustPromptKey(pty.screen) {
                    trustKeys += 1
                    pty.send(key)
                    usleep(key == "\r" ? 1_500_000 : 200_000)
                    continue
                }
                if elapsed > 1.5, t.contains("❯") || elapsed > 6 {
                    pty.send("/usage"); usleep(600_000); pty.send("\r")
                    sentUsage = true; sentAt = Date()
                }
            } else {
                let since = Date().timeIntervalSince(sentAt)
                // `/usage` first shows cached numbers with "Refreshing…", then overwrites
                // them in place. Wait until the refresh is gone from the screen.
                let s = pty.screen
                let found = TerminalText.count(s, pattern: "\\d{1,3}\\s*%\\s*used") >= 2 && !s.contains("Refreshing")
                if (found && since > 1.5) || since > 12 { usleep(300_000); break }
            }
        }

        pty.drain()
        let result = (pty.text, sentUsage ? nil : UsageError.noResponse)
        pty.finish(exitKeys: ["\u{1b}", "\u{3}", "\u{3}"]) // Esc, Ctrl-C twice
        return result
    }
}

extension ProviderError {
    init(_ e: UsageError) {
        switch e {
        case .claudeNotFound: self = .notInstalled
        case .launchFailed:   self = .launchFailed
        case .noResponse:     self = .timeout
        case .notLoggedIn:    self = .notLoggedIn
        case .apiBilling:     self = .unsupportedPlan
        case .unparsable:     self = .unparsable
        }
    }
}
