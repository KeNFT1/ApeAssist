#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="${APEASSIST_APP_NAME:-ApeAssist}"
APP_PATH="${APP_PATH:-$DIST_DIR/${APP_NAME}.app}"
SKIP_APP_BUILD="${APEASSIST_SKIP_APP_BUILD:-false}"
OUTPUT_DMG="${OUTPUT_DMG:-}"
DMG_VOLUME_NAME="${APEASSIST_DMG_VOLUME_NAME:-ApeAssist Remote Setup}"
TEMPLATE_DIR="$ROOT_DIR/packaging/dmg"

cd "$ROOT_DIR"

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required to create a macOS DMG." >&2
  exit 1
fi

if [[ "$SKIP_APP_BUILD" != "true" ]]; then
  "$SCRIPT_DIR/package-app.sh"
elif [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  echo "Unset APEASSIST_SKIP_APP_BUILD or run scripts/package-app.sh first." >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
read_plist_value() {
  local key="$1"
  if command -v plutil >/dev/null 2>&1; then
    plutil -extract "$key" raw -o - "$INFO_PLIST" 2>/dev/null && return 0
  fi
  if [[ -x /usr/libexec/PlistBuddy ]]; then
    /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null && return 0
  fi
  return 1
}

APP_VERSION="${APEASSIST_DMG_VERSION:-$(read_plist_value CFBundleShortVersionString || true)}"
APP_VERSION="${APP_VERSION:-0.1.0}"
if [[ -z "$OUTPUT_DMG" ]]; then
  OUTPUT_DMG="$DIST_DIR/${APP_NAME}-${APP_VERSION}.dmg"
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/apeassist-dmg-staging.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

mkdir -p "$DIST_DIR"
rm -f "$OUTPUT_DMG"

cp -R "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"
cp "$TEMPLATE_DIR/README.txt" "$STAGING_DIR/README.txt"
cp "$TEMPLATE_DIR/START HERE.command" "$STAGING_DIR/START HERE.command"
chmod +x "$STAGING_DIR/START HERE.command"
ln -s /Applications "$STAGING_DIR/Applications"

# Keep the image compact while leaving enough room for filesystem metadata.
APP_SIZE_KB="$(du -sk "$STAGING_DIR" | awk '{print $1}')"
DMG_SIZE_MB="$(( (APP_SIZE_KB / 1024) + 64 ))"
TMP_DMG="$DIST_DIR/.${APP_NAME}-${APP_VERSION}.rw.dmg"
rm -f "$TMP_DMG"

hdiutil create \
  -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -size "${DMG_SIZE_MB}m" \
  "$TMP_DMG" >/dev/null

hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG" >/dev/null
rm -f "$TMP_DMG"

hdiutil verify "$OUTPUT_DMG" >/dev/null

echo "Packaged $OUTPUT_DMG"
echo "DMG contains: ${APP_NAME}.app, START HERE.command, README.txt, and an Applications shortcut."
