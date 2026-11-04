import CryptoKit
import Foundation

/// A verified new app, sitting next to the installed one and ready to swap in.
public struct PreparedUpdate: Sendable {
    public let newApp: URL
    public let installedApp: URL
    let staging: URL

    /// Waits for the app (`pid`) to quit, swaps the bundles, and opens the result. It runs after
    /// the app is gone, so it has to be a separate process.
    public func launchSwap(waitingFor pid: Int32, openArguments: [String] = []) throws {
        _ = try startSwap(waitingFor: pid, openArguments: openArguments)
    }

    func startSwap(waitingFor pid: Int32, openArguments: [String] = [], waitTicks: Int = 100,
                   environment: [String: String]? = nil) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", Self.swapScript, "noonchi-update", String(pid), String(waitTicks),
                             installedApp.path, newApp.path, staging.path] + openArguments
        if let environment { process.environment = environment }
        try process.run()
        return process
    }

    /// The one rule: the backup is deleted only once an app is in place and has opened. Otherwise
    /// the user is left with whichever copy exists, even if that means a stray staging folder.
    static let swapScript = #"""
    pid=$1; ticks=$2; old=$3; new=$4; staging=$5; shift 5
    i=0
    while [ "$i" -lt "$ticks" ] && kill -0 "$pid" 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
    if kill -0 "$pid" 2>/dev/null; then rm -rf "$staging"; exit 1; fi

    backup="$staging/previous.app"
    launch() {
      for _ in 1 2 3 4 5; do
        open "$@" "$old" 2>/dev/null && return 0
        sleep 1
      done
      return 1
    }

    if ! mv "$old" "$backup"; then
      launch "$@"
      rm -rf "$staging"
      exit 1
    fi
    if ! mv "$new" "$old"; then
      mv "$backup" "$old" || exit 1
      launch "$@"
      rm -rf "$staging"
      exit 1
    fi
    if launch "$@"; then
      rm -rf "$staging"
      exit 0
    fi
    # The new app won't open. Put the old one back.
    mv "$old" "$staging/rejected.app" || exit 1
    mv "$backup" "$old" || exit 1
    launch "$@"
    rm -rf "$staging"
    exit 1
    """#
}

public enum ReleaseInstaller {
    private static let stagingPrefix = ".Noonchi-update-"

    public static var currentSystem: AppVersion {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return AppVersion("\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)") ?? AppVersion("0")!
    }

    /// Checks the download and unpacks it beside the installed app, on the same volume, so the
    /// swap is a rename. Throws before anything of the installed app is touched.
    public static func prepare(zip: URL, release: Release, download: Release.Download, installedApp: URL, bundleID: String,
                               systemVersion: AppVersion = currentSystem) throws -> PreparedUpdate {
        guard let data = try? Data(contentsOf: zip, options: .mappedIfSafe),
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == download.sha256
        else { throw UpdateFailure.damagedDownload }

        let fm = FileManager.default
        let parent = installedApp.deletingLastPathComponent()
        guard installedApp.pathExtension == "app", fm.isWritableFile(atPath: parent.path),
              fm.isWritableFile(atPath: installedApp.path)
        else { throw UpdateFailure.cannotWriteToApp }

        // A crash or quit mid-update leaves one of these behind.
        for name in (try? fm.contentsOfDirectory(atPath: parent.path)) ?? [] where name.hasPrefix(stagingPrefix) {
            try? fm.removeItem(at: parent.appendingPathComponent(name))
        }
        let staging = parent.appendingPathComponent(stagingPrefix + UUID().uuidString)
        do {
            try fm.createDirectory(at: staging, withIntermediateDirectories: false)
            guard run("/usr/bin/ditto", "-x", "-k", zip.path, staging.path),
                  case let apps = try fm.contentsOfDirectory(atPath: staging.path).filter({ $0.hasSuffix(".app") }),
                  apps.count == 1,
                  case let newApp = staging.appendingPathComponent(apps[0]),
                  try fm.attributesOfItem(atPath: newApp.path)[.type] as? FileAttributeType == .typeDirectory
            else { throw UpdateFailure.invalidApp }
            guard let info = NSDictionary(contentsOf: newApp.appendingPathComponent("Contents/Info.plist")),
                  info["CFBundleIdentifier"] as? String == bundleID,
                  (info["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init) == release.version,
                  run("/usr/bin/codesign", "--verify", "--deep", "--strict", newApp.path)
            else { throw UpdateFailure.invalidApp }
            if let needed = (info["LSMinimumSystemVersion"] as? String).flatMap(AppVersion.init), needed > systemVersion {
                throw UpdateFailure.requiresNewerMacOS
            }
            return PreparedUpdate(newApp: newApp, installedApp: installedApp, staging: staging)
        } catch {
            try? fm.removeItem(at: staging)
            throw error as? UpdateFailure ?? UpdateFailure.invalidApp
        }
    }

    private static func run(_ executable: String, _ arguments: String...) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
