import Foundation
import Testing
@testable import TubeCore

@Suite("BrowserNavigationPolicy")
struct BrowserNavigationPolicyTests {
    private let policy = BrowserNavigationPolicy()

    @Test("opens YouTube host internally")
    func youtubeHostOpensInternally() {
        #expect(policy.decision(for: URL(string: "https://www.youtube.com"), isMainFrame: true) == .allowInApp)
    }

    @Test("opens YouTube short links internally")
    func youtubeShortLinksOpenInternally() {
        #expect(policy.decision(for: URL(string: "https://youtu.be/dQw4w9WgXcQ"), isMainFrame: true) == .allowInApp)
    }

    @Test("opens YouTube subdomains internally")
    func youtubeSubdomainsOpenInternally() {
        #expect(policy.decision(for: URL(string: "https://music.youtube.com"), isMainFrame: true) == .allowInApp)
    }

    @Test("opens Google account sign-in internally")
    func googleAccountSignInOpensInternally() {
        #expect(policy.decision(for: URL(string: "https://accounts.google.com/signin/v2"), isMainFrame: true) == .allowInApp)
    }

    @Test("opens YouTube sign-in internally")
    func youtubeSignInOpensInternally() {
        let url = URL(string: "https://www.youtube.com/signin?action_handle_signin=true&app=desktop&next=https%3A%2F%2Fwww.youtube.com%2F")
        #expect(policy.decision(for: url, isMainFrame: true) == .allowInApp)
    }

    @Test("opens Google ServiceLogin flow internally")
    func googleServiceLoginFlowOpensInternally() {
        let url = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2F")
        #expect(policy.decision(for: url, isMainFrame: true) == .allowInApp)
    }

    @Test("opens unrelated web destinations externally")
    func unrelatedWebDestinationsOpenExternally() {
        #expect(policy.decision(for: URL(string: "https://example.com"), isMainFrame: true) == .openExternally)
    }

    @Test("opens mail links externally")
    func mailLinksOpenExternally() {
        #expect(policy.decision(for: URL(string: "mailto:hello@example.com"), isMainFrame: true) == .openExternally)
    }

    @Test("cancels invalid URLs")
    func invalidURLsCancelSafely() {
        #expect(policy.decision(for: nil, isMainFrame: true) == .cancel)
    }

    @Test("allows subframe navigations by default")
    func subframeNavigationsAreAllowed() {
        #expect(policy.decision(for: URL(string: "https://example.com/ad-frame"), isMainFrame: false) == .allowInApp)
    }

    @Test("does not treat lookalike domains as YouTube")
    func lookalikeDomainsOpenExternally() {
        #expect(policy.decision(for: URL(string: "https://youtube.com.evil.example"), isMainFrame: true) == .openExternally)
        #expect(policy.decision(for: URL(string: "https://notyoutube.com"), isMainFrame: true) == .openExternally)
    }

    @Test("cancels script-like main-frame schemes")
    func scriptLikeSchemesCancel() {
        #expect(policy.decision(for: URL(string: "javascript:alert(1)"), isMainFrame: true) == .cancel)
        #expect(policy.decision(for: URL(string: "data:text/html,hello"), isMainFrame: true) == .cancel)
    }
}
