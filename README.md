# ApeAssist

ApeAssist is a native macOS floating AI sidekick powered by OpenClaw. It gives your local OpenClaw agent a small always-on-top desktop buddy: part quick chat launcher, part status indicator, part approval surface for risky actions.

The current character/art direction is Lulo: a playful ape desktop companion with BAYC-inspired taste. ApeAssist is an independent project and is not affiliated with, endorsed by, or sponsored by Yuga Labs or Bored Ape Yacht Club.

## Highlights

- Floating transparent desktop buddy window (`NSPanel`) with animated ape sprite states.
- Menu bar accessory app with controls to show/hide the buddy, open chat, open settings, and quit.
- SwiftUI chat panel with message history, local dry-run replies, media preview, and opt-in live OpenClaw replies.
- Speech bubble on the floating buddy for the latest assistant response, sized to the response with scrolling for long text.
- Push-to-talk voice/status seam: hold Option+Space while ApeAssist is focused to preview `listening` state. No audio is recorded yet.
- Local-only speech playback hook using macOS `AVSpeechSynthesizer` for short previews/status snippets. No external TTS is called.
- Notification permission/status controller with an explicit Settings button; permission is not requested automatically.
- Risky-action confirmation scaffolding for external sends, browser/app clicks, file deletion, trading/financial actions, and config changes.
- Setup/Settings flow for local OpenClaw or a remote Mac mini over Tailscale, with Gateway token storage in macOS Keychain.
- Pairing-invite import for remote setup, so Ken can send an encrypted invite instead of sharing the raw Gateway token in chat.
- `OpenClawBridge` + `OpenClawClient` seam for local OpenClaw/Gateway integration.

## Sprite sheet

ApeAssist currently packages Lulo desktop buddy art from:

```text
Resources/Sprites/lulo-sprite-sheet.png       # original/provenance sheet
Resources/Sprites/lulo-sprite-sheet.json
Resources/Sprites/Frames/lulo-00.png ...      # locally sliced runtime frames
Resources/AppIcon/LuloAppIcon.icns            # package icon derived from frame 4
```

The PNG is a 4×4, 1024×1024 sprite sheet: 16 square frames at 256×256 each. The JSON defines animation frame indexes:

- `idle`: frames `0...3`
- `wave`: frames `4...7`
- `thinking`: frames `8...11` (also used as the listening placeholder until voice input lands)
- `talking`: frames `12...15`

`LuloSpriteView` loads these files through `Bundle.module`, prefers the pre-sliced `Frames/lulo-XX.png` assets for cheaper rendering, and falls back to row/column sheet cropping if the derived frames are missing. To inspect/regenerate/key/slice/iconize assets locally without external services:

```bash
scripts/sprite_pipeline.py inspect
scripts/sprite_pipeline.py all
```

See `docs/sprite-assets.md` for asset quality notes, chroma-key options, and packaging details.

## Assistant states

`AssistantStatus` supports `idle`, `wave`, `listening`, `thinking`, `needsConfirmation`, and `talking`.

- The buddy idles normally.
- Sending a chat message sets `thinking` while `OpenClawBridge.send` is in flight.
- After an assistant response, ApeAssist switches to `talking` briefly, then returns to `idle`.
- If a tool/action proposal looks risky, ApeAssist switches to `needsConfirmation` and shows approval UI instead of executing.
- Holding Option+Space while ApeAssist is focused sets `listening`; release returns through `thinking` to `idle`. This is only a state seam and does not record audio.
- Local speech preview sets `talking` for the duration of AVSpeechSynthesizer playback.
- The menu bar and Settings include preview/debug controls for state and animation speed.

## Voice and notifications

See [`docs/voice-notifications.md`](docs/voice-notifications.md) for the full policy and implementation notes.

Current safety defaults:

- No audio capture or transcription.
- No external TTS.
- No automatic notification permission prompt; the user must click the Settings button.

## Risky-action confirmations

ApeAssist treats these action classes as requiring explicit user confirmation before execution:

- external sends/posts/uploads/messages
- browser or app clicks/form submissions
- file deletion/destructive overwrites
- trading, payments, withdrawals, purchases, or other financial actions
- Gateway/app/security/automation configuration changes

The current Swift implementation is intentionally a safe scaffold: `OpenClawBridge` detects likely risky requests/replies, enqueues a `PendingAction`, and renders approval cards plus a `ConfirmationSheet` with details and **Approve once** / **Deny** buttons. Approving currently records intent only; Gateway approval dispatch remains stubbed until the native protocol is finalized.

## Build and run

```bash
cd /Users/pinchy/.openclaw/workspace/lulo-clippy
swift build
swift run lulo-clippy

# Optional local .app bundle with the generated app icon
scripts/package-app.sh
```

The app uses `.accessory` activation policy, so it behaves like a menu bar app instead of a normal Dock app. Look for ApeAssist in the macOS menu bar.

## Clickable local `.app`

For a Finder-clickable local dev build, package the SwiftPM executable into a minimal app bundle:

```bash
cd /Users/pinchy/.openclaw/workspace/lulo-clippy
scripts/package-app.sh
open "dist/ApeAssist.app"
```

Or use the guarded launcher:

```bash
scripts/open-app.sh
```

`package-app.sh` builds `lulo-clippy` in release mode by default, assembles `dist/ApeAssist.app`, copies SwiftPM resource bundles, installs `Resources/AppIcon/LuloAppIcon.icns`, and ad-hoc signs the result for local launch. If the icon is missing, it regenerates it locally from the local sprite pipeline. It does **not** install launch agents, login items, global config, or make permanent system changes.

Useful overrides:

```bash
LULO_CONFIGURATION=debug scripts/package-app.sh
APEASSIST_APP_NAME="ApeAssist Dev" scripts/package-app.sh
APP_PATH="dist/ApeAssist.app" scripts/open-app.sh
```

Legacy `LULO_APP_NAME` / `LULO_BUNDLE_ID` environment overrides are still accepted by the package script for compatibility.

## Install

### Installer package into `/Applications`

Build a local unsigned `.pkg` installer and install ApeAssist into `/Applications`:

```bash
scripts/package-pkg.sh
sudo installer -pkg dist/ApeAssist-0.1.0.pkg -target /
open "/Applications/ApeAssist.app"
```

`package-pkg.sh` calls `scripts/package-app.sh` first, then packages `dist/ApeAssist.app` with `pkgbuild` and `productbuild` when available. The installer output is `dist/ApeAssist-<version>.pkg` and uses package identifier `app.apeassist.mac.pkg` by default.

This package is intentionally unsigned unless you build it with your own Developer ID Installer certificate. Local unsigned packages/apps can trip Gatekeeper or quarantine prompts if copied between machines. For local testing, right-click/Open once in Finder or remove quarantine from the local build if you trust it:

```bash
xattr -dr com.apple.quarantine "/Applications/ApeAssist.app"
```

Optional overrides:

```bash
APEASSIST_PKG_IDENTIFIER="app.apeassist.mac.pkg.dev" scripts/package-pkg.sh
APEASSIST_SKIP_APP_BUILD=true APP_PATH="dist/ApeAssist.app" scripts/package-pkg.sh
OUTPUT_PKG="dist/ApeAssist.pkg" scripts/package-pkg.sh
```

To uninstall a package-installed local build:

```bash
sudo rm -rf "/Applications/ApeAssist.app"
pkgutil --forget app.apeassist.mac.pkg 2>/dev/null || true
```

### User-local app copy

Build and install a local `.app` bundle without a pkg:

```bash
scripts/package-app.sh
scripts/install-app.sh
open "$HOME/Applications/ApeAssist.app"
```

`install-app.sh` copies the app to `~/Applications` by default and moves any previous install aside with a timestamped backup. Use `INSTALL_DIR=/Applications scripts/install-app.sh` if you want a system-wide install without building a pkg.

## OpenClaw bridge configuration

The bridge supports two setup modes in Settings:

1. **This Mac** — ApeAssist talks to OpenClaw on the same machine at `http://127.0.0.1:18789`.
2. **Mac mini over Tailscale** — ApeAssist talks to a remote OpenClaw Gateway on your tailnet, for example `http://<mac-mini-tailscale-ip>:18789`.

Gateway bearer tokens are stored in macOS Keychain (`app.apeassist.gateway`) instead of source or plain `UserDefaults`. Legacy prototype tokens from `UserDefaults` are migrated automatically.

The bridge is local-first. By default, it targets the local OpenClaw Gateway; you can disable POST mode in Settings or with `LULO_OPENCLAW_ENABLE_POST=false` to force dry-run placeholder replies.

Defaults are intentionally local and do not include secrets:

- HTTP base URL: `http://127.0.0.1:18789`
- WebSocket URL: `ws://127.0.0.1:18789`
- Session: `agent:main:clippy:local`
- Agent target: `openclaw/default`
- POST mode: on for the local Gateway unless disabled

Non-secret Settings fields are stored in `UserDefaults`. Secrets go to Keychain. You can also override development settings with environment variables:

```bash
export LULO_OPENCLAW_HTTP_BASE_URL="http://127.0.0.1:18789"
export LULO_OPENCLAW_WS_URL="ws://127.0.0.1:18789"
export LULO_OPENCLAW_SESSION="agent:main:clippy:local"
export LULO_OPENCLAW_AGENT="openclaw/default"
export LULO_OPENCLAW_MODEL="" # optional provider/model override
export LULO_OPENCLAW_TOKEN="replace-with-local-token"
export LULO_OPENCLAW_ENABLE_POST=true

swift run lulo-clippy
```

Settings also includes **Check Gateway**, which calls `GET /v1/models` to verify the base URL/auth without sending a chat turn.

When POST mode is enabled, the chat panel calls OpenClaw's documented OpenResponses-compatible Gateway endpoint:

```text
POST http://127.0.0.1:18789/v1/responses
```

Request body:

```json
{
  "model": "openclaw/default",
  "input": "user text",
  "instructions": null,
  "stream": false,
  "user": "agent:main:clippy:local"
}
```

Headers:

```http
Authorization: Bearer <optional gateway token/password>
x-openclaw-session-key: agent:main:clippy:local
x-openclaw-model: <optional provider/model override>
```

The client parses both top-level `output_text` and item-based `output[].content[].text` response bodies, truncates long HTTP error bodies, and shows useful hints for auth failures or disabled endpoints.

### Remote Mac mini over Tailscale

For another Mac to use the Mac mini backend:

1. Install and log in to Tailscale on both Macs.
2. Keep OpenClaw running on the Mac mini with `/v1/responses` enabled and token auth.
3. Configure the Gateway to listen on the tailnet IP (`gateway.bind = "tailnet"`) **or** enable Tailscale Serve in your tailnet and use `gateway.tailscale.mode = "serve"`.
4. In ApeAssist Settings choose **Mac mini over Tailscale**.
5. If no token is saved, use **Pair with Ken’s Pinchy** → **Enter pairing code**.
6. Paste Ken’s ApeAssist invite, enter the passphrase if the invite is encrypted, click **Import Pairing Invite**, then click **Check Gateway**.

Ken can create an encrypted invite without printing the raw token:

```bash
scripts/create-pairing-invite.sh --output ~/Desktop/apeassist-invite.txt
```

By default the script reads `~/.openclaw/openclaw.json` at runtime, uses endpoint `https://pinchys-mac-mini.taild71e14.ts.net/`, prompts for an OpenSSL passphrase, and writes a payload beginning with `APEASSIST-INVITE-ENC-v1:`. Share the passphrase over a different channel when possible. A clear base64 JSON invite is available only for last-resort/manual delivery:

```bash
scripts/create-pairing-invite.sh --cleartext --output ~/Desktop/apeassist-invite.txt
```

Clear invites contain the token after base64 decoding. Do not post either invite type publicly, commit it, or leave it in shared folders.


Current Tailscale Serve endpoint for this Mac mini:

```text
https://pinchys-mac-mini.taild71e14.ts.net/
```

Tailscale encrypts tailnet traffic, but the HTTP API still requires the Gateway token. Pairing invites are just a safer delivery wrapper around that token until OpenClaw exposes a scoped token/pairing endpoint. Do not expose this with Tailscale Funnel/public internet unless you intentionally harden auth and TLS.

Note: OpenClaw's `/v1/responses` endpoint is disabled by default. Enable the Gateway HTTP endpoint before turning on POST mode; do not put tokens in source:

```json5
{
  gateway: {
    http: {
      endpoints: {
        responses: { enabled: true }
      }
    }
  }
}
```

## Structure

```text
LuloClippyApp
├── AppDelegate
│   └── FloatingBuddyController   # AppKit always-on-top buddy panel
├── MenuBarControls               # SwiftUI MenuBarExtra actions
├── ChatPanelView                 # SwiftUI chat UI
├── OpenClawBridge                # Dry-run / opt-in OpenClaw seam
├── OpenClawClient                # Async OpenResponses client + WS placeholder
└── SettingsView                  # Gateway/session/agent settings
```

## Next steps

1. Add SSE streaming, cancellation, and tool-progress state to `OpenClawBridge`.
2. Decide whether ApeAssist should use an isolated session (`agent:main:clippy:local`) or Ken's main session.
3. Persist chat history.
4. Replace the local dev bundle script with a Developer ID signed/notarized release flow when distribution is needed.
