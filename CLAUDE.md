# Tube

Tube is a minimal native macOS app for watching streaming services in a focused
window. It's built with Swift 6 + SwiftPM, using AppKit for the app shell and a
`WKWebView` wrapper (no bundled browser runtime) for provider websites.

## Commands

- `swift test` — run the unit tests (TubeCore only).
- `scripts/build-app.sh debug` or `scripts/build-app.sh release` — build
  `Build/Tube.app`.
- `open Build/Tube.app` — launch the built app.

## Source map

- `Sources/Tube` — the AppKit app.
  - `AppDelegate.swift`, `main.swift` — app entry point.
  - `BrowserWindowController.swift` — the window: hover-revealed titlebar
    chrome, drag surfaces, frame persistence.
  - `BrowserViewController.swift` — hosts `TubeWebView`/`WKWebView`.
  - `ServiceSwitcherController.swift` — native Command-K provider palette.
  - `BrowserCommands.swift` — builds the entire main menu and keyboard
    shortcuts programmatically.
  - `BezelContainerView.swift` — the draggable bezel border around the
    content.
  - `TubeAppearance.swift` — light/dark appearance handling.
  - `BrowserErrorOverlay.swift` — load-error UI overlay.
- `Sources/TubeCore` — streaming-service definitions, pure-logic navigation
  policy, and swipe-gesture resolver. This is the only unit-tested target.

## Notes

- All menus and keyboard shortcuts are built in code in
  `BrowserCommands.swift` — there is no nib or storyboard.
- Release process (versioning, signing, notarizing, publishing) is documented
  in `RELEASING.md`.
- Verify UI changes with the `verify` skill (`.claude/skills/verify`) before
  considering them done.
