import XCTest
@testable import UsageCore

/// Runs a shell script as a stand-in server.
final class JSONRPCProcessTests: XCTestCase {
    private func server(_ script: String) throws -> JSONRPCProcess {
        try JSONRPCProcess(executable: "/bin/sh", arguments: ["-c", script], environment: [:],
                           directory: NSTemporaryDirectory())
    }

    func testSkipsNotificationsAndMatchesID() throws {
        let rpc = try server("""
        read l; echo '{"method":"note","params":{}}'; echo '{"id":1,"result":{"ok":true}}'
        read l; echo '{"id":2,"error":{"code":-32600,"message":"nope"}}'
        """)
        defer { rpc.finish() }
        let result = try rpc.request("a", timeout: 5)
        XCTAssertEqual(String(decoding: result, as: UTF8.self), #"{"ok":true}"#)
        XCTAssertThrowsError(try rpc.request("b", timeout: 5)) {
            XCTAssertEqual($0 as? JSONRPCError, .remote(code: -32600, message: "nope"))
        }
    }

    func testTimeout() throws {
        let rpc = try server("sleep 5")
        defer { rpc.finish() }
        XCTAssertThrowsError(try rpc.request("a", timeout: 0.2)) { XCTAssertEqual($0 as? JSONRPCError, .timeout) }
    }

    func testExitBeforeAnswerIsClosed() throws {
        let rpc = try server("read l")
        defer { rpc.finish() }
        XCTAssertThrowsError(try rpc.request("a", timeout: 5)) { XCTAssertEqual($0 as? JSONRPCError, .closed) }
    }
}
