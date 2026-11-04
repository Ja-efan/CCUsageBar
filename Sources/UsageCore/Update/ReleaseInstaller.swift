import CryptoKit
import Foundation

/// A verified new app, sitting next to the installed one and ready to swap in.
public struct PreparedUpdate: Sendable {
    public let newApp: URL
    public let installedApp: URL
    let staging: URL

    /// Waits for the app (`pid`) to quit, swaps the bundles, and opens the result. A failed
    /// swap puts the old app back. It runs after the app is gone, so it has to be a separate process.
    public func launchSwap(waitingFor pid: Int32, openArguments: [String] = []) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", Self.swapScript, "noonchi-update", String(pid),
                             installedApp.path, newApp.path, staging.path] + openArguments
        try process.run()
    }

    static let swapScript = #"""
    pid=$1; old=$2; new=$3; staging=$4; shift 4
    for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    if kill -0 "$pid" 2>/dev/null; then rm -rf "$staging"; exit 1; fi
    backup="$staging/previous.app"
    if mv "$old" "$backup"; then
      if ! mv "$new" "$old"; then mv "$backup" "$old"; fi
    fi
    for _ in 1 2 3 4 5; do open "$@" "$old" 2>/dev/null && break; sleep 1; done
    rm -rf "$staging"
    """#
}

public enum ReleaseInstaller {
    private static let stagingPrefix = ".Noonchi-update-"

    /// Checks the download and unpacks it beside the installed app, on the same volume, so the
    /// swap is a rename. Throws before anything of the installed app is touched.
    public static func prepare(zip: URL, release: Release, installedApp: URL, bundleID: String) throws -> PreparedUpdate {
        guard let data = try? Data(contentsOf: zip, options: .mappedIfSafe),
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == release.sha256
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
                  let name = try fm.contentsOfDirectory(atPath: staging.path).first(where: { $0.hasSuffix(".app") })
            else { throw UpdateFailure.invalidApp }
            let newApp = staging.appendingPathComponent(name)
            guard let info = NSDictionary(contentsOf: newApp.appendingPathComponent("Contents/Info.plist")),
                  info["CFBundleIdentifier"] as? String == bundleID,
                  (info["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init) == release.version,
                  run("/usr/bin/codesign", "--verify", "--deep", "--strict", newApp.path)
            else { throw UpdateFailure.invalidApp }
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
