# Lulo / Pinchy Clippy — Packaging & Security Plan

This document covers local-development packaging, the clickable `.app` bundle path, launch-at-login options, secrets/config storage, permissions UX, the threat model, and a future signing/notarization path for a macOS ambient assistant.

## Current goal

Ship a safe local developer loop first:

- build/run from source without permanent system changes;
- keep the OpenClaw bridge in dry-run mode unless Ken explicitly opts in;
- avoid committing tokens or personal local config;
- document the security boundaries before adding more ambient/context features.

The Swift scaffold lives in this `lulo-clippy` folder as a Swift Package Manager executable. Local dev packaging now creates a minimal app bundle under `dist/`; release distribution remains intentionally conservative until signing/notarization is finalized.

## Local development scripts

Added safe helpers:

- `scripts/build-dev.sh` — runs `swift build` in the app source dir.
- `scripts/run-dev.sh` — runs the app with dry-run bridge defaults unless env vars explicitly enable posting.
- `scripts/package-app.sh` — builds the SwiftPM executable and assembles `dist/Lulo Clippy.app`.
- `scripts/open-app.sh` — opens the local app bundle with the same guarded local bridge defaults.
- `packaging/app/Info.plist` — checked-in reference plist with minimal bundle metadata, `LSUIElement=true`, usage descriptions, and local-network disclosure. The current package script writes equivalent local-dev plist metadata into the assembled bundle.
- `config/dev.env.example` — copy to a private local env file if needed; do not commit real tokens.
- `packaging/LuloClippy.entitlements.template.plist` — minimal entitlements template for a future signed app bundle.
- `packaging/PinchyClippy.entitlements.template.plist` — legacy-name template kept for continuity while naming settles.
- `packaging/com.lulo.PinchyClippy.launchd.example.plist` — launchd reference only; do not install without explicit approval.

No launch agents, login items, global config, or persistent system changes are installed by these files.

## Local `.app` bundle shape

`./scripts/package-app.sh` creates:

```text
dist/Lulo Clippy.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/Lulo Clippy
    └── Resources/
        ├── LuloAppIcon.icns                # generated locally from sprite frame 4 when missing
        └── LuloClippy_LuloClippy.bundle    # SwiftPM processed sprite/app-icon resources
```

The script removes and recreates only the target bundle path under `dist/` by default, then ad-hoc signs the bundle with `codesign --sign -` when `codesign` is available. Ad-hoc signing is for local launch only; it is not a distribution signature.

Verification commands:

```bash
scripts/package-app.sh
plutil -lint "dist/Lulo Clippy.app/Contents/Info.plist"
test -x "dist/Lulo Clippy.app/Contents/MacOS/Lulo Clippy"
test -f "dist/Lulo Clippy.app/Contents/Resources/LuloAppIcon.icns"
test -d "dist/Lulo Clippy.app/Contents/Resources/LuloClippy_LuloClippy.bundle"
codesign --verify --deep --strict --verbose=2 "dist/Lulo Clippy.app"
```

Use `open "dist/Lulo Clippy.app"` or `scripts/open-app.sh` to launch manually. Do not add login-item or launch-agent behavior to these scripts.

## Config and secrets

### Preferred production storage

Use macOS Keychain for secrets:

- service: `com.lulo.PinchyClippy`
- account examples:
  - `openclaw.gateway.token`
  - `postiz.api.token` if social posting is ever added
  - `trading.api.token.<venue>` only if trading integration is explicitly in scope

Non-secret preferences can live in `UserDefaults` or Application Support:

- `~/Library/Application Support/PinchyClippy/config.json`
- file mode should be owner-only where possible (`0600`) if it contains sensitive local context.

### Local dev storage

For local dev only:

1. Copy `config/dev.env.example` to a private file such as `config/dev.env.local`.
2. Never commit `*.env`, `*.env.local`, or files containing real tokens.
3. Prefer Keychain even in dev once the bridge stabilizes.

### Git hygiene

Keep these out of git:

- `.build/`, `.swiftpm/`, `DerivedData/`;
- `*.env`, `*.env.local`, `*.secret`, `secrets.*`;
- exported chat transcripts, screenshots, logs, or window-content captures unless intentionally scrubbed.

## Permission UX

Ask just-in-time, with a plain-language reason and a visible off switch. Do not ask for all permissions on first launch.

Recommended UX pattern:

1. User enables a feature.
2. App explains exactly what permission is needed and what data will be accessed.
3. App opens the relevant macOS Settings pane or triggers the system prompt.
4. App shows current permission status and a “disable feature” option.

### Permission map

| Feature | macOS permission | When to request | Guardrails |
| --- | --- | --- | --- |
| Chat with local OpenClaw | Local network / HTTP only if needed | When bridge posting is enabled | Dry-run default, local host allowlist |
| Read active window/screen context | Screen Recording | First time user asks for screen/window context | Preview captured context before sending to model |
| Click/type/control apps | Accessibility | First automation action | Require per-action confirmation for destructive/external actions |
| Voice input | Microphone + Speech Recognition | First voice command | Push-to-talk default; visible listening indicator |
| Launch at login | Login Item / launchd | User toggles “start at login” | Show installed item, disable/remove control |
| Notifications | User Notifications | First reminder/status notification | Quiet defaults, notification categories |

## Bridge and action policy

Default mode should be passive and local:

- `LULO_OPENCLAW_ENABLE_POST` must be explicitly true before HTTP POSTs happen.
- Prefer `127.0.0.1`/`localhost` endpoints during dev.
- Reject or warn on non-local gateway URLs unless the user confirms.
- Do not send screenshots/window text to external model APIs unless the user explicitly opts in.

Suggested action tiers:

1. **Read-only local:** status, summarization of user-provided text, local dry-run replies. No confirmation needed.
2. **Sensitive read:** screenshots, active-window content, browser/app context, files outside a selected folder. Ask once per feature and show scope.
3. **External send:** email, messages, posts, PR comments, API writes. Always show recipient/content and require confirmation.
4. **Financial/trading:** orders, cancellations, withdrawals, fund movement. Require explicit typed confirmation with venue, instrument, side, size, price/slippage, and max loss/exposure.
5. **System changes:** launch agents, login items, Accessibility automation, persistent daemons. Require explicit approval and provide rollback instructions.

## Threat model

### Assets to protect

- Ken’s private messages, files, screenshots, active-window contents, calendar/email context.
- OpenClaw/Gateway tokens and any downstream API credentials.
- Trading accounts, wallets, exchange credentials, and order authority.
- The user’s reputation on external messaging/social platforms.
- Local system integrity and persistence points like login items/launch agents.

### Primary risks and mitigations

#### Accidental data leakage

Risks:

- ambient assistant captures too much screen/window text;
- logs include prompts, screenshots, tokens, or personal data;
- bridge sends context to a remote URL by mistake.

Mitigations:

- collect minimum context needed for the current task;
- user-visible context preview before model/tool submission;
- local-only endpoint allowlist by default;
- redact obvious secrets in logs;
- short log retention and opt-in diagnostic exports;
- keep secrets in Keychain, not env or logs.

#### Malicious prompts in app/window content

Risks:

- webpage, PDF, email, terminal, or chat content says “ignore previous instructions” or asks the assistant to exfiltrate data;
- captured content manipulates tool/action decisions.

Mitigations:

- treat screen/app content as untrusted data, never as instructions;
- wrap captured content with a clear boundary: “untrusted context”; 
- system/tool policies must override app content;
- never let captured content authorize external sends, code execution, trading, or config changes;
- confirmation dialogs should summarize the actual action, not the untrusted text’s requested action.

#### External sends

Risks:

- app sends messages/emails/posts to the wrong recipient;
- prompt injection drafts malicious content;
- background automation acts without the user noticing.

Mitigations:

- external sends require an interstitial confirmation with destination, account, body, attachments, and thread;
- maintain a send queue with cancel option;
- no “auto-send” mode until there is a hardened allowlist and audit log;
- include post-send receipts in the UI.

#### Trading/actions confirmation

Risks:

- model misreads market data or instrument;
- prompt injection triggers a trade;
- stale data creates unintended exposure;
- automated retries duplicate orders.

Mitigations:

- typed confirmation for every real trade/action: `CONFIRM BUY 10 XYZ @ LIMIT 1.23` style;
- display venue, instrument, side, quantity, order type, limit/slippage, estimated notional, fees, and max exposure;
- require fresh market/account snapshot;
- idempotency keys for order placement;
- hard-coded per-session and daily limits;
- default paper-trading/dry-run until explicitly enabled.

#### Persistence and privilege creep

Risks:

- launch-at-login or Accessibility permissions create unexpected long-running authority;
- app bundle update is tampered with.

Mitigations:

- no launch agents installed by scripts;
- use modern `SMAppService` for login items in a signed app when possible;
- show status of persistence/permissions in Settings;
- signed/notarized releases with hardened runtime;
- verify updates/signatures before applying.

## Launch at login

Local dev options, safest first:

1. Manual: run `scripts/run-dev.sh` when needed.
2. App setting later: use `SMAppService.mainApp.register()` in a bundled app with a visible Settings toggle.
3. launchd only for development/testing: use the example plist in `packaging/`, but do not install it without explicit approval.

If Ken approves launchd installation later, install by copying the plist to `~/Library/LaunchAgents/`, then `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.lulo.PinchyClippy.plist`. Rollback: `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.lulo.PinchyClippy.plist` and remove the file.

## Entitlements

Start minimal. For a non-sandboxed local dev build, SPM’s ad-hoc signing is enough.

For a distributable app, use hardened runtime and add only required entitlements. Avoid broad file/network entitlements unless the feature needs them. Usage descriptions belong in `Info.plist`:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSCameraUsageDescription` only if ever needed
- screen recording is controlled by TCC and needs clear in-app guidance; there is no simple `Info.plist` key equivalent for all cases.

The template at `packaging/PinchyClippy.entitlements.template.plist` intentionally keeps sandbox off until the app’s integration surface is settled. If sandboxing becomes a release goal, design around explicit user-selected files, local-network exceptions, and helper/XPC boundaries.

## Future distributable roadmap

1. **Bundle shape**
   - Keep the deterministic bundle script for local dev.
   - Move to an Xcode app target or hardened release bundler if distribution needs richer app lifecycle support.
   - Replace placeholder icon generation with a designed `.icns` before public release.
   - Keep `Info.plist`, version/build numbers, LSUIElement/menu-bar behavior, and usage strings reviewed.

2. **Secrets + settings**
   - Move token lookup to Keychain.
   - Store non-secret preferences in UserDefaults/Application Support.
   - Add redaction for logs and diagnostics.

3. **Code signing**
   - Enroll/use Apple Developer ID Application certificate.
   - Enable hardened runtime.
   - Sign nested helpers/frameworks before the main app.
   - Verify: `codesign --verify --deep --strict --verbose=2 PinchyClippy.app`.

4. **Notarization**
   - Archive as zip/dmg/pkg.
   - Submit with `xcrun notarytool submit --wait`.
   - Staple: `xcrun stapler staple PinchyClippy.app` or the DMG.
   - Verify Gatekeeper: `spctl --assess --type execute --verbose PinchyClippy.app`.

5. **Distribution**
   - Prefer DMG with drag-to-Applications flow.
   - Publish checksums and release notes.
   - If auto-update is added, use a signed update framework/feed and verify signatures.

6. **Security review gate before release**
   - Test permission prompts on a clean macOS account.
   - Confirm no tokens in bundle, logs, crash reports, or sample configs.
   - Confirm all external sends/actions have confirmation UI.
   - Confirm prompt-injection boundaries in screen/app context paths.
