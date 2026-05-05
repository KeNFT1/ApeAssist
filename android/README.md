# ApeAssist Android MVP

This folder contains a small Android MVP scaffold for ApeAssist. It is intentionally separate from the SwiftPM/macOS app so macOS packaging stays untouched.

## What is included

- Kotlin + Jetpack Compose single-activity app (`app.apeassist.android`).
- Default endpoint mode for Ken's Mac mini over Tailscale:
  `https://pinchys-mac-mini.taild71e14.ts.net/`
- Pairing screen that imports the current clear v1 ApeAssist invite format:
  `APEASSIST-INVITE-v1:<base64-json>` or raw invite JSON.
- Encrypted invite prefix detection (`APEASSIST-INVITE-ENC-v1:`) with a clear TODO/error. Android decryption needs a native crypto implementation compatible with the macOS `openssl enc -aes-256-cbc -pbkdf2 -iter 200000` flow.
- Secure token storage through AndroidX Security `EncryptedSharedPreferences` backed by Android Keystore.
- Chat screen that sends `POST <endpoint>/v1/responses` with:
  - `model`: `openclaw/default` or invite `agentTarget`
  - `input`: user text
  - `stream`: `false`
  - `user`: saved session key
  - `Authorization: Bearer <token>` when paired
  - `x-openclaw-session-key`: saved session key
- Settings screen for endpoint, token status, token clearing, and `GET /v1/models` Gateway health check.

No real Gateway token or pairing invite is committed.

## Build

Prerequisites:

1. Android Studio or command-line Android SDK.
2. JDK 17+.
3. Tailscale installed on the Android device/emulator and joined to the same tailnet as the Mac mini.

Build from this directory:

```bash
cd android
# If you have Gradle installed:
gradle :app:assembleDebug

# Or open this folder in Android Studio and run the `app` configuration.
```

This repo currently does not include a Gradle wrapper because this scaffold was created on a host without Java/Gradle available to generate one. Android Studio can create/use its managed Gradle installation, or a wrapper can be added later with:

```bash
gradle wrapper --gradle-version 8.9
```

## Pairing flow

1. Install/run the Android app.
2. Make sure Tailscale is connected and can reach `pinchys-mac-mini.taild71e14.ts.net`.
3. Paste Ken's ApeAssist clear v1 invite on the Pair screen.
4. Tap **Import invite**.
5. Tap **Check Gateway**. A healthy setup should report that `/v1/models` is reachable and auth is OK.
6. Open **Chat** and send a message.

## MVP limitations

- No streaming responses yet (`stream=false` only).
- Encrypted invite decryption is stubbed/detected, not implemented.
- No push notifications, voice, approval cards, or Android-specific Tailscale onboarding.
- The endpoint health check only verifies `/v1/models`; it does not create a chat turn.
