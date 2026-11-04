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
        XCTAssertEqual(release.assetURL.lastPathComponent, "Noonchi-0.4.2.zip")
        XCTAssertEqual(release.sha256.count, 64)
    }

    private func response(url: String = "https://github.com/x/Noonchi-1.0.zip", digest: String? = "sha256:AB", name: String = "Noonchi-1.0.zip") -> Data {
        let d = digest.map { #","digest":"\#($0)""# } ?? ""
        return Data(#"{"tag_name":"v1.0","html_url":"https://github.com/x","assets":[{"name":"\#(name)","browser_download_url":"\#(url)"\#(d)}]}"#.utf8)
    }

    func testRefusesWhatItShouldNotDownload() {
        for bad in [response(url: "http://github.com/x.zip"), response(url: "https://evil.example/x.zip"),
                    response(digest: nil), response(name: "Other.zip"), Data("nope".utf8)] {
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

    private func makeApp(at url: URL, version: String, id: String? = nil, sign: Bool = true) throws {
        let macOS = url.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: macOS.appendingPathComponent("App").path)
        let info: NSDictionary = ["CFBundleIdentifier": id ?? bundleID, "CFBundleShortVersionString": version, "CFBundleExecutable": "App"]
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
        XCTAssertThrowsError(try ReleaseInstaller.prepare(zip: zip, release: release, installedApp: app, bundleID: bundleID), line: line) {
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
        XCTAssertThrowsError(try ReleaseInstaller.prepare(zip: zip, release: release, installedApp: app, bundleID: bundleID)) {
            XCTAssertEqual($0 as? UpdateFailure, .cannotWriteToApp)
        }
    }

    func testLeftoverFromAnInterruptedUpdateIsCleared() throws {
        let app = try installed()
        let stale = app.deletingLastPathComponent().appendingPathComponent(".Noonchi-update-old")
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        let (zip, release) = try makeRelease()
        _ = try ReleaseInstaller.prepare(zip: zip, release: release, installedApp: app, bundleID: bundleID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
    }

    private func swap(_ prepared: PreparedUpdate, waitFor sleeper: Process) throws -> Void {
        // `open` on a test bundle does nothing useful: point it at a harmless flag.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        let script = PreparedUpdate.swapScript.replacingOccurrences(of: #"open "$@" "$old""#, with: "true")
        p.arguments = ["-c", script, "x", String(sleeper.processIdentifier), prepared.installedApp.path, prepared.newApp.path, prepared.newApp.deletingLastPathComponent().path]
        try p.run()
        sleeper.waitUntilExit()
        p.waitUntilExit()
    }

    func testSwapReplacesAfterTheAppQuitsAndCleansUp() throws {
        let app = try installed()
        let (zip, release) = try makeRelease()
        let prepared = try ReleaseInstaller.prepare(zip: zip, release: release, installedApp: app, bundleID: bundleID)
        XCTAssertEqual(installedVersion(app), "1.0", "not swapped before the app quits")
        let sleeper = Process()
        sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleeper.arguments = ["0.3"]
        try sleeper.run()
        try swap(prepared, waitFor: sleeper)
        XCTAssertEqual(installedVersion(app), "2.0")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: app.deletingLastPathComponent().path), ["Noonchi.app"])
    }

    func testFailedSwapPutsTheOldAppBack() throws {
        let app = try installed()
        let (zip, release) = try makeRelease()
        let prepared = try ReleaseInstaller.prepare(zip: zip, release: release, installedApp: app, bundleID: bundleID)
        try FileManager.default.removeItem(at: prepared.newApp)
        let sleeper = Process()
        sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleeper.arguments = ["0.1"]
        try sleeper.run()
        try swap(prepared, waitFor: sleeper)
        XCTAssertEqual(installedVersion(app), "1.0")
    }
}
