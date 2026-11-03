import Foundation

public enum JSONRPCError: Error, Equatable, Sendable {
    case launchFailed
    case timeout
    /// The process closed its output before answering.
    case closed
    case remote(code: Int, message: String)
    case malformed
}

/// A child process that speaks newline-delimited JSON-RPC on stdin/stdout
/// (`codex app-server`). Calls block, so run them off the main thread.
public final class JSONRPCProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let lock = NSCondition()
    private var buffer = Data()
    private var closed = false
    private var nextID = 1

    public init(executable: String, arguments: [String], environment: [String: String], directory: String) throws {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        // Writing after the process exits would raise SIGPIPE and kill the app.
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self else { return }
            self.lock.lock()
            if data.isEmpty {
                self.closed = true
                handle.readabilityHandler = nil
            } else {
                self.buffer.append(data)
            }
            self.lock.broadcast()
            self.lock.unlock()
        }
        do { try process.run() } catch { throw JSONRPCError.launchFailed }
    }

    /// Sends a request and returns its `result` as JSON. Messages that aren't the
    /// answer (notifications, server requests) are skipped.
    public func request(_ method: String, params: [String: Any]? = nil, timeout: TimeInterval) throws -> Data {
        let id = nextID
        nextID += 1
        var message: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method]
        if let params { message["params"] = params }
        try send(message)

        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let line = try nextLine(before: deadline)
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  obj["method"] == nil, obj["id"] as? Int == id
            else { continue }
            if let error = obj["error"] as? [String: Any] {
                throw JSONRPCError.remote(code: error["code"] as? Int ?? 0, message: error["message"] as? String ?? "")
            }
            guard let result = obj["result"],
                  let data = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed])
            else { throw JSONRPCError.malformed }
            return data
        }
    }

    public func notify(_ method: String) throws {
        try send(["jsonrpc": "2.0", "method": method])
    }

    /// Closes stdin and makes sure the process exits, in the background.
    public func finish() {
        output.fileHandleForReading.readabilityHandler = nil
        try? input.fileHandleForWriting.close()
        let process = self.process
        DispatchQueue.global(qos: .background).async {
            // Exits on its own once stdin closes; escalate if it doesn't.
            for signal in [0, SIGTERM, SIGKILL] {
                if signal != 0, process.isRunning { kill(process.processIdentifier, signal) }
                let deadline = Date().addingTimeInterval(1)
                while process.isRunning, Date() < deadline { usleep(50_000) }
                if !process.isRunning { return }
            }
        }
    }

    private func send(_ message: [String: Any]) throws {
        guard var data = try? JSONSerialization.data(withJSONObject: message) else { throw JSONRPCError.malformed }
        data.append(0x0A)
        do { try input.fileHandleForWriting.write(contentsOf: data) } catch { throw JSONRPCError.closed }
    }

    private func nextLine(before deadline: Date) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                return Data(line)
            }
            if closed { throw JSONRPCError.closed }
            if !lock.wait(until: deadline) { throw JSONRPCError.timeout }
        }
    }
}
