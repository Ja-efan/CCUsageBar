import Foundation

/// Turns raw PTY output (with ANSI escapes and cursor moves) into plain lines.
public enum TerminalText {
    public static func clean(_ s: String) -> String {
        var r = s
        // OSC sequences (window title, hyperlinks).
        r = r.replacingOccurrences(of: "\u{1b}\\][^\u{07}\u{1b}]*(\u{07}|\u{1b}\\\\)", with: "", options: .regularExpression)
        // Cursor-forward is used instead of spaces by TUI renderers.
        r = r.replacingOccurrences(of: "\u{1b}\\[\\d*C", with: " ", options: .regularExpression)
        // Styling / in-line sequences: colors (m), erase-in-line (K), column moves (G),
        // mode switches (h/l), cursor shape (q). These must NOT break lines.
        r = r.replacingOccurrences(of: "\u{1b}\\[[0-9;:?<>=]*[ -/]*[mKGhlq]", with: "", options: .regularExpression)
        // Remaining CSI sequences move the cursor between rows: treat as line breaks.
        r = r.replacingOccurrences(of: "\u{1b}\\[[0-9;?<>=]*[ -/]*[@-~]", with: "\n", options: .regularExpression)
        // Charset selection and other 2-byte escapes.
        r = r.replacingOccurrences(of: "\u{1b}[()][0-9A-Za-z]", with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: "\u{1b}[=>78]", with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: "\r", with: "\n")
        return r.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Text after the last `/usage` command (not `/usage-something` or `/usage...` hints).
    public static func usageSection(_ t: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "/usage(?![\\w-])") else { return t }
        let ns = NSRange(t.startIndex..., in: t)
        guard let m = re.matches(in: t, range: ns).last, let r = Range(m.range, in: t) else { return t }
        return String(t[r.upperBound...])
    }

    static func count(_ s: String, pattern: String) -> Int {
        (try? NSRegularExpression(pattern: pattern))?
            .numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s)) ?? 0
    }
}
