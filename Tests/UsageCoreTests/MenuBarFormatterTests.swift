import XCTest
@testable import UsageCore

final class MenuBarFormatterTests: XCTestCase {
    private let usage = ProviderUsage(windows: [
        UsageWindow(id: "5h", kind: .rolling(minutes: 300), usedPercent: 42),
        UsageWindow(id: "week", kind: .rolling(minutes: 10080), usedPercent: 10.4),
        UsageWindow(id: "model:Fable", kind: .model(name: "Fable", minutes: 10080), usedPercent: 2),
    ])

    private func label(_ ids: [String], _ style: MenuBarLabelStyle = .labeled,
                       usage: ProviderUsage?? = nil, hasLoaded: Bool = true) -> String {
        MenuBarFormatter.label(usage: usage ?? self.usage, hasLoaded: hasLoaded, windowIDs: ids, style: style)
    }

    func testLabeledKeepsSelectedOrder() {
        XCTAssertEqual(label(["5h", "week", "model:Fable"]), "5h 42% · 7d 10% · Fable 2%")
        XCTAssertEqual(label(["model:Fable", "5h"]), "Fable 2% · 5h 42%")
    }

    func testCompact() {
        XCTAssertEqual(label(["5h", "week"], .compact), "42% · 10%")
    }

    func testMissingWindowShowsDash() {
        XCTAssertEqual(label(["model:Sonnet", "week"]), "Sonnet – · 7d 10%")
        let weekOnly = ProviderUsage(windows: [UsageWindow(id: "week", kind: .rolling(minutes: 10080), usedPercent: 5)])
        XCTAssertEqual(label(["5h", "week"], usage: weekOnly), "5h – · 7d 5%")
    }

    func testStates() {
        XCTAssertEqual(label(["5h"], hasLoaded: false), "CC …")
        XCTAssertEqual(label(["5h"], usage: .some(nil)), "CC ⚠︎")
        XCTAssertEqual(label([]), "CC")
    }

    func testShortLabels() {
        XCTAssertEqual(UsageWindow.Kind.rolling(minutes: 300).shortLabel, "5h")
        XCTAssertEqual(UsageWindow.Kind.rolling(minutes: 10080).shortLabel, "7d")
        XCTAssertEqual(UsageWindow.Kind.rolling(minutes: 43200).shortLabel, "30d")
    }
}

final class UsageToneTests: XCTestCase {
    func testByUsageThresholds() {
        let tones = [nil, 0, 69, 70, 89, 90, 100].map { UsageTone(percent: $0, mode: .byUsage, warnHigh: false) }
        XCTAssertEqual(tones, [.unknown, .low, .low, .elevated, .elevated, .high, .high])
    }

    func testFixedWarnsOnlyWhenEnabled() {
        XCTAssertEqual(UsageTone(percent: 89, mode: .fixed, warnHigh: true), .custom)
        XCTAssertEqual(UsageTone(percent: 90, mode: .fixed, warnHigh: true), .high)
        XCTAssertEqual(UsageTone(percent: 95, mode: .fixed, warnHigh: false), .custom)
    }
}
