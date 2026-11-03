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

/// Items that can be shown in the menu bar.
enum MenuBarItem: Hashable {
    case session
    case week
    case model(String)

    var key: String {
        switch self {
        case .session: return "session"
        case .week: return "week"
        case .model(let name): return "model:\(name)"
        }
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

    private let defaults = UserDefaults.standard
    private enum Key {
        static let language = "language"
        static let menuItems = "menuBarItems"
        static let labelStyle = "labelStyle"
        static let colorMode = "barColorMode"
        static let barColor = "barColorHex"
        static let warnHigh = "warnHighUsage"
        static let knownModels = "knownModels"
    }

    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: Key.language) } }
    @Published var menuItemKeys: Set<String> { didSet { defaults.set(Array(menuItemKeys), forKey: Key.menuItems) } }
    @Published var labelStyle: MenuBarLabelStyle { didSet { defaults.set(labelStyle.rawValue, forKey: Key.labelStyle) } }
    @Published var colorMode: BarColorMode { didSet { defaults.set(colorMode.rawValue, forKey: Key.colorMode) } }
    @Published var barColorHex: String { didSet { defaults.set(barColorHex, forKey: Key.barColor) } }
    @Published var warnHighUsage: Bool { didSet { defaults.set(warnHighUsage, forKey: Key.warnHigh) } }
    /// Model-scoped caps seen so far (e.g. "Fable"), so they can be toggled before the next refresh.
    @Published private(set) var knownModels: [String] { didSet { defaults.set(knownModels, forKey: Key.knownModels) } }

    private init() {
        let d = UserDefaults.standard
        Self.migrateFromOldBundleID(into: d)
        language = d.string(forKey: Key.language).flatMap(AppLanguage.init) ?? .systemDefault
        menuItemKeys = Set(d.stringArray(forKey: Key.menuItems) ?? ["session", "week"])
        labelStyle = d.string(forKey: Key.labelStyle).flatMap(MenuBarLabelStyle.init) ?? .labeled
        colorMode = d.string(forKey: Key.colorMode).flatMap(BarColorMode.init) ?? .byUsage
        barColorHex = d.string(forKey: Key.barColor) ?? "#D97757"
        warnHighUsage = d.object(forKey: Key.warnHigh) as? Bool ?? true
        knownModels = d.stringArray(forKey: Key.knownModels) ?? []
    }

    /// Settings saved before the rename (CCUsageBar) live under the old bundle ID.
    private static func migrateFromOldBundleID(into d: UserDefaults) {
        guard d.object(forKey: "settingsMigrated") == nil else { return }
        d.set(true, forKey: "settingsMigrated")
        guard let old = UserDefaults(suiteName: "io.github.ja-efan.ccusagebar") else { return }
        let keys = [Key.language, Key.menuItems, Key.labelStyle, Key.colorMode, Key.barColor, Key.warnHigh, Key.knownModels]
        for key in keys where d.object(forKey: key) == nil {
            if let v = old.object(forKey: key) { d.set(v, forKey: key) }
        }
    }

    var strings: Strings { Strings(language: language) }

    func isShown(_ item: MenuBarItem) -> Bool { menuItemKeys.contains(item.key) }

    func setShown(_ item: MenuBarItem, _ on: Bool) {
        if on { menuItemKeys.insert(item.key) } else { menuItemKeys.remove(item.key) }
    }

    func binding(for item: MenuBarItem) -> Binding<Bool> {
        Binding(get: { self.isShown(item) }, set: { self.setShown(item, $0) })
    }

    func registerModels(_ names: [String]) {
        let new = names.filter { !knownModels.contains($0) }
        if !new.isEmpty { knownModels += new }
    }

    // MARK: Colors

    var barColor: Color {
        get { Color(hex: barColorHex) ?? .orange }
        set { barColorHex = newValue.hexString }
    }

    var barColorBinding: Binding<Color> {
        Binding(get: { self.barColor }, set: { self.barColor = $0 })
    }

    func color(for percent: Int?) -> Color {
        switch UsageTone(percent: percent, mode: colorMode, warnHigh: warnHighUsage) {
        case .unknown: return .gray
        case .low: return .green
        case .elevated: return .orange
        case .high: return .red
        case .custom: return barColor
        }
    }

    // MARK: Menu bar label

    /// Selected menu bar windows, in display order.
    var menuBarWindowIDs: [String] {
        var ids: [String] = []
        if isShown(.session) { ids.append("5h") }
        if isShown(.week) { ids.append("week") }
        ids += knownModels.filter { isShown(.model($0)) }.map { "model:\($0)" }
        return ids
    }

    func menuBarLabel(usage: ProviderUsage?, hasLoaded: Bool) -> String {
        MenuBarFormatter.label(usage: usage, hasLoaded: hasLoaded, windowIDs: menuBarWindowIDs, style: labelStyle)
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
