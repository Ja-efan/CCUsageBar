import Foundation

/// Extracts session (5-hour) and weekly usage from cleaned `/usage` output.
public enum UsageParser {
    public static func parse(_ cleaned: String, updatedAt: Date = Date()) -> UsageSnapshot {
        var snap = UsageSnapshot(raw: cleaned, updatedAt: updatedAt)
        let lines = TerminalText.usageSection(cleaned).components(separatedBy: "\n")

        // Use the LAST matching header: TUI redraws repeat earlier frames.
        if let i = lines.lastIndex(where: isSessionHeader) {
            (snap.sessionPercent, snap.sessionReset) = readBlock(lines, from: i)
        }
        if let i = lines.lastIndex(where: isWeekHeader) {
            (snap.weekPercent, snap.weekReset) = readBlock(lines, from: i)
        }

        if !snap.hasUsage {
            if cleaned.contains("Not logged in") { snap.error = .notLoggedIn }
            else if cleaned.contains("API Usage Billing") { snap.error = .apiBilling }
            else { snap.error = .unparsable }
        }
        return snap
    }

    static func isSessionHeader(_ l: String) -> Bool {
        let s = l.lowercased()
        return s.contains("current session") || s.contains("5-hour") || s.contains("5 hour")
    }

    static func isWeekHeader(_ l: String) -> Bool {
        let s = l.lowercased()
        guard s.contains("current week") || s.contains("weekly") else { return false }
        // Skip model-scoped weekly caps (Sonnet only, Opus, ...).
        return !s.contains("sonnet") && !s.contains("opus") && !s.contains(" only")
    }

    /// Reads "NN% used" and "Resets ..." within a few lines after a header.
    static func readBlock(_ lines: [String], from idx: Int) -> (Int?, String?) {
        var percent: Int?
        var reset: String?
        for j in idx..<min(idx + 6, lines.count) {
            let l = lines[j]
            if j > idx, isSessionHeader(l) || l.lowercased().contains("current week") { break }
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
