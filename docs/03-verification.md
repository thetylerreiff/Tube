# Verification Log

Date: 2026-07-01

## Toolchain

- `xcodebuild -version`: Xcode 26.6, build 17F113
- `xcode-select -p`: `/Applications/Xcode.app/Contents/Developer`
- `swift --version`: Apple Swift 6.3.3

## Automated Tests

Command:

```sh
swift test
```

Result:

- Passed.
- 12 `BrowserNavigationPolicy` tests passed.
- 4 `SwipeNavigationResolver` tests passed.
- Coverage includes YouTube domains, Google sign-in, unrelated external URLs, mail links, invalid URLs, subframe allowance, lookalike domains, script-like schemes, trackpad swipe direction mapping, incomplete swipe suppression, and unavailable-history suppression.

## Release Build

Command:

```sh
scripts/build-app.sh release
```

Result:

- Built `Build/Tube.app`.
- Copied `Tube/Info.plist`.
- Copied `AppIcon.icns` and `Assets.car` into bundle resources.
- Ad-hoc signed the app with `Tube/Tube.entitlements`.

## Bundle Checks

Commands:

```sh
du -sh Build/Tube.app
codesign --verify --deep --strict --verbose=2 Build/Tube.app
plutil -lint Build/Tube.app/Contents/Info.plist
codesign -d --entitlements - Build/Tube.app
file Build/Tube.app/Contents/Resources/AppIcon.icns Build/Tube.app/Contents/Resources/Assets.car
python3 -m json.tool Tube/Assets.xcassets/AppIcon.appiconset/Contents.json
```

Results:

- Bundle size: `176K`.
- Code signature valid on disk.
- App satisfies its designated requirement.
- Info.plist is valid.
- Bundle includes `Resources/AppIcon.icns`.
- Bundle includes `Resources/Assets.car`.
- `Tube/Assets.xcassets/AppIcon.appiconset/Contents.json` is valid JSON.
- App icon source sizes from 16px through 1024px are present.
- Entitlements include only App Sandbox and outgoing network client access.

## App Identity Verification

Commands:

```sh
scripts/clean-app-icon-source.py docs/app-identity/tube-icon-retro-tv-user-source.png docs/app-identity/tube-icon-retro-tv-master-clean.png
scripts/generate-app-icon.sh
sips -g pixelWidth -g pixelHeight -g hasAlpha Tube/Assets.xcassets/AppIcon.appiconset/*.png
file Tube/AppIcon.icns
```

Results:

- Generated a cleaned RGBA icon master from the user-selected liquid-glass retro TV image.
- Removed the edge-connected black corner background by converting it to alpha transparency.
- Verified exported icon PNGs preserve alpha and have transparent corner pixels.
- Generated a macOS app icon set from the cleaned selected image.
- Generated `Tube/AppIcon.icns`.
- `About Tube` opens from the app menu and renders the app icon, `Version 0.1.0 (Build 1)`, privacy summary, and copyright.
- `Tube/Info.plist` includes `CFBundleIconFile`, `CFBundleIconName`, `NSHumanReadableCopyright`, `CFBundleGetInfoString`, and `NSPrincipalClass`.

## Launch Verification

Command:

```sh
open Build/Tube.app
```

Result:

- App launched.
- macOS UI scripting reported a frontmost `Tube` window with one visible window.
- Computer Use verified a native Tube window with YouTube HTML content loaded at `youtube.com/`.
- The rendered app had no URL bar or visible in-window app toolbar.
- The macOS menu bar exposed `Tube`, `File`, `View`, `History`, and `Window`.
- Back/forward is exposed through hover-revealed titlebar buttons, the `History` menu, `Command-[` / `Command-]`, WebKit navigation gestures, and an AppKit fluid-scroll fallback for trackpad page swipes.
- Native Tube chrome is implemented with dynamic AppKit colors that resolve from `effectiveAppearance`; WebKit under-page background is also appearance-aware.
- Current launch verification ran with macOS dark mode enabled. System light/dark toggling was not performed because it changes the user's system setting.
- Broad native bezel/background dragging is disabled so YouTube receives pointer and scroll events. The previous invisible top overlay was removed because it intercepted YouTube pointer events.
- Window dragging and double-click zoom use AppKit window APIs without a broad hit-test overlay over YouTube. The content view extends behind the transparent titlebar so there is no permanent header strip, the standard red/yellow/green controls and glass back/forward cluster fade in when the pointer enters the titlebar area, drag is handled in the revealed titlebar band, and zoom is limited to double-click handling in that band.

## Interaction Verification

Using Computer Use:

- Focused YouTube search field inside the `WKWebView`.
- Typed `lofi beats` and submitted with Return.
- Verified navigation to `youtube.com/results?search_query=lofi+beats`.
- Verified YouTube search results and thumbnails rendered inside the app.
- Opened a YouTube watch page from the results.
- Verified the YouTube player surface, controls, video metadata, and recommendations rendered inside the app.
- Triggered `File > Sign In to YouTube`.
- Verified the app navigated inside Tube to Google's `accounts.google.com` sign-in page for continuing to YouTube.
- Did not enter credentials.

## Trackpad Swipe Troubleshooting

Research source:

- Local Apple SDK headers from the installed Xcode 26.6 SDK.
- `WKWebView.allowsBackForwardNavigationGestures` enables WebKit's built-in horizontal swipe back/forward handling.
- `NSResponder.wantsScrollEventsForSwipeTracking(on:)` is the AppKit hook for receiving fluid scroll events as swipe tracking events when scrollable content is already at an edge.
- `NSEvent.isSwipeTrackingFromScrollEventsEnabled` reflects the user's Mouse/Trackpad "Swipe between pages" preference, and `NSEvent.trackSwipeEvent(...)` tracks the completed fluid swipe.

Implementation result:

- Added `TubeWebView`, a small `WKWebView` subclass that keeps WebKit's built-in back/forward gestures enabled and adds an AppKit fallback for horizontal fluid scroll swipes.
- Added `SwipeNavigationResolver` unit coverage so right swipe maps to back, left swipe maps to forward, incomplete swipes are ignored, and unavailable history directions do not navigate.
- Physical trackpad verification still requires a real user gesture on hardware; automated checks can verify build/test behavior but cannot synthesize the exact system gesture.

## Not Yet Verified

- Session persistence across a real signed-in account restart.
- Fullscreen video.
- Physical two-finger trackpad back/forward gesture on hardware.
- Direct notarization.
