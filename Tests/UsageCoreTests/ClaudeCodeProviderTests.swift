import XCTest
@testable import UsageCore

final class ClaudeCodeProviderTests: XCTestCase {
    private func realSnapshot() throws -> UsageSnapshot {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "real-2.1.310", withExtension: "txt", subdirectory: "Fixtures"))
        return UsageParser.parse(try String(contentsOf: url, encoding: .utf8))
    }

    func testRealOutputBecomesWindows() throws {
        let usage = try ClaudeCodeProvider.usage(from: realSnapshot()).get()
        XCTAssertEqual(usage.windows.map(\.id), ["5h", "week", "model:Fable"])
        XCTAssertEqual(usage.window(id: "5h")?.kind, .rolling(minutes: 300))
        XCTAssertEqual(usage.window(id: "5h")?.usedPercent, 100)
        XCTAssertEqual(usage.window(id: "week")?.resetText, "Nov 8 at 9am (Asia/Seoul)")
        XCTAssertEqual(usage.window(id: "model:Fable")?.kind, .model(name: "Fable", minutes: 10080))
    }

    /// The UI still reads `UsageSnapshot`; going through `ProviderUsage` must not change it.
    func testRoundTripKeepsSnapshot() throws {
        let snap = try realSnapshot()
        let back = UsageSnapshot(try ClaudeCodeProvider.usage(from: snap).get())
        XCTAssertEqual(back, snap)
    }

    func testFailureKeepsReasonAndRaw() {
        let result = ClaudeCodeProvider.usage(from: UsageSnapshot(error: .notLoggedIn, raw: "Not logged in"))
        XCTAssertEqual(result, .failure(ProviderFailure(.notLoggedIn, raw: "Not logged in")))
        let shown = UsageSnapshot(ProviderFailure(.notLoggedIn, raw: "Not logged in"))
        XCTAssertEqual(shown.error, .notLoggedIn)
        XCTAssertEqual(shown.raw, "Not logged in")
    }

    func testErrorMappingRoundTrips() {
        let all: [UsageError] = [.claudeNotFound, .launchFailed, .noResponse, .notLoggedIn, .apiBilling, .unparsable]
        for e in all { XCTAssertEqual(UsageError(ProviderError(e)), e) }
    }
}
