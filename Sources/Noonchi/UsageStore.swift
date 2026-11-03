import SwiftUI
import UsageCore

@MainActor
final class UsageStore: ObservableObject {
    /// Installed services in registry order. Others aren't polled or shown.
    @Published private(set) var shown: [any UsageProvider] = []
    @Published private(set) var states: [ProviderID: ProviderState] = [:]
    /// Claude has answered at least once; the menu bar shows "…" until then.
    @Published private(set) var hasLoaded = false
    @Published var contentHeight: CGFloat = 0

    private var timers: [Timer] = []

    init() {
        refresh()
        // Each service polls on its own interval and never waits for another.
        for provider in Providers.all {
            let interval = TimeInterval(provider.refreshInterval.components.seconds)
            timers.append(Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh(provider) }
            })
        }
        // Timers don't fire during sleep; values would be stale for up to one interval.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var isLoading: Bool { states.values.contains { $0.isLoading } }
    var claudeUsage: ProviderUsage? { states[ClaudeCodeProvider().id]?.usage }
    /// Time of the newest good reading.
    var lastUpdated: Date? { states.values.compactMap { $0.usage?.fetchedAt }.max() }

    func refresh() {
        for provider in Providers.all { refresh(provider) }
    }

    func refresh(_ provider: any UsageProvider) {
        let id = provider.id
        let isClaude = provider is ClaudeCodeProvider
        guard provider.locateExecutable() != nil else {
            states[id] = nil
            shown = Providers.all.filter { states[$0.id] != nil }
            if isClaude { hasLoaded = true }
            return
        }
        guard states[id]?.isLoading != true else { return }
        states[id, default: ProviderState()].isLoading = true
        shown = Providers.all.filter { states[$0.id] != nil }

        Task {
            let result: Result<ProviderUsage, ProviderFailure>
            do {
                result = .success(try await provider.fetch())
            } catch let failure as ProviderFailure {
                result = .failure(failure)
            } catch {
                result = .failure(ProviderFailure(.failed(String(describing: error))))
            }
            states[id, default: ProviderState()].apply(result)
            states[id]?.isLoading = false
            if isClaude {
                hasLoaded = true
                if case .success(let usage) = result {
                    AppSettings.shared.registerModels(usage.windows.compactMap { w in
                        if case .model(let name, _) = w.kind { return name } else { return nil }
                    })
                }
            }
        }
    }
}
