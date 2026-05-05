# Lulo Clippy

A small native macOS “Clippy for OpenClaw” scaffold, built with SwiftUI + AppKit and Swift Package Manager.

## Included

- Floating always-on-top desktop buddy window (`NSPanel`) with animated Lulo sprite states.
- Menu bar accessory app with:
  - show/hide desktop buddy
  - open chat panel
  - open settings
  - quit
- SwiftUI chat panel with message list, input, send button, local dry-run replies, and opt-in live OpenClaw replies.
- Push-to-talk voice/status seam: hold Option+Space while Lulo is focused to preview `listening` state. No audio is recorded yet.
- Local-only speech playback hook using macOS `AVSpeechSynthesizer` for short previews/status snippets. No external TTS is called.
- Notification permission/status controller with an explicit Settings button; permission is not requested automatically.
- Risky-action confirmation scaffolding: local `ActionRisk` / `PendingAction` models plus approval cards and a detail sheet for external sends, browser/app clicks, file deletion, trading/financial actions, and config changes.
- Settings for OpenClaw Gateway HTTP/WS URLs, session target, agent target, optional model override, bearer token, POST enablement, voice preview, sprite preview, and notification status.
- `OpenClawBridge` + `OpenClawClient` seam for local OpenClaw/Gateway integration.

## Sprite sheet

Lulo's desktop buddy art is packaged from:

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
- After an assistant response, Lulo switches to `talking` briefly, then returns to `idle`.
- If a tool/action proposal looks risky, Lulo switches to `needsConfirmation` and shows approval UI instead of executing.
- Holding Option+Space while Lulo is focused sets `listening`; release returns through `thinking` to `idle`. This is only a state seam and does not record audio.
- Local speech preview sets `talking` for the duration of AVSpeechSynthesizer playback.
- The menu bar and Settings include preview/debug controls for state and animation speed.

## Voice and notifications

See [`docs/voice-notifications.md`](docs/voice-notifications.md) for the full policy and implementation notes.

Current safety defaults:

- No audio capture or transcription.
- No external TTS.
- No automatic notification permission prompt; the user must click the Settings button.

## Risky-action confirmations

Lulo treats these action classes as requiring explicit user confirmation before execution:

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

# Optional local .app bundle with the generated Lulo icon
scripts/package-app.sh
```

The app uses `.accessory` activation policy, so it behaves like a menu bar app instead of a normal Dock app. Look for the paperclip icon in the macOS menu bar.

## Clickable local `.app`

For a Finder-clickable local dev build, package the SwiftPM executable into a minimal app bundle:

```bash
cd /Users/pinchy/.openclaw/workspace/lulo-clippy
scripts/package-app.sh
open "dist/Lulo Clippy.app"
```

Or use the guarded launcher:

```bash
scripts/open-app.sh
```

`package-app.sh` builds `lulo-clippy` in release mode by default, assembles `dist/Lulo Clippy.app`, copies SwiftPM resource bundles, installs `Resources/AppIcon/LuloAppIcon.icns`, and ad-hoc signs the result for local launch. If the icon is missing, it regenerates it locally from the Lulo sprite pipeline. It does **not** install launch agents, login items, global config, or make permanent system changes.

Useful overrides:

```bash
LULO_CONFIGURATION=debug scripts/package-app.sh
LULO_APP_NAME="Lulo Clippy Dev" scripts/package-app.sh
APP_PATH="dist/Lulo Clippy.app" scripts/open-app.sh
```

## OpenClaw bridge configuration

The bridge is safe by default. Chat messages stay local and return placeholder replies unless POST mode is explicitly enabled in Settings or with `LULO_OPENCLAW_ENABLE_POST=true`.

Defaults are intentionally local to Ken's Mac and do not include secrets:

- HTTP base URL: `http://127.0.0.1:18789`
- WebSocket URL: `ws://127.0.0.1:18789`
- Session: `agent:main:clippy:local`
- Agent target: `openclaw/default`
- POST mode: off

Settings fields are stored in `UserDefaults`. You can also override them with environment variables:

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
2. Decide whether Clippy should use an isolated session (`agent:main:clippy:local`) or Ken's main session.
3. Persist chat history.
4. Replace the local dev bundle script with a Developer ID signed/notarized release flow when distribution is needed.
