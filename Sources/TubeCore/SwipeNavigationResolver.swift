public enum SwipeNavigationDecision: Equatable, Sendable {
    case back
    case forward
    case none
}

public struct SwipeNavigationResolver: Sendable {
    private let completionThreshold: Double

    public init(completionThreshold: Double = 0.5) {
        self.completionThreshold = completionThreshold
    }

    public func decision(
        gestureAmount: Double,
        canGoBack: Bool,
        canGoForward: Bool
    ) -> SwipeNavigationDecision {
        if gestureAmount <= -completionThreshold, canGoBack {
            return .back
        }

        if gestureAmount >= completionThreshold, canGoForward {
            return .forward
        }

        return .none
    }
}
