#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="${LULO_APP_NAME:-Lulo Clippy}"
BUNDLE_ID="${LULO_BUNDLE_ID:-com.lulo.LuloClippy}"
CONFIGURATION="${LULO_CONFIGURATION:-release}"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
ICON="$ROOT_DIR/Resources/AppIcon/LuloAppIcon.icns"

cd "$ROOT_DIR"

if [[ ! -f "$ICON" ]]; then
  echo "App icon missing; generating from sprite frame 4."
  "$SCRIPT_DIR/sprite_pipeline.py" icon
fi

swift build -c "$CONFIGURATION"
BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE="$BIN_PATH/lulo-clippy"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/Lulo Clippy"
cp "$ICON" "$APP_DIR/Contents/Resources/LuloAppIcon.icns"

# SwiftPM emits processed resources as bundles next to the executable. Keep any
# generated bundle intact so Bundle.module can still resolve Sprites/AppIcon.
find "$BIN_PATH" -maxdepth 1 -name '*.bundle' -type d -exec cp -R {} "$APP_DIR/Contents/Resources/" \;

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>Lulo Clippy</string>
  <key>CFBundleIconFile</key>
  <string>LuloAppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

echo "Packaged $APP_DIR"
