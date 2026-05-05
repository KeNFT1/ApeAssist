#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/Lulo Clippy.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  echo "Run scripts/package-app.sh first, or set APP_PATH=/path/to/Lulo\ Clippy.app" >&2
  exit 1
fi

# Safe local defaults. Posting is enabled for the local Gateway; the guard below refuses
# accidental non-local POSTs unless explicitly reviewed.
export LULO_OPENCLAW_HTTP_BASE_URL="${LULO_OPENCLAW_HTTP_BASE_URL:-http://127.0.0.1:18789}"
export LULO_OPENCLAW_WS_URL="${LULO_OPENCLAW_WS_URL:-ws://127.0.0.1:18789}"
export LULO_OPENCLAW_ENABLE_POST="${LULO_OPENCLAW_ENABLE_POST:-true}"

if [[ "$LULO_OPENCLAW_ENABLE_POST" == "true" ]]; then
  case "$LULO_OPENCLAW_HTTP_BASE_URL" in
    http://127.0.0.1:*|http://localhost:*|https://127.0.0.1:*|https://localhost:*) ;;
    *)
      echo "refusing to POST to non-local gateway URL by default: $LULO_OPENCLAW_HTTP_BASE_URL" >&2
      echo "Review docs/packaging-security.md before changing this guard." >&2
      exit 1
      ;;
  esac
fi

echo "Opening $APP_PATH"
echo "Gateway: $LULO_OPENCLAW_HTTP_BASE_URL"
echo "Bridge POST enabled: $LULO_OPENCLAW_ENABLE_POST"
open "$APP_PATH"
