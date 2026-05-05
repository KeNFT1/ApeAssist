#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_SOURCE_DIR="${LULO_CLIPPY_SOURCE_DIR:-$ROOT_DIR}"

if [[ ! -f "$APP_SOURCE_DIR/Package.swift" ]]; then
  echo "error: no Package.swift found at: $APP_SOURCE_DIR" >&2
  echo "Set LULO_CLIPPY_SOURCE_DIR=/path/to/app-source if needed." >&2
  exit 1
fi

# Safe local defaults. Posting remains disabled unless the caller explicitly exports true.
export LULO_OPENCLAW_HTTP_BASE_URL="${LULO_OPENCLAW_HTTP_BASE_URL:-${LULO_OPENCLAW_ENDPOINT:-http://127.0.0.1:18789}}"
export LULO_OPENCLAW_WS_URL="${LULO_OPENCLAW_WS_URL:-ws://127.0.0.1:18789}"
export LULO_OPENCLAW_ENABLE_POST="${LULO_OPENCLAW_ENABLE_POST:-false}"

if [[ "${LULO_OPENCLAW_ENABLE_POST}" == "true" ]]; then
  case "$LULO_OPENCLAW_HTTP_BASE_URL" in
    http://127.0.0.1:*|http://localhost:*|https://127.0.0.1:*|https://localhost:*) ;;
    *)
      echo "refusing to POST to non-local gateway URL by default: $LULO_OPENCLAW_HTTP_BASE_URL" >&2
      echo "Use a local Gateway URL for dev, or review docs/packaging-security.md before changing this guard." >&2
      exit 1
      ;;
  esac
fi

cd "$APP_SOURCE_DIR"
echo "Running LuloClippy from $APP_SOURCE_DIR"
echo "Gateway: $LULO_OPENCLAW_HTTP_BASE_URL"
echo "Bridge POST enabled: $LULO_OPENCLAW_ENABLE_POST"
swift run lulo-clippy "$@"
