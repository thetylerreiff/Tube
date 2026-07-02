import Testing
@testable import TubeCore

@Suite("SwipeNavigationResolver")
struct SwipeNavigationResolverTests {
    private let resolver = SwipeNavigationResolver()

    @Test("maps completed right swipe to back navigation")
    func mapsRightSwipeToBack() {
        #expect(resolver.decision(gestureAmount: -1, canGoBack: true, canGoForward: false) == .back)
    }

    @Test("maps completed left swipe to forward navigation")
    func mapsLeftSwipeToForward() {
        #expect(resolver.decision(gestureAmount: 1, canGoBack: false, canGoForward: true) == .forward)
    }

    @Test("ignores incomplete swipe")
    func ignoresIncompleteSwipe() {
        #expect(resolver.decision(gestureAmount: 0.25, canGoBack: true, canGoForward: true) == .none)
    }

    @Test("does not navigate when matching history entry is unavailable")
    func requiresAvailableHistoryEntry() {
        #expect(resolver.decision(gestureAmount: -1, canGoBack: false, canGoForward: true) == .none)
        #expect(resolver.decision(gestureAmount: 1, canGoBack: true, canGoForward: false) == .none)
    }
}
