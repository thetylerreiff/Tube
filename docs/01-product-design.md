# Product Design

## Product Definition

Tube is a native Mac window dedicated to YouTube.

It is not a YouTube clone, not a custom player, and not a rewritten interface. It is a focused browser shell that opens YouTube and gets out of the way.

## Design Direction

The reference screenshot shows the right product posture:

- YouTube fills nearly the entire window.
- The native app contributes only a thin outer frame.
- There is no visible URL bar.
- There is no visible toolbar.
- There is no app navigation competing with YouTube's own navigation.
- The edge treatment makes the experience feel intentional rather than like a raw browser tab.

## Visual Model

```text
NSWindow
  dark native window background
  4-8 px outer bezel
  rounded outer corners from the macOS window
  clipped inner content region
  WKWebView loading https://www.youtube.com
```

The bezel should be subtle:

- dark neutral/blue-black background
- thin border stroke, roughly 1 px
- no ornamental gradients
- no decorative controls
- no custom branding over YouTube

The web content should be inset just enough to reveal the frame. The frame is the app's identity.

Tube's native chrome should follow the user's macOS light/dark appearance. The app should not inject CSS or scripts to force YouTube's own page theme; YouTube remains responsible for its in-page light/dark behavior.

The native titlebar should own window movement and double-click zoom behavior. Do not layer invisible hit-test views above YouTube content, because they steal normal page clicks and scrolling.

## Window Behavior

V1 should use a standard resizable macOS window with hidden title text and a transparent native titlebar. The content view should extend under the titlebar so there is no permanent blank header strip.

Recommended implementation details:

- `NSWindow.StyleMask.titled`
- `NSWindow.StyleMask.fullSizeContentView`
- `closable`, `miniaturizable`, and `resizable`
- transparent or hidden titlebar appearance
- `isMovableByWindowBackground = false` so YouTube receives normal pointer and scroll events
- standard fullscreen support

Traffic-light controls can fade in when the pointer enters the native titlebar area. Because the content view extends behind the transparent titlebar, Tube reserves the revealed titlebar band for window drag handling and double-click zoom. Pointer and scroll events below that band should continue to flow to YouTube. Do not place a broad transparent hit-test view over YouTube content.

The revealed titlebar should include a compact glass control cluster near the stoplights with icon-only back and forward buttons. Use `NSGlassEffectView` where available and an `NSVisualEffectView` titlebar material fallback on older supported macOS versions.

## Native Commands

No visible browser chrome, but the app still needs browser affordances through the menu bar and shortcuts.

V1 commands:

- Back: `Command-[`
- Forward: `Command-]`
- Hover titlebar back/forward buttons
- Reload: `Command-R`
- Stop loading: `Escape`
- Open Current Page in Browser
- Reset YouTube Session
- Enter Full Screen: native macOS behavior
- Quit: native macOS behavior

Optional later commands:

- New Window
- Always on Top
- Hide Bezel in Full Screen
- Developer Inspect Mode

## Navigation Behavior

Tube opens `https://www.youtube.com` on launch.

Main-frame navigation should stay inside Tube only when it is part of the YouTube/Google experience required for normal use. Unrelated destinations should open in the user's default browser.

Initial internal domains:

- `youtube.com`
- `www.youtube.com`
- `m.youtube.com`
- `youtu.be`
- `youtube-nocookie.com`
- `accounts.google.com`
- `myaccount.google.com`
- `consent.google.com`
- `google.com` only where required for authentication/consent

Subframe navigation should generally be allowed because embedded login, consent, payment, and media flows may rely on frames. The stricter policy should apply to top-level destination changes.

## Session Model

Use persistent website storage by default.

Expected behavior:

- User signs in once.
- App restart preserves YouTube session.
- Cookies, cache, IndexedDB, and local storage persist through `WKWebsiteDataStore.default()`.
- Reset YouTube Session clears website data and reloads YouTube.

No app-owned analytics or tracking should be added in v1.

## Error States

When YouTube fails to load, show a native overlay inside the app frame.

The overlay should be sparse:

- short failure title
- retry button
- open in browser button
- no marketing copy

## Legal And Product Boundaries

Tube must remain a single-site browser.

Do not add:

- ad blocking
- sponsor skipping
- download/save media features
- transcript scraping
- injected custom CSS/JavaScript
- custom recommendation ranking
- background automation
- alternate playback controls that bypass YouTube UI

Features that are acceptable because they belong to the browser shell:

- native window frame
- menus and keyboard shortcuts
- reload/back/forward
- persistent session
- session reset
- external-link routing
- crash/error recovery

## Success Criteria

The app succeeds when:

- cold launch feels immediate for a native Mac app
- YouTube loads full-window with only a thin bezel visible
- playback works with normal YouTube behavior
- sign-in works
- restart preserves session
- external links do not trap users inside Tube
- no visible app UI competes with YouTube
