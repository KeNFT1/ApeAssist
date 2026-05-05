#!/usr/bin/env bash
set -euo pipefail

DMG_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$DMG_DIR/ApeAssist.app"
APP_DEST_DIR="$HOME/Applications"
APP_DEST="$APP_DEST_DIR/ApeAssist.app"
README_PATH="$DMG_DIR/README.txt"

clear || true
cat <<'TEXT'
ApeAssist setup
===============

This helper will copy ApeAssist into your user Applications folder and open it.
No administrator password is required.
TEXT

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "Could not find ApeAssist.app next to this setup helper."
  echo "Open the disk image again and run START HERE.command from inside it."
  exit 1
fi

mkdir -p "$APP_DEST_DIR"
if [[ -e "$APP_DEST" ]]; then
  BACKUP="$APP_DEST_DIR/ApeAssist-previous-$(date +%Y%m%d-%H%M%S).app"
  echo "Existing ApeAssist found; moving it to: $BACKUP"
  mv "$APP_DEST" "$BACKUP"
fi

echo "Copying ApeAssist to: $APP_DEST"
ditto "$APP_SOURCE" "$APP_DEST"

# Local ad-hoc builds copied from a DMG may inherit quarantine. Remove only from
# this app copy so nontechnical testers can open the trusted build Ken sent them.
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true
fi

cat <<'TEXT'

Next steps:
1. Install Tailscale: https://tailscale.com/download/mac
2. Log in to Ken's tailnet.
3. In ApeAssist Settings -> OpenClaw Bridge, choose "Mac mini over Tailscale".
4. Click "Pair with Ken's Pinchy" -> "Enter pairing code".
5. Paste Ken's pairing invite, enter the passphrase if needed, then click "Check Gateway".

Opening ApeAssist now...
TEXT

open "$APP_DEST"
if [[ -f "$README_PATH" ]]; then
  open -a TextEdit "$README_PATH" 2>/dev/null || open "$README_PATH" 2>/dev/null || true
fi

echo
read -r -p "Press Return to close this setup window. " _ || true
