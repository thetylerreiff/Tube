# Research and Stack Decision

Date: 2026-07-01

## Goal

Build a simple, native, high-performance app that behaves like a single-site browser for YouTube.

The app must not reimplement YouTube, modify YouTube, inject scripts into YouTube, strip ads, download media, scrape content, or interfere with playback/security features. The product surface is the native frame around the real YouTube website.

## Recommendation

Use Swift, AppKit, and `WKWebView` for v1.

This is the smallest durable macOS stack for the requested product:

- `WKWebView` is the platform web view.
- AppKit gives direct control over the native window, titlebar, bezel, menus, shortcuts, fullscreen, and app lifecycle.
- There is no separate frontend framework because the app does not have a custom web UI.
- There is no bundled browser engine because macOS already provides WebKit.

## Source Findings

### Local Apple SDK

This machine currently has:

- Apple Swift 6.3.3
- macOS SDK 26.5 through Command Line Tools
- `xcodebuild` unavailable because the active developer directory is `/Library/Developer/CommandLineTools`, not full Xcode

The installed WebKit headers confirm the core APIs:

- `WKWebView` "displays interactive Web content" and is an `NSView` on macOS.
- `WKWebsiteDataStore` represents cookies, cache, IndexedDB, local storage, and other persistent website data.
- `WKWebsiteDataStore.defaultDataStore()` is the right default for preserving sign-in and session state.
- `WKNavigationDelegate` decides whether to allow or cancel navigations.
- `WKUIDelegate` handles native UI on behalf of a webpage, including new web view requests.

### External Sources

- Apple WebKit API documentation: [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview), [WKWebsiteDataStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore), [WKNavigationDelegate](https://developer.apple.com/documentation/webkit/wknavigationdelegate), [WKUIDelegate](https://developer.apple.com/documentation/webkit/wkuidelegate)
- Apple App Review Guideline 4.2 says App Store apps should include features, content, and UI beyond a repackaged website. That makes Mac App Store distribution risky for a pure single-site browser. See [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
- Apple App Review Guideline 5.2.2 says apps using or displaying third-party services need permission under the service terms; 5.2.3 specifically calls out media downloading from services such as YouTube.
- YouTube Terms allow users to view content through the service, but restrict modifying, interfering with, automating, scraping, downloading, or using the service outside authorized behavior. See [YouTube Terms of Service](https://www.youtube.com/t/terms).
- Electron embeds Chromium and Node.js into the app binary for cross-platform desktop apps. That is powerful, but heavy for this app's minimalist native goal. See [Electron docs](https://www.electronjs.org/docs/latest/).
- Tauri uses Rust plus HTML rendered in the OS webview and keeps apps small because it does not ship a runtime. Good future cross-platform option, but unnecessary for a macOS-only v1. See [Tauri architecture](https://v2.tauri.app/concept/architecture/).
- On Windows, the native equivalent would be WebView2, which embeds web technologies in native apps using Microsoft Edge as the rendering engine. See [Microsoft WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/).

## Stack Comparison

| Stack | Fit | Why |
| --- | --- | --- |
| Swift + AppKit + WKWebView | Best v1 fit | Native, minimal, low overhead, precise macOS window control |
| SwiftUI + WKWebView wrapper | Acceptable | Modern app structure, but less direct for a one-window webview shell |
| Tauri 2 | Future cross-platform option | Small binaries and system webviews, but adds Rust/Tauri machinery v1 does not need |
| Electron | Avoid for v1 | Best Chromium compatibility, but bundles Chromium/Node and costs more memory, size, and update surface |
| Native-per-platform | Best premium cross-platform path | Mac uses WKWebView, Windows uses WebView2, each app stays idiomatic |

## Decision

Build v1 as:

```text
macOS native app
  AppKit app lifecycle
  NSWindow with thin custom bezel
  WKWebView as the only content view
  persistent WKWebsiteDataStore.default()
  WKNavigationDelegate for main-frame navigation policy
  WKUIDelegate for target=_blank/new-window handling
  native app menu and keyboard shortcuts
```

## Distribution Decision

Target local/direct distribution first.

Do not optimize v1 for Mac App Store submission. A pure single-site browser may have App Store review risk under Guideline 4.2, and YouTube-related media/service review concerns are avoidable if we start with direct distribution and notarization.

## Open Research Item

The exact domain allowlist must be verified empirically during implementation. YouTube sign-in and consent flows can involve Google-owned domains, and the policy should allow the minimum set that preserves normal browsing and account login.

