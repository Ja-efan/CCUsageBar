import Foundation

public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    private let parts: [Int]

    /// Accepts "0.4.2" and "v0.4.2".
    public init?(_ text: String) {
        let trimmed = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, !parts.contains(where: { $0 == nil }) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let (x, y) = (i < a.parts.count ? a.parts[i] : 0, i < b.parts.count ? b.parts[i] : 0)
            if x != y { return x < y }
        }
        return false
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }
}

public enum UpdateFailure: Error, Equatable, Sendable {
    case network
    case unreadableRelease
    case damagedDownload
    /// The app's folder can't be written, e.g. macOS is running it from a read-only copy.
    case cannotWriteToApp
    case invalidApp
}

/// A published release, parsed from GitHub's API response.
public struct Release: Equatable, Sendable {
    public let version: AppVersion
    public let pageURL: URL
    public let assetURL: URL
    public let sha256: String

    private struct Response: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
            let digest: String?
        }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    public static func isGitHubDownload(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "github.com"
    }

    /// `allowsDownload` is the boundary check: what the app will fetch and run comes from here.
    public init(githubResponse data: Data, allowsDownload: (URL) -> Bool = Release.isGitHubDownload) throws {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              let version = AppVersion(response.tag_name),
              let asset = response.assets.first(where: { $0.name == "Noonchi-\(version).zip" }),
              allowsDownload(asset.browser_download_url),
              let digest = asset.digest, digest.hasPrefix("sha256:")
        else { throw UpdateFailure.unreadableRelease }
        self.version = version
        pageURL = response.html_url
        assetURL = asset.browser_download_url
        sha256 = String(digest.dropFirst("sha256:".count)).lowercased()
    }
}
