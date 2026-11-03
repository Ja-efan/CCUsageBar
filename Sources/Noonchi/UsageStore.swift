import SwiftUI
import UsageCore

@MainActor
final class UsageStore: ObservableObject {
    /// Installed services in registry order. Others aren't polled or shown.
    @Published private(set) var shown: [any UsageProvider] = []
    @Published private(set) var states: [ProviderID: ProviderState] = [:]
    @Published var contentHeight: CGFloat = 0
    var paceModel: any PaceModel = PaceEstimator()
    private var observers: [any UsageObserver] = []

    private var timers: [Timer] = []
    /// Bumped when a service is turned off, so a read started before that is dropped.
    private var generation: [ProviderID: Int] = [:]

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
    var lastUpdated: Date? { states.values.compactMap { $0.usage?.fetchedAt }.max() }

    func refresh() {
        for provider in Providers.all { refresh(provider) }
    }

    func addObserver(_ observer: any UsageObserver) { observers.append(observer) }

    func refresh(_ provider: any UsageProvider) {
        let id = provider.id
        guard AppSettings.shared.isEnabled(id), provider.locateExecutable() != nil else {
            if states[id] != nil { generation[id, default: 0] += 1 }
            states[id] = nil
            shown = Providers.all.filter { states[$0.id] != nil }
            return
        }
        guard states[id]?.isLoading != true else { return }
        states[id, default: ProviderState()].isLoading = true
        shown = Providers.all.filter { states[$0.id] != nil }
        let started = generation[id, default: 0]

        Task {
            let result: Result<ProviderUsage, ProviderFailure>
            do {
                result = .success(try await provider.fetch())
            } catch let failure as ProviderFailure {
                result = .failure(failure)
            } catch {
                result = .failure(ProviderFailure(.failed(String(describing: error))))
            }
            // Turned off (and maybe on again) while the read was running.
            guard generation[id, default: 0] == started, states[id] != nil else { return }
            states[id]?.apply(result)
            states[id]?.isLoading = false
            if case .success(let usage) = result {
                AppSettings.shared.registerWindows(usage.windows.map(\.id), for: id)
                observers.forEach { $0.usageDidUpdate(usage, provider: id) }
            }
        }
    }
}
