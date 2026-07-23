import AppKit
import TubeCore

@MainActor
final class UpdateController {
    private enum CheckKind {
        case automatic
        case manual
    }

    private static let lastAutomaticCheckKey = "TubeLastAutomaticUpdateCheckDate"

    private let releaseClient: GitHubReleaseClient
    private let defaults: UserDefaults
    private let now: () -> Date

    private(set) var isChecking = false {
        didSet {
            NSApp.mainMenu?.update()
        }
    }

    init(
        releaseClient: GitHubReleaseClient = GitHubReleaseClient(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.releaseClient = releaseClient
        self.defaults = defaults
        self.now = now
    }

    func checkAutomaticallyIfNeeded() {
        let checkDate = now()
        let lastCheckDate = defaults.object(forKey: Self.lastAutomaticCheckKey) as? Date
        guard AutomaticUpdateCheckSchedule.isDue(
            lastAttempt: lastCheckDate,
            now: checkDate
        ) else {
            return
        }

        defaults.set(checkDate, forKey: Self.lastAutomaticCheckKey)
        check(kind: .automatic)
    }

    func checkManually() {
        check(kind: .manual)
    }

    private func check(kind: CheckKind) {
        guard !isChecking else {
            return
        }

        isChecking = true
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let latestRelease = try await releaseClient.fetchLatestRelease()
                finishCheck(with: latestRelease, kind: kind)
            } catch {
                finishCheck(with: error, kind: kind)
            }
        }
    }

    private func finishCheck(with latestRelease: GitHubRelease, kind: CheckKind) {
        isChecking = false

        let installedVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? ""

        switch UpdateDiscovery.decision(
            installedVersion: installedVersion,
            latestRelease: latestRelease
        ) {
        case .updateAvailable(let release):
            showUpdateAvailable(release, installedVersion: installedVersion)
        case .upToDate:
            if kind == .manual {
                showUpToDate(installedVersion: installedVersion)
            }
        case .invalidInstalledVersion:
            if kind == .manual {
                showCheckFailure()
            }
        }
    }

    private func finishCheck(with _: Error, kind: CheckKind) {
        isChecking = false

        if kind == .manual {
            showCheckFailure()
        }
    }

    private func showUpdateAvailable(_ release: GitHubRelease, installedVersion: String) {
        let alert = NSAlert()
        alert.messageText = "A new version of Tube is available"
        alert.informativeText = """
        Tube \(displayVersion(release.tagName)) is available. You are using Tube \(installedVersion).
        """
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Remind Me Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.pageURL)
        }
    }

    private func showUpToDate(installedVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Tube is up to date"
        alert.informativeText = "You are using the latest version of Tube (\(installedVersion))."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showCheckFailure() {
        let alert = NSAlert()
        alert.messageText = "Unable to check for updates"
        alert.informativeText = "Check your internet connection and try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func displayVersion(_ tagName: String) -> String {
        if tagName.first == "v" || tagName.first == "V" {
            return String(tagName.dropFirst())
        }
        return tagName
    }
}
