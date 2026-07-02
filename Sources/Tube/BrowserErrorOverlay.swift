import AppKit

@MainActor
final class BrowserErrorOverlay: NSView {
    var retryHandler: (() -> Void)?
    var openInBrowserHandler: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Connection issue")
    private let messageLabel = NSTextField(labelWithString: "YouTube could not load.")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    func updateMessage(_ message: String) {
        messageLabel.stringValue = message
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.alignment = .center

        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2

        let retryButton = NSButton(title: "Retry", target: self, action: #selector(retryTapped))
        retryButton.bezelStyle = .rounded

        let openButton = NSButton(title: "Open in Browser", target: self, action: #selector(openInBrowserTapped))
        openButton.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [retryButton, openButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 10

        let stack = NSStackView(views: [titleLabel, messageLabel, buttonStack])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14

        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            openButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])

        applyAppearance()
    }

    private func applyAppearance() {
        let appearance = effectiveAppearance
        layer?.backgroundColor = TubeAppearance.overlayBackground(for: appearance).cgColor
        layer?.borderColor = TubeAppearance.overlayBorder(for: appearance).cgColor
        titleLabel.textColor = .labelColor
        messageLabel.textColor = .secondaryLabelColor
    }

    @objc private func retryTapped() {
        retryHandler?()
    }

    @objc private func openInBrowserTapped() {
        openInBrowserHandler?()
    }
}
