import Foundation

/// How percentages appear in the menu bar.
public enum MenuBarLabelStyle: String, CaseIterable, Identifiable, Sendable {
    case labeled   // 5h 42% · 7d 10%
    case compact   // 42% · 10%
    public var id: String { rawValue }
}

/// Menu bar text. Kept out of the app target so it can be tested.
public enum MenuBarFormatter {
    /// `windowIDs` are the windows to show, in order. A selected window missing from
    /// the reading shows "–" so the menu bar doesn't jump between layouts.
    public static func label(usage: ProviderUsage?, hasLoaded: Bool,
                             windowIDs: [String], style: MenuBarLabelStyle) -> String {
        guard hasLoaded else { return "CC …" }
        guard let usage else { return "CC ⚠︎" }
        let parts = windowIDs.map { id -> String in
            let window = usage.window(id: id)
            let pct = window.map { "\(Int($0.usedPercent.rounded()))%" } ?? "–"
            guard style == .labeled else { return pct }
            return "\(window?.kind.shortLabel ?? shortLabel(forID: id)) \(pct)"
        }
        return parts.isEmpty ? "CC" : parts.joined(separator: " · ")
    }

    /// Label for a selected window that isn't in the current reading.
    static func shortLabel(forID id: String) -> String {
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
