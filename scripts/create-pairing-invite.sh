#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${APEASSIST_PAIRING_ENDPOINT:-https://pinchys-mac-mini.taild71e14.ts.net/}"
CONFIG_PATH="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
SESSION_TARGET="${APEASSIST_PAIRING_SESSION:-agent:main:clippy:remote}"
AGENT_TARGET="${APEASSIST_PAIRING_AGENT:-openclaw/default}"
LABEL="${APEASSIST_PAIRING_LABEL:-Ken’s Pinchy}"
MODE="encrypted"
OUTPUT_FILE=""

usage() {
  cat <<'EOF'
Usage: scripts/create-pairing-invite.sh [--endpoint URL] [--output PATH] [--cleartext]

Creates a pasteable ApeAssist pairing invite from the local OpenClaw config.
The Gateway token is read at runtime and is never printed in plaintext.

Default endpoint: https://pinchys-mac-mini.taild71e14.ts.net/
Default mode: passphrase-encrypted invite (recommended)

Environment overrides:
  OPENCLAW_CONFIG=/path/to/openclaw.json
  APEASSIST_PAIRING_ENDPOINT=https://...
  APEASSIST_PAIRING_SESSION=agent:main:clippy:remote
  APEASSIST_PAIRING_AGENT=openclaw/default
  APEASSIST_PAIRING_LABEL="Ken's Pinchy"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)
      ENDPOINT="${2:?missing endpoint}"
      shift 2
      ;;
    --output|-o)
      OUTPUT_FILE="${2:?missing output path}"
      shift 2
      ;;
    --cleartext)
      MODE="cleartext"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Missing OpenClaw config: $CONFIG_PATH" >&2
  exit 1
fi

PYTHON="$(command -v python3 || command -v python || true)"
if [[ -z "$PYTHON" ]]; then
  echo "python3 is required to read $CONFIG_PATH" >&2
  exit 1
fi

json_payload="$($PYTHON - "$CONFIG_PATH" "$ENDPOINT" "$SESSION_TARGET" "$AGENT_TARGET" "$LABEL" <<'PY'
import datetime, json, sys
config_path, endpoint, session, agent, label = sys.argv[1:]
with open(config_path, 'r', encoding='utf-8') as f:
    config = json.load(f)

def find_token(obj):
    if not isinstance(obj, dict):
        return None
    gateway = obj.get('gateway') if isinstance(obj.get('gateway'), dict) else {}
    auth = gateway.get('auth') if isinstance(gateway.get('auth'), dict) else {}
    for key in ('token', 'bearerToken', 'password'):
        value = auth.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    root_auth = obj.get('auth') if isinstance(obj.get('auth'), dict) else {}
    for key in ('token', 'bearerToken', 'password'):
        value = root_auth.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None

token = find_token(config)
if not token:
    print('Could not find gateway.auth.token in OpenClaw config.', file=sys.stderr)
    sys.exit(2)

payload = {
    'version': 1,
    'endpoint': endpoint,
    'token': token,
    'session': session,
    'agentTarget': agent,
    'label': label,
    'createdAt': datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z'),
}
print(json.dumps(payload, separators=(',', ':')))
PY
)"

if [[ "$MODE" == "cleartext" ]]; then
  invite="APEASSIST-INVITE-v1:$(printf '%s' "$json_payload" | /usr/bin/base64 | tr -d '\n')"
  echo "SECURITY WARNING: this cleartext invite contains the Gateway token (base64 JSON). Deliver it only over a trusted channel." >&2
else
  if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl is required for encrypted invites. Re-run with --cleartext only if you accept the risk." >&2
    exit 1
  fi
  echo "Enter a passphrase for the recipient to type into ApeAssist." >&2
  echo "Use a different channel than the invite itself if possible." >&2
  cipher="$(printf '%s' "$json_payload" | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -a -A)"
  invite="APEASSIST-INVITE-ENC-v1:$cipher"
fi

if [[ -n "$OUTPUT_FILE" ]]; then
  umask 077
  printf '%s\n' "$invite" > "$OUTPUT_FILE"
  echo "Wrote pairing invite to $OUTPUT_FILE"
else
  printf '%s\n' "$invite"
fi
