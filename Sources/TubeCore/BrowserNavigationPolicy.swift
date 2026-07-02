import Foundation

public enum NavigationDecision: Equatable, Sendable {
    case allowInApp
    case openExternally
    case cancel
}

public struct BrowserNavigationPolicy: Sendable {
    private let allowedHostSuffixes: Set<String>
    private let allowedExactHosts: Set<String>
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

            return isAllowedWebHost(host) ? .allowInApp : .openExternally

        case "http":
            return .openExternally

        case "about":
            return url.absoluteString.lowercased() == "about:blank" ? .allowInApp : .cancel

        default:
            return externalSchemes.contains(scheme) ? .openExternally : .cancel
        }
    }

    private func isAllowedWebHost(_ host: String) -> Bool {
        if allowedExactHosts.contains(host) {
            return true
        }

        return allowedHostSuffixes.contains { suffix in
            host == suffix || host.hasSuffix(".\(suffix)")
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
}

