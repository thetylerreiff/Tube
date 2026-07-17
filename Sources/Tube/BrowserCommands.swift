import AppKit
import TubeCore

@MainActor
enum BrowserCommands {
    static func installMainMenu(target: AppDelegate) {
        let mainMenu = NSMenu(title: "Main Menu")
        NSApp.mainMenu = mainMenu

        addAppMenu(to: mainMenu, target: target)
        addFileMenu(to: mainMenu, target: target)
        addServiceMenu(to: mainMenu, target: target)
        addEditMenu(to: mainMenu)
        addViewMenu(to: mainMenu, target: target)
        addHistoryMenu(to: mainMenu, target: target)
        addWindowMenu(to: mainMenu, target: target)
    }

    private static func addAppMenu(to mainMenu: NSMenu, target: AppDelegate) {
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu(title: "Tube")
        appItem.submenu = appMenu

        appMenu.addItem(item(
            title: "About Tube",
            action: #selector(AppDelegate.showAboutPanel(_:)),
            key: "",
            target: target
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Hide Tube",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        ).keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Tube",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
    }

    private static func addFileMenu(to mainMenu: NSMenu, target: AppDelegate) {
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)

        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu

        fileMenu.addItem(item(
            title: "Open Current Page in Browser",
            action: #selector(AppDelegate.openCurrentPageInBrowser(_:)),
            key: "o",
            target: target
        ))
        fileMenu.addItem(item(
            title: "Sign In to \(target.currentService.displayName)",
            action: #selector(AppDelegate.signInToCurrentService(_:)),
            key: "l",
            target: target,
            modifiers: [.command, .shift]
        ))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item(
            title: "Close Window",
            action: #selector(AppDelegate.closeWindow(_:)),
            key: "w",
            target: target
        ))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item(
            title: "Reset \(target.currentService.displayName) Session",
            action: #selector(AppDelegate.resetCurrentServiceSession(_:)),
            key: "",
            target: target
        ))
    }

    private static func addServiceMenu(to mainMenu: NSMenu, target: AppDelegate) {
        let serviceItem = NSMenuItem()
        mainMenu.addItem(serviceItem)

        let serviceMenu = NSMenu(title: "Service")
        serviceItem.submenu = serviceMenu

        for service in StreamingService.allCases {
            let serviceMenuItem = item(
                title: service.displayName,
                action: #selector(AppDelegate.switchService(_:)),
                key: "",
                target: target
            )
            serviceMenuItem.representedObject = service.rawValue
            serviceMenuItem.state = service == target.currentService ? .on : .off
            serviceMenu.addItem(serviceMenuItem)
        }

        serviceMenu.addItem(.separator())
        serviceMenu.addItem(item(
            title: "Choose Service…",
            action: #selector(AppDelegate.showServiceSwitcher(_:)),
            key: "k",
            target: target
        ))
    }

    private static func addEditMenu(to mainMenu: NSMenu) {
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)

        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Paste and Match Style",
            action: #selector(NSTextView.pasteAsPlainText(_:)),
            keyEquivalent: "v"
        ).keyEquivalentModifierMask = [.command, .option, .shift]
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    }

    private static func addViewMenu(to mainMenu: NSMenu, target: AppDelegate) {
        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)

        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu

        viewMenu.addItem(item(
            title: "Reload",
            action: #selector(AppDelegate.reloadPage(_:)),
            key: "r",
            target: target
        ))

        viewMenu.addItem(item(
            title: "Stop Loading",
            action: #selector(AppDelegate.stopLoading(_:)),
            key: ".",
            target: target
        ))

        viewMenu.addItem(.separator())
        viewMenu.addItem(
            withTitle: "Enter Full Screen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        ).keyEquivalentModifierMask = [.control, .command]
    }

    private static func addHistoryMenu(to mainMenu: NSMenu, target: AppDelegate) {
        let historyItem = NSMenuItem()
        mainMenu.addItem(historyItem)

        let historyMenu = NSMenu(title: "History")
        historyItem.submenu = historyMenu

        historyMenu.addItem(item(
            title: "Back",
            action: #selector(AppDelegate.goBack(_:)),
            key: "[",
            target: target
        ))
        historyMenu.addItem(item(
            title: "Forward",
            action: #selector(AppDelegate.goForward(_:)),
            key: "]",
            target: target
        ))
    }

    private static func addWindowMenu(to mainMenu: NSMenu, target: AppDelegate) {
        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)

        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        windowMenu.addItem(item(
            title: "Minimize",
            action: #selector(AppDelegate.minimizeWindow(_:)),
            key: "m",
            target: target
        ))
        windowMenu.addItem(
            withTitle: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            withTitle: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
    }

    private static func item(
        title: String,
        action: Selector,
        key: String,
        target: AnyObject,
        modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = target
        menuItem.keyEquivalentModifierMask = modifiers
        return menuItem
    }
}
