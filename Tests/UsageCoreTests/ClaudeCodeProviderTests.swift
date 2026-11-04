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

    func testRejectedFlagIsNoticed() {
        XCTAssertTrue(ClaudeCodeProvider.rejectedArguments("error: unknown option '--strict-mcp-config'"))
        XCTAssertFalse(ClaudeCodeProvider.rejectedArguments("Current session\n5% used"))
    }

    func testErrorMapping() {
        let all: [UsageError] = [.claudeNotFound, .launchFailed, .noResponse, .notLoggedIn, .apiBilling, .unparsable]
        XCTAssertEqual(all.map(ProviderError.init),
                       [.notInstalled, .launchFailed, .timeout, .notLoggedIn, .unsupportedPlan, .unparsable])
    }
}

final class UsageCommandTests: XCTestCase {
    /// The final screen from issue #1 (Claude Code 2.1.280): typed, never run.
    private func recorded() throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "usage-not-run-2.1.280", withExtension: "txt", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testTypedButNotRunIsNoticedAndReadsAsNoUsage() throws {
        let screen = try recorded()
        XCTAssertTrue(ClaudeCodeProvider.commandStillTyped(screen))
        XCTAssertFalse(UsageParser.parse(screen).hasUsage)
    }

    /// In a normal run the highlighted autocomplete row has a description after it.
    func testAutocompleteRowIsNotTheTypedCommand() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "real-2.1.310", withExtension: "txt", subdirectory: "Fixtures"))
        XCTAssertFalse(ClaudeCodeProvider.commandStillTyped(try String(contentsOf: url, encoding: .utf8)))
    }
}

final class TrustPromptTests: XCTestCase {
    /// The rendered screen Claude Code 2.1.310 shows for a new folder.
    private func recorded() throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "trust-prompt-2.1.310", withExtension: "txt", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testMovesDownWhenNoIsSelected() throws {
        XCTAssertEqual(ClaudeCodeProvider.trustPromptKey(try recorded()), "\u{1b}[B")
    }

    func testConfirmsWhenYesIsSelected() throws {
        // What the same screen shows after one Down (also captured live).
        let moved = try recorded()
            .replacingOccurrences(of: "❯ No, exit", with: "No, exit")
            .replacingOccurrences(of: "Yes, I trust this folder", with: "❯ Yes, I trust this folder")
        XCTAssertEqual(ClaudeCodeProvider.trustPromptKey(moved), "\r")
    }

    func testIgnoresMainPrompt() {
        XCTAssertNil(ClaudeCodeProvider.trustPromptKey("❯ Try \"how does <filepath> work?\""))
    }
}
