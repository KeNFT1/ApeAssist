#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="${APEASSIST_APP_NAME:-ApeAssist}"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/${APP_NAME}.app}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
DEST_PATH="$INSTALL_DIR/$(basename "$APP_PATH")"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  echo "Run scripts/package-app.sh first."
  exit 1
fi

mkdir -p "$INSTALL_DIR"
if [[ -e "$DEST_PATH" ]]; then
  BACKUP_PATH="$INSTALL_DIR/$(basename "$APP_PATH" .app)-previous-$(date +%Y%m%d-%H%M%S).app"
  echo "Existing app found; moving it to $BACKUP_PATH"
  mv "$DEST_PATH" "$BACKUP_PATH"
fi

cp -R "$APP_PATH" "$DEST_PATH"

if command -v codesign >/dev/null 2>&1; then
  codesign --verify --deep --strict "$DEST_PATH"
fi

echo "Installed $DEST_PATH"
echo "Open with: open '$DEST_PATH'"
