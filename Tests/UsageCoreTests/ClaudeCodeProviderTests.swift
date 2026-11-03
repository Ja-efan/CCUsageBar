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

    func testFailureKeepsReasonAndRaw() {
        let result = ClaudeCodeProvider.usage(from: UsageSnapshot(error: .notLoggedIn, raw: "Not logged in"))
        XCTAssertEqual(result, .failure(ProviderFailure(.notLoggedIn, raw: "Not logged in")))
    }

    func testResetTimesAreParsed() throws {
        let snap = UsageSnapshot(sessionPercent: 1, sessionReset: "3pm (Asia/Seoul)", updatedAt: Date(timeIntervalSince1970: 0))
        let usage = try ClaudeCodeProvider.usage(from: snap).get()
        // 1970-01-01 09:00 KST → next 3pm KST is 06:00 UTC the same day.
        XCTAssertEqual(usage.window(id: "5h")?.resetsAt, Date(timeIntervalSince1970: 6 * 3600))
    }

    func testErrorMapping() {
        let all: [UsageError] = [.claudeNotFound, .launchFailed, .noResponse, .notLoggedIn, .apiBilling, .unparsable]
        XCTAssertEqual(all.map(ProviderError.init),
                       [.notInstalled, .launchFailed, .timeout, .notLoggedIn, .unsupportedPlan, .unparsable])
    }
}

final class TrustPromptTests: XCTestCase {
    private let prompt = """
    Quick safety check: Is this a project you created or one you trust?
    Security guide
    %@No, exit
    %@Yes, I trust this folder
    Enter to confirm · Esc to cancel
    """

    func testMovesDownWhenNoIsSelected() {
        XCTAssertEqual(ClaudeCodeProvider.trustPromptKey(String(format: prompt, "❯ ", "")), "\u{1b}[B")
    }

    func testConfirmsWhenYesIsSelected() {
        XCTAssertEqual(ClaudeCodeProvider.trustPromptKey(String(format: prompt, "", "❯ ")), "\r")
    }

    func testIgnoresMainPrompt() {
        XCTAssertNil(ClaudeCodeProvider.trustPromptKey("❯ Try \"how does <filepath> work?\""))
    }
}
