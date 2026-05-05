# Lulo Clippy Voice + Notifications UX

## Current implementation

Lulo now owns the voice/status/notification seams that were prototyped in the sibling `pinchy-clippy` app, with Lulo branding preserved.

Added in `Sources/LuloClippy`:

- `AssistantStatus.swift` — canonical UI status enum: `idle`, `wave`, `listening`, `thinking`, `talking`.
- `VoiceInteractionController.swift` — push-to-talk state seam plus local macOS speech playback via `AVSpeechSynthesizer`.
- `NotificationUXController.swift` — notification authorization status, explicit permission request, and local notification helper.

The existing animated Lulo sprite remains the source of truth for visual state:

- `idle` → idle row
- `wave` → wave row
- `listening` / `thinking` → thinking row until dedicated listening art lands
- `talking` → talking row

## Safety boundaries

Current behavior intentionally stays conservative:

- No audio is recorded.
- No speech-to-text is started.
- No external TTS or OpenClaw `tts` call is made.
- Notification permission is **not** requested on launch.
- Notification permission is requested only from the Settings button.
- Local context and chat sending remain governed by existing explicit user actions.

## Voice input path

### v1 seam: keyboard push-to-talk

Default prototype shortcut: **hold Option+Space** while Lulo is focused.

Behavior today:

1. User holds Option+Space, or clicks “Start Listening Preview” in Settings.
2. Lulo switches to `listening`.
3. User releases Option+Space, or clicks “Stop”.
4. Lulo briefly routes through `thinking`, then returns to `idle`.

This is only a UX/state seam. The TODO is to place capture/transcription behind explicit microphone/speech permission UX and route final transcript text into the same `OpenClawBridge.send(_:)` path as typed chat.

Production shortcut options:

- Carbon `RegisterEventHotKey` for a dependency-light global shortcut.
- `KeyboardShortcuts` Swift package for rebinding/settings UX.

## Voice output / TTS

`SpeechPlaybackController` wraps `AVSpeechSynthesizer` for local-only playback. Settings includes a “Speak Local Preview” button for verification.

Good default uses later:

- Short confirmations.
- User-triggered “speak this” actions.
- Local status snippets like build/task completion.

Avoid by default:

- Reading long answers automatically.
- Speaking unexpectedly in the background.
- Sending private content to external TTS providers without an explicit opt-in setting.

## Notifications

`NotificationUXController` can refresh authorization status at launch/settings time without prompting. The actual macOS permission prompt is only shown when the user clicks **Request Notification Permission** in Settings.

After permission, useful local notifications should be rare and deduped:

- Build/test/task finished after the user started it.
- Long-running OpenClaw job needs attention or failed.
- Bridge offline/auth expired/permission missing.
- User-configured reminders or calendar nudges.

Require explicit future opt-in:

- Email/social/message summaries.
- Weather/travel nudges.
- Background voice announcements.

Never do:

- Marketing-style engagement pings.
- Repeated nagging for the same event.
- Sensitive lock-screen content unless the user opts in.

## Next work

1. Add real microphone + speech permission status rows.
2. Add a transcript adapter protocol with Apple Speech and local Whisper implementations.
3. Promote Option+Space from app-focused monitor to a global, configurable shortcut.
4. Add user settings for voice replies, external TTS opt-in, proactive notifications, quiet hours, and notification dedupe/rate limits.
5. Route task/build completion events into `NotificationUXController.notify(...)` with stable identifiers.

## Verification

Run from the canonical app directory:

```bash
cd /Users/pinchy/.openclaw/workspace/lulo-clippy
swift build
```
