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
