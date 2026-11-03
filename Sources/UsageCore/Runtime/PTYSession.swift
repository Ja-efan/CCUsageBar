import Foundation
import Darwin

/// A child process running in a pseudo-terminal. The caller polls `drain()` and
/// reads `output`; `finish(exitKeys:)` shuts the process down in the background.
public final class PTYSession {
    public let columns: Int
    public let rows: Int
    public private(set) var output = Data()
    private let pid: pid_t
    private let master: Int32

    /// Starts `executable` in `directory`. Returns nil if the terminal couldn't be created.
    public static func spawn(executable: String, environment: [String: String], directory: String,
                             columns: Int, rows: Int) -> PTYSession? {
        // Build every C string before fork: the child of a multithreaded process may only
        // make async-signal-safe calls, and allocating there can deadlock on a held malloc lock.
        let path = strdup(executable)
        let dir = strdup(directory)
        let argv: [UnsafeMutablePointer<CChar>?] = [strdup(executable), nil]
        let envp: [UnsafeMutablePointer<CChar>?] = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { ([path, dir] + argv + envp).forEach { free($0) } }

        var master: Int32 = 0
        var ws = winsize(ws_row: UInt16(rows), ws_col: UInt16(columns), ws_xpixel: 0, ws_ypixel: 0)
        let pid = forkpty(&master, nil, nil, &ws)
        if pid < 0 { return nil }
        if pid == 0 {
            // Never run (and answer prompts) anywhere but the given directory.
            if chdir(dir) != 0 { _exit(126) }
            // Pipes the app holds (e.g. another service's stdin) would otherwise stay open
            // in the CLI and its helpers, and that process would never see EOF.
            for fd in 3..<getdtablesize() { close(fd) }
            execve(path, argv, envp)
            _exit(127)
        }

        _ = fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK)
        return PTYSession(pid: pid, master: master, columns: columns, rows: rows)
    }

    private init(pid: pid_t, master: Int32, columns: Int, rows: Int) {
        self.pid = pid
        self.master = master
        self.columns = columns
        self.rows = rows
    }

    public var text: String { String(decoding: output, as: UTF8.self) }

    /// What a terminal of this size shows now.
    public var screen: String { TerminalScreen.render(text, columns: columns, rows: rows).text }

    /// Appends whatever the process has written so far.
    public func drain() {
        var chunk = [UInt8](repeating: 0, count: 8192)
        while true {
            let n = read(master, &chunk, chunk.count)
            if n <= 0 { break }
            output.append(contentsOf: chunk[0..<n])
        }
    }

    public func send(_ s: String) { _ = s.withCString { write(master, $0, strlen($0)) } }

    /// Shuts down in the background so the caller gets its result immediately.
    /// `exitKeys` are sent first, 100 ms apart, as a polite exit.
    public func finish(exitKeys: [String]) {
        let (pid, master) = (self.pid, self.master)
        DispatchQueue.global(qos: .background).async {
            Self.terminate(pid: pid, master: master, exitKeys: exitKeys)
        }
    }

    /// Keeps draining the PTY while waiting: on macOS a process can't finish
    /// exiting while its terminal output buffer is full (that caused a hang).
    static func terminate(pid: pid_t, master: Int32, exitKeys: [String]) {
        var chunk = [UInt8](repeating: 0, count: 8192)
        func drain() { while read(master, &chunk, chunk.count) > 0 {} }
        func send(_ s: String) { _ = s.withCString { write(master, $0, strlen($0)) } }
        func reaped(within seconds: Double) -> Bool {
            let deadline = Date().addingTimeInterval(seconds)
            var status: Int32 = 0
            while Date() < deadline {
                drain()
                let r = waitpid(pid, &status, WNOHANG)
                if r == pid || r == -1 { return true }
                usleep(50_000)
            }
            return false
        }

        for (i, key) in exitKeys.enumerated() {
            if i > 0 { usleep(100_000) }
            send(key)
        }
        if reaped(within: 1.5) { close(master); return }
        // SIGTERM / SIGKILL the whole process group (the CLI may spawn helpers).
        kill(-pid, SIGTERM); kill(pid, SIGTERM)
        if reaped(within: 1.0) { close(master); return }
        kill(-pid, SIGKILL); kill(pid, SIGKILL)
        if reaped(within: 1.0) { close(master); return }
        // Last resort: hang up the terminal, then reap without blocking forever.
        close(master)
        var status: Int32 = 0
        for _ in 0..<100 { if waitpid(pid, &status, WNOHANG) != 0 { return }; usleep(100_000) }
    }
}
