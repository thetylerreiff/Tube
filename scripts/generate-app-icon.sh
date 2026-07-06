#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_IMAGE="${1:-$ROOT_DIR/docs/app-identity/tube-icon-retro-tv-master-clean.png}"
APPICONSET_DIR="$ROOT_DIR/Tube/Assets.xcassets/AppIcon.appiconset"
ASSETCATALOG_BUILD_DIR="$ROOT_DIR/Build/AssetCatalog"
PARTIAL_INFO_PLIST="$ROOT_DIR/Build/assetcatalog-info.plist"
ACTOOL_LOG="$ROOT_DIR/Build/actool.log"
ICNS_PATH="$ROOT_DIR/Tube/AppIcon.icns"

if [[ ! -f "$SOURCE_IMAGE" ]]; then
  if [[ -f "$ICNS_PATH" && -f "$ASSETCATALOG_BUILD_DIR/Assets.car" ]]; then
    echo "Icon source missing: $SOURCE_IMAGE; reusing existing icon artifacts" >&2
    echo "$ICNS_PATH"
    exit 0
  fi
  echo "Missing icon source: $SOURCE_IMAGE" >&2
  exit 66
fi

mkdir -p "$APPICONSET_DIR" "$ASSETCATALOG_BUILD_DIR"

render_icon() {
  local size="$1"
  local filename="$2"
  local destination="$APPICONSET_DIR/$filename"

  /usr/bin/sips -s format png -z "$size" "$size" "$SOURCE_IMAGE" --out "$destination" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

if ! /usr/bin/xcrun actool "$ROOT_DIR/Tube/Assets.xcassets" \
  --compile "$ASSETCATALOG_BUILD_DIR" \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$PARTIAL_INFO_PLIST" > /dev/null 2>"$ACTOOL_LOG"; then
  sed -n '1,200p' "$ACTOOL_LOG" >&2
  exit 1
fi

cp "$ASSETCATALOG_BUILD_DIR/AppIcon.icns" "$ICNS_PATH"

echo "$ICNS_PATH"
