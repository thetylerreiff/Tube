# Tube

Tube is a minimal native macOS single-site browser for YouTube.

The app goal is intentionally narrow: open YouTube in a fast native window with a thin bezel, no URL bar, no visible navigation chrome, and no modification of YouTube content or behavior.

## Current Documents

- [Research and Stack Decision](docs/00-research-and-stack-decision.md)
- [Product Design](docs/01-product-design.md)
- [Implementation Plan](docs/02-implementation-plan.md)
- [Verification Log](docs/03-verification.md)
- [Production Readiness](docs/04-production-readiness.md)
- [App Identity](docs/app-identity/README.md)

## Current Decision

Build v1 as a macOS app using Swift, AppKit, and `WKWebView`.

Electron is intentionally out of scope for v1 because it bundles Chromium and Node.js. Tauri remains a future option if cross-platform delivery becomes more important than the smallest native Mac implementation.

## Build And Run

Run tests:

```sh
swift test
```

Build a signed local app bundle:

```sh
scripts/build-app.sh release
```

Launch the app:

```sh
open Build/Tube.app
```

Create a production release artifact:

```sh
scripts/release-app.sh --identity "Developer ID Application: Your Name (TEAMID)" --notary-profile tube-notary
```

The release script requires a Developer ID Application certificate and a `notarytool` keychain profile. It signs with hardened runtime, creates `.zip` and `.dmg` artifacts, submits notarization, staples tickets, and runs Gatekeeper validation.

Account login is handled by YouTube/Google inside the `WKWebView`. Use `File > Sign In to YouTube` to start the normal Google sign-in flow. Tube does not collect credentials or store tokens itself; WebKit persists the resulting website session.

Navigation stays native and mostly chrome-free: use the hover-revealed titlebar buttons, `Command-[` / `Command-]`, the `History` menu, or trackpad swipe gestures to move backward and forward through YouTube page history. Trackpad navigation respects the user's macOS "Swipe between pages" setting.

Tube's native bezel, window background, error overlay, and WebKit under-page background follow the user's macOS light/dark appearance. YouTube's own in-page theme remains controlled by YouTube/account settings.

Tube uses native macOS window controls with the content view extended behind the titlebar so there is no permanent header strip. The red/yellow/green controls and a compact glass back/forward cluster fade in when hovering the titlebar area; the revealed titlebar band supports dragging and double-click zoom without blocking normal YouTube clicks and scrolling below it.

## App Identity

Tube includes a generated liquid-glass retro TV app icon concept, exported as a macOS icon set and bundled as `AppIcon.icns` by `scripts/build-app.sh`.

The About panel shows Tube's version/build, copyright, icon, and a short privacy summary. The longer privacy note lives at [docs/app-identity/privacy.md](docs/app-identity/privacy.md).

## License

Tube is released under the [MIT License](LICENSE).
