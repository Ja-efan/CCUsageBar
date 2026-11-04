import AppKit
import SwiftUI
import UsageCore

/// One update attempt. The window shows whichever state this is in.
enum UpdatePhase: Equatable {
    case checking
    case upToDate(AppVersion)
    case available(Release, current: AppVersion)
    case downloading(Release)
    case failed(UpdateFailure, Release?)
}

@MainActor
final class AppUpdater: ObservableObject {
    /// False on builds that must not be replaced by a release.
    static let installsUpdates = true
    static let releasesPage = URL(string: "https://github.com/Ja-efan/Noonchi/releases/latest")!

    @Published private(set) var phase = UpdatePhase.checking

    private var feed = URL(string: "https://api.github.com/repos/Ja-efan/Noonchi/releases/latest")!
    private var allowsDownload: (URL) -> Bool = Release.isGitHubDownload
    private var openArguments: [String] = []

    init() {
#if NOONCHI_VERIFY
        let env = ProcessInfo.processInfo.environment
        if let local = env["NOONCHI_UPDATE_FEED"].flatMap(URL.init(string:)) {
            feed = local
            allowsDownload = { _ in true }
        }
        // `open` drops the environment, and the relaunched copy has to stay isolated.
        let kept = ["CFFIXED_USER_HOME", "HOME", "NOONCHI_VERIFY_DIR", "NOONCHI_CLAUDE_PATH", "NOONCHI_CODEX_PATH", "NOONCHI_UPDATE_FEED"]
        openArguments = kept.flatMap { key in env[key].map { ["--env", "\(key)=\($0)"] } ?? [] }
#endif
    }

    private var current: AppVersion {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
            ?? AppVersion("0")!
    }

    /// A swap that failed can't report anything: it runs after the app quit. So the app notes
    /// what it was installing and compares on the next launch.
    private static let attemptKey = "updateAttempt"

    func reportFailedAttempt() -> Bool {
        let defaults = UserDefaults.standard
        guard let attempted = defaults.string(forKey: Self.attemptKey).flatMap(AppVersion.init) else { return false }
        defaults.removeObject(forKey: Self.attemptKey)
        guard current < attempted else { return false }
        phase = .failed(.couldNotReplace, nil)
        return true
    }

    func check() {
        if case .downloading = phase { return }
        phase = .checking
        Task {
            do {
                var request = URLRequest(url: feed, timeoutInterval: 15)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                switch (response as? HTTPURLResponse)?.statusCode {
                case 200: break
                case 403, 429: throw UpdateFailure.rateLimited
                default: throw UpdateFailure.network
                }
                let release = try Release(githubResponse: data, allowsDownload: allowsDownload)
                phase = release.version > current ? .available(release, current: current) : .upToDate(current)
            } catch {
                phase = .failed(error as? UpdateFailure ?? .network, nil)
            }
        }
    }

    func install(_ release: Release) {
        guard let download = release.download else { return }
        if case .downloading = phase { return }
        phase = .downloading(release)
        let app = Bundle.main.bundleURL
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let pid = ProcessInfo.processInfo.processIdentifier
        let openArguments = self.openArguments
        Task {
            do {
                let (zip, response) = try await URLSession.shared.download(from: download.url)
                defer { try? FileManager.default.removeItem(at: zip) }
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateFailure.network }
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try ReleaseInstaller.prepare(zip: zip, release: release, download: download, installedApp: app, bundleID: bundleID)
                }.value
                do {
                    try prepared.launchSwap(waitingFor: pid, openArguments: openArguments)
                } catch {
                    throw UpdateFailure.couldNotReplace
                }
                UserDefaults.standard.set(release.version.description, forKey: Self.attemptKey)
                NSApp.terminate(nil)
            } catch {
                phase = .failed(error as? UpdateFailure ?? .network, release)
            }
        }
    }
}

extension NSApplication {
    /// Opening a window takes keyboard focus. Verification builds run while someone is
    /// typing on this Mac, so they leave it alone.
    func bringToFront() {
#if !NOONCHI_VERIFY
        activate(ignoringOtherApps: true)
#endif
    }
}

@MainActor
enum UpdateWindow {
    private static var window: NSWindow?
    private static let updater = AppUpdater()

    static func show(settings: AppSettings) {
        updater.check()
        present(settings: settings)
    }

    private static func present(settings: AppSettings) {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: UpdateView(updater: updater, settings: settings)))
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.title = settings.strings.updateTitle
        NSApp.bringToFront()
        window?.makeKeyAndOrderFront(nil)
    }

    static func close() { window?.close() }

    /// At launch: tells the user if the update they asked for didn't take.
    static func showIfLastUpdateFailed(settings: AppSettings) {
        guard updater.reportFailedAttempt() else { return }
        present(settings: settings)
    }
}

struct UpdateView: View {
    @ObservedObject var updater: AppUpdater
    @ObservedObject var settings: AppSettings
    private var s: Strings { settings.strings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch updater.phase {
            case .checking:
                progress(s.updateChecking)
            case .upToDate(let current):
                message(s.updateLatest, s.updateCurrent(current.description))
                buttons { Button(s.done) { UpdateWindow.close() }.keyboardShortcut(.defaultAction) }
            case .available(let release, let current):
                let installable = AppUpdater.installsUpdates && release.download != nil
                message(s.updateAvailable(release.version.description),
                        installable ? s.updateInstallNote(current.description)
                                    : AppUpdater.installsUpdates ? s.updateManual : s.updateFromSource)
                buttons {
                    Button(s.updateChanges) { NSWorkspace.shared.open(release.pageURL) }
                    Button(s.updateLater) { UpdateWindow.close() }
                    if installable {
                        Button(s.updateInstall) { updater.install(release) }.keyboardShortcut(.defaultAction)
                    }
                }
            case .downloading:
                progress(s.updateDownloading)
            case .failed(let failure, let release):
                message(s.updateFailed, s.updateFailure(failure))
                buttons {
                    Button(s.updateOpenPage) { NSWorkspace.shared.open(release?.pageURL ?? AppUpdater.releasesPage) }
                    Button(s.done) { UpdateWindow.close() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(18)
        .frame(width: 380, alignment: .leading)
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text)
        }
    }

    private func message(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func buttons<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack {
            Spacer()
            content()
        }
    }
}
