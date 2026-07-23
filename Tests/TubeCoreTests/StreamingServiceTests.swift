import Foundation
import Testing
@testable import TubeCore

@Suite("StreamingService")
struct StreamingServiceTests {
    @Test("defines the supported services in switcher order")
    func definesSupportedServices() {
        #expect(StreamingService.allCases == [
            .youtube,
            .youtubeTV,
            .netflix,
            .appleTV,
            .hulu,
            .twitch,
            .audible
        ])
    }

    @Test("allows each service home and sign-in URLs in its own policy", arguments: StreamingService.allCases)
    func allowsServiceDestinations(service: StreamingService) {
        let policy = service.navigationPolicy

        #expect(policy.decision(for: service.homeURL, isMainFrame: true) == .allowInApp)
        #expect(policy.decision(for: service.signInURL, isMainFrame: true) == .allowInApp)
    }

    @Test("keeps unrelated service destinations outside the active service", arguments: [
        (StreamingService.youtube, StreamingService.netflix),
        (StreamingService.netflix, StreamingService.appleTV),
        (StreamingService.appleTV, StreamingService.hulu),
        (StreamingService.hulu, StreamingService.twitch),
        (StreamingService.twitch, StreamingService.audible),
        (StreamingService.audible, StreamingService.youtube)
    ])
    func isolatesServicePolicies(activeService: StreamingService, unrelatedService: StreamingService) {
        #expect(
            activeService.navigationPolicy.decision(
                for: unrelatedService.homeURL,
                isMainFrame: true
            ) == .openExternally
        )
    }

    @Test("allows Apple account authentication without allowing arbitrary Apple pages")
    func scopesAppleAccountAuthentication() {
        let policy = StreamingService.appleTV.navigationPolicy

        #expect(
            policy.decision(
                for: URL(string: "https://idmsa.apple.com/appleauth/auth/signin"),
                isMainFrame: true
            ) == .allowInApp
        )
        #expect(
            policy.decision(
                for: URL(string: "https://www.apple.com/mac/"),
                isMainFrame: true
            ) == .openExternally
        )
    }

    @Test("allows Hulu authentication within the Hulu boundary")
    func allowsHuluAuthentication() {
        #expect(
            StreamingService.hulu.navigationPolicy.decision(
                for: URL(string: "https://auth.hulu.com/login"),
                isMainFrame: true
            ) == .allowInApp
        )
    }

    @Test("allows Audible Amazon authentication without allowing arbitrary Amazon pages")
    func scopesAudibleAmazonAuthentication() {
        let policy = StreamingService.audible.navigationPolicy

        #expect(
            policy.decision(
                for: URL(string: "https://www.amazon.com/ap/signin"),
                isMainFrame: true
            ) == .allowInApp
        )
        #expect(
            policy.decision(
                for: URL(string: "https://www.amazon.com/ap/mfa"),
                isMainFrame: true
            ) == .allowInApp
        )
        #expect(
            policy.decision(
                for: URL(string: "https://amazon.com/ap/signin"),
                isMainFrame: true
            ) == .allowInApp
        )
        #expect(
            policy.decision(
                for: URL(string: "https://www.amazon.com/appliances"),
                isMainFrame: true
            ) == .openExternally
        )
        #expect(
            policy.decision(
                for: URL(string: "https://www.amazon.com/gp/product/example"),
                isMainFrame: true
            ) == .openExternally
        )
    }

    @Test("matches only website data owned by the active service")
    func matchesOwnedWebsiteData() {
        #expect(StreamingService.netflix.ownsWebsiteDataRecord(named: "www.netflix.com"))
        #expect(StreamingService.netflix.ownsWebsiteDataRecord(named: ".NETFLIX.COM."))
        #expect(!StreamingService.netflix.ownsWebsiteDataRecord(named: "notnetflix.com"))
        #expect(!StreamingService.netflix.ownsWebsiteDataRecord(named: "youtube.com"))
        #expect(StreamingService.audible.ownsWebsiteDataRecord(named: "www.amazon.com"))
        #expect(!StreamingService.audible.ownsWebsiteDataRecord(named: "notamazon.com"))
    }

    @Test("shares Google website data between YouTube services")
    func sharesGoogleWebsiteData() {
        #expect(StreamingService.youtube.ownsWebsiteDataRecord(named: "accounts.google.com"))
        #expect(StreamingService.youtubeTV.ownsWebsiteDataRecord(named: "www.youtube.com"))
    }
}
