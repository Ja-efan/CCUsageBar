import SwiftUI
import UsageCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var contentHeight: CGFloat = 0

    private let claude = ClaudeCodeProvider()
    private var timer: Timer?

    init() {
        refresh()
        let interval = TimeInterval(claude.refreshInterval.components.seconds)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
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
        Task {
            let snap: UsageSnapshot
            do {
                snap = UsageSnapshot(try await claude.fetch())
            } catch let failure as ProviderFailure {
                snap = UsageSnapshot(failure)
            } catch {
                snap = UsageSnapshot(ProviderFailure(.failed(String(describing: error))))
            }
            snapshot = snapshot.updated(with: snap)
            AppSettings.shared.registerModels(snap.modelLimits.map(\.name))
            hasLoaded = true
            isLoading = false
        }
    }
}
