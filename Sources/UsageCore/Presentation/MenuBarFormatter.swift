import Foundation

public enum MenuBarMode: String, CaseIterable, Identifiable, Sendable {
    /// Each service's 5-hour window, or its shortest one if it has none.
    case auto
    /// The windows picked in Settings › Services.
    case custom
    public var id: String { rawValue }
}

public enum MenuBarValue: String, CaseIterable, Identifiable, Sendable {
    case used, remaining
    public var id: String { rawValue }

    /// Remaining comes from the rounded used percent so the bar and the panel always add to 100.
    public func shownPercent(used: Double) -> Int {
        let rounded = Int(used.rounded())
        switch self {
        case .used: return rounded
        case .remaining: return max(0, 100 - rounded)
        }
    }
}

public enum IconStyle: String, CaseIterable, Identifiable, Sendable {
    case symbol, monogram, ring
    public var id: String { rawValue }
}

/// Color only for high usage: orange from 80%, red from 95%.
public enum Highlight: Int, Comparable, Sendable {
    case none, warning, critical

    public init(percent: Double, enabled: Bool) {
        guard enabled else { self = .none; return }
        self = percent >= 95 ? .critical : (percent >= 80 ? .warning : .none)
    }

    public static func < (a: Highlight, b: Highlight) -> Bool { a.rawValue < b.rawValue }
}

/// One service's part of the menu bar.
public struct MenuBarItem: Equatable, Sendable {
    /// One value, colored on its own so a high limit doesn't make the others look high.
    public struct Part: Equatable, Sendable {
        public var text: String
        public var highlight: Highlight
    }

    public static let separator = " · "

    public var providerID: ProviderID
    /// "19%", or "5h 19%" and "7d 20%". "…" while loading, "⚠︎" when there's nothing to show.
    public var parts: [Part]
    /// For the ring icon: the first shown window's number, so the ring matches the text.
    public var ringPercent: Double?

    public var text: String { parts.map(\.text).joined(separator: Self.separator) }
    /// The icon's color: the highest of the parts.
    public var highlight: Highlight { parts.map(\.highlight).max() ?? .none }
}

/// Menu bar content. Kept out of the app target so it can be tested.
public enum MenuBarFormatter {
    /// `selected` holds "provider:window" keys for custom mode, e.g. "claude:5h".
    public static func items(for services: [(id: ProviderID, state: ProviderState)], mode: MenuBarMode,
                             selected: [String], labeled: Bool, highlightHigh: Bool,
                             value: MenuBarValue = .used) -> [MenuBarItem] {
        services.compactMap { id, state in
            let windowIDs: [String]
            switch mode {
            case .auto:
                windowIDs = state.usage.flatMap(autoWindow).map { [$0.id] } ?? []
            case .custom:
                let prefix = id.rawValue + ":"
                let picked = selected.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
                if picked.isEmpty { return nil }
                // None of the picks exist any more (Ultra has no 5-hour limit): show something
                // real rather than a lone dash.
                if let usage = state.usage, !picked.contains(where: { usage.window(id: $0) != nil }),
                   let window = autoWindow(usage) {
                    windowIDs = [window.id]
                } else {
                    windowIDs = picked
                }
            }
            guard let usage = state.usage else {
                return MenuBarItem(providerID: id, parts: [.init(text: state.error == nil ? "…" : "⚠︎", highlight: .none)], ringPercent: nil)
            }
            let windows = windowIDs.map { usage.window(id: $0) }
            let parts = zip(windowIDs, windows).map { id, window -> MenuBarItem.Part in
                let pct = window.map { "\(value.shownPercent(used: $0.usedPercent))%" } ?? "–"
                return MenuBarItem.Part(text: labeled ? "\(window?.kind.shortLabel ?? shortLabel(forID: id)) \(pct)" : pct,
                                        highlight: window.map { Highlight(percent: $0.usedPercent, enabled: highlightHigh) } ?? .none)
            }
            return MenuBarItem(providerID: id, parts: parts, ringPercent: windows.compactMap { $0 }.first.map { Double(value.shownPercent(used: $0.usedPercent)) })
        }
    }

    /// The 5-hour window, else the shortest rolling one, else the first.
    public static func autoWindow(_ usage: ProviderUsage) -> UsageWindow? {
        if let w = usage.window(id: "5h") { return w }
        let rolling = usage.windows.compactMap { w -> (UsageWindow, Int)? in
            if case .rolling(let m) = w.kind { return (w, m) } else { return nil }
        }
        return rolling.min { $0.1 < $1.1 }?.0 ?? usage.windows.first
    }

    /// Label for a window known only by its ID (selected but missing from the reading).
    public static func shortLabel(forID id: String) -> String {
        if id.hasPrefix("model:") { return String(id.dropFirst("model:".count)) }
        return id == "week" ? "7d" : id
    }
}

extension UsageWindow.Kind {
    /// "5h", "7d", "30d", or the model name.
    public var shortLabel: String {
        switch self {
        case .rolling(let minutes):
            return minutes < 1440 ? "\(minutes / 60)h" : "\(minutes / 1440)d"
        case .model(let name, _):
            return name
        }
    }
}
