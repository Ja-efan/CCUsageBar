import Foundation

/// A minimal VT100-style screen. Replays PTY output onto a fixed grid so the result
/// is what a terminal would show at the end.
///
/// Claude Code redraws only the cells that change: after `/usage` refreshes, it moves
/// the cursor to a number and overwrites it. Reading the output as a stream keeps the
/// stale value next to its header; replaying it on a grid keeps only the new one.
public struct TerminalScreen {
    public let columns: Int
    public let rows: Int
    /// Content went past the bottom and lines were lost off the top since the last clear.
    public private(set) var overflowed = false
    private var grid: [[Unicode.Scalar]]
    private var row = 0
    private var col = 0
    private var pendingWrap = false
    private var saved = (row: 0, col: 0)

    private static let blank: Unicode.Scalar = " "
    /// Right half of a double-width character; skipped when reading text.
    private static let continuation: Unicode.Scalar = "\u{0}"

    public init(columns: Int = 140, rows: Int = 50) {
        self.columns = columns
        self.rows = rows
        grid = Array(repeating: Array(repeating: Self.blank, count: columns), count: rows)
    }

    /// Renders `output` on a fresh screen.
    public static func render(_ output: String, columns: Int = 140, rows: Int = 50) -> TerminalScreen {
        var screen = TerminalScreen(columns: columns, rows: rows)
        screen.feed(output)
        return screen
    }

    /// Non-empty screen lines, trimmed (same shape as `TerminalText.clean`).
    public var text: String {
        grid.map { line in
            var s = String.UnicodeScalarView()
            for c in line where c != Self.continuation { s.append(c) }
            return String(s).trimmingCharacters(in: .whitespaces)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    public mutating func feed(_ output: String) {
        let s = Array(output.unicodeScalars)
        var i = 0
        while i < s.count {
            let c = s[i]
            switch c.value {
            case 0x1B:
                i = escape(s, from: i + 1)
                continue
            case 0x0D:
                col = 0; pendingWrap = false
            case 0x0A, 0x0B, 0x0C:
                lineFeed()
            case 0x08:
                col = max(0, col - 1); pendingWrap = false
            case 0x09:
                col = min(columns - 1, (col / 8 + 1) * 8)
            case 0..<0x20, 0x7F:
                break
            default:
                put(c)
            }
            i += 1
        }
    }

    // MARK: Escape sequences

    private mutating func escape(_ s: [Unicode.Scalar], from j: Int) -> Int {
        guard j < s.count else { return j }
        switch s[j] {
        case "[":
            var k = j + 1
            var params = ""
            while k < s.count, (0x20...0x3F).contains(s[k].value) {
                params.unicodeScalars.append(s[k]); k += 1
            }
            guard k < s.count else { return k }
            csi(params, final: s[k])
            return k + 1
        case "]", "P", "_", "^":
            // OSC / DCS / APC / PM: skip to BEL or ST.
            var k = j + 1
            while k < s.count {
                if s[k] == "\u{07}" { return k + 1 }
                if s[k] == "\u{1B}", k + 1 < s.count, s[k + 1] == "\\" { return k + 2 }
                k += 1
            }
            return k
        case "(", ")", "*", "+":
            return j + 2
        case "7":
            saved = (row, col)
        case "8":
            (row, col) = saved; pendingWrap = false
        case "D":
            lineFeed()
        case "E":
            col = 0; lineFeed()
        case "M":
            row = max(0, row - 1); pendingWrap = false
        case "c":
            clear(); row = 0; col = 0
        default:
            break
        }
        return j + 1
    }

    private mutating func csi(_ params: String, final: Unicode.Scalar) {
        if params.hasPrefix("?") {
            // Alternate screen on/off starts from a blank screen. Other modes don't affect layout.
            let modes = params.dropFirst().split(separator: ";")
            if final == "h" || final == "l", modes.contains(where: { ["47", "1047", "1049"].contains($0) }) {
                clear(); row = 0; col = 0; pendingWrap = false
            }
            return
        }
        // Only digits and ';' matter for the sequences handled below.
        let nums = params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        func n(_ i: Int, _ d: Int = 1) -> Int { i < nums.count && nums[i] != 0 ? nums[i] : d }
        func mode() -> Int { nums.first ?? 0 }

        switch final {
        case "A": row = max(0, row - n(0))
        case "B", "e": row = min(rows - 1, row + n(0))
        case "C", "a": col = min(columns - 1, col + n(0))
        case "D": col = max(0, col - n(0))
        case "E": row = min(rows - 1, row + n(0)); col = 0
        case "F": row = max(0, row - n(0)); col = 0
        case "G", "`": col = clampCol(n(0) - 1)
        case "d": row = clampRow(n(0) - 1)
        case "H", "f": row = clampRow(n(0) - 1); col = clampCol(n(1) - 1)
        case "K":
            switch mode() {
            case 1: fill(row, 0...col)
            case 2: fill(row, 0...(columns - 1))
            default: fill(row, col...(columns - 1))
            }
        case "J":
            switch mode() {
            case 1:
                for r in 0..<row { fill(r, 0...(columns - 1)) }
                fill(row, 0...col)
            case 2, 3:
                clear()
            default:
                fill(row, col...(columns - 1))
                for r in (row + 1)..<rows { fill(r, 0...(columns - 1)) }
            }
        case "X": fill(row, col...min(columns - 1, col + n(0) - 1))
        case "P":
            let k = min(n(0), columns - col)
            grid[row].removeSubrange(col..<(col + k))
            grid[row].append(contentsOf: Array(repeating: Self.blank, count: k))
        case "@":
            let k = min(n(0), columns - col)
            grid[row].insert(contentsOf: Array(repeating: Self.blank, count: k), at: col)
            grid[row].removeLast(k)
        case "L":
            for _ in 0..<min(n(0), rows - row) { grid.insert(blankLine, at: row); grid.removeLast() }
        case "M":
            for _ in 0..<min(n(0), rows - row) { grid.remove(at: row); grid.append(blankLine) }
        case "S":
            overflowed = true
            for _ in 0..<min(n(0), rows) { grid.removeFirst(); grid.append(blankLine) }
        case "T":
            for _ in 0..<min(n(0), rows) { grid.removeLast(); grid.insert(blankLine, at: 0) }
        default:
            return // styling (m), modes, cursor shape, etc.
        }
        pendingWrap = false
    }

    // MARK: Grid

    private var blankLine: [Unicode.Scalar] { Array(repeating: Self.blank, count: columns) }
    private func clampRow(_ r: Int) -> Int { min(max(r, 0), rows - 1) }
    private func clampCol(_ c: Int) -> Int { min(max(c, 0), columns - 1) }

    private mutating func clear() {
        grid = Array(repeating: blankLine, count: rows)
        overflowed = false
    }

    private mutating func fill(_ r: Int, _ range: ClosedRange<Int>) {
        guard range.lowerBound <= range.upperBound else { return }
        for c in range { grid[r][c] = Self.blank }
    }

    private mutating func lineFeed() {
        pendingWrap = false
        if row == rows - 1 {
            overflowed = true
            grid.removeFirst(); grid.append(blankLine)
        } else {
            row += 1
        }
    }

    private mutating func put(_ c: Unicode.Scalar) {
        let width = Self.width(of: c)
        guard width > 0 else { return }
        // Wrap is deferred until the next character, like a real terminal,
        // so a full-width line followed by CR LF doesn't skip a row.
        if pendingWrap || (width == 2 && col == columns - 1) {
            col = 0; lineFeed()
        }
        grid[row][col] = c
        if width == 2 { grid[row][col + 1] = Self.continuation }
        col += width
        if col >= columns { col = columns - 1; pendingWrap = true }
    }

    /// Terminal cell width: 0 for combining marks, 2 for CJK/Hangul/emoji, else 1.
    static func width(of c: Unicode.Scalar) -> Int {
        switch c.value {
        case 0x0300...0x036F, 0x200B...0x200F, 0xFE00...0xFE0F: return 0
        case 0x1100...0x115F, 0x2E80...0xA4CF, 0xAC00...0xD7A3, 0xF900...0xFAFF,
             0xFE30...0xFE4F, 0xFF00...0xFF60, 0xFFE0...0xFFE6,
             0x1F300...0x1F64F, 0x1F900...0x1F9FF, 0x20000...0x3FFFD: return 2
        default: return 1
        }
    }
}
