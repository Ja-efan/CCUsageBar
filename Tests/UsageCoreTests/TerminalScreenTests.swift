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

final class ProviderStateTests: XCTestCase {
    private let good = ProviderUsage(windows: [UsageWindow(id: "5h", kind: .rolling(minutes: 300), usedPercent: 40)],
                                     fetchedAt: Date(timeIntervalSince1970: 100), raw: "ok")

    func testFailureKeepsLastGoodValues() {
        var state = ProviderState()
        state.apply(.success(good))
        state.apply(.failure(ProviderFailure(.timeout, raw: "timeout")))
        XCTAssertEqual(state.usage, good)
        XCTAssertEqual(state.error, .timeout)
        XCTAssertEqual(state.raw, "timeout")
        XCTAssertTrue(state.isStale)
    }

    func testSuccessReplacesAndClearsError() {
        var state = ProviderState()
        state.apply(.failure(ProviderFailure(.timeout)))
        state.apply(.success(good))
        XCTAssertEqual(state.usage, good)
        XCTAssertNil(state.error)
        XCTAssertFalse(state.isStale)
    }

    private func reading(_ windows: [UsageWindow], unavailable: Bool = false) -> Result<ProviderUsage, ProviderFailure> {
        .success(ProviderUsage(windows: windows, modelWindowsUnavailable: unavailable))
    }
    private let fiveHour = UsageWindow(id: "5h", kind: .rolling(minutes: 300), usedPercent: 41)
    private func fable(resets: Date?) -> UsageWindow {
        UsageWindow(id: "model:Fable", kind: .model(name: "Fable", minutes: 10080), usedPercent: 9, resetsAt: resets)
    }

    func testUnavailableModelCapKeepsLastValue() {
        let now = Date(timeIntervalSince1970: 1000)
        var state = ProviderState()
        state.apply(reading([fiveHour, fable(resets: now.addingTimeInterval(3600))]), at: now)
        state.apply(reading([fiveHour], unavailable: true), at: now)
        XCTAssertEqual(state.usage?.windows.map(\.id), ["5h", "model:Fable"])
        XCTAssertEqual(state.usage?.window(id: "model:Fable")?.usedPercent, 9)
    }

    func testUnavailableModelCapDropsOnceReset() {
        let now = Date(timeIntervalSince1970: 1000)
        var state = ProviderState()
        state.apply(reading([fiveHour, fable(resets: now.addingTimeInterval(-1))]), at: now)
        state.apply(reading([fiveHour], unavailable: true), at: now)
        XCTAssertEqual(state.usage?.windows.map(\.id), ["5h"])
    }

    /// Without Claude Code's notice, a cap that's missing really is gone.
    func testMissingModelCapWithoutNoticeIsDropped() {
        var state = ProviderState()
        state.apply(reading([fiveHour, fable(resets: nil)]))
        state.apply(reading([fiveHour]))
        XCTAssertEqual(state.usage?.windows.map(\.id), ["5h"])
    }

    func testFirstFailureHasNoValues() {
        var state = ProviderState()
        state.apply(.failure(ProviderFailure(.notLoggedIn)))
        XCTAssertNil(state.usage)
        XCTAssertEqual(state.error, .notLoggedIn)
        XCTAssertFalse(state.isStale)
    }
}
