import Foundation

/// How usage bars and percentages are colored.
public enum BarColorMode: String, CaseIterable, Identifiable, Sendable {
    case byUsage   // green / orange / red by threshold
    case fixed     // one color chosen by the user
    public var id: String { rawValue }
}

/// The color role for a usage value; the app maps each case to a color.
public enum UsageTone: Equatable, Sendable {
    case unknown   // no value
    case low
    case elevated
    case high
    case custom    // the user's chosen color

    public init(percent: Int?, mode: BarColorMode, warnHigh: Bool) {
        guard let p = percent else { self = .unknown; return }
        switch mode {
        case .byUsage:
            self = p >= 90 ? .high : (p >= 70 ? .elevated : .low)
        case .fixed:
            self = (warnHigh && p >= 90) ? .high : .custom
        }
    }
}
