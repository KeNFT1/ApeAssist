#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Override if the Swift app source moves.
APP_SOURCE_DIR="${LULO_CLIPPY_SOURCE_DIR:-$ROOT_DIR}"

if [[ ! -f "$APP_SOURCE_DIR/Package.swift" ]]; then
  echo "error: no Package.swift found at: $APP_SOURCE_DIR" >&2
  echo "Set LULO_CLIPPY_SOURCE_DIR=/path/to/app-source if needed." >&2
  exit 1
fi

cd "$APP_SOURCE_DIR"
echo "Building LuloClippy from $APP_SOURCE_DIR"
swift build "$@"
