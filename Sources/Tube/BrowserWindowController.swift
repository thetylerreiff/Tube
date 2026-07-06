import AppKit
import QuartzCore

@MainActor
final class BrowserWindowController: NSWindowController {
    let browserViewController = BrowserViewController()
    private let titlebarRevealHeight: CGFloat = 34
    private let titlebarChromeLeading: CGFloat = 8
    private let titlebarChromeTopInset: CGFloat = 0
    private let titlebarChromeWidth: CGFloat = 160
    private let titlebarRevealAnimationDuration: TimeInterval = 0.18
    private let titlebarChromeView = TitlebarChromeView()
    private let titlebarDragHandle = TitlebarDragHandleView()
    private var titlebarHoverMonitor: Any?
    private var titlebarChromeShouldBeVisible = false
    private var standardWindowButtonsShouldBeVisible = false

    init() {
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

        window.title = "Tube"
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
        installTitlebarChrome(in: window)
        browserViewController.navigationStateDidChange = { [weak self] in
            self?.updateTitlebarNavigationState()
        }
        setTitlebarChromeVisible(false, animated: false)
        installTitlebarHoverMonitor(for: window)
        window.center()
        window.setFrameAutosaveName("TubeMainWindow")
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setTitlebarChromeVisible(_ isVisible: Bool, animated: Bool) {
        titlebarDragHandle.isHidden = !isVisible
        setStandardWindowButtonsVisible(isVisible, animated: animated)
        setTitlebarNavigationVisible(isVisible, animated: animated)
    }

    private func setTitlebarNavigationVisible(_ isVisible: Bool, animated: Bool) {
        guard titlebarChromeShouldBeVisible != isVisible || !animated else {
            return
        }

        titlebarChromeShouldBeVisible = isVisible

        if isVisible {
            titlebarChromeView.isHidden = false
            titlebarChromeView.alphaValue = animated ? 0 : 1
        }

        guard animated else {
            titlebarChromeView.alphaValue = isVisible ? 1 : 0
            titlebarChromeView.isHidden = !isVisible
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = titlebarRevealAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            titlebarChromeView.animator().alphaValue = isVisible ? 1 : 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, titlebarChromeShouldBeVisible == isVisible else {
                    return
                }

                titlebarChromeView.isHidden = !isVisible
            }
        }
    }

    private func setStandardWindowButtonsVisible(_ isVisible: Bool, animated: Bool) {
        guard let window else {
            return
        }

        guard standardWindowButtonsShouldBeVisible != isVisible || !animated else {
            return
        }

        standardWindowButtonsShouldBeVisible = isVisible

        let buttons = standardWindowButtons(in: window)

        if isVisible {
            buttons.forEach { button in
                button.isHidden = false
                button.alphaValue = animated ? 0 : 1
            }
        }

        guard animated else {
            buttons.forEach { button in
                button.alphaValue = isVisible ? 1 : 0
                button.isHidden = !isVisible
            }
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = titlebarRevealAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            buttons.forEach { button in
                button.animator().alphaValue = isVisible ? 1 : 0
            }
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, standardWindowButtonsShouldBeVisible == isVisible else {
                    return
                }

                standardWindowButtons(in: window).forEach { button in
                    button.isHidden = !isVisible
                }
            }
        }
    }

    private func installTitlebarHoverMonitor(for window: NSWindow) {
        titlebarHoverMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .mouseMoved,
            .leftMouseDown,
            .leftMouseDragged,
            .leftMouseUp
        ]) { [weak self, weak window] event in
            guard let self, let window, event.window === window else {
                return event
            }

            updateTitlebarButtonVisibility(for: window)
            return event
        }
    }

    private func removeTitlebarHoverMonitor() {
        guard let titlebarHoverMonitor else {
            return
        }

        NSEvent.removeMonitor(titlebarHoverMonitor)
        self.titlebarHoverMonitor = nil
    }

    private func updateTitlebarButtonVisibility(for window: NSWindow) {
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let windowBounds = NSRect(origin: .zero, size: window.frame.size)
        let revealMinY = max(windowBounds.maxY - titlebarRevealHeight, 0)
        let isHoveringTitlebar = window.isKeyWindow
            && windowBounds.contains(mouseLocation)
            && mouseLocation.y >= revealMinY

        setTitlebarChromeVisible(isHoveringTitlebar, animated: true)
    }

    private func installTitlebarChrome(in window: NSWindow) {
        guard let contentView = window.contentView else {
            return
        }

        titlebarChromeView.translatesAutoresizingMaskIntoConstraints = false
        titlebarChromeView.backAction = { [weak self] in
            self?.browserViewController.goBack()
            self?.updateTitlebarNavigationState()
        }
        titlebarChromeView.forwardAction = { [weak self] in
            self?.browserViewController.goForward()
            self?.updateTitlebarNavigationState()
        }
        titlebarChromeView.alphaValue = 0
        titlebarChromeView.isHidden = true

        titlebarDragHandle.translatesAutoresizingMaskIntoConstraints = false
        titlebarDragHandle.isHidden = true
        titlebarDragHandle.scrollTarget = { [weak self] in
            self?.browserViewController.webContentView
        }

        contentView.addSubview(titlebarDragHandle)
        contentView.addSubview(titlebarChromeView, positioned: .above, relativeTo: titlebarDragHandle)

        NSLayoutConstraint.activate([
            titlebarDragHandle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titlebarDragHandle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titlebarDragHandle.topAnchor.constraint(equalTo: contentView.topAnchor),
            titlebarDragHandle.heightAnchor.constraint(equalToConstant: titlebarRevealHeight),

            titlebarChromeView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: titlebarChromeLeading
            ),
            titlebarChromeView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: titlebarChromeTopInset
            ),
            titlebarChromeView.widthAnchor.constraint(equalToConstant: titlebarChromeWidth),
            titlebarChromeView.heightAnchor.constraint(equalToConstant: titlebarRevealHeight)
        ])

        updateTitlebarNavigationState()
    }

    private func updateTitlebarNavigationState() {
        titlebarChromeView.updateNavigationState(
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
}

extension BrowserWindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        guard let window else {
            return
        }

        updateTitlebarButtonVisibility(for: window)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window else {
            return
        }

        updateTitlebarButtonVisibility(for: window)
    }

    func windowDidResignKey(_ notification: Notification) {
        setTitlebarChromeVisible(false, animated: true)
    }

    func windowWillClose(_ notification: Notification) {
        removeTitlebarHoverMonitor()
    }
}

private final class TitlebarDragHandleView: NSView {
    var scrollTarget: (() -> NSView?)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        if event.clickCount == 2 {
            performTitlebarDoubleClickAction(on: window)
        } else {
            window.performDrag(with: event)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard let target = scrollTarget?() else {
            super.scrollWheel(with: event)
            return
        }

        target.scrollWheel(with: event)
    }

    private func performTitlebarDoubleClickAction(on window: NSWindow) {
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

private final class TitlebarChromeView: NSView {
    private let navigationLeading: CGFloat = 68
    private let navigationSpacing: CGFloat = 4
    private let buttonSize = NSSize(width: 34, height: 28)
    private let backButton: NSButton
    private let forwardButton: NSButton
    private let glassSurface: NSView
    private let glassContentView = NSView()

    var backAction: (() -> Void)?
    var forwardAction: (() -> Void)?

    override init(frame frameRect: NSRect) {
        backButton = TitlebarChromeView.makeNavigationButton(
            symbolName: "chevron.left",
            accessibilityLabel: "Back",
            tooltip: "Back"
        )
        forwardButton = TitlebarChromeView.makeNavigationButton(
            symbolName: "chevron.right",
            accessibilityLabel: "Forward",
            tooltip: "Forward"
        )
        glassSurface = TitlebarChromeView.makeGlassSurface(contentView: glassContentView)

        super.init(frame: frameRect)

        setupView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)

        switch hitView {
        case self, glassSurface, glassContentView:
            return nil
        default:
            return hitView
        }
    }

    func updateNavigationState(canGoBack: Bool, canGoForward: Bool) {
        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false

        glassSurface.translatesAutoresizingMaskIntoConstraints = false
        glassContentView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(glassSurface)
        NSLayoutConstraint.activate([
            glassSurface.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassSurface.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassSurface.topAnchor.constraint(equalTo: topAnchor),
            glassSurface.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if glassContentView.superview == nil {
            glassSurface.addSubview(glassContentView)
        }

        NSLayoutConstraint.activate([
            glassContentView.leadingAnchor.constraint(equalTo: glassSurface.leadingAnchor),
            glassContentView.trailingAnchor.constraint(equalTo: glassSurface.trailingAnchor),
            glassContentView.topAnchor.constraint(equalTo: glassSurface.topAnchor),
            glassContentView.bottomAnchor.constraint(equalTo: glassSurface.bottomAnchor)
        ])

        let stackView = NSStackView(views: [backButton, forwardButton])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillEqually
        stackView.spacing = navigationSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        backButton.target = self
        backButton.action = #selector(backButtonPressed(_:))
        forwardButton.target = self
        forwardButton.action = #selector(forwardButtonPressed(_:))

        glassContentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: glassContentView.leadingAnchor, constant: navigationLeading),
            stackView.centerYAnchor.constraint(equalTo: glassContentView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: buttonSize.width),
            backButton.heightAnchor.constraint(equalToConstant: buttonSize.height),
            forwardButton.widthAnchor.constraint(equalToConstant: buttonSize.width),
            forwardButton.heightAnchor.constraint(equalToConstant: buttonSize.height)
        ])
    }

    @objc private func backButtonPressed(_ sender: NSButton) {
        backAction?()
    }

    @objc private func forwardButtonPressed(_ sender: NSButton) {
        forwardAction?()
    }

    private static func makeNavigationButton(
        symbolName: String,
        accessibilityLabel: String,
        tooltip: String
    ) -> NSButton {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityLabel
        )?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .medium))

        let button = NSButton(image: image ?? NSImage(), target: nil, action: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = tooltip
        button.setAccessibilityLabel(accessibilityLabel)
        button.contentTintColor = NSColor.labelColor.withAlphaComponent(0.72)
        button.setButtonType(.momentaryChange)
        return button
    }

    private static func makeGlassSurface(contentView: NSView) -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = PassthroughGlassEffectView()
            glassView.cornerRadius = 17
            glassView.style = .regular
            glassView.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.08)
            glassView.contentView = contentView
            return glassView
        }

        let visualEffectView = PassthroughVisualEffectView()
        visualEffectView.material = .titlebar
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 17
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        return visualEffectView
    }
}

private final class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)
        return hitView === self ? nil : hitView
    }
}

@available(macOS 26.0, *)
private final class PassthroughGlassEffectView: NSGlassEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)
        return hitView === self ? nil : hitView
    }
}
