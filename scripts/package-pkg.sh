#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="${APEASSIST_APP_NAME:-ApeAssist}"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/${APP_NAME}.app}"
PKG_IDENTIFIER="${APEASSIST_PKG_IDENTIFIER:-app.apeassist.mac.pkg}"
SKIP_APP_BUILD="${APEASSIST_SKIP_APP_BUILD:-false}"

cd "$ROOT_DIR"

if ! command -v pkgbuild >/dev/null 2>&1; then
  echo "pkgbuild is required to create a macOS installer package."
  echo "Install Apple's Command Line Tools or Xcode, then retry."
  exit 1
fi

if [[ "$SKIP_APP_BUILD" != "true" ]]; then
  "$SCRIPT_DIR/package-app.sh"
elif [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  echo "Unset APEASSIST_SKIP_APP_BUILD or run scripts/package-app.sh first."
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing Info.plist at $INFO_PLIST"
  exit 1
fi

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

APP_VERSION="${APEASSIST_PKG_VERSION:-$(read_plist_value CFBundleShortVersionString || true)}"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUNDLE_NAME="$(basename "$APP_PATH" .app)"
OUTPUT_PKG="${OUTPUT_PKG:-$ROOT_DIR/dist/${APP_BUNDLE_NAME}-${APP_VERSION}.pkg}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/apeassist-pkg.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
COMPONENT_PKG="$TMP_DIR/${APP_BUNDLE_NAME}-component.pkg"

mkdir -p "$(dirname "$OUTPUT_PKG")"
rm -f "$OUTPUT_PKG"

pkgbuild \
  --component "$APP_PATH" \
  --install-location /Applications \
  --identifier "$PKG_IDENTIFIER" \
  --version "$APP_VERSION" \
  "$COMPONENT_PKG"

# productbuild is optional for local unsigned installs. When available, wrap the
# component package into a product archive; otherwise emit the component pkg.
if command -v productbuild >/dev/null 2>&1; then
  productbuild --package "$COMPONENT_PKG" "$OUTPUT_PKG"
else
  cp "$COMPONENT_PKG" "$OUTPUT_PKG"
fi

if command -v pkgutil >/dev/null 2>&1; then
  pkgutil --check-signature "$OUTPUT_PKG" || true
  pkgutil --pkg-info-plist "$OUTPUT_PKG" >/dev/null 2>&1 || true
fi

echo "Packaged $OUTPUT_PKG"
echo "Install with: sudo installer -pkg '$OUTPUT_PKG' -target /"
