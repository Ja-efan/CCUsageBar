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

    func testIgnoresModelScopedWeeklyCap() {
        let text = "/usage\nCurrent week (Sonnet only)\n77% used"
        XCTAssertNil(UsageParser.parse(text).weekPercent)
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
