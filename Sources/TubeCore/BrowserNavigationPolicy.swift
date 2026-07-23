import Foundation

public enum NavigationDecision: Equatable, Sendable {
    case allowInApp
    case openExternally
    case cancel
}

public struct BrowserNavigationPolicy: Sendable {
    private let allowedHostSuffixes: Set<String>
    private let allowedExactHosts: Set<String>
    private let allowedPathPrefixesByExactHost: [String: Set<String>]
    private let externalSchemes: Set<String>

    public init(
        allowedHostSuffixes: Set<String> = [
            "youtube.com",
            "youtube-nocookie.com"
        ],
        allowedExactHosts: Set<String> = [
            "youtu.be",
            "accounts.google.com",
            "myaccount.google.com",
            "consent.google.com",
            "google.com",
            "www.google.com"
        ],
        allowedPathPrefixesByExactHost: [String: Set<String>] = [:],
        externalSchemes: Set<String> = [
            "facetime",
            "facetime-audio",
            "mailto",
            "sms",
            "tel"
        ]
    ) {
        self.allowedHostSuffixes = Set(allowedHostSuffixes.map(Self.normalizeHost))
        self.allowedExactHosts = Set(allowedExactHosts.map(Self.normalizeHost))
        self.allowedPathPrefixesByExactHost = allowedPathPrefixesByExactHost.reduce(into: [:]) {
            normalizedRules, rule in
            normalizedRules[Self.normalizeHost(rule.key), default: []]
                .formUnion(rule.value.map(Self.normalizePathPrefix))
        }
        self.externalSchemes = Set(externalSchemes.map { $0.lowercased() })
    }

    public func decision(for url: URL?, isMainFrame: Bool) -> NavigationDecision {
        guard let url else {
            return .cancel
        }

        if !isMainFrame {
            return .allowInApp
        }

        guard let scheme = url.scheme?.lowercased() else {
            return .cancel
        }

        switch scheme {
        case "https":
            guard let host = normalizedHost(for: url) else {
                return .cancel
            }

            return isAllowedWebURL(url, host: host) ? .allowInApp : .openExternally

        case "http":
            return .openExternally

        case "about":
            return url.absoluteString.lowercased() == "about:blank" ? .allowInApp : .cancel

        default:
            return externalSchemes.contains(scheme) ? .openExternally : .cancel
        }
    }

    private func isAllowedWebURL(_ url: URL, host: String) -> Bool {
        if allowedExactHosts.contains(host) {
            return true
        }

        if allowedHostSuffixes.contains(where: { suffix in
            host == suffix || host.hasSuffix(".\(suffix)")
        }) {
            return true
        }

        guard let allowedPathPrefixes = allowedPathPrefixesByExactHost[host] else {
            return false
        }

        return allowedPathPrefixes.contains { prefix in
            url.path == prefix || url.path.hasPrefix("\(prefix)/")
        }
    }

    private func normalizedHost(for url: URL) -> String? {
        guard let host = url.host else {
            return nil
        }

        return Self.normalizeHost(host)
    }

    private static func normalizeHost(_ host: String) -> String {
        host
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }

    private static func normalizePathPrefix(_ pathPrefix: String) -> String {
        let prefixedPath = pathPrefix.hasPrefix("/") ? pathPrefix : "/\(pathPrefix)"

        if prefixedPath.count > 1, prefixedPath.hasSuffix("/") {
            return String(prefixedPath.dropLast())
        }

        return prefixedPath
    }
}
