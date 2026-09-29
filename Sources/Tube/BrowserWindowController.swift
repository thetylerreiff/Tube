import AppKit
import QuartzCore
import TubeCore

@MainActor
final class BrowserWindowController: NSWindowController {
    let browserViewController: BrowserViewController
    var onWindowWillClose: (() -> Void)?
    private let revealZoneHeight: CGFloat = 34
    private let revealDelay: Duration = .milliseconds(150)
    private let hideDelay: Duration = .milliseconds(350)
    private let showAnimationDuration: TimeInterval = 0.14
    private let hideAnimationDuration: TimeInterval = 0.18
    private let revealSlideDistance: CGFloat = 2
    private let chromeIsland = ChromeIslandView()
    private let revealZone = RevealZoneView()
    private var pendingVisibilityChange: Task<Void, Never>?
    private var chromeShouldBeVisible = false
    private var isFullScreen = false

    init() {
        let browserViewController = BrowserViewController()
        self.browserViewController = browserViewController

        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.title = "Tube — \(browserViewController.selectedService.displayName)"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.backgroundColor = TubeAppearance.dynamicWindowBackground
        window.minSize = NSSize(width: 920, height: 560)
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.contentViewController = browserViewController

        super.init(window: window)
        window.delegate = self
        browserViewController.windowCornerRadius = Self.cornerRadius(of: window)
        installChrome(in: window)
        browserViewController.navigationStateDidChange = { [weak self] in
            self?.updateNavigationState()
        }
        browserViewController.serviceDidChange = { [weak self] service in
            self?.window?.title = "Tube — \(service.displayName)"
        }
        setChromeVisible(false, animated: false)
        window.center()
        window.setFrameAutosaveName("TubeMainWindow")
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func installChrome(in window: NSWindow) {
        guard let contentView = window.contentView else {
            return
        }

        revealZone.frame = NSRect(
            x: 0,
            y: contentView.bounds.maxY - revealZoneHeight,
            width: contentView.bounds.width,
            height: revealZoneHeight
        )
        revealZone.autoresizingMask = [.width, .minYMargin]
        revealZone.onHoverChange = { [weak self] isHovering in
            self?.scheduleChromeVisibility(isHovering)
        }

        chromeIsland.autoresizingMask = [.maxXMargin, .minYMargin]
        chromeIsland.backAction = { [weak self] in
            self?.browserViewController.goBack()
            self?.updateNavigationState()
        }
        chromeIsland.forwardAction = { [weak self] in
            self?.browserViewController.goForward()
            self?.updateNavigationState()
        }

        contentView.addSubview(revealZone)
        contentView.addSubview(chromeIsland, positioned: .above, relativeTo: revealZone)

        layoutChromeIsland()
        updateNavigationState()
    }

    /// Wraps the island around the traffic lights, which AppKit positions and we can't move.
    private func layoutChromeIsland() {
        guard
            let window,
            let contentView = window.contentView,
            let closeButton = window.standardWindowButton(.closeButton),
            let zoomButton = window.standardWindowButton(.zoomButton)
        else {
            return
        }

        let trafficLights = closeButton.convert(closeButton.bounds, to: contentView)
            .union(zoomButton.convert(zoomButton.bounds, to: contentView))
        chromeIsland.layout(aroundTrafficLights: trafficLights, in: contentView.bounds)
    }

    private func scheduleChromeVisibility(_ isVisible: Bool) {
        pendingVisibilityChange?.cancel()

        guard !isFullScreen, isVisible != chromeShouldBeVisible else {
            return
        }

        let delay = isVisible ? revealDelay : hideDelay
        pendingVisibilityChange = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else {
                return
            }

            setChromeVisible(isVisible, animated: true)
        }
    }

    private func setChromeVisible(_ isVisible: Bool, animated: Bool) {
        guard let window else {
            return
        }

        chromeShouldBeVisible = isVisible
        let buttons = standardWindowButtons(in: window)

        if isVisible {
            layoutChromeIsland()
            chromeIsland.isHidden = false
            buttons.forEach { $0.isHidden = false }
        }

        let restingOrigin = chromeIsland.restingOrigin
        let hiddenOrigin = NSPoint(x: restingOrigin.x, y: restingOrigin.y + revealSlideDistance)

        guard animated else {
            chromeIsland.setFrameOrigin(isVisible ? restingOrigin : hiddenOrigin)
            chromeIsland.alphaValue = isVisible ? 1 : 0
            chromeIsland.isHidden = !isVisible
            buttons.forEach { button in
                button.alphaValue = isVisible ? 1 : 0
                button.isHidden = !isVisible
            }
            return
        }

        if isVisible {
            chromeIsland.setFrameOrigin(hiddenOrigin)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = isVisible ? showAnimationDuration : hideAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: isVisible ? .easeOut : .easeIn)
            context.allowsImplicitAnimation = true
            chromeIsland.animator().alphaValue = isVisible ? 1 : 0
            chromeIsland.animator().setFrameOrigin(isVisible ? restingOrigin : hiddenOrigin)
            buttons.forEach { $0.animator().alphaValue = isVisible ? 1 : 0 }
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, chromeShouldBeVisible == isVisible, !isFullScreen else {
                    return
                }

                chromeIsland.isHidden = !isVisible
                standardWindowButtons(in: window).forEach { $0.isHidden = !isVisible }
            }
        }
    }

    private func updateNavigationState() {
        chromeIsland.updateNavigationState(
            canGoBack: browserViewController.canGoBack,
            canGoForward: browserViewController.canGoForward
        )
    }

    private func standardWindowButtons(in window: NSWindow) -> [NSButton] {
        [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ].compactMap { $0 }
    }

    private static func cornerRadius(of window: NSWindow) -> CGFloat {
        if let frameRadius = window.contentView?.superview?.layer?.cornerRadius, frameRadius > 0 {
            return frameRadius
        }

        if #available(macOS 26.0, *) {
            return 16
        }

        return 10
    }
}

extension BrowserWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        guard !isFullScreen else {
            return
        }

        // Tracking areas don't report an enter when the window becomes key under a resting cursor.
        scheduleChromeVisibility(revealZone.containsMouse)
    }

    func windowDidResignKey(_ notification: Notification) {
        pendingVisibilityChange?.cancel()
        guard !isFullScreen else {
            return
        }

        setChromeVisible(false, animated: true)
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        pendingVisibilityChange?.cancel()
        setChromeVisible(false, animated: false)
        isFullScreen = true

        // In fullscreen the system reveals the titlebar itself, so the traffic lights must stay visible.
        if let window {
            standardWindowButtons(in: window).forEach { button in
                button.isHidden = false
                button.alphaValue = 1
            }
        }

        browserViewController.setFramed(false)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        isFullScreen = false
        browserViewController.setFramed(true)
        setChromeVisible(false, animated: false)
        scheduleChromeVisibility(revealZone.containsMouse)
    }

    func windowWillClose(_ notification: Notification) {
        pendingVisibilityChange?.cancel()
        onWindowWillClose?()
    }
}

/// Watches the top band of the window without taking clicks or scrolls away from the page.
private final class RevealZoneView: NSView {
    var onHoverChange: ((Bool) -> Void)?

    var containsMouse: Bool {
        guard let window else {
            return false
        }

        let location = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return bounds.contains(location)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }
}

/// A tab that grows out of the bezel's top-left corner, holding the traffic lights and back/forward.
/// Its background drags the window.
private final class ChromeIslandView: NSView {
    private let cornerRadius: CGFloat = 10
    private let trafficLightGap: CGFloat = 8
    private let trailingPadding: CGFloat = 6
    private let buttonSpacing: CGFloat = 2
    private let buttonSize = NSSize(width: 26, height: 22)
    private let backButton = NavigationButton(symbolName: "chevron.left", label: "Back")
    private let forwardButton = NavigationButton(symbolName: "chevron.right", label: "Forward")

    var backAction: (() -> Void)?
    var forwardAction: (() -> Void)?
    private(set) var restingOrigin: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.maskedCorners = [.layerMaxXMinYCorner]
        layer?.borderWidth = 1

        backButton.target = self
        backButton.action = #selector(backPressed)
        forwardButton.target = self
        forwardButton.action = #selector(forwardPressed)
        addSubview(backButton)
        addSubview(forwardButton)
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Sits flush with the window's top and left edges; the extra point on each hides the hairline there.
    func layout(aroundTrafficLights trafficLights: NSRect, in bounds: NSRect) {
        let height = ((bounds.maxY - trafficLights.midY) * 2).rounded() + 1
        let backX = trafficLights.maxX + trafficLightGap + 1
        let width = backX + buttonSize.width * 2 + buttonSpacing + trailingPadding
        restingOrigin = NSPoint(x: bounds.minX - 1, y: bounds.maxY + 1 - height)
        frame = NSRect(origin: restingOrigin, size: NSSize(width: width, height: height))

        let buttonY = (trafficLights.midY - restingOrigin.y - buttonSize.height / 2).rounded()
        backButton.frame = NSRect(origin: NSPoint(x: backX, y: buttonY), size: buttonSize)
        forwardButton.frame = NSRect(
            origin: NSPoint(x: backX + buttonSize.width + buttonSpacing, y: buttonY),
            size: buttonSize
        )
    }

    func updateNavigationState(canGoBack: Bool, canGoForward: Bool) {
        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        if event.clickCount == 2 {
            Self.performTitlebarDoubleClickAction(on: window)
        } else {
            window.performDrag(with: event)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func applyAppearance() {
        let appearance = effectiveAppearance
        layer?.backgroundColor = TubeAppearance.windowBackground(for: appearance).cgColor
        layer?.borderColor = TubeAppearance.hairline(for: appearance).cgColor
    }

    @objc private func backPressed() {
        backAction?()
    }

    @objc private func forwardPressed() {
        forwardAction?()
    }

    private static func performTitlebarDoubleClickAction(on window: NSWindow) {
        switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
        case "Minimize":
            window.performMiniaturize(nil)
        case "None":
            break
        default:
            // "Maximize" and "Fill" have no public API distinction; zoom covers both.
            window.performZoom(nil)
        }
    }
}

private final class NavigationButton: NSButton {
    private var isHovering = false
    private var isPressing = false

    init(symbolName: String, label: String) {
        super.init(frame: .zero)

        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleNone
        toolTip = label
        setAccessibilityLabel(label)
        setButtonType(.momentaryChange)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isEnabled: Bool {
        didSet {
            updateAppearance()
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        isPressing = true
        updateAppearance()
        // Runs the button's tracking loop until mouse up.
        super.mouseDown(with: event)
        isPressing = false
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let showsFill = isEnabled && (isHovering || isPressing)
        layer?.backgroundColor = showsFill
            ? TubeAppearance.controlFill(for: effectiveAppearance, pressed: isPressing).cgColor
            : nil
        contentTintColor = NSColor.labelColor.withAlphaComponent(isEnabled ? 0.75 : 0.30)
    }
}
