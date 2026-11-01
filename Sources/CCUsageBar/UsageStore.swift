import SwiftUI
import UsageCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var showRaw = false

    /// Refresh interval in seconds.
    static let refreshInterval: TimeInterval = 300

    private let runner = ClaudeRunner()
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        let runner = self.runner
        DispatchQueue.global(qos: .utility).async {
            let snap = runner.fetch()
            DispatchQueue.main.async {
                self.snapshot = snap
                self.hasLoaded = true
                self.isLoading = false
            }
        }
    }

    var menuBarLabel: String {
        guard hasLoaded else { return "CC …" }
        guard snapshot.hasUsage else { return "CC ⚠︎" }
        func f(_ v: Int?) -> String { v.map { "\($0)%" } ?? "–" }
        return "5h \(f(snapshot.sessionPercent)) · 7d \(f(snapshot.weekPercent))"
    }
}
