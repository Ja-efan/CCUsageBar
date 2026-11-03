import Foundation

/// Extracts session (5-hour), weekly, and model-scoped weekly usage from cleaned `/usage` output.
///
/// Expected shape (Claude Code 2.1.x):
///   Current session
///   ██████        42%used
///   Resets 12am (Asia/Seoul)
///   Current week (all models)
///   ██            10%used
///   Resets Nov 8 at 9am (Asia/Seoul)
///   Current week (Fable)
///   █              2%used
///   Resets Nov 8 at 9am (Asia/Seoul)
public enum UsageParser {
    public static func parse(_ cleaned: String, updatedAt: Date = Date()) -> UsageSnapshot {
        var snap = UsageSnapshot(raw: cleaned, updatedAt: updatedAt)
        let lines = cleaned.components(separatedBy: "\n")

        // Later occurrences win: TUI redraws repeat earlier frames.
        var models: [String: ModelLimit] = [:]
        var order: [String] = []

        for (i, line) in lines.enumerated() {
            if isSessionHeader(line) {
                let (p, r) = readBlock(lines, from: i)
                if p != nil { snap.sessionPercent = p; snap.sessionReset = r }
            } else if let scope = weekScope(line) {
                let (p, r) = readBlock(lines, from: i)
                guard p != nil else { continue }
                if scope == nil {
                    snap.weekPercent = p; snap.weekReset = r
                } else if let name = scope {
                    if models[name] == nil { order.append(name) }
                    models[name] = ModelLimit(name: name, percent: p, reset: r)
                }
            }
        }
        snap.modelLimits = order.compactMap { models[$0] }

        if !snap.hasUsage {
            if cleaned.contains("Not logged in") { snap.error = .notLoggedIn }
            else if cleaned.contains("API Usage Billing") { snap.error = .apiBilling }
            else { snap.error = .unparsable }
        }
        return snap
    }

    static func isSessionHeader(_ l: String) -> Bool {
        let s = l.lowercased()
        return s.hasPrefix("current session") || s.contains("5-hour") || s.contains("5 hour")
    }

    /// For a weekly header returns `.some(nil)` for the all-models cap,
    /// `.some(name)` for a model-scoped cap, and `nil` if the line isn't a weekly header.
    static func weekScope(_ l: String) -> String?? {
        let s = l.trimmingCharacters(in: .whitespaces)
        guard s.lowercased().hasPrefix("current week") || s.lowercased().hasPrefix("weekly") else { return nil }
        guard let open = s.firstIndex(of: "("), let close = s.lastIndex(of: ")"), open < close else {
            return .some(nil) // "Current week" with no scope = all models
        }
        var name = String(s[s.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
        if name.lowercased() == "all models" { return .some(nil) }
        name = name.replacingOccurrences(of: " only", with: "", options: .caseInsensitive)
        return .some(name)
    }

    static func isHeader(_ l: String) -> Bool { isSessionHeader(l) || weekScope(l) != nil }

    /// Reads "NN% used" and "Resets ..." within a few lines after a header.
    static func readBlock(_ lines: [String], from idx: Int) -> (Int?, String?) {
        var percent: Int?
        var reset: String?
        for j in idx..<min(idx + 5, lines.count) {
            let l = lines[j]
            if j > idx, isHeader(l) { break }
            if percent == nil, let m = l.range(of: "(\\d{1,3})\\s*%", options: .regularExpression) {
                percent = Int(l[m].filter(\.isNumber))
            }
            if reset == nil, let m = l.range(of: "[Rr]esets?\\s+.*", options: .regularExpression) {
                reset = String(l[m]).replacingOccurrences(of: "^[Rr]esets?\\s+", with: "", options: .regularExpression)
            }
        }
        return (percent, reset)
    }
}
