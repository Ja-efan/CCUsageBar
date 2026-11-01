import Foundation

/// Turns raw PTY output (with ANSI escapes and cursor moves) into plain lines.
public enum TerminalText {
    public static func clean(_ s: String) -> String {
        var r = s
        // Cursor-forward is used instead of spaces by TUI renderers.
        r = r.replacingOccurrences(of: "\u{1b}\\[(\\d*)C", with: " ", options: .regularExpression)
        // OSC sequences (window title, hyperlinks).
        r = r.replacingOccurrences(of: "\u{1b}\\][^\u{07}\u{1b}]*(\u{07}|\u{1b}\\\\)", with: "", options: .regularExpression)
        // Other CSI sequences: treat as line breaks (cursor jumps).
        r = r.replacingOccurrences(of: "\u{1b}\\[[0-9;?<>=]*[ -/]*[@-~]", with: "\n", options: .regularExpression)
        // Charset selection.
        r = r.replacingOccurrences(of: "\u{1b}[()][0-9A-Za-z]", with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: "\r", with: "\n")
        return r.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Text after the last `/usage` command echo.
    public static func usageSection(_ t: String) -> String {
        if let r = t.range(of: "/usage", options: .backwards) { return String(t[r.upperBound...]) }
        return t
    }

    static func count(_ s: String, pattern: String) -> Int {
        (try? NSRegularExpression(pattern: pattern))?
            .numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s)) ?? 0
    }
}
