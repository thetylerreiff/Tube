import AppKit
import TubeCore
import WebKit

@MainActor
final class BrowserViewController: NSViewController {
    private let homeURL = URL(string: "https://www.youtube.com")!
    private let signInURL = URL(
        string: "https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26hl%3Den%26next%3Dhttps%253A%252F%252Fwww.youtube.com%252F&hl=en"
    )!
    private let navigationPolicy = BrowserNavigationPolicy()
    private let webView: TubeWebView
    private let bezelView = BezelContainerView()
    private let errorOverlay = BrowserErrorOverlay()
    private let bezelInset: CGFloat = 6
    private var navigationStateObservations: [NSKeyValueObservation] = []

    var navigationStateDidChange: (() -> Void)?

    var canGoBack: Bool {
        webView.canGoBack
    }

    var canGoForward: Bool {
        webView.canGoForward
    }

    var isLoading: Bool {
        webView.isLoading
    }

    var currentURL: URL? {
        webView.url
    }

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        webView = TubeWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = TubeAppearance.dynamicWebBackground
        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        observeNavigationState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let rootView = AppearanceReportingView()
        rootView.onEffectiveAppearanceChange = { [weak self] in
            self?.applyAppearance()
        }

        view = rootView
        view.wantsLayer = true

        bezelView.translatesAutoresizingMaskIntoConstraints = false
        bezelView.wantsLayer = true
        bezelView.layer?.borderWidth = 1
        bezelView.layer?.cornerRadius = 10
        bezelView.layer?.masksToBounds = true

        webView.translatesAutoresizingMaskIntoConstraints = false

        errorOverlay.translatesAutoresizingMaskIntoConstraints = false
        errorOverlay.isHidden = true
        errorOverlay.retryHandler = { [weak self] in
            self?.loadHome()
        }
        errorOverlay.openInBrowserHandler = { [weak self] in
            self?.openCurrentPageInBrowser()
        }

        view.addSubview(bezelView)
        bezelView.addSubview(webView)
        bezelView.addSubview(errorOverlay)

        NSLayoutConstraint.activate([
            bezelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bezelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bezelView.topAnchor.constraint(equalTo: view.topAnchor),
            bezelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            webView.leadingAnchor.constraint(equalTo: bezelView.leadingAnchor, constant: bezelInset),
            webView.trailingAnchor.constraint(equalTo: bezelView.trailingAnchor, constant: -bezelInset),
            webView.topAnchor.constraint(equalTo: bezelView.topAnchor, constant: bezelInset),
            webView.bottomAnchor.constraint(equalTo: bezelView.bottomAnchor, constant: -bezelInset),

            errorOverlay.centerXAnchor.constraint(equalTo: bezelView.centerXAnchor),
            errorOverlay.centerYAnchor.constraint(equalTo: bezelView.centerYAnchor)
        ])

        applyAppearance()
    }

    func loadHome() {
        errorOverlay.isHidden = true
        webView.load(URLRequest(url: homeURL))
        notifyNavigationStateDidChange()
    }

    func goBack() {
        guard webView.canGoBack else {
            return
        }

        webView.goBack()
        notifyNavigationStateDidChange()
    }

    func goForward() {
        guard webView.canGoForward else {
            return
        }

        webView.goForward()
        notifyNavigationStateDidChange()
    }

    func reloadPage() {
        errorOverlay.isHidden = true
        webView.reload()
        notifyNavigationStateDidChange()
    }

    func stopLoading() {
        webView.stopLoading()
        notifyNavigationStateDidChange()
    }

    func openCurrentPageInBrowser() {
        NSWorkspace.shared.open(webView.url ?? homeURL)
    }

    func signInToYouTube() {
        errorOverlay.isHidden = true
        webView.load(URLRequest(url: signInURL))
        notifyNavigationStateDidChange()
    }

    func resetSession() {
        let alert = NSAlert()
        alert.messageText = "Reset YouTube session?"
        alert.informativeText = "This clears Tube's YouTube website data and reloads YouTube."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        webView.stopLoading()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(
            ofTypes: dataTypes,
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { [weak self] in
            self?.loadHome()
        }
    }

    private func openExternally(_ url: URL?) {
        guard let url else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func observeNavigationState() {
        navigationStateObservations = [
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.notifyNavigationStateDidChange()
                }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.notifyNavigationStateDidChange()
                }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.notifyNavigationStateDidChange()
                }
            }
        ]
    }

    private func notifyNavigationStateDidChange() {
        navigationStateDidChange?()
    }

    private func showError(_ error: Error) {
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else {
            return
        }

        errorOverlay.updateMessage(nsError.localizedDescription)
        errorOverlay.isHidden = false
    }

    private func applyAppearance() {
        guard isViewLoaded else {
            return
        }

        let appearance = view.effectiveAppearance
        view.layer?.backgroundColor = TubeAppearance.windowBackground(for: appearance).cgColor
        bezelView.layer?.backgroundColor = TubeAppearance.windowBackground(for: appearance).cgColor
        bezelView.layer?.borderColor = TubeAppearance.bezelBorder(for: appearance).cgColor
        webView.underPageBackgroundColor = TubeAppearance.webBackground(for: appearance)
    }
}

private final class AppearanceReportingView: NSView {
    var onEffectiveAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onEffectiveAppearanceChange?()
    }
}

extension BrowserViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

        switch navigationPolicy.decision(for: navigationAction.request.url, isMainFrame: isMainFrame) {
        case .allowInApp:
            decisionHandler(.allow)
        case .openExternally:
            openExternally(navigationAction.request.url)
            decisionHandler(.cancel)
        case .cancel:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorOverlay.isHidden = true
        notifyNavigationStateDidChange()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorOverlay.isHidden = true
        notifyNavigationStateDidChange()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error)
        notifyNavigationStateDidChange()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error)
        notifyNavigationStateDidChange()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
        notifyNavigationStateDidChange()
    }
}

extension BrowserViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else {
            return nil
        }

        switch navigationPolicy.decision(for: navigationAction.request.url, isMainFrame: true) {
        case .allowInApp:
            webView.load(navigationAction.request)
        case .openExternally:
            openExternally(navigationAction.request.url)
        case .cancel:
            break
        }

        return nil
    }
}
