import XCTest
@testable import UsageCore

final class TerminalScreenTests: XCTestCase {
    /// `/usage` draws cached numbers with "Refreshing…", then overwrites only the changed
    /// digits. Same cursor moves as a Claude Code 2.1.310 capture where the stream parser
    /// reported 18% while the terminal showed 19%.
    func testPartialRedrawReplacesStaleNumber() {
        let frame = "\u{1b}[2J\u{1b}[H"
            + "Current session\r\n"
            + "█████\u{1b}[40G18% used\r\n"
            + "Resets 3:59pm (Asia/Seoul)\r\n"
            + "Current week (all models)\r\n"
            + "██\u{1b}[40G20% used\r\n"
            + "Resets Nov 8 at 8:59am (Asia/Seoul)\r\n"
            + "Refreshing…"
        let redraw = "\u{1b}[?2026h\u{1b}[H\r\n\u{1b}[40G19\u{1b}[7;1H\u{1b}[K\u{1b}[?2026l"

        let screen = TerminalScreen.render(frame + redraw).text
        XCTAssertFalse(screen.contains("Refreshing"))
        let snap = UsageParser.parse(screen)
        XCTAssertEqual(snap.sessionPercent, 19)
        XCTAssertEqual(snap.weekPercent, 20)

        // The old stream cleanup keeps the stale value; this is the bug being fixed.
        XCTAssertEqual(UsageParser.parse(TerminalText.clean(frame + redraw)).sessionPercent, 18)
    }

    func testFullWidthLineThenNewlineDoesNotSkipRow() {
        XCTAssertEqual(TerminalScreen.render("abcd\r\nef", columns: 4, rows: 3).text, "abcd\nef")
    }

    func testLongLineWraps() {
        XCTAssertEqual(TerminalScreen.render("abcdef", columns: 4, rows: 3).text, "abcd\nef")
    }

    func testEraseToEndOfLine() {
        XCTAssertEqual(TerminalScreen.render("hello world\r\u{1b}[5C\u{1b}[K", columns: 20, rows: 2).text, "hello")
    }

    func testWideCharactersTakeTwoCells() {
        XCTAssertEqual(TerminalScreen.render("한글\u{1b}[5Gx", columns: 10, rows: 1).text, "한글x")
    }

    func testOSCAndStylingAreIgnored() {
        let s = "\u{1b}]0;title\u{07}\u{1b}[1mCurrent\u{1b}[22m session"
        XCTAssertEqual(TerminalScreen.render(s).text, "Current session")
    }
}

final class SnapshotUpdateTests: XCTestCase {
    private let good = UsageSnapshot(sessionPercent: 40, weekPercent: 10, raw: "ok",
                                     updatedAt: Date(timeIntervalSince1970: 100))

    func testFailureKeepsLastGoodValues() {
        let failed = UsageSnapshot(error: .noResponse, raw: "timeout", updatedAt: Date(timeIntervalSince1970: 200))
        let shown = good.updated(with: failed)
        XCTAssertEqual(shown.sessionPercent, 40)
        XCTAssertEqual(shown.updatedAt, good.updatedAt)
        XCTAssertEqual(shown.error, .noResponse)
        XCTAssertEqual(shown.raw, "timeout")
    }

    func testSuccessReplaces() {
        let next = UsageSnapshot(sessionPercent: 41, weekPercent: 11)
        XCTAssertEqual(good.updated(with: next), next)
    }

    func testFirstFailureIsShownAsIs() {
        let failed = UsageSnapshot(error: .notLoggedIn)
        XCTAssertEqual(UsageSnapshot().updated(with: failed), failed)
    }
}
