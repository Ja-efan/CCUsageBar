import SwiftUI
import UsageCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var contentHeight: CGFloat = 0

    /// Refresh interval in seconds.
    static let refreshInterval: TimeInterval = 300

    private let runner = ClaudeRunner()
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // The timer doesn't fire during sleep; values would be stale for up to one interval.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
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
                self.snapshot = self.snapshot.updated(with: snap)
                AppSettings.shared.registerModels(snap.modelLimits.map(\.name))
                self.hasLoaded = true
                self.isLoading = false
            }
        }
    }
}
