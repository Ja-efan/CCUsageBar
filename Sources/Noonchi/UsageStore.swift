import Combine
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

    private var timer: Timer?
    private var intervalChange: AnyCancellable?
    private var screenAsleep = false
    private var screenLocked = false
    private var screenOff: Bool { screenAsleep || screenLocked }
    /// A scheduled read was held back, so the screen coming back should catch up.
    private var skippedRead = false
    /// Bumped when a service is turned off, so a read started before that is dropped.
    private var generation: [ProviderID: Int] = [:]

    init() {
#if NOONCHI_VERIFY
        VerifyDriver.start(store: self)
#endif
        refresh()
        intervalChange = AppSettings.shared.$refreshInterval.sink { [weak self] in self?.startTimer($0) }
        // Timers don't fire during sleep; values would be stale for up to one interval.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.readDueServices() }
        }
        observeScreen()
    }

    private func startTimer(_ interval: RefreshInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval.seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.readDueServices() }
        }
        timer.tolerance = interval.seconds / 10 // lets macOS group wakeups
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func observeScreen() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setScreen(asleep: true) }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setScreen(asleep: false) }
        }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setScreen(locked: true) }
        }
        distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setScreen(locked: false) }
        }
    }

    func setScreen(asleep: Bool? = nil, locked: Bool? = nil) {
        if let asleep { screenAsleep = asleep }
        if let locked { screenLocked = locked }
        if !screenOff, skippedRead { readDueServices() }
    }

    /// The timer, wake, and the screen coming back all land here. The Refresh button doesn't:
    /// someone pressing it wants a read.
    func readDueServices() {
        var skipped = false
        for provider in Providers.all {
            if ScheduledRead.isDue(screenOff: screenOff, lastAttempt: states[provider.id]?.lastAttempt, now: Date()) {
                refresh(provider)
            } else {
                skipped = true
            }
        }
        skippedRead = skipped
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
