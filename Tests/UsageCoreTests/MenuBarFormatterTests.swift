import XCTest
@testable import UsageCore

final class MenuBarFormatterTests: XCTestCase {
    private let claude = ProviderID("claude")
    private let codex = ProviderID("codex")

    private func state(_ windows: [UsageWindow]) -> ProviderState {
        var s = ProviderState()
        s.apply(.success(ProviderUsage(windows: windows)))
        return s
    }

    private lazy var claudeState = state([
        UsageWindow(id: "5h", kind: .rolling(minutes: 300), usedPercent: 19),
        UsageWindow(id: "week", kind: .rolling(minutes: 10080), usedPercent: 20.4),
        UsageWindow(id: "model:Fable", kind: .model(name: "Fable", minutes: 10080), usedPercent: 2),
    ])
    private lazy var codexState = state([UsageWindow(id: "30d", kind: .rolling(minutes: 43200), usedPercent: 7)])

    private func texts(_ mode: MenuBarMode, _ selected: [String] = [], labeled: Bool = false) -> [String] {
        MenuBarFormatter.items(for: [(claude, claudeState), (codex, codexState)], mode: mode,
                               selected: selected, labeled: labeled, highlightHigh: true).map(\.text)
    }

    func testAutoUsesFiveHourElseShortest() {
        XCTAssertEqual(texts(.auto), ["19%", "7%"])
        XCTAssertEqual(texts(.auto, labeled: true), ["5h 19%", "30d 7%"])
    }

    func testCustomKeepsSelectedOrderAndSkipsUnselectedServices() {
        XCTAssertEqual(texts(.custom, ["claude:5h", "claude:week"], labeled: true), ["5h 19% · 7d 20%"])
        XCTAssertEqual(texts(.custom, ["claude:model:Fable", "codex:30d"]), ["2%", "7%"])
    }

    func testMissingSelectedWindowShowsDash() {
        XCTAssertEqual(texts(.custom, ["claude:model:Sonnet"], labeled: true), ["Sonnet –"])
    }

    func testLoadingAndFailedServices() {
        var failed = ProviderState()
        failed.apply(.failure(ProviderFailure(.notLoggedIn)))
        let items = MenuBarFormatter.items(for: [(claude, ProviderState()), (codex, failed)], mode: .auto,
                                           selected: [], labeled: false, highlightHigh: true)
        XCTAssertEqual(items.map(\.text), ["…", "⚠︎"])
    }

    func testHighlightUsesHighestShownWindow() {
        let hot = state([
            UsageWindow(id: "5h", kind: .rolling(minutes: 300), usedPercent: 50),
            UsageWindow(id: "week", kind: .rolling(minutes: 10080), usedPercent: 96),
        ])
        let auto = MenuBarFormatter.items(for: [(claude, hot)], mode: .auto, selected: [], labeled: false, highlightHigh: true)
        XCTAssertEqual(auto.first?.highlight, Highlight.none)
        XCTAssertEqual(auto.first?.ringPercent, 50)
        let custom = MenuBarFormatter.items(for: [(claude, hot)], mode: .custom, selected: ["claude:5h", "claude:week"],
                                            labeled: false, highlightHigh: true)
        XCTAssertEqual(custom.first?.highlight, .critical)
        let off = MenuBarFormatter.items(for: [(claude, hot)], mode: .custom, selected: ["claude:week"],
                                         labeled: false, highlightHigh: false)
        XCTAssertEqual(off.first?.highlight, Highlight.none)
    }

    func testHighlightThresholds() {
        XCTAssertEqual([79.9, 80, 94, 95, 100].map { Highlight(percent: $0, enabled: true) },
                       [.none, .warning, .warning, .critical, .critical])
    }

    func testShortLabels() {
        XCTAssertEqual(UsageWindow.Kind.rolling(minutes: 300).shortLabel, "5h")
        XCTAssertEqual(UsageWindow.Kind.rolling(minutes: 10080).shortLabel, "7d")
        XCTAssertEqual(UsageWindow.Kind.rolling(minutes: 43200).shortLabel, "30d")
    }

    func testKindFromID() {
        XCTAssertEqual(UsageWindow.kind(forID: "5h"), .rolling(minutes: 300))
        XCTAssertEqual(UsageWindow.kind(forID: "week"), .rolling(minutes: 10080))
        XCTAssertEqual(UsageWindow.kind(forID: "30d"), .rolling(minutes: 43200))
        XCTAssertEqual(UsageWindow.kind(forID: "model:Fable"), .model(name: "Fable", minutes: nil))
        XCTAssertNil(UsageWindow.kind(forID: "bogus"))
    }

    func testWindowSortOrder() {
        let ids = ["model:Fable", "30d", "week", "5h", "90m", "bogus"]
        XCTAssertEqual(ids.sorted { UsageWindow.sortKey(id: $0) < UsageWindow.sortKey(id: $1) },
                       ["90m", "5h", "week", "30d", "bogus", "model:Fable"])
    }
}

final class SettingsMigrationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1000)

    func testPickedItemsBecomeCustom() {
        let new = SettingsMigration.toV2(["menuBarItems": ["model:Fable", "week", "session"], "labelStyle": "compact"], now: now)
        XCTAssertEqual(new["menuBar.mode"] as? String, "custom")
        XCTAssertEqual(new["menuBar.items"] as? [String], ["claude:5h", "claude:week", "claude:model:Fable"])
        XCTAssertEqual(new["menuBar.labeled"] as? Bool, false)
    }

    func testPickedItemsWithoutStyleKeepV03Labels() {
        let new = SettingsMigration.toV2(["menuBarItems": ["session"]], now: now)
        XCTAssertEqual(new["menuBar.labeled"] as? Bool, true)
    }

    func testDuplicateKnownModelsDoNotCrash() {
        let new = SettingsMigration.toV2(["knownModels": ["Fable", "Fable"]], now: now)
        XCTAssertEqual(new["knownWindows"] as? [String: [String: Date]], ["claude": ["model:Fable": now]])
    }

    func testUntouchedSettingsStayDefault() {
        XCTAssertTrue(SettingsMigration.toV2([:], now: now).isEmpty)
        // byUsage was the old default: new defaults (highlight on, system color) apply.
        XCTAssertTrue(SettingsMigration.toV2(["barColorMode": "byUsage"], now: now).isEmpty)
    }

    func testFixedColorKeepsColorAndWarning() {
        let new = SettingsMigration.toV2(["barColorMode": "fixed", "barColorHex": "#3B82F6", "warnHighUsage": false], now: now)
        XCTAssertEqual(new["barColor"] as? String, "#3B82F6")
        XCTAssertEqual(new["highlightHigh"] as? Bool, false)
    }

    func testKnownModelsBecomeKnownWindows() {
        let new = SettingsMigration.toV2(["knownModels": ["Fable"]], now: now)
        XCTAssertEqual(new["knownWindows"] as? [String: [String: Date]], ["claude": ["model:Fable": now]])
    }
}

final class PaceEstimatorTests: XCTestCase {
    private let reset = Date(timeIntervalSince1970: 100_000)
    private let estimator = PaceEstimator()

    private func window(_ used: Double, minutes: Int = 300) -> UsageWindow {
        UsageWindow(id: "5h", kind: .rolling(minutes: minutes), usedPercent: used, resetsAt: reset)
    }

    func testProjectsWhenFasterThanWindow() {
        // 2 of 5 hours gone, 60% used → 100% at 3h20m, before the reset.
        let now = reset.addingTimeInterval(-3 * 3600)
        let start = reset.addingTimeInterval(-5 * 3600)
        let hit = estimator.projectedLimit(for: window(60), provider: ProviderID("claude"), now: now)
        XCTAssertEqual(hit!.timeIntervalSince(start), 2 * 3600 * 100 / 60, accuracy: 1)
    }

    func testNothingWhenOnPaceOrUnknown() {
        let now = reset.addingTimeInterval(-3 * 3600)
        let id = ProviderID("claude")
        XCTAssertNil(estimator.projectedLimit(for: window(30), provider: id, now: now))
        XCTAssertNil(estimator.projectedLimit(for: window(0), provider: id, now: now))
        XCTAssertNil(estimator.projectedLimit(for: window(100), provider: id, now: now))
        let noReset = UsageWindow(id: "5h", kind: .rolling(minutes: 300), usedPercent: 90)
        XCTAssertNil(estimator.projectedLimit(for: noReset, provider: id, now: now))
    }

    func testTooEarlyInWindowIsIgnored() {
        // 20 minutes into 5 hours (under 10%): one burst shouldn't raise an alarm.
        let now = reset.addingTimeInterval(-(5 * 3600 - 20 * 60))
        XCTAssertNil(estimator.projectedLimit(for: window(30), provider: ProviderID("claude"), now: now))
    }
}

final class RefreshIntervalTests: XCTestCase {
    func testSavedValues() {
        XCTAssertEqual(RefreshInterval(saved: nil), .five)
        XCTAssertEqual(RefreshInterval(saved: 10), .ten)
        XCTAssertEqual(RefreshInterval(saved: 1), .five)
        XCTAssertEqual(RefreshInterval.thirty.seconds, 1800)
    }
}

final class ScheduledReadTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)

    func testScreenOnAlwaysReads() {
        XCTAssertTrue(ScheduledRead.isDue(screenOff: false, lastAttempt: now, now: now))
    }

    func testScreenOffHolds() {
        XCTAssertFalse(ScheduledRead.isDue(screenOff: true, lastAttempt: now.addingTimeInterval(-300), now: now))
    }

    /// A missed unlock notification must not stop reads for good.
    func testLongestHoldThenReads() {
        XCTAssertTrue(ScheduledRead.isDue(screenOff: true, lastAttempt: now.addingTimeInterval(-3600), now: now))
    }

    func testNeverReadReads() {
        XCTAssertTrue(ScheduledRead.isDue(screenOff: true, lastAttempt: nil, now: now))
    }
}
