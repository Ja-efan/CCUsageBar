import XCTest
@testable import UsageCore

final class CodexProviderTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    /// Recorded from codex-cli 0.159.2 on a Free plan (account ID removed).
    func testFreePlanThirtyDayWindow() throws {
        let usage = try CodexProvider.usage(from: fixture("codex-free-0.159.2")).get()
        XCTAssertEqual(usage.plan, "Free")
        XCTAssertEqual(usage.windows, [
            UsageWindow(id: "30d", kind: .rolling(minutes: 43200), usedPercent: 7,
                        resetsAt: Date(timeIntervalSince1970: 1795096880)),
        ])
    }

    /// Same shape with the Pro Lite values a Codex session file recorded on 2026-10-07.
    /// The account is now on Free, so this one couldn't be recorded live.
    func testProLiteWeeklyWindow() throws {
        let usage = try CodexProvider.usage(from: fixture("codex-prolite-weekly")).get()
        XCTAssertEqual(usage.plan, "Pro Lite")
        XCTAssertEqual(usage.windows.map(\.id), ["week"])
        XCTAssertEqual(usage.windows.first?.usedPercent, 26)
        XCTAssertEqual(usage.windows.first?.kind.shortLabel, "7d")
    }

    func testPrimaryAndSecondaryWindows() throws {
        let json = """
        {"rateLimits":{"planType":"plus",
          "primary":{"usedPercent":12,"windowDurationMins":300,"resetsAt":1795000000},
          "secondary":{"usedPercent":40,"windowDurationMins":10080,"resetsAt":null}}}
        """
        let usage = try CodexProvider.usage(from: Data(json.utf8)).get()
        XCTAssertEqual(usage.windows.map(\.id), ["5h", "week"])
        XCTAssertNil(usage.windows[1].resetsAt)
    }

    func testRawOutputDropsAccountID() {
        let raw = CodexProvider.redacted(Data(#"{"accountId":"acct-123","userEmail":"a@b.c","rateLimits":{}}"#.utf8))
        XCTAssertFalse(raw.contains("acct-123"))
        XCTAssertFalse(raw.contains("a@b.c"))
        XCTAssertTrue(raw.contains("rateLimits"))
    }

    func testNoWindowsIsUnparsable() {
        let result = CodexProvider.usage(from: Data(#"{"rateLimits":{"primary":null,"secondary":null}}"#.utf8))
        guard case .failure(let f) = result else { return XCTFail() }
        XCTAssertEqual(f.error, .unparsable)
    }

    func testNotLoggedInError() {
        let e = JSONRPCError.remote(code: -32600, message: "codex account authentication required to read rate limits")
        XCTAssertEqual(ProviderError(e), .notLoggedIn)
    }

    /// Reported in issue #1 from codex-cli 0.147.0, which answers any params with this error.
    func testRequestSendsNoParams() throws {
        let dir = NSTemporaryDirectory() + "noonchi-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir); unsetenv("NOONCHI_CODEX_PATH") }
        let script = dir + "/codex"
        try #"""
        #!/bin/bash
        while read -r line; do
          id=$(printf '%s' "$line" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
          case "$line" in
            *'"initialized"'*) ;;
            *'"initialize"'*) echo "{\"id\":$id,\"result\":{}}" ;;
            *'"params"'*rateLimits*|*rateLimits*'"params"'*) echo "{\"id\":$id,\"error\":{\"code\":-32600,\"message\":\"Invalid request: invalid type: map, expected unit\"}}" ;;
            *rateLimits*) echo "{\"id\":$id,\"result\":{\"rateLimits\":{\"planType\":\"plus\",\"primary\":{\"usedPercent\":3,\"windowDurationMins\":300}}}}" ;;
          esac
        done
        """#.write(toFile: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script)
        setenv("NOONCHI_CODEX_PATH", script, 1)
        let usage = try CodexProvider(workDirectory: dir).read().get()
        XCTAssertEqual(usage.window(id: "5h")?.usedPercent, 3)
    }

    func testRollingIDs() {
        XCTAssertEqual([300, 10080, 43200, 90].map(UsageWindow.rollingID), ["5h", "week", "30d", "90m"])
    }
}
