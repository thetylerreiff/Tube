import AppKit
import TubeCore
import WebKit

@MainActor
final class TubeWebView: WKWebView {
    private let swipeNavigationResolver = SwipeNavigationResolver()
    private var isTrackingBackForwardSwipe = false

    override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        axis == .horizontal || super.wantsScrollEventsForSwipeTracking(on: axis)
    }

    override func swipe(with event: NSEvent) {
        let decision = swipeNavigationResolver.decision(
            gestureAmount: Double(event.deltaX),
            canGoBack: canGoBack,
            canGoForward: canGoForward
        )

        guard performSwipeNavigation(decision) else {
            super.swipe(with: event)
            return
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard !isTrackingBackForwardSwipe else {
            return
        }

        guard shouldTrackBackForwardSwipe(from: event) else {
            super.scrollWheel(with: event)
            return
        }

        isTrackingBackForwardSwipe = true
        event.trackSwipeEvent(
            options: .lockDirection,
            dampenAmountThresholdMin: 0.2,
            max: 0.2
        ) { [weak self] gestureAmount, _, isComplete, stop in
            guard let self else {
                stop.pointee = true
                return
            }

            guard isComplete else {
                return
            }

            self.isTrackingBackForwardSwipe = false
            let decision = self.swipeNavigationResolver.decision(
                gestureAmount: Double(gestureAmount),
                canGoBack: self.canGoBack,
                canGoForward: self.canGoForward
            )
            _ = self.performSwipeNavigation(decision)
        }
    }

    private func shouldTrackBackForwardSwipe(from event: NSEvent) -> Bool {
        guard NSEvent.isSwipeTrackingFromScrollEventsEnabled else {
            return false
        }

        guard canGoBack || canGoForward else {
            return false
        }

        guard event.phase.contains(.began) || event.phase.contains(.changed) else {
            return false
        }

        return abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
    }

    @discardableResult
    private func performSwipeNavigation(_ decision: SwipeNavigationDecision) -> Bool {
        switch decision {
        case .back:
            goBack()
            return true
        case .forward:
            goForward()
            return true
        case .none:
            return false
        }
    }
}
