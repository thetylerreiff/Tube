#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
APP_DIR="${TUBE_APP_DIR:-$ROOT_DIR/Build/Tube.app}"
CODESIGN_IDENTITY="${TUBE_CODESIGN_IDENTITY:--}"

case "$CONFIGURATION" in
  debug|release)
    ;;
  *)
    echo "Usage: scripts/build-app.sh [debug|release]" >&2
    exit 64
    ;;
esac

swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_PATH="$ROOT_DIR/Tube/AppIcon.icns"
ASSETS_CAR_PATH="$ROOT_DIR/Build/AssetCatalog/Assets.car"
GENERATED_ICON_PATH="$ROOT_DIR/Build/AssetCatalog/AppIcon.icns"

"$ROOT_DIR/scripts/generate-app-icon.sh" >/dev/null

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/Tube" "$MACOS_DIR/Tube"
cp "$ROOT_DIR/Tube/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -f "$GENERATED_ICON_PATH" ]]; then
  cp "$GENERATED_ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"
elif [[ -f "$ICON_PATH" ]]; then
  cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"
else
  echo "No app icon is available; the bundle will use the macOS default icon" >&2
fi

if [[ -f "$ASSETS_CAR_PATH" ]]; then
  cp "$ASSETS_CAR_PATH" "$RESOURCES_DIR/Assets.car"
fi

codesign_args=(
  --force
  --sign "$CODESIGN_IDENTITY"
  --entitlements "$ROOT_DIR/Tube/Tube.entitlements"
)

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--options runtime --timestamp)
fi

codesign "${codesign_args[@]}" "$APP_DIR"

echo "$APP_DIR"
