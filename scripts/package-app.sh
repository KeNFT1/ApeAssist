#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="${APEASSIST_APP_NAME:-${LULO_APP_NAME:-ApeAssist}}"
BUNDLE_ID="${APEASSIST_BUNDLE_ID:-${LULO_BUNDLE_ID:-app.apeassist.mac}}"
CONFIGURATION="${LULO_CONFIGURATION:-release}"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
ICON="$ROOT_DIR/Resources/AppIcon/LuloAppIcon.icns"
EXECUTABLE_NAME="${APEASSIST_EXECUTABLE_NAME:-ApeAssist}"
MIN_MACOS_VERSION="${APEASSIST_MIN_MACOS_VERSION:-14.0}"
ARCHS="${APEASSIST_ARCHS:-arm64 x86_64}"

cd "$ROOT_DIR"

if [[ ! -f "$ICON" ]]; then
  echo "App icon missing; generating from sprite frame 4."
  "$SCRIPT_DIR/sprite_pipeline.py" icon
fi

IFS=' ' read -r -a requested_archs <<< "$ARCHS"
if [[ ${#requested_archs[@]} -eq 0 ]]; then
  echo "APEASSIST_ARCHS must contain at least one architecture (for example: arm64 x86_64)." >&2
  exit 1
fi

EXECUTABLE_INPUTS=()
RESOURCE_BIN_PATH=""
for arch in "${requested_archs[@]}"; do
  case "$arch" in
    arm64|x86_64) ;;
    *)
      echo "Unsupported architecture '$arch'. Use arm64 and/or x86_64." >&2
      exit 1
      ;;
  esac
  TRIPLE="${arch}-apple-macosx${MIN_MACOS_VERSION}"
  echo "Building ${APP_NAME} for ${arch} (macOS ${MIN_MACOS_VERSION}+)."
  swift build -c "$CONFIGURATION" --triple "$TRIPLE"
  BIN_PATH="$(swift build -c "$CONFIGURATION" --triple "$TRIPLE" --show-bin-path)"
  EXECUTABLE="$BIN_PATH/lulo-clippy"
  if [[ ! -x "$EXECUTABLE" ]]; then
    echo "Missing built executable: $EXECUTABLE" >&2
    exit 1
  fi
  EXECUTABLE_INPUTS+=("$EXECUTABLE")
  RESOURCE_BIN_PATH="${RESOURCE_BIN_PATH:-$BIN_PATH}"
done

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

if [[ ${#EXECUTABLE_INPUTS[@]} -eq 1 ]]; then
  cp "${EXECUTABLE_INPUTS[0]}" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
else
  lipo -create "${EXECUTABLE_INPUTS[@]}" -output "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
fi
chmod 755 "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ICON" "$APP_DIR/Contents/Resources/LuloAppIcon.icns"

# SwiftPM emits processed resources as bundles next to the executable. Keep any
# generated bundle intact so Bundle.module can still resolve Sprites/AppIcon.
find "$RESOURCE_BIN_PATH" -maxdepth 1 -name '*.bundle' -type d -exec cp -R {} "$APP_DIR/Contents/Resources/" \;

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
  <string>${EXECUTABLE_NAME}</string>
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
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS_VERSION}</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSLocalNetworkUsageDescription</key>
  <string>ApeAssist can connect to a local OpenClaw Gateway when bridge POST mode is enabled.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>ApeAssist may use the microphone for voice input if you enable voice features in a future build.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>ApeAssist may use speech recognition for voice commands if you enable voice features in a future build.</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null
  codesign --verify --deep --strict "$APP_DIR"
fi

if command -v lipo >/dev/null 2>&1; then
  lipo -archs "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
fi

echo "Packaged $APP_DIR"
