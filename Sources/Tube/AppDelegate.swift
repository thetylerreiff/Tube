import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var browserWindowController: BrowserWindowController?

    private var browserViewController: BrowserViewController? {
        browserWindowController?.browserViewController
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        BrowserCommands.installMainMenu(target: self)
        NSApp.applicationIconImage = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage

        let windowController = BrowserWindowController()
        browserWindowController = windowController
        windowController.showWindow(self)
        windowController.browserViewController.loadHome()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return true
        }

        browserWindowController?.showWindow(self)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func goBack(_ sender: Any?) {
        browserViewController?.goBack()
    }

    @objc func goForward(_ sender: Any?) {
        browserViewController?.goForward()
    }

    @objc func reloadPage(_ sender: Any?) {
        browserViewController?.reloadPage()
    }

    @objc func stopLoading(_ sender: Any?) {
        browserViewController?.stopLoading()
    }

    @objc func openCurrentPageInBrowser(_ sender: Any?) {
        browserViewController?.openCurrentPageInBrowser()
    }

    @objc func signInToYouTube(_ sender: Any?) {
        browserViewController?.signInToYouTube()
    }

    @objc func resetYouTubeSession(_ sender: Any?) {
        browserViewController?.resetSession()
    }

    @objc func showAboutPanel(_ sender: Any?) {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let privacySummary = """
        A focused native window for YouTube.

        Privacy: Tube does not collect credentials, inject scripts, modify YouTube, or track usage. Google and YouTube sign-in happen inside WebKit.
        """
        let credits = NSAttributedString(
            string: privacySummary,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Tube",
            .applicationIcon: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage as Any,
            .applicationVersion: shortVersion,
            .version: "Build \(buildVersion)",
            .credits: credits
        ])
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }

        switch action {
        case #selector(goBack(_:)):
            return browserViewController?.canGoBack ?? false
        case #selector(goForward(_:)):
            return browserViewController?.canGoForward ?? false
        case #selector(stopLoading(_:)):
            return browserViewController?.isLoading ?? false
        case #selector(openCurrentPageInBrowser(_:)):
            return browserViewController?.currentURL != nil
        default:
            return true
        }
    }
}
