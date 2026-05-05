ApeAssist Remote Setup
======================

ApeAssist is a macOS desktop sidekick that connects to Ken's OpenClaw/Pinchy backend.

Quick install:
1. Double-click START HERE.command in this disk image.
   - It copies ApeAssist.app to your user Applications folder and opens it.
   - You can also drag ApeAssist.app onto the Applications shortcut yourself.
2. Install Tailscale from https://tailscale.com/download/mac and log in to Ken's tailnet.
3. In ApeAssist, open Settings -> OpenClaw Bridge.
4. Choose: Mac mini over Tailscale.
5. Click Pair with Ken's Pinchy -> Enter pairing code.
6. Paste the ApeAssist pairing invite Ken sends you.
7. Enter the invite passphrase if Ken protected it.
8. Click Import Pairing Invite, then Check Gateway.
9. Click the floating ape and ask a question.

Why setup still needs you:
- Tailscale login must be completed by the Mac user so the device joins the private tailnet.
- The pairing invite contains or decrypts to a Gateway token. It is not bundled in this installer so the app can be shared without leaking Ken's backend access.

If macOS warns that ApeAssist is from an unidentified developer, right-click ApeAssist.app and choose Open once. Only do this for a DMG you received directly from Ken.
