import AppKit

final class BezelContainerView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        false
    }
}
