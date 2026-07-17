import AppKit
import TubeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var browserWindowController: BrowserWindowController?
    private var serviceSwitcherController: ServiceSwitcherController?

    private var browserViewController: BrowserViewController? {
        browserWindowController?.browserViewController
    }

    var currentService: StreamingService {
        browserViewController?.selectedService ?? .defaultService
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage

        let windowController = BrowserWindowController()
        browserWindowController = windowController
        BrowserCommands.installMainMenu(target: self)
        windowController.onWindowWillClose = { [weak self] in
            self?.serviceSwitcherController?.dismiss()
            self?.browserWindowController = nil
            NSApp.terminate(nil)
        }
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

    @objc func closeWindow(_ sender: Any?) {
        browserWindowController?.window?.close()
    }

    @objc func minimizeWindow(_ sender: Any?) {
        browserWindowController?.window?.miniaturize(sender)
    }

    @objc func openCurrentPageInBrowser(_ sender: Any?) {
        browserViewController?.openCurrentPageInBrowser()
    }

    @objc func switchService(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let service = StreamingService(rawValue: rawValue)
        else {
            return
        }

        switchToService(service)
    }

    @objc func showServiceSwitcher(_ sender: Any?) {
        guard let window = browserWindowController?.window else {
            return
        }

        let controller: ServiceSwitcherController
        if let serviceSwitcherController {
            controller = serviceSwitcherController
        } else {
            controller = ServiceSwitcherController()
            controller.onSelectService = { [weak self] service in
                self?.switchToService(service)
            }
            serviceSwitcherController = controller
        }

        if controller.isVisible {
            controller.dismiss()
        } else {
            controller.show(relativeTo: window, selectedService: currentService)
        }
    }

    @objc func signInToCurrentService(_ sender: Any?) {
        browserViewController?.signIn()
    }

    @objc func resetCurrentServiceSession(_ sender: Any?) {
        browserViewController?.resetSession()
    }

    @objc func showAboutPanel(_ sender: Any?) {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let privacySummary = """
        A focused native window for streaming services.

        Privacy: Tube does not collect credentials, inject scripts, modify streaming sites, or track usage. Service sign-in happens inside WebKit. If a provider requests location for local or live programming, macOS asks for permission and Tube does not store it.
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
        case #selector(switchService(_:)):
            guard let rawValue = menuItem.representedObject as? String,
                  let service = StreamingService(rawValue: rawValue)
            else {
                return false
            }

            menuItem.state = service == currentService ? .on : .off
            return true
        case #selector(signInToCurrentService(_:)):
            menuItem.title = "Sign In to \(currentService.displayName)"
            return true
        case #selector(resetCurrentServiceSession(_:)):
            menuItem.title = "Reset \(currentService.displayName) Session"
            return true
        case #selector(goBack(_:)):
            return browserViewController?.canGoBack ?? false
        case #selector(goForward(_:)):
            return browserViewController?.canGoForward ?? false
        case #selector(stopLoading(_:)):
            return browserViewController?.isLoading ?? false
        case #selector(closeWindow(_:)):
            return browserWindowController?.window?.isVisible ?? false
        case #selector(minimizeWindow(_:)):
            guard let window = browserWindowController?.window else {
                return false
            }

            return window.isVisible
                && !window.isMiniaturized
                && window.styleMask.contains(.miniaturizable)
        case #selector(openCurrentPageInBrowser(_:)):
            return browserViewController?.currentURL != nil
        default:
            return true
        }
    }

    private func switchToService(_ service: StreamingService) {
        browserViewController?.switchService(to: service)
        NSApp.mainMenu?.update()
    }
}
