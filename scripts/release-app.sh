#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Tube"
INFO_PLIST="$ROOT_DIR/Tube/Info.plist"
DIST_DIR="${TUBE_DIST_DIR:-$ROOT_DIR/Dist}"
IDENTITY="${TUBE_CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${TUBE_NOTARY_PROFILE:-}"
SKIP_NOTARIZATION=0
DMG_STAGING_DIR=""
DMG_MOUNT_DIR=""
DMG_IS_MOUNTED=0

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/release-app.sh [options]

Builds, Developer ID signs, packages, notarizes, staples, and validates Tube.

Options:
  --identity NAME          Developer ID Application signing identity.
  --notary-profile NAME   notarytool keychain profile created with xcrun notarytool store-credentials.
  --dist-dir PATH         Output directory. Defaults to ./Dist.
  --skip-notarization     Build signed zip/dmg artifacts without notarizing. Not production-ready.
  -h, --help              Show this help.

Environment:
  TUBE_CODESIGN_IDENTITY  Same as --identity.
  TUBE_NOTARY_PROFILE     Same as --notary-profile.
  TUBE_DIST_DIR           Same as --dist-dir.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

cleanup() {
  if [[ "$DMG_IS_MOUNTED" -eq 1 ]]; then
    hdiutil detach "$DMG_MOUNT_DIR" >/dev/null 2>&1 || true
  fi

  if [[ -n "$DMG_STAGING_DIR" && -d "$DMG_STAGING_DIR" ]]; then
    rm -rf "$DMG_STAGING_DIR"
  fi

  if [[ -n "$DMG_MOUNT_DIR" && -d "$DMG_MOUNT_DIR" ]]; then
    rmdir "$DMG_MOUNT_DIR" 2>/dev/null || true
  fi
}

trap cleanup EXIT

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST"
}

discover_developer_id_identity() {
  local identities count
  identities="$(security find-identity -p codesigning -v | awk -F '"' '/Developer ID Application/ { print $2 }')"
  count="$(printf '%s\n' "$identities" | sed '/^$/d' | wc -l | tr -d ' ')"

  case "$count" in
    0)
      return 1
      ;;
    1)
      printf '%s\n' "$identities" | sed '/^$/d'
      ;;
    *)
      echo "Multiple Developer ID Application identities found:" >&2
      printf '%s\n' "$identities" | sed '/^$/d' >&2
      fail "pass --identity with the exact signing identity to use"
      ;;
  esac
}

submit_for_notarization() {
  local artifact="$1"
  xcrun notarytool submit "$artifact" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity)
      [[ $# -ge 2 ]] || fail "--identity requires a value"
      IDENTITY="$2"
      shift 2
      ;;
    --notary-profile)
      [[ $# -ge 2 ]] || fail "--notary-profile requires a value"
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --dist-dir)
      [[ $# -ge 2 ]] || fail "--dist-dir requires a value"
      DIST_DIR="$2"
      shift 2
      ;;
    --skip-notarization)
      SKIP_NOTARIZATION=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      fail "unknown option: $1"
      ;;
  esac
done

require_tool swift
require_tool codesign
require_tool security
require_tool ditto
require_tool hdiutil
require_tool spctl
require_tool xcrun

VERSION="$(plist_value CFBundleShortVersionString)"
BUILD="$(plist_value CFBundleVersion)"
RELEASE_NAME="$APP_NAME-$VERSION-build-$BUILD"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$RELEASE_NAME.zip"
DMG_PATH="$DIST_DIR/$RELEASE_NAME.dmg"

if [[ -z "$IDENTITY" ]]; then
  if ! IDENTITY="$(discover_developer_id_identity)"; then
    fail "no Developer ID Application signing identity found. Install the certificate in Keychain Access or pass --identity."
  fi
fi

if [[ "$IDENTITY" == "-" ]]; then
  fail "ad-hoc signing is not allowed for production releases"
fi

if [[ "$SKIP_NOTARIZATION" -eq 0 && -z "$NOTARY_PROFILE" ]]; then
  fail "notarization requires --notary-profile. Create one with: xcrun notarytool store-credentials <profile-name>"
fi

mkdir -p "$DIST_DIR"

echo "==> Running tests"
swift test

echo "==> Building and signing $APP_NAME.app"
TUBE_APP_DIR="$APP_DIR" TUBE_CODESIGN_IDENTITY="$IDENTITY" "$ROOT_DIR/scripts/build-app.sh" release >/dev/null

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
codesign -dvvv --entitlements :- "$APP_DIR"

echo "==> Creating notarization zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
  echo "==> Notarizing app zip"
  submit_for_notarization "$ZIP_PATH"

  echo "==> Stapling app"
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"

  echo "==> Gatekeeper app assessment"
  spctl -a -vv "$APP_DIR"

  echo "==> Recreating zip with stapled app"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
else
  echo "warning: skipping notarization; artifacts are not production-ready" >&2
fi

echo "==> Creating dmg"
rm -f "$DMG_PATH"
DMG_STAGING_DIR="$(mktemp -d "$DIST_DIR/.dmg-root.XXXXXX")"
ditto "$APP_DIR" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "==> Signing dmg"
codesign --force --sign "$IDENTITY" --timestamp "$DMG_PATH"

echo "==> Verifying dmg"
hdiutil verify "$DMG_PATH"
DMG_MOUNT_DIR="$(mktemp -d "$DIST_DIR/.dmg-mount.XXXXXX")"
hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "$DMG_MOUNT_DIR" \
  "$DMG_PATH" >/dev/null
DMG_IS_MOUNTED=1
[[ -d "$DMG_MOUNT_DIR/$APP_NAME.app" ]] || fail "dmg is missing $APP_NAME.app"
[[ -L "$DMG_MOUNT_DIR/Applications" ]] || fail "dmg is missing the Applications symlink"
[[ "$(readlink "$DMG_MOUNT_DIR/Applications")" == "/Applications" ]] \
  || fail "dmg Applications symlink does not target /Applications"
hdiutil detach "$DMG_MOUNT_DIR" >/dev/null
DMG_IS_MOUNTED=0
rmdir "$DMG_MOUNT_DIR"
DMG_MOUNT_DIR=""

if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
  echo "==> Notarizing dmg"
  submit_for_notarization "$DMG_PATH"

  echo "==> Stapling dmg"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"

  echo "==> Gatekeeper dmg assessment"
  spctl -a -vv --type open --context context:primary-signature "$DMG_PATH"
fi

echo "Release artifacts:"
echo "  $APP_DIR"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
