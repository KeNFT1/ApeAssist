#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
SETUP_DIR="$DIST_DIR/ApeAssist-Remote-Setup"
ZIP_PATH="$DIST_DIR/ApeAssist-Remote-Setup.zip"
PKG_PATH="${PKG_PATH:-$DIST_DIR/ApeAssist-0.1.0.pkg}"

cd "$ROOT_DIR"

if [[ ! -f "$PKG_PATH" ]]; then
  "$SCRIPT_DIR/package-pkg.sh"
fi

rm -rf "$SETUP_DIR" "$ZIP_PATH"
mkdir -p "$SETUP_DIR"
cp "$PKG_PATH" "$SETUP_DIR/$(basename "$PKG_PATH")"
cat > "$SETUP_DIR/README.txt" <<'EOF'
ApeAssist remote setup
======================

This installs ApeAssist, a macOS desktop sidekick that connects to Ken's OpenClaw/Pinchy backend.

Requirements:
1. macOS 14+.
2. Tailscale installed and logged into Ken's tailnet.
3. Ken must provide an ApeAssist pairing invite separately. If encrypted, Ken must also provide the passphrase.

Install:
1. Double-click ApeAssist-0.1.0.pkg.
2. If macOS blocks it because it is unsigned/local, right-click the pkg -> Open.
3. Open ApeAssist from Applications.
4. In ApeAssist Settings -> OpenClaw Bridge:
   - Choose: Mac mini over Tailscale
   - If Auth says no token is saved, use Pair with Ken's Pinchy -> Enter pairing code
   - Paste the ApeAssist invite Ken sends you
   - Enter the invite passphrase if Ken protected it
   - Click: Import Pairing Invite
   - Click: Check Gateway
5. Click the floating ape and ask a question.

Ken's invite command:

  scripts/create-pairing-invite.sh --output ~/Desktop/apeassist-invite.txt

Security note:
The pairing invite contains or decrypts to a Gateway token that can access Ken's OpenClaw backend. Do not post it publicly, forward it, or commit it anywhere. Ken should prefer encrypted invites and share the passphrase over a different channel.
EOF

(
  cd "$DIST_DIR"
  zip -qr "$(basename "$ZIP_PATH")" "$(basename "$SETUP_DIR")"
)

echo "Packaged $ZIP_PATH"
