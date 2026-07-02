# Implementation Plan

## Scope

Build a macOS-only v1 named Tube.

The implementation should create a native app that opens YouTube in a single `WKWebView`, framed by a thin native bezel, with all controls exposed through menus and keyboard shortcuts.

## Prerequisites

Current local state:

- Swift is available.
- macOS SDK 26.5 is available through Command Line Tools.
- `xcodebuild` is not currently available because full Xcode is not the active developer directory.

Recommended build prerequisite:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

If full Xcode is not installed or not desired, the first prototype can still be compiled with direct Swift tooling, but a durable app bundle, asset catalog, signing, and future notarization path are cleaner through Xcode.

## Implemented Project Structure

```text
Package.swift
Sources/
  Tube/
    AppDelegate.swift
    BrowserCommands.swift
    BrowserErrorOverlay.swift
    BrowserViewController.swift
    BrowserWindowController.swift
    main.swift
  TubeCore/
    BrowserNavigationPolicy.swift
Tube/
  Assets.xcassets
    AppIcon.appiconset
  AppIcon.icns
  Info.plist
  Tube.entitlements
Tests/
  TubeCoreTests/
  BrowserNavigationPolicyTests.swift
scripts/
  build-app.sh
docs/
  00-research-and-stack-decision.md
  01-product-design.md
  02-implementation-plan.md
  03-verification.md
```

The project currently uses SwiftPM for fast tests and compilation, then `scripts/build-app.sh` assembles and signs `Build/Tube.app`. Xcode can open the package directly, but a checked-in `.xcodeproj` is not required for v1.

## Core Classes

### `AppDelegate`

Responsibilities:

- create the main window on launch
- install native menus
- handle reopen-from-Dock behavior
- route global menu commands to the active browser window

### `BrowserWindowController`

Responsibilities:

- configure the `NSWindow`
- apply thin bezel styling
- preserve/restore window size and position
- handle fullscreen state

Window setup:

```swift
let styleMask: NSWindow.StyleMask = [
    .titled,
    .closable,
    .miniaturizable,
    .resizable
]
```

Recommended window properties:

- hidden title text
- transparent titlebar appearance
- `fullSizeContentView` so YouTube visually extends behind the hidden native titlebar
- dark window background
- keep broad `isMovableByWindowBackground` disabled so YouTube receives clicks and scroll events
- keep hover reveal visual; route the revealed titlebar band to AppKit drag handling and only second clicks in the titlebar band to zoom handling
- add a compact glass titlebar control cluster with icon-only back/forward buttons
- content view contains the bezel container and web view

### `BrowserViewController`

Responsibilities:

- create and own `WKWebView`
- load `https://www.youtube.com`
- expose back/forward/reload/stop commands
- publish navigation state changes so titlebar controls and menus can update enabled state
- enable native WebKit back/forward swipe gestures
- allow exposed native bezel/background areas to drag the window
- show/hide native error overlay
- handle loading state
- update native frame colors when macOS light/dark appearance changes

WebView configuration:

```swift
let configuration = WKWebViewConfiguration()
configuration.websiteDataStore = .default()
configuration.allowsAirPlayForMediaPlayback = true
configuration.mediaTypesRequiringUserActionForPlayback = []
```

WebView behavior:

```swift
webView.allowsBackForwardNavigationGestures = true
webView.underPageBackgroundColor = TubeAppearance.dynamicWebBackground
```

Do not add user scripts or custom content blockers in v1.

Native appearance:

- keep the app appearance unset so macOS controls light/dark mode
- resolve frame, border, overlay, and under-page colors from `effectiveAppearance`
- update layer-backed colors in `viewDidChangeEffectiveAppearance`
- do not inject CSS into YouTube to force a page theme

### `BrowserNavigationPolicy`

Responsibilities:

- decide whether a URL should open inside Tube
- decide whether a URL should open externally
- keep policy deterministic and unit-tested

Policy rules:

- allow `https` main-frame navigations to YouTube domains
- allow required Google auth/consent domains
- deny unsupported schemes inside the webview
- open unrelated `http`/`https` top-level links in the default browser
- allow subframe navigations unless they trigger a clear top-level escape

### `WKNavigationDelegate`

Responsibilities:

- call `BrowserNavigationPolicy`
- allow or cancel main-frame navigation
- open external URLs via `NSWorkspace.shared.open(_:)`
- update error/loading state

### `WKUIDelegate`

Responsibilities:

- handle `target=_blank` and new-window requests
- load allowed destinations in the existing `WKWebView`
- open unrelated destinations in the default browser
- provide native handling for JavaScript alert/confirm/prompt only if YouTube requires it

## Entitlements

Start with the smallest sandbox surface:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

Do not request file access, camera, microphone, automation, or incoming network permissions unless a later feature genuinely needs them.

If YouTube requests camera/microphone for upload/live features, let WebKit/macOS prompt through normal permission flows rather than pre-granting anything app-specific.

## Menu Commands

Create a standard macOS menu with:

- App: About Tube, Quit Tube
- File: Open Current Page in Browser, Sign In to YouTube, Reset YouTube Session
- View: Reload, Stop Loading, Actual Size if needed, Enter Full Screen
- History: Back, Forward
- Window: Minimize, Zoom, Bring All to Front

The app should have no visible in-window toolbar.

Back/forward should remain available through the menu, keyboard shortcuts, and native trackpad gestures rather than permanent visible in-window controls.

The native bezel and error overlay should respect the user's macOS light/dark setting without adding visible theme controls.

Window dragging and double-click zoom should use AppKit window APIs, not a broad custom overlay. Tube may fade the standard red/yellow/green controls in when the pointer enters the titlebar area. The revealed titlebar band should be routed to drag handling, and only the second click of a double-click in the titlebar band should be routed to zoom handling, so YouTube keeps normal pointer and scroll events below the titlebar.

## Session Reset

Use `WKWebsiteDataStore.default().removeData(...)`.

Reset flow:

1. Confirm with a native alert.
2. Stop loading.
3. Remove all website data types modified since distant past.
4. Reload `https://www.youtube.com`.

This clears Tube's WebKit website state. It should not touch Safari, Chrome, or unrelated app data.

## Account Login

Account login is not a native OAuth implementation. Tube starts YouTube's normal Google account flow inside `WKWebView`, then relies on `WKWebsiteDataStore.default()` to persist the resulting YouTube/Google website session.

The native `File > Sign In to YouTube` command loads Google `ServiceLogin` with `service=youtube` and a YouTube continuation URL. Tube never sees or stores credentials, access tokens, or refresh tokens.

## Testing

### Unit Tests

Focus unit tests on `BrowserNavigationPolicy`.

Required cases:

- `https://www.youtube.com` opens internally
- `https://youtu.be/...` opens internally
- `https://accounts.google.com/...` opens internally
- `https://example.com` opens externally
- `mailto:` opens externally
- invalid URLs open externally or cancel safely
- subframe navigations are allowed by default

### Manual Verification

Before calling v1 complete:

- launch app
- confirm YouTube loads
- confirm only thin bezel/native frame is visible
- play a video
- enter and exit fullscreen video
- use YouTube search
- use Back, Forward, Reload, Stop Loading
- open an unrelated external link and confirm it opens in default browser
- quit and reopen, then confirm session persists
- reset session and confirm sign-in state is cleared
- test dark/light system appearance
- test window resize from compact to large desktop sizes

### Performance Checks

Use direct observation first, then Instruments if needed.

Track:

- cold launch to first visible YouTube content
- idle memory after YouTube home settles
- memory during video playback
- CPU while idle on home
- CPU while playing 1080p video
- battery/energy impact if this becomes a daily-use app

Avoid adding background timers, polling, app analytics, injected scripts, or custom rendering layers unless there is a measured reason.

## Build Milestones

1. Create native app project and app bundle. Done with SwiftPM plus `scripts/build-app.sh`.
2. Add full-window `WKWebView` and load YouTube. Done.
3. Add bezel/window styling. Done.
4. Add navigation policy and external-link routing. Done.
5. Add menu commands and keyboard shortcuts. Done.
6. Add session reset. Done.
7. Add error overlay. Done.
8. Add unit tests for policy. Done.
9. Add real app identity: icon set, bundle metadata, About panel, and privacy note. Done.
10. Run manual verification checklist. Partially done; see `docs/03-verification.md`.
11. Prepare direct notarized distribution. Production release script is implemented; Developer ID certificate and notarization profile are still required.

## Future Platform Path

If Windows becomes a requirement, prefer a separate native Windows shell using WebView2.

If maintaining separate native shells becomes too much, reevaluate Tauri 2 as the shared app shell. Do not switch to Electron unless Chromium parity is more important than app size, native footprint, and idle resource use.
