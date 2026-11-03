import XCTest
@testable import UsageCore

final class UsageParserTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testSubscriptionUsage() throws {
        let snap = UsageParser.parse(TerminalText.clean(try fixture("subscription")))
        XCTAssertEqual(snap.sessionPercent, 42)
        XCTAssertEqual(snap.sessionReset, "3pm (Asia/Seoul)")
        XCTAssertEqual(snap.weekPercent, 18)
        XCTAssertEqual(snap.weekReset, "Nov 6, 10am (Asia/Seoul)")
        XCTAssertNil(snap.error)
    }

    func testNotLoggedIn() throws {
        let snap = UsageParser.parse(TerminalText.clean(try fixture("not-logged-in")))
        XCTAssertFalse(snap.hasUsage)
        XCTAssertEqual(snap.error, .notLoggedIn)
    }

    func testCursorForwardBecomesSpace() {
        XCTAssertEqual(TerminalText.clean("Total\u{1b}[3Ccost"), "Total cost")
    }

    func testModelScopedWeeklyCapIsSeparate() {
        let text = "/usage\nCurrent week (Sonnet only)\n77% used"
        let snap = UsageParser.parse(text)
        XCTAssertNil(snap.weekPercent)
        XCTAssertEqual(snap.modelLimit(named: "Sonnet")?.percent, 77)
    }
}

final class StyledOutputTests: XCTestCase {
    /// Every word wrapped in color codes + a `/usage-credits` hint below the numbers.
    func testStyledWordsAndUsageCreditsHint() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "styled-words", withExtension: "txt", subdirectory: "Fixtures"))
        let snap = UsageParser.parse(TerminalText.clean(try String(contentsOf: url, encoding: .utf8)))
        XCTAssertEqual(snap.sessionPercent, 27)
        XCTAssertEqual(snap.sessionReset, "11pm (Asia/Seoul)")
        XCTAssertEqual(snap.weekPercent, 9)
        XCTAssertEqual(snap.weekReset, "Nov 6, 10am (Asia/Seoul)")
    }

    func testColorCodesDoNotSplitLines() {
        XCTAssertEqual(TerminalText.clean("\u{1b}[1mCurrent\u{1b}[22m \u{1b}[1msession\u{1b}[22m"), "Current session")
    }

    func testUsageSectionIgnoresUsageCreditsHint() {
        XCTAssertEqual(TerminalText.usageSection("❯ /usage\nA\n/usage-credits to turn on").hasPrefix("\nA"), true)
    }
}

final class RealOutputTests: XCTestCase {
    /// Captured from Claude Code 2.1.310 on a Max plan (personal stats trimmed).
    func testRealOutputWithFableWeeklyCap() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "real-2.1.310", withExtension: "txt", subdirectory: "Fixtures"))
        let snap = UsageParser.parse(try String(contentsOf: url, encoding: .utf8))
        XCTAssertEqual(snap.sessionPercent, 100)
        XCTAssertEqual(snap.sessionReset, "12am (Asia/Seoul)")
        XCTAssertEqual(snap.weekPercent, 10)
        XCTAssertEqual(snap.weekReset, "Nov 8 at 9am (Asia/Seoul)")
        XCTAssertEqual(snap.modelLimits, [ModelLimit(name: "Fable", percent: 2, reset: "Nov 8 at 9am (Asia/Seoul)")])
        XCTAssertEqual(snap.plan, "Max")
    }
}

final class PlanTests: XCTestCase {
    func testPlanWithAndWithoutSpaces() {
        XCTAssertEqual(UsageParser.plan(in: "▝▜██████▀  Opus 5.5 · Claude Max"), "Max")
        XCTAssertEqual(UsageParser.plan(in: "▝▜██████▀Opus5.5·ClaudePro"), "Pro")
        XCTAssertNil(UsageParser.plan(in: "Claude Code v2.1.310"))
    }
}

final class LocalStatsTests: XCTestCase {
    func testContributingSectionIsCut() {
        let text = "Current session\n37% used\nWhat's contributing to your limits usage?\nSkills  % of usage\n/emil-design-eng 1%"
        XCTAssertEqual(UsageParser.withoutLocalStats(text), "Current session\n37% used")
        XCTAssertEqual(UsageParser.withoutLocalStats("Current session\n37% used"), "Current session\n37% used")
    }
}
