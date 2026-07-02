# Tube

Tube is a minimal native macOS app for watching YouTube in a focused window.
It uses Swift, AppKit, and `WKWebView` instead of bundling a browser runtime.

The project is intentionally narrow: it opens YouTube, keeps browser chrome out
of the way, and avoids modifying YouTube content or behavior. Tube is not
affiliated with YouTube or Google.

## Features

- Native macOS window with standard traffic-light controls.
- Focused YouTube experience with no URL bar or permanent browser toolbar.
- Back, forward, reload, stop, and open-in-browser commands.
- Trackpad back/forward navigation that respects the macOS setting.
- YouTube/Google sign-in inside WebKit.
- Light and dark appearance support for the native app chrome.
- Small Vite-powered marketing site in `site/`.

## Requirements

- macOS 13 or newer.
- Xcode Command Line Tools with Swift 6 support.
- Node.js `^20.19.0` or `>=22.12.0` for the marketing site.

## Run The Mac App Locally

Clone the repo:

```sh
git clone https://github.com/thetylerreiff/Tube.git
cd Tube
```

Run the Swift tests:

```sh
swift test
```

Build a local app bundle:

```sh
scripts/build-app.sh debug
```

Launch the app:

```sh
open Build/Tube.app
```

For a release-style local build, use:

```sh
scripts/build-app.sh release
```

By default, local app bundles are ad-hoc signed. Production distribution
requires a Developer ID Application certificate and notarization.

## Run The Site Locally

Install dependencies:

```sh
cd site
npm install
```

Start the local dev server:

```sh
npm run dev
```

Build the static site:

```sh
npm run build
```

Preview the production build:

```sh
npm run preview
```

The site is intentionally separate from the macOS app. It is a small static
front end for project/download information.

## Release Builds

The release helper signs, packages, notarizes, staples, and validates the app:

```sh
scripts/release-app.sh \
  --identity "Developer ID Application: Your Name (TEAMID)" \
  --notary-profile tube-notary
```

Create the `notarytool` keychain profile before the first notarized release:

```sh
xcrun notarytool store-credentials tube-notary
```

## Privacy

Tube does not collect credentials, inject scripts, modify YouTube, or track
usage. Google and YouTube sign-in happen inside WebKit, and WebKit manages the
resulting website session.

## Contributing

Issues and pull requests are welcome. Please keep changes aligned with the
project scope: a small native Mac wrapper for YouTube, minimal chrome, and no
content injection or scraping.

Before opening a PR, run:

```sh
swift test
cd site
npm run build
```

## License

Tube is released under the [MIT License](LICENSE).
