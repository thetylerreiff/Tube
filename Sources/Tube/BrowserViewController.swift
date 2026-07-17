import AppKit
import TubeCore
import WebKit

@MainActor
final class BrowserViewController: NSViewController {
    private static let selectedServiceDefaultsKey = "SelectedStreamingService"

    private var webView: TubeWebView
    private let bezelView = BezelContainerView()
    private let errorOverlay = BrowserErrorOverlay()
    private let bezelInset: CGFloat = 6
    private var navigationStateObservations: [NSKeyValueObservation] = []

    var navigationStateDidChange: (() -> Void)?
    var serviceDidChange: ((StreamingService) -> Void)?

    private(set) var selectedService: StreamingService

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

    var webContentView: NSView {
        webView
    }

    init() {
        let savedService = UserDefaults.standard.string(
            forKey: Self.selectedServiceDefaultsKey
        ).flatMap(StreamingService.init(rawValue:))

        selectedService = savedService ?? .defaultService
        webView = Self.makeWebView(for: selectedService)
        super.init(nibName: nil, bundle: nil)
        configureWebView(webView)
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

        errorOverlay.translatesAutoresizingMaskIntoConstraints = false
        errorOverlay.isHidden = true
        errorOverlay.retryHandler = { [weak self] in
            self?.loadHome()
        }
        errorOverlay.openInBrowserHandler = { [weak self] in
            self?.openCurrentPageInBrowser()
        }

        view.addSubview(bezelView)
        installWebView(webView)
        bezelView.addSubview(errorOverlay)

        NSLayoutConstraint.activate([
            bezelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bezelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bezelView.topAnchor.constraint(equalTo: view.topAnchor),
            bezelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            errorOverlay.centerXAnchor.constraint(equalTo: bezelView.centerXAnchor),
            errorOverlay.centerYAnchor.constraint(equalTo: bezelView.centerYAnchor)
        ])

        applyAppearance()
    }

    func loadHome() {
        errorOverlay.isHidden = true
        webView.load(URLRequest(url: selectedService.homeURL))
        notifyNavigationStateDidChange()
    }

    func switchService(to service: StreamingService) {
        guard selectedService != service else {
            return
        }

        selectedService = service
        UserDefaults.standard.set(service.rawValue, forKey: Self.selectedServiceDefaultsKey)
        replaceWebView()
        loadHome()
        serviceDidChange?(service)
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
        NSWorkspace.shared.open(webView.url ?? selectedService.homeURL)
    }

    func signIn() {
        errorOverlay.isHidden = true
        webView.load(URLRequest(url: selectedService.signInURL))
        notifyNavigationStateDidChange()
    }

    func resetSession() {
        let service = selectedService
        let alert = NSAlert()
        alert.messageText = "Reset \(service.displayName) session?"
        alert.informativeText = resetSessionMessage(for: service)
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        webView.stopLoading()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: dataTypes) { [weak self] records in
            let matchingRecords = records.filter { record in
                service.ownsWebsiteDataRecord(named: record.displayName)
            }

            dataStore.removeData(ofTypes: dataTypes, for: matchingRecords) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, selectedService == service else {
                        return
                    }

                    replaceWebView()
                    loadHome()
                }
            }
        }
    }

    private static func makeWebView(for service: StreamingService) -> TubeWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        if service != .youtube {
            configuration.applicationNameForUserAgent = safariUserAgentSuffix
        }

        return TubeWebView(frame: .zero, configuration: configuration)
    }

    private static var safariUserAgentSuffix: String {
        let safariVersion = Bundle(path: "/Applications/Safari.app")?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "18.0"
        return "Version/\(safariVersion) Safari/605.1.15"
    }

    private func configureWebView(_ webView: TubeWebView) {
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = TubeAppearance.dynamicWebBackground
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    private func installWebView(_ webView: TubeWebView) {
        webView.translatesAutoresizingMaskIntoConstraints = false

        if errorOverlay.superview === bezelView {
            bezelView.addSubview(webView, positioned: .below, relativeTo: errorOverlay)
        } else {
            bezelView.addSubview(webView)
        }

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: bezelView.leadingAnchor, constant: bezelInset),
            webView.trailingAnchor.constraint(equalTo: bezelView.trailingAnchor, constant: -bezelInset),
            webView.topAnchor.constraint(equalTo: bezelView.topAnchor, constant: bezelInset),
            webView.bottomAnchor.constraint(equalTo: bezelView.bottomAnchor, constant: -bezelInset)
        ])
    }

    private func replaceWebView() {
        navigationStateObservations.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()

        let replacement = Self.makeWebView(for: selectedService)
        webView = replacement
        configureWebView(replacement)

        if isViewLoaded {
            installWebView(replacement)
            applyAppearance()
        }

        observeNavigationState()
        notifyNavigationStateDidChange()
    }

    private func resetSessionMessage(for service: StreamingService) -> String {
        switch service {
        case .youtube, .youtubeTV:
            "This clears Tube's Google and YouTube website data, signs out both YouTube services in Tube, and reloads \(service.displayName)."
        case .appleTV:
            "This clears Tube's Apple TV and Apple Account website data, signs out Apple TV in Tube, and reloads it."
        default:
            "This clears Tube's \(service.displayName) website data, signs out that service in Tube, and reloads it."
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

        switch selectedService.navigationPolicy.decision(
            for: navigationAction.request.url,
            isMainFrame: isMainFrame
        ) {
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

        switch selectedService.navigationPolicy.decision(
            for: navigationAction.request.url,
            isMainFrame: true
        ) {
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
