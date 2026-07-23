import Foundation
import Testing
@testable import TubeCore

@Suite("Update discovery")
struct UpdateDiscoveryTests {
    @Test("normalizes numeric versions", arguments: [
        ("0.3.1", "0.3.1"),
        ("v0.3.1", "0.3.1"),
        ("V1.2", "1.2.0"),
        ("1.0.0", "1")
    ])
    func normalizesEquivalentVersions(lhs: String, rhs: String) {
        #expect(AppVersion(lhs) == AppVersion(rhs))
    }

    @Test("orders numeric components rather than comparing text")
    func ordersNumericComponents() throws {
        let older = try #require(AppVersion("0.9.0"))
        let newer = try #require(AppVersion("0.10.0"))

        #expect(older < newer)
        #expect(!(newer < older))
    }

    @Test("orders versions with differing component counts")
    func ordersDifferentComponentCounts() throws {
        let shorter = try #require(AppVersion("1.2"))
        let longer = try #require(AppVersion("1.2.1"))

        #expect(shorter < longer)
    }

    @Test("rejects invalid versions", arguments: [
        "",
        "v",
        "1..2",
        "1.2-beta",
        "release-1.2.3",
        ".1.2",
        "1.2."
    ])
    func rejectsInvalidVersions(value: String) {
        #expect(AppVersion(value) == nil)
    }

    @Test("decodes a GitHub latest release response")
    func decodesLatestRelease() throws {
        let data = Data(
            """
            {
              "tag_name": "v0.4.0",
              "html_url": "https://github.com/thetylerreiff/Tube/releases/tag/v0.4.0"
            }
            """.utf8
        )

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        #expect(release.tagName == "v0.4.0")
        #expect(
            release.pageURL.absoluteString
                == "https://github.com/thetylerreiff/Tube/releases/tag/v0.4.0"
        )
    }

    @Test("rejects malformed release fields", arguments: [
        """
        {"html_url":"https://github.com/thetylerreiff/Tube/releases/tag/v0.4.0"}
        """,
        """
        {"tag_name":"latest","html_url":"https://github.com/thetylerreiff/Tube/releases/latest"}
        """,
        """
        {"tag_name":"v0.4.0","html_url":"not a URL"}
        """,
        """
        {"tag_name":"v0.4.0","html_url":"http://github.com/thetylerreiff/Tube/releases/tag/v0.4.0"}
        """,
        """
        {"tag_name":"v0.4.0","html_url":"https://example.com/thetylerreiff/Tube/releases/tag/v0.4.0"}
        """,
        """
        {"tag_name":"v0.4.0","html_url":"https://github.com/another-owner/Tube/releases/tag/v0.4.0"}
        """
    ])
    func rejectsMalformedReleaseFields(json: String) {
        #expect(throws: Error.self) {
            try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
        }
    }

    @Test("reports a newer release")
    func reportsNewerRelease() throws {
        let release = try decodeRelease(tagName: "v0.4.0")

        #expect(
            UpdateDiscovery.decision(installedVersion: "0.3.1", latestRelease: release)
                == .updateAvailable(release)
        )
    }

    @Test("treats equal and older releases as up to date", arguments: [
        ("0.3.1", "v0.3.1"),
        ("0.4.0", "v0.3.1")
    ])
    func treatsNonNewerReleaseAsUpToDate(installedVersion: String, releaseTag: String) throws {
        let release = try decodeRelease(tagName: releaseTag)

        #expect(
            UpdateDiscovery.decision(
                installedVersion: installedVersion,
                latestRelease: release
            ) == .upToDate
        )
    }

    @Test("reports an invalid installed version")
    func reportsInvalidInstalledVersion() throws {
        let release = try decodeRelease(tagName: "v0.4.0")

        #expect(
            UpdateDiscovery.decision(installedVersion: "development", latestRelease: release)
                == .invalidInstalledVersion
        )
    }

    @Test("schedules the first automatic check")
    func schedulesFirstAutomaticCheck() {
        #expect(
            AutomaticUpdateCheckSchedule.isDue(
                lastAttempt: nil,
                now: Date(timeIntervalSince1970: 1_000)
            )
        )
    }

    @Test("throttles automatic checks for 24 hours")
    func throttlesAutomaticChecks() {
        let lastAttempt = Date(timeIntervalSince1970: 1_000)

        #expect(
            !AutomaticUpdateCheckSchedule.isDue(
                lastAttempt: lastAttempt,
                now: lastAttempt.addingTimeInterval(AutomaticUpdateCheckSchedule.interval - 1)
            )
        )
        #expect(
            AutomaticUpdateCheckSchedule.isDue(
                lastAttempt: lastAttempt,
                now: lastAttempt.addingTimeInterval(AutomaticUpdateCheckSchedule.interval)
            )
        )
    }

    @Test("checks again when the stored date is unexpectedly in the future")
    func checksWhenStoredDateIsInFuture() {
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(
            AutomaticUpdateCheckSchedule.isDue(
                lastAttempt: now.addingTimeInterval(AutomaticUpdateCheckSchedule.interval),
                now: now
            )
        )
    }

    private func decodeRelease(tagName: String) throws -> GitHubRelease {
        let json = """
        {
          "tag_name": "\(tagName)",
          "html_url": "https://github.com/thetylerreiff/Tube/releases/tag/\(tagName)"
        }
        """
        return try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
    }
}
