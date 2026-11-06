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
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func display(_ at: Date, now: Date) -> ResetDisplay { ResetDisplay(at, now: now, calendar: calendar) }

    func testWithinAnHourCountsDownEvenPastMidnight() {
        XCTAssertEqual(display(date(7, 0, 20), now: date(6, 23, 40)), .inMinutes(40))
        XCTAssertEqual(display(date(6, 9, 59), now: date(6, 10, 0)), .inMinutes(0))
    }

    func testLaterTodayIsJustTheTime() {
        let at = date(6, 23, 50)
        XCTAssertEqual(display(at, now: date(6, 10, 12)), .time(at))
    }

    /// Friday 10:12 AM, 20 hours ahead: "6:16 AM" alone left people asking which day.
    func testTomorrowNamesTheDayEvenWithinADay() {
        let at = date(7, 6, 16)
        XCTAssertEqual(display(at, now: date(6, 10, 12)), .weekdayTime(at))
    }

    func testSixDaysAheadNamesTheDay() {
        let at = date(12, 23, 0)
        XCTAssertEqual(display(at, now: date(6, 10, 12)), .weekdayTime(at))
    }

    /// Next Friday under a week away would read "Fri 9:00 AM" on a Friday, as if already past.
    func testSameWeekdayNextWeekShowsTheDate() {
        let at = date(13, 9, 0)
        XCTAssertEqual(display(at, now: date(6, 10, 12)), .date(at))
    }

    func testTrimmedDropsTimeZone() {
        XCTAssertEqual(ResetDisplay.trimmed("Nov 8 at 9am (Asia/Seoul)"), "Nov 8 at 9am")
        XCTAssertEqual(ResetDisplay.trimmed("soon"), "soon")
    }
}
