import CryptoKit
import XCTest
@testable import UsageCore

final class AppVersionTests: XCTestCase {
    func testOrdering() {
        XCTAssertLessThan(AppVersion("0.4.2")!, AppVersion("0.4.10")!)
        XCTAssertLessThan(AppVersion("v0.4.2")!, AppVersion("1.0")!)
        XCTAssertEqual(AppVersion("v0.4.0")!, AppVersion("0.4")!)
        XCTAssertNil(AppVersion("nightly"))
    }
}

final class ReleaseTests: XCTestCase {
    /// Recorded from GitHub's API for v0.4.2.
    private func recorded() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "github-release-v0.4.2", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func testReadsRealResponse() throws {
        let release = try Release(githubResponse: recorded())
        XCTAssertEqual(release.version, AppVersion("0.4.2"))
        XCTAssertEqual(release.download?.url.lastPathComponent, "Noonchi-0.4.2.zip")
        XCTAssertEqual(release.download?.sha256.count, 64)
    }

    private func response(url: String = "https://github.com/x/Noonchi-1.0.zip", digest: String? = "sha256:AB", name: String = "Noonchi-1.0.zip") -> Data {
        let d = digest.map { #","digest":"\#($0)""# } ?? ""
        return Data(#"{"tag_name":"v1.0","html_url":"https://github.com/x","assets":[{"name":"\#(name)","browser_download_url":"\#(url)"\#(d)}]}"#.utf8)
    }

    /// A release that can't be installed here must still be announced: apps already
    /// shipped have no other way to learn of a fix.
    func testStillAnnouncesWhatItWontDownload() throws {
        for bad in [response(url: "http://github.com/x.zip"), response(url: "https://evil.example/x.zip"),
                    response(digest: nil), response(name: "Other.zip")] {
            let release = try Release(githubResponse: bad)
            XCTAssertEqual(release.version, AppVersion("1.0"))
            XCTAssertNil(release.download)
        }
    }

    func testUnreadableIsAFailure() {
        for bad in [Data("nope".utf8), Data(#"{"tag_name":"v1.0-beta","html_url":"https://github.com/x","assets":[]}"#.utf8)] {
            XCTAssertThrowsError(try Release(githubResponse: bad)) {
                XCTAssertEqual($0 as? UpdateFailure, .unreadableRelease)
            }
        }
    }
}

final class ReleaseInstallerTests: XCTestCase {
    private var root: URL!
    private let bundleID = "test.noonchi"

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("installer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.appendingPathComponent("Apps dir").path)
        try? FileManager.default.removeItem(at: root)
    }

    private func sh(_ executable: String, _ arguments: String...) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, executable)
    }

    private func makeApp(at url: URL, version: String, id: String? = nil, sign: Bool = true, minimumSystem: String = "14.0") throws {
        let macOS = url.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: macOS.appendingPathComponent("App").path)
        let info: NSDictionary = ["CFBundleIdentifier": id ?? bundleID, "CFBundleShortVersionString": version, "CFBundleExecutable": "App", "LSMinimumSystemVersion": minimumSystem]
        info.write(to: url.appendingPathComponent("Contents/Info.plist"), atomically: true)
        if sign { try sh("/usr/bin/codesign", "--force", "--sign", "-", url.path) }
    }

    /// Returns the zip and a release that describes it.
    private func makeRelease(version: String = "2.0", appVersion: String? = nil, id: String? = nil, sign: Bool = true, wrongDigest: Bool = false) throws -> (URL, Release) {
        let source = root.appendingPathComponent("src-\(UUID().uuidString)")
        try makeApp(at: source.appendingPathComponent("New.app"), version: appVersion ?? version, id: id, sign: sign)
        let zip = root.appendingPathComponent("\(UUID().uuidString).zip")
        try sh("/usr/bin/ditto", "-c", "-k", "--keepParent", source.appendingPathComponent("New.app").path, zip.path)
        let hash = wrongDigest ? String(repeating: "0", count: 64)
            : SHA256.hash(data: try Data(contentsOf: zip)).map { String(format: "%02x", $0) }.joined()
        let json = #"{"tag_name":"v\#(version)","html_url":"https://github.com/x","assets":[{"name":"Noonchi-\#(version).zip","browser_download_url":"https://github.com/x.zip","digest":"sha256:\#(hash)"}]}"#
        return (zip, try Release(githubResponse: Data(json.utf8)))
    }

    private func installed() throws -> URL {
        let app = root.appendingPathComponent("Apps dir/Noonchi.app")
        try makeApp(at: app, version: "1.0")
        return app
    }

    private func installedVersion(_ app: URL) -> String? {
        NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
    }

    private func assertRefused(_ expected: UpdateFailure, zip: URL, release: Release, app: URL, line: UInt = #line) {
        XCTAssertThrowsError(try ReleaseInstaller.prepare(zip: zip, release: release, download: release.download!, installedApp: app, bundleID: bundleID), line: line) {
            XCTAssertEqual($0 as? UpdateFailure, expected, line: line)
        }
        XCTAssertEqual(installedVersion(app), "1.0", "installed app untouched", line: line)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: app.deletingLastPathComponent().path)) ?? []
        XCTAssertEqual(leftovers, ["Noonchi.app"], "nothing left behind", line: line)
    }

    func testRefusesBadDownloads() throws {
        let app = try installed()
        let damaged = try makeRelease(wrongDigest: true)
        assertRefused(.damagedDownload, zip: damaged.0, release: damaged.1, app: app)
        let otherApp = try makeRelease(id: "someone.else")
        assertRefused(.invalidApp, zip: otherApp.0, release: otherApp.1, app: app)
        let otherVersion = try makeRelease(appVersion: "1.5")
        assertRefused(.invalidApp, zip: otherVersion.0, release: otherVersion.1, app: app)
        let unsigned = try makeRelease(sign: false)
        assertRefused(.invalidApp, zip: unsigned.0, release: unsigned.1, app: app)
    }

    func testRefusesReadOnlyFolder() throws {
        let app = try installed()
        let (zip, release) = try makeRelease()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: app.deletingLastPathComponent().path)
        XCTAssertThrowsError(try ReleaseInstaller.prepare(zip: zip, release: release, download: release.download!, installedApp: app, bundleID: bundleID)) {
            XCTAssertEqual($0 as? UpdateFailure, .cannotWriteToApp)
        }
    }

    func testLeftoverFromAnInterruptedUpdateIsCleared() throws {
        let app = try installed()
        let stale = app.deletingLastPathComponent().appendingPathComponent(".Noonchi-update-old")
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        let (zip, release) = try makeRelease()
        _ = try ReleaseInstaller.prepare(zip: zip, release: release, download: release.download!, installedApp: app, bundleID: bundleID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
    }

    /// Runs the real swap with `mv` and `open` standing in, so each failure can be forced.
    private struct SwapRun {
        let openedPaths: [String]
        let openedArguments: [[String]]
        let status: Int32
    }

    private func runSwap(_ prepared: PreparedUpdate, waitingFor pid: Int32, waitTicks: Int = 100, failingMoves: [Int] = [], failingOpens: Int = 0) throws -> SwapRun {
        let shims = root.appendingPathComponent("shims-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: shims, withIntermediateDirectories: true)
        let log = shims.appendingPathComponent("open.log").path
        let moves = shims.appendingPathComponent("moves").path
        let opens = shims.appendingPathComponent("opens").path
        try "0".write(toFile: moves, atomically: true, encoding: .utf8)
        try "0".write(toFile: opens, atomically: true, encoding: .utf8)
        let failing = failingMoves.map(String.init).joined(separator: " ")
        let mv = "#!/bin/sh\nn=$(( $(cat '\(moves)') + 1 )); echo $n > '\(moves)'\nfor f in \(failing); do [ \"$f\" = \"$n\" ] && exit 1; done\nexec /bin/mv \"$@\"\n"
        let open = "#!/bin/sh\nn=$(( $(cat '\(opens)') + 1 )); echo $n > '\(opens)'\n[ \"$n\" -le \(failingOpens) ] && exit 1\nprintf '%s\\n' \"$*\" >> '\(log)'\n"
        for (name, body) in [("mv", mv), ("open", open)] {
            let path = shims.appendingPathComponent(name).path
            try body.write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        }
        let process = try prepared.startSwap(waitingFor: pid, openArguments: ["--env", "A=B"], waitTicks: waitTicks,
                                             environment: ["PATH": "\(shims.path):/usr/bin:/bin"])
        process.waitUntilExit()
        let lines = ((try? String(contentsOfFile: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        return SwapRun(openedPaths: lines, openedArguments: [], status: process.terminationStatus)
    }

    private func gonePid() throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try p.run()
        p.waitUntilExit()
        return p.processIdentifier
    }

    private func prepared() throws -> (PreparedUpdate, URL) {
        let app = try installed()
        let (zip, release) = try makeRelease()
        return (try ReleaseInstaller.prepare(zip: zip, release: release, download: release.download!, installedApp: app, bundleID: bundleID), app)
    }

    private func folder(_ app: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: app.deletingLastPathComponent().path).sorted()
    }

    func testSwapWaitsForTheAppThenReplacesOpensAndCleansUp() throws {
        let (update, app) = try prepared()
        XCTAssertEqual(installedVersion(app), "1.0", "not swapped before the app quits")
        let sleeper = Process()
        sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleeper.arguments = ["0.3"]
        try sleeper.run()
        let run = try runSwap(update, waitingFor: sleeper.processIdentifier)
        XCTAssertEqual(run.status, 0)
        XCTAssertEqual(installedVersion(app), "2.0")
        XCTAssertEqual(run.openedPaths, ["--env A=B \(app.path)"])
        XCTAssertEqual(try folder(app), ["Noonchi.app"])
    }

    func testAppThatWontQuitIsLeftRunningUntouched() throws {
        let (update, app) = try prepared()
        let sleeper = Process()
        sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleeper.arguments = ["30"]
        try sleeper.run()
        defer { sleeper.terminate() }
        let run = try runSwap(update, waitingFor: sleeper.processIdentifier, waitTicks: 2)
        XCTAssertEqual(run.status, 1)
        XCTAssertEqual(installedVersion(app), "1.0")
        XCTAssertEqual(run.openedPaths, [], "it's still running, so nothing to open")
        XCTAssertEqual(try folder(app), ["Noonchi.app"])
    }

    func testCantMoveOldAppKeepsItAndReopensIt() throws {
        let (update, app) = try prepared()
        let run = try runSwap(update, waitingFor: try gonePid(), failingMoves: [1])
        XCTAssertEqual(run.status, 1)
        XCTAssertEqual(installedVersion(app), "1.0")
        XCTAssertEqual(run.openedPaths.count, 1)
        XCTAssertEqual(try folder(app), ["Noonchi.app"])
    }

    func testCantMoveNewAppPutsOldBack() throws {
        let (update, app) = try prepared()
        let run = try runSwap(update, waitingFor: try gonePid(), failingMoves: [2])
        XCTAssertEqual(run.status, 1)
        XCTAssertEqual(installedVersion(app), "1.0")
        XCTAssertEqual(run.openedPaths.count, 1)
        XCTAssertEqual(try folder(app), ["Noonchi.app"])
    }

    /// Review finding: this path used to delete the only copy of the app.
    func testWhenRestoreAlsoFailsTheBackupIsNotDeleted() throws {
        let (update, app) = try prepared()
        let run = try runSwap(update, waitingFor: try gonePid(), failingMoves: [2, 3])
        XCTAssertEqual(run.status, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.path))
        let staging = try XCTUnwrap(try folder(app).first { $0.hasPrefix(".Noonchi-update-") })
        let backup = app.deletingLastPathComponent().appendingPathComponent(staging).appendingPathComponent("previous.app")
        XCTAssertEqual(installedVersion(backup), "1.0")
    }

    /// Review finding: this path used to leave only an app that can't run.
    func testNewAppThatWontOpenIsReplacedByTheOldOne() throws {
        let (update, app) = try prepared()
        let run = try runSwap(update, waitingFor: try gonePid(), failingOpens: 5)
        XCTAssertEqual(run.status, 1)
        XCTAssertEqual(installedVersion(app), "1.0")
        XCTAssertEqual(run.openedPaths.count, 1, "the old app opened")
        XCTAssertEqual(try folder(app), ["Noonchi.app"])
    }

    func testRefusesANewerSystemRequirement() throws {
        let app = try installed()
        let source = root.appendingPathComponent("min")
        let new = source.appendingPathComponent("New.app")
        try makeApp(at: new, version: "2.0", minimumSystem: "99.0")
        let zip2 = root.appendingPathComponent("min.zip")
        try sh("/usr/bin/ditto", "-c", "-k", "--keepParent", new.path, zip2.path)
        let hash = SHA256.hash(data: try Data(contentsOf: zip2)).map { String(format: "%02x", $0) }.joined()
        let r = try Release(githubResponse: Data(#"{"tag_name":"v2.0","html_url":"https://github.com/x","assets":[{"name":"Noonchi-2.0.zip","browser_download_url":"https://github.com/x.zip","digest":"sha256:\#(hash)"}]}"#.utf8))
        assertRefused(.requiresNewerMacOS, zip: zip2, release: r, app: app)
    }

    func testRefusesAZipWithTwoApps() throws {
        let app = try installed()
        let source = root.appendingPathComponent("two")
        try makeApp(at: source.appendingPathComponent("A.app"), version: "2.0")
        try makeApp(at: source.appendingPathComponent("B.app"), version: "2.0")
        let zip = root.appendingPathComponent("two.zip")
        try sh("/usr/bin/ditto", "-c", "-k", source.path, zip.path)
        let hash = SHA256.hash(data: try Data(contentsOf: zip)).map { String(format: "%02x", $0) }.joined()
        let r = try Release(githubResponse: Data(#"{"tag_name":"v2.0","html_url":"https://github.com/x","assets":[{"name":"Noonchi-2.0.zip","browser_download_url":"https://github.com/x.zip","digest":"sha256:\#(hash)"}]}"#.utf8))
        assertRefused(.invalidApp, zip: zip, release: r, app: app)
    }
}
