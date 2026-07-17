# Releasing Tube

## Preconditions

- A Developer ID Application certificate for Tyler Reiff (team `Y8NYM9UVJR`) installed in the keychain.
- A `notarytool` keychain profile named `tube-notary`. Create it once with:

  ```sh
  xcrun notarytool store-credentials tube-notary \
    --apple-id <apple-id> \
    --team-id Y8NYM9UVJR
  ```

- `gh` CLI installed and authenticated (`gh auth status`).

## 1. Bump the version

Edit `Tube/Info.plist` and update all **three** version fields:

- `CFBundleShortVersionString` — the marketing version, e.g. `0.2.0`.
- `CFBundleVersion` — the build number; increment it (it must always go up).
- `CFBundleGetInfoString` — contains the version too, e.g. `Tube 0.2.0, Copyright © 2026 Tyler Reiff. All rights reserved.`

Commit with the message `Release Tube X.Y.Z`.

## 2. Build, sign, and notarize

```sh
scripts/release-app.sh --notary-profile tube-notary
```

This runs `swift test`, builds the release configuration, code-signs with your
Developer ID identity (auto-discovered from the keychain, or pass
`--identity`), creates a zip and DMG, notarizes and staples both, and runs a
Gatekeeper (`spctl`) assessment on each. Artifacts land in `Dist/` as:

- `Dist/Tube-X.Y.Z-build-N.dmg`
- `Dist/Tube-X.Y.Z-build-N.zip`

`X.Y.Z` and `N` are read from `Info.plist`, so make sure step 1 is committed
before running this.

## 3. Publish the GitHub release

```sh
gh release create vX.Y.Z \
  Dist/Tube-X.Y.Z-build-N.dmg \
  Dist/Tube-X.Y.Z-build-N.zip \
  --title "Tube X.Y.Z" \
  --notes "..."
```

## 4. Update the marketing site

The site in `site/` is hosted on Vercel via the GitHub integration (domain
`tube.thetylerreiff.co`); there is no Vercel config in this repo. Any push to
`main` auto-deploys in about a minute.

The download button and release-notes links in `site/index.html` are
hardcoded to a specific version/URL. Update them only **after** the GitHub
release assets from step 3 exist — if you push the site update first, it
serves a dead download link.

## Icon caveat

`scripts/generate-app-icon.sh` looks for a source image at
`docs/app-identity/tube-icon-retro-tv-master-clean.png`, which is not checked
into the repo. When that file is absent, the script falls back to the
already-committed `Tube/AppIcon.icns` and `Build/AssetCatalog/Assets.car`, so
normal builds still work. Regenerating the icon from scratch requires locating
that source PNG first.
