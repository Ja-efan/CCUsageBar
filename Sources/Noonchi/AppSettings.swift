import SwiftUI
import AppKit
import UsageCore

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"
    var id: String { rawValue }
    var displayName: String { self == .korean ? "한국어" : "English" }

    static var systemDefault: AppLanguage {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("ko") ? .korean : .english
    }
}

/// User preferences, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let presetColors: [(name: String, hex: String)] = [
        ("Claude", "#D97757"),
        ("Blue", "#3B82F6"),
        ("Purple", "#8B5CF6"),
        ("Green", "#22C55E"),
        ("Teal", "#14B8A6"),
        ("Pink", "#EC4899"),
        ("Gray", "#8E8E93"),
    ]
    /// Windows not seen for this long drop out of the menu bar choices.
    static let forgetWindowsAfter: TimeInterval = 7 * 86400

    private let defaults = UserDefaults.standard
    private enum Key {
        static let language = "language"
        static let mode = "menuBar.mode"
        static let items = "menuBar.items"
        static let labeled = "menuBar.labeled"
        static let iconStyle = "menuBar.iconStyle"
        static let highlightHigh = "highlightHigh"
        static let barColor = "barColor"
        static let knownWindows = "knownWindows"
        static let disabled = "disabledProviders"
        static let refreshMinutes = "refreshMinutes"
        static let version = "settingsVersion"
    }

    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: Key.language) } }
    @Published var menuBarMode: MenuBarMode { didSet { defaults.set(menuBarMode.rawValue, forKey: Key.mode) } }
    /// "provider:window" keys shown in custom mode, in display order.
    @Published var menuBarItems: [String] { didSet { defaults.set(menuBarItems, forKey: Key.items) } }
    @Published var labeled: Bool { didSet { defaults.set(labeled, forKey: Key.labeled) } }
    @Published var iconStyle: IconStyle { didSet { defaults.set(iconStyle.rawValue, forKey: Key.iconStyle) } }
    @Published var highlightHigh: Bool { didSet { defaults.set(highlightHigh, forKey: Key.highlightHigh) } }
    /// Nil means the system color.
    @Published var barColorHex: String? { didSet { defaults.set(barColorHex ?? "system", forKey: Key.barColor) } }
    @Published var disabledProviders: Set<String> { didSet { defaults.set(Array(disabledProviders), forKey: Key.disabled) } }
    @Published var refreshInterval: RefreshInterval { didSet { defaults.set(refreshInterval.minutes, forKey: Key.refreshMinutes) } }
    /// Window IDs seen per service and when, so they can be picked before the next refresh.
    @Published private(set) var knownWindows: [String: [String: Date]] {
        didSet { defaults.set(knownWindows, forKey: Key.knownWindows) }
    }

    private init() {
        let d = UserDefaults.standard
        Self.migrateFromOldBundleID(into: d)
        Self.migrateToV2(d)
        language = d.string(forKey: Key.language).flatMap(AppLanguage.init) ?? .systemDefault
        menuBarMode = d.string(forKey: Key.mode).flatMap(MenuBarMode.init) ?? .auto
        menuBarItems = d.stringArray(forKey: Key.items) ?? ["claude:5h"]
        labeled = d.object(forKey: Key.labeled) as? Bool ?? false
        iconStyle = d.string(forKey: Key.iconStyle).flatMap(IconStyle.init) ?? .symbol
        highlightHigh = d.object(forKey: Key.highlightHigh) as? Bool ?? true
        barColorHex = d.string(forKey: Key.barColor).flatMap { $0 == "system" ? nil : $0 }
        disabledProviders = Set(d.stringArray(forKey: Key.disabled) ?? [])
        refreshInterval = RefreshInterval(saved: d.object(forKey: Key.refreshMinutes) as? Int)
        knownWindows = d.dictionary(forKey: Key.knownWindows) as? [String: [String: Date]] ?? [:]
    }

    /// Settings saved before the rename (CCUsageBar) live under the old bundle ID.
    private static func migrateFromOldBundleID(into d: UserDefaults) {
        guard d.object(forKey: "settingsMigrated") == nil else { return }
        d.set(true, forKey: "settingsMigrated")
        guard let old = UserDefaults(suiteName: "io.github.ja-efan.ccusagebar") else { return }
        for key in [Key.language] + SettingsMigration.oldKeys where d.object(forKey: key) == nil {
            if let v = old.object(forKey: key) { d.set(v, forKey: key) }
        }
    }

    /// v0.3 had one service; see `SettingsMigration`.
    private static func migrateToV2(_ d: UserDefaults) {
        guard d.integer(forKey: Key.version) < SettingsMigration.version else { return }
        let old = Dictionary(uniqueKeysWithValues: SettingsMigration.oldKeys.compactMap { k in d.object(forKey: k).map { (k, $0) } })
        for (key, value) in SettingsMigration.toV2(old) { d.set(value, forKey: key) }
        SettingsMigration.oldKeys.forEach(d.removeObject)
        d.set(SettingsMigration.version, forKey: Key.version)
    }

    var strings: Strings { Strings(language: language) }

    // MARK: Services

    func isEnabled(_ id: ProviderID) -> Bool { !disabledProviders.contains(id.rawValue) }

    func setEnabled(_ id: ProviderID, _ on: Bool) {
        if on { disabledProviders.remove(id.rawValue) } else { disabledProviders.insert(id.rawValue) }
    }

    // MARK: Menu bar items

    func isSelected(_ id: ProviderID, _ window: String) -> Bool { menuBarItems.contains("\(id.rawValue):\(window)") }

    func toggle(_ id: ProviderID, _ window: String) {
        let key = "\(id.rawValue):\(window)"
        if let i = menuBarItems.firstIndex(of: key) { menuBarItems.remove(at: i) } else { menuBarItems.append(key) }
    }

    /// Records the windows in a reading and forgets stale ones.
    func registerWindows(_ ids: [String], for id: ProviderID, now: Date = Date()) {
        var seen = knownWindows[id.rawValue] ?? [:]
        for w in ids { seen[w] = now }
        seen = seen.filter { now.timeIntervalSince($0.value) < Self.forgetWindowsAfter }
        if seen != knownWindows[id.rawValue] { knownWindows[id.rawValue] = seen }
    }

    /// Windows that can be picked for a service, short to long.
    func choices(for id: ProviderID) -> [String] {
        (knownWindows[id.rawValue] ?? [:]).keys.sorted { UsageWindow.sortKey(id: $0) < UsageWindow.sortKey(id: $1) }
    }

    func menuBarItems(for store: UsageStore) -> [MenuBarItem] {
        MenuBarFormatter.items(for: store.shown.map { ($0.id, store.states[$0.id] ?? ProviderState()) },
                               mode: menuBarMode, selected: menuBarItems, labeled: labeled, highlightHigh: highlightHigh)
    }

    // MARK: Colors

    /// Bar fill: orange/red when high and highlighting is on, else the chosen color, else gray.
    func barColor(for percent: Double) -> Color {
        Self.color(for: Highlight(percent: percent, enabled: highlightHigh))
            ?? barColorHex.flatMap(Color.init(hex:)) ?? Color.primary.opacity(0.6)
    }

    func textColor(for percent: Double) -> Color {
        Self.color(for: Highlight(percent: percent, enabled: highlightHigh)) ?? .primary
    }

    static func color(for highlight: Highlight) -> Color? {
        switch highlight {
        case .none: return nil
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Hex color helpers

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#D97757" }
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}
