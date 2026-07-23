import Foundation

public struct AppVersion: Comparable, Sendable {
    private let components: [Int]

    public init?(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" {
            value.removeFirst()
        }

        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
        else {
            return nil
        }

        let parsedComponents = parts.compactMap { Int($0) }
        guard parsedComponents.count == parts.count else {
            return nil
        }

        var normalizedComponents = parsedComponents
        while normalizedComponents.count > 1 && normalizedComponents.last == 0 {
            normalizedComponents.removeLast()
        }
        components = normalizedComponents
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let componentCount = max(lhs.components.count, rhs.components.count)

        for index in 0..<componentCount {
            let lhsComponent = index < lhs.components.count ? lhs.components[index] : 0
            let rhsComponent = index < rhs.components.count ? rhs.components[index] : 0

            if lhsComponent != rhsComponent {
                return lhsComponent < rhsComponent
            }
        }

        return false
    }
}

public struct GitHubRelease: Decodable, Equatable, Sendable {
    public let tagName: String
    public let pageURL: URL
    public let version: AppVersion

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case pageURL = "html_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tagName = try container.decode(String.self, forKey: .tagName)
        let pageURL = try container.decode(URL.self, forKey: .pageURL)

        guard let version = AppVersion(tagName) else {
            throw DecodingError.dataCorruptedError(
                forKey: .tagName,
                in: container,
                debugDescription: "The release tag is not a numeric version."
            )
        }
        guard pageURL.scheme == "https",
              pageURL.host?.lowercased() == "github.com",
              pageURL.path.hasPrefix("/thetylerreiff/Tube/releases/")
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .pageURL,
                in: container,
                debugDescription: "The release page must be a Tube GitHub Releases URL."
            )
        }

        self.tagName = tagName
        self.pageURL = pageURL
        self.version = version
    }
}

public enum UpdateDiscoveryDecision: Equatable, Sendable {
    case updateAvailable(GitHubRelease)
    case upToDate
    case invalidInstalledVersion
}

public enum UpdateDiscovery {
    public static func decision(
        installedVersion: String,
        latestRelease: GitHubRelease
    ) -> UpdateDiscoveryDecision {
        guard let installedVersion = AppVersion(installedVersion) else {
            return .invalidInstalledVersion
        }

        return installedVersion < latestRelease.version
            ? .updateAvailable(latestRelease)
            : .upToDate
    }
}

public enum AutomaticUpdateCheckSchedule {
    public static let interval: TimeInterval = 24 * 60 * 60

    public static func isDue(lastAttempt: Date?, now: Date) -> Bool {
        guard let lastAttempt else {
            return true
        }

        let elapsed = now.timeIntervalSince(lastAttempt)
        return elapsed < 0 || elapsed >= interval
    }
}

public enum GitHubReleaseClientError: Error, Sendable {
    case invalidResponse
    case unsuccessfulStatusCode(Int)
}

public struct GitHubReleaseClient: Sendable {
    public static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/thetylerreiff/Tube/releases/latest"
    )!

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Tube-macOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubReleaseClientError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw GitHubReleaseClientError.unsuccessfulStatusCode(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
}
