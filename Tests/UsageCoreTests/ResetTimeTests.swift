import XCTest
@testable import UsageCore

final class ResetTimeParserTests: XCTestCase {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    private func kst(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = seoul
        return c.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testTimeOnlyIsNextOccurrence() {
        let now = kst(2026, 11, 3, 14, 30)
        XCTAssertEqual(ResetTimeParser.parse("3pm (Asia/Seoul)", now: now), kst(2026, 11, 3, 15))
        XCTAssertEqual(ResetTimeParser.parse("12am (Asia/Seoul)", now: now), kst(2026, 11, 4, 0))
        XCTAssertEqual(ResetTimeParser.parse("2pm (Asia/Seoul)", now: now), kst(2026, 11, 4, 14))
        XCTAssertEqual(ResetTimeParser.parse("3:30pm (Asia/Seoul)", now: now), kst(2026, 11, 3, 15, 30))
    }

    func testDateForms() {
        let now = kst(2026, 11, 3, 14)
        XCTAssertEqual(ResetTimeParser.parse("Nov 8 at 9am (Asia/Seoul)", now: now), kst(2026, 11, 8, 9))
        XCTAssertEqual(ResetTimeParser.parse("Nov 6, 10am (Asia/Seoul)", now: now), kst(2026, 11, 6, 10))
        XCTAssertEqual(ResetTimeParser.parse("Jan 2 at 9am (Asia/Seoul)", now: kst(2026, 12, 30, 9)), kst(2027, 1, 2, 9))
    }

    func testTimeZoneIsHonored() {
        let now = kst(2026, 11, 3, 14)
        let utc = ResetTimeParser.parse("Nov 8 at 9am (UTC)", now: now)
        XCTAssertEqual(utc, kst(2026, 11, 8, 18))
    }

    func testUnknownWordingIsNil() {
        XCTAssertNil(ResetTimeParser.parse("tomorrow", now: Date()))
        XCTAssertNil(ResetTimeParser.parse("13pm", now: Date()))
    }

    /// Every reset line in the recorded fixtures parses.
    func testFixtureResetsParse() throws {
        for name in ["subscription", "styled-words", "real-2.1.310"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures"))
            let raw = try String(contentsOf: url, encoding: .utf8)
            let snap = UsageParser.parse(name == "real-2.1.310" ? raw : TerminalText.clean(raw))
            let usage = try ClaudeCodeProvider.usage(from: snap).get()
            for w in usage.windows { XCTAssertNotNil(w.resetsAt, "\(name): \(w.resetText ?? "")") }
        }
    }
}

final class ResetDisplayTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testBuckets() {
        XCTAssertEqual(ResetDisplay(now.addingTimeInterval(41 * 60 + 5), now: now), .inMinutes(42))
        XCTAssertEqual(ResetDisplay(now.addingTimeInterval(-30), now: now), .inMinutes(0))
        XCTAssertEqual(ResetDisplay(now.addingTimeInterval(3600), now: now), .time(now.addingTimeInterval(3600)))
        XCTAssertEqual(ResetDisplay(now.addingTimeInterval(86400), now: now), .weekdayTime(now.addingTimeInterval(86400)))
        XCTAssertEqual(ResetDisplay(now.addingTimeInterval(7 * 86400), now: now), .date(now.addingTimeInterval(7 * 86400)))
    }

    func testTrimmedDropsTimeZone() {
        XCTAssertEqual(ResetDisplay.trimmed("Nov 8 at 9am (Asia/Seoul)"), "Nov 8 at 9am")
        XCTAssertEqual(ResetDisplay.trimmed("soon"), "soon")
    }
}
