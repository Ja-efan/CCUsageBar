import Foundation
import Darwin

/// Runs the `claude` CLI in a pseudo-terminal, sends `/usage`, and captures output.
/// No model call is made, so no tokens are used. Keychain is never read directly.
public struct ClaudeRunner: Sendable {
    public var timeout: TimeInterval = 25
    public var workDirectory: String

    public init(workDirectory: String = NSHomeDirectory() + "/Library/Application Support/CCUsageBar") {
        self.workDirectory = workDirectory
    }

    public static func findClaude() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            ProcessInfo.processInfo.environment["CCUSAGEBAR_CLAUDE_PATH"],
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func fetch() -> UsageSnapshot {
        guard let claude = Self.findClaude() else { return UsageSnapshot(error: .claudeNotFound) }
        let (raw, err) = capture(claudePath: claude)
        var snap = UsageParser.parse(raw)
        if let err { snap.error = err }
        return snap
    }

    func capture(claudePath: String) -> (String, UsageError?) {
        try? FileManager.default.createDirectory(atPath: workDirectory, withIntermediateDirectories: true)

        var master: Int32 = 0
        var ws = winsize(ws_row: 50, ws_col: 140, ws_xpixel: 0, ws_ypixel: 0)
        let pid = forkpty(&master, nil, nil, &ws)
        if pid < 0 { return ("", .launchFailed) }
        if pid == 0 {
            chdir(workDirectory)
            let home = NSHomeDirectory()
            setenv("TERM", "xterm-256color", 1)
            setenv("HOME", home, 1)
            setenv("PATH", "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin", 1)
            let args: [UnsafeMutablePointer<CChar>?] = [strdup(claudePath), nil]
            execv(claudePath, args)
            _exit(127)
        }

        _ = fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK)

        var buffer = Data()
        let start = Date()
        var sentUsage = false
        var sentAt = Date()
        var trustHandled = false

        func send(_ s: String) { _ = s.withCString { write(master, $0, strlen($0)) } }
        func drain() {
            var chunk = [UInt8](repeating: 0, count: 8192)
            while true {
                let n = read(master, &chunk, chunk.count)
                if n <= 0 { break }
                buffer.append(contentsOf: chunk[0..<n])
            }
        }
        func text() -> String { TerminalText.clean(String(decoding: buffer, as: UTF8.self)) }

        while Date().timeIntervalSince(start) < timeout {
            drain()
            usleep(100_000)
            let t = text()
            let elapsed = Date().timeIntervalSince(start)

            if !sentUsage {
                if !trustHandled, t.lowercased().contains("trust"), t.lowercased().contains("folder") {
                    trustHandled = true
                    send("\r") // accept "trust this folder" for the app's private work dir
                    usleep(1_500_000)
                    continue
                }
                if elapsed > 2.5, t.contains("❯") || elapsed > 6 {
                    send("/usage"); usleep(600_000); send("\r")
                    sentUsage = true; sentAt = Date()
                }
            } else {
                let since = Date().timeIntervalSince(sentAt)
                let found = TerminalText.count(TerminalText.usageSection(t), pattern: "\\d{1,3}\\s*%") >= 2
                if (found && since > 2.0) || since > 12 { usleep(500_000); break }
            }
        }

        drain()
        send("\u{1b}"); usleep(300_000); send("\u{3}"); usleep(300_000); send("\u{3}"); usleep(500_000)
        kill(pid, SIGTERM); usleep(300_000); kill(pid, SIGKILL)
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        close(master)

        return (text(), sentUsage ? nil : .noResponse)
    }
}
