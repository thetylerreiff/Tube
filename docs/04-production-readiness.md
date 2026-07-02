# Production Readiness

Date: 2026-07-01

## Current Status

Tube is ready as a local development build and early manual prototype. It is not yet ready for public distribution.

Current evidence:

- `swift test` passes.
- `scripts/build-app.sh release` builds `Build/Tube.app`.
- `scripts/release-app.sh` implements the production release pipeline.
- The app bundle verifies with local ad-hoc signing.
- Entitlements are intentionally narrow: App Sandbox and outgoing network client access.
- The current local app is ad-hoc signed, has no Team ID, and is rejected by Gatekeeper assessment.
- This machine currently has no valid Developer ID Application signing identity installed.
- Manual verification is partially complete; remaining items are tracked in `docs/03-verification.md`.

Latest local release-script result:

- `scripts/release-app.sh` exits before building with: `no Developer ID Application signing identity found`.
- This is the expected production-safe behavior until a Developer ID Application certificate is installed or passed with `--identity`.

## Distribution Recommendation

Ship v1 as a notarized Developer ID app distributed outside the Mac App Store.

Rationale:

- Tube is a focused single-site browser for YouTube.
- Direct distribution avoids Mac App Store review uncertainty around a third-party content wrapper.
- Developer ID signing plus notarization gives users the normal macOS trust path without changing the app architecture.
- The current Swift, AppKit, and `WKWebView` stack is already aligned with a small native direct-distribution app.

## Readiness Checklist

### P0: Required Before Sharing Publicly

- [x] Add a strict production release script.
- [x] Make app assembly reusable for both local and production output paths.
- [x] Enable hardened runtime signing in the production path.
- [x] Produce `.zip` and `.dmg` artifacts in the production path.
- [x] Add notarization, stapling, Gatekeeper, and disk image validation steps in the production path.
- [x] Preserve the current minimal entitlements in the production path.
- [ ] Sign release builds with a Developer ID Application certificate.
- [ ] Submit the release artifact to Apple notarization.
- [ ] Staple the notarization ticket to the shipped app or disk image.
- [ ] Confirm Gatekeeper accepts the final shipped artifact.
- [ ] Complete the manual QA checklist in `docs/03-verification.md`.
- [ ] Add a clear "not affiliated with YouTube or Google" note in release-facing copy.

### P1: Strongly Recommended For First Public Beta

- [ ] Add a version bump process for `CFBundleShortVersionString` and `CFBundleVersion`.
- [ ] Add a changelog.
- [x] Add a `Release/` or `Dist/` output path separate from local `Build/`.
- [x] Add a repeatable release checklist document or script.
- [ ] Add a basic support contact or issue-reporting path.
- [ ] Add a short public privacy page based on `docs/app-identity/privacy.md`.
- [ ] Verify session persistence with a real signed-in Google account.
- [ ] Verify fullscreen video behavior.
- [ ] Verify hardware trackpad back/forward gestures.
- [ ] Verify light and dark mode on a real desktop session.
- [ ] Verify external links open in the default browser.

### P2: Later Production Polish

- [ ] Add Sparkle 2 for signed automatic updates.
- [ ] Add crash report guidance or an opt-in diagnostics story.
- [ ] Add a small release notes view or link.
- [ ] Add UI automation coverage for app launch, menu commands, and basic WebKit navigation where practical.
- [ ] Profile memory, CPU, and energy during common YouTube flows.

## Release Build Acceptance Criteria

A release build is production-ready only when this passes on a clean machine:

```sh
scripts/release-app.sh --identity "Developer ID Application: Your Name (TEAMID)" --notary-profile tube-notary
```

The script runs:

```sh
swift test
scripts/build-app.sh release
codesign --verify --deep --strict --verbose=2 Dist/Tube.app
spctl -a -vv Dist/Tube.app
xcrun stapler validate Dist/Tube.app
```

For the `.dmg` release, it also validates the disk image:

```sh
hdiutil verify Dist/Tube-0.1.0-build-1.dmg
spctl -a -vv --type open --context context:primary-signature Dist/Tube-0.1.0-build-1.dmg
xcrun stapler validate Dist/Tube-0.1.0-build-1.dmg
```

Expected outcome:

- Tests pass.
- Code signature is valid.
- Gatekeeper accepts the artifact.
- Stapled notarization ticket validates.
- The app launches, loads YouTube, and shows no in-window browser chrome.

## Signing And Notarization Notes

The current local build uses:

```sh
codesign --force --sign - --entitlements Tube/Tube.entitlements Build/Tube.app
```

That is correct for local development, but not enough for distribution.

The production path is:

- Developer ID Application certificate.
- Hardened runtime.
- The same minimal entitlements unless a new feature proves otherwise.
- `notarytool` for notarization.
- `stapler` before publishing.

Create a `notarytool` keychain profile before the first notarized release:

```sh
xcrun notarytool store-credentials tube-notary
```

Then run:

```sh
scripts/release-app.sh --identity "Developer ID Application: Your Name (TEAMID)" --notary-profile tube-notary
```

Useful inspection commands:

```sh
codesign -dvvv --entitlements :- Dist/Tube.app
security find-identity -p codesigning -v
spctl -a -vv Dist/Tube.app
```

## Manual QA Gate

Before calling v1 production-ready, verify:

- YouTube home loads.
- YouTube search works.
- Video playback works.
- Fullscreen video enters and exits cleanly.
- Back, Forward, Reload, and Stop Loading work from menus and keyboard shortcuts.
- Trackpad back/forward gestures work with the user's macOS "Swipe between pages" setting enabled.
- Sign in flow reaches Google sign-in inside Tube.
- Signed-in session persists after quit and reopen.
- Reset session clears Tube's WebKit website state.
- External links open in the default browser.
- The bezel can drag the window without blocking YouTube clicks or scroll.
- Light and dark system appearance are respected.
- Resize works from compact to large desktop sizes.

## Open Decisions

- Release artifact: `.dmg`, `.zip`, or both.
- Distribution surface: GitHub Releases, personal site, or both.
- Auto-update timing: manual updates for v1, Sparkle 2 after first public beta.
- Support channel: email, GitHub Issues, or a lightweight webpage.
- App name and trademark posture for public copy.

## References

- Apple: Notarizing macOS software before distribution: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple: Hardened Runtime: https://developer.apple.com/documentation/security/hardened-runtime
- Apple: Distributing your app for beta testing and releases: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
