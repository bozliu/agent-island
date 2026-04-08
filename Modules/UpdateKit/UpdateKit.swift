import AppKit
import Foundation

public struct UpdateConfiguration: Sendable, Hashable {
    public let repositoryOwner: String?
    public let repositoryName: String?
    public let repositoryURL: URL
    public let downloadURL: URL

    public init(
        repositoryOwner: String? = nil,
        repositoryName: String? = nil,
        repositoryURL: URL = URL(string: "https://github.com/bozliu/agent-island")!,
        downloadURL: URL = URL(string: "https://github.com/bozliu/agent-island/releases")!
    ) {
        self.repositoryOwner = repositoryOwner
        self.repositoryName = repositoryName
        self.repositoryURL = repositoryURL
        self.downloadURL = downloadURL
    }

    public var releasesURL: URL? {
        guard let repositoryOwner, let repositoryName else { return nil }
        return URL(string: "https://github.com/\(repositoryOwner)/\(repositoryName)/releases")
    }

    public var latestReleaseAPIURL: URL? {
        guard let repositoryOwner, let repositoryName else { return nil }
        return URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest")
    }

    public var preferredUpdatesURL: URL {
        releasesURL ?? downloadURL
    }

    public var issuesURL: URL {
        if let repositoryOwner, let repositoryName,
           let issuesURL = URL(string: "https://github.com/\(repositoryOwner)/\(repositoryName)/issues") {
            return issuesURL
        }
        return repositoryURL.appendingPathComponent("issues")
    }

    public static func bundled(bundle: Bundle = .main) -> UpdateConfiguration {
        let info = bundle.infoDictionary ?? [:]

        let repositoryOwner = (info["AgentIslandRepositoryOwner"] as? String) ?? (info["VibeIslandRepositoryOwner"] as? String)
        let repositoryName = (info["AgentIslandRepositoryName"] as? String) ?? (info["VibeIslandRepositoryName"] as? String)
        let repositoryURL = (
            info["AgentIslandRepositoryURL"] as? String
            ?? info["VibeIslandRepositoryURL"] as? String
        )
        .flatMap(URL.init(string:))
            ?? URL(string: "https://github.com/bozliu/agent-island")!
        let downloadURL = (info["AgentIslandDownloadURL"] as? String).flatMap(URL.init(string:))
            ?? (info["VibeIslandDownloadURL"] as? String).flatMap(URL.init(string:))
            ?? repositoryURL.appendingPathComponent("releases")

        return UpdateConfiguration(
            repositoryOwner: repositoryOwner,
            repositoryName: repositoryName,
            repositoryURL: repositoryURL,
            downloadURL: downloadURL
        )
    }
}

public struct GitHubRelease: Decodable, Sendable, Hashable {
    public let name: String
    public let tagName: String
    public let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

public final class UpdateService: @unchecked Sendable {
    private let configuration: UpdateConfiguration
    private let urlSession: URLSession

    public init(configuration: UpdateConfiguration = .bundled(), urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    public func fetchLatestRelease() async throws -> GitHubRelease {
        if let latestReleaseAPIURL = configuration.latestReleaseAPIURL {
            do {
                let (data, response) = try await urlSession.data(from: latestReleaseAPIURL)
                if let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode {
                    return try JSONDecoder().decode(GitHubRelease.self, from: data)
                }
            } catch {
                // Fall back to the verified public website in OSS builds.
            }
        }

        do {
            var request = URLRequest(url: configuration.downloadURL)
            request.httpMethod = "HEAD"
            _ = try await urlSession.data(for: request)
        } catch {
            _ = try await urlSession.data(from: configuration.repositoryURL)
        }
        return GitHubRelease(
            name: "Manual web updates",
            tagName: "manual-web",
            htmlURL: configuration.downloadURL
        )
    }

    @discardableResult
    public func openLatestReleasePage() -> Bool {
        NSWorkspace.shared.open(configuration.preferredUpdatesURL)
    }

    @discardableResult
    public func openRepositoryPage() -> Bool {
        NSWorkspace.shared.open(configuration.repositoryURL)
    }

    @discardableResult
    public func openIssuesPage() -> Bool {
        NSWorkspace.shared.open(configuration.issuesURL)
    }
}
