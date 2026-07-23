import Foundation

public enum StreamingService: String, CaseIterable, Codable, Sendable {
    case youtube
    case youtubeTV
    case netflix
    case appleTV
    case hulu
    case twitch
    case audible

    public static let defaultService: StreamingService = .youtube

    public var displayName: String {
        switch self {
        case .youtube:
            "YouTube"
        case .youtubeTV:
            "YouTube TV"
        case .netflix:
            "Netflix"
        case .appleTV:
            "Apple TV"
        case .hulu:
            "Hulu"
        case .twitch:
            "Twitch"
        case .audible:
            "Audible"
        }
    }

    public var homeURL: URL {
        switch self {
        case .youtube:
            Self.url("https://www.youtube.com/")
        case .youtubeTV:
            Self.url("https://tv.youtube.com/")
        case .netflix:
            Self.url("https://www.netflix.com/")
        case .appleTV:
            Self.url("https://tv.apple.com/")
        case .hulu:
            Self.url("https://www.hulu.com/welcome")
        case .twitch:
            Self.url("https://www.twitch.tv/")
        case .audible:
            Self.url("https://www.audible.com/library/titles")
        }
    }

    public var signInURL: URL {
        switch self {
        case .youtube:
            Self.url(
                "https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26hl%3Den%26next%3Dhttps%253A%252F%252Fwww.youtube.com%252F&hl=en"
            )
        case .youtubeTV:
            Self.url("https://tv.youtube.com/")
        case .netflix:
            Self.url("https://www.netflix.com/login")
        case .appleTV:
            Self.url("https://tv.apple.com/login")
        case .hulu:
            Self.url("https://auth.hulu.com/login")
        case .twitch:
            Self.url("https://www.twitch.tv/login")
        case .audible:
            Self.url("https://www.audible.com/sign-in")
        }
    }

    public var navigationPolicy: BrowserNavigationPolicy {
        BrowserNavigationPolicy(
            allowedHostSuffixes: allowedHostSuffixes,
            allowedExactHosts: allowedExactHosts,
            allowedPathPrefixesByExactHost: allowedPathPrefixesByExactHost
        )
    }

    public var websiteDataHostSuffixes: Set<String> {
        switch self {
        case .youtube, .youtubeTV:
            ["youtube.com", "google.com"]
        case .netflix:
            ["netflix.com"]
        case .appleTV:
            ["apple.com"]
        case .hulu:
            ["hulu.com"]
        case .twitch:
            ["twitch.tv"]
        case .audible:
            ["audible.com", "amazon.com"]
        }
    }

    public func ownsWebsiteDataRecord(named displayName: String) -> Bool {
        let normalizedName = displayName
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        return websiteDataHostSuffixes.contains { suffix in
            normalizedName == suffix || normalizedName.hasSuffix(".\(suffix)")
        }
    }

    private var allowedHostSuffixes: Set<String> {
        switch self {
        case .youtube, .youtubeTV:
            ["youtube.com", "youtube-nocookie.com"]
        case .netflix:
            ["netflix.com"]
        case .appleTV:
            []
        case .hulu:
            ["hulu.com"]
        case .twitch:
            ["twitch.tv"]
        case .audible:
            ["audible.com"]
        }
    }

    private var allowedExactHosts: Set<String> {
        switch self {
        case .youtube, .youtubeTV:
            [
                "youtu.be",
                "accounts.google.com",
                "myaccount.google.com",
                "consent.google.com",
                "google.com",
                "www.google.com"
            ]
        case .netflix:
            []
        case .appleTV:
            [
                "tv.apple.com",
                "idmsa.apple.com"
            ]
        case .hulu:
            []
        case .twitch:
            []
        case .audible:
            []
        }
    }

    private var allowedPathPrefixesByExactHost: [String: Set<String>] {
        switch self {
        case .audible:
            [
                "amazon.com": ["/ap"],
                "www.amazon.com": ["/ap"]
            ]
        default:
            [:]
        }
    }

    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid built-in streaming service URL: \(string)")
        }

        return url
    }
}
