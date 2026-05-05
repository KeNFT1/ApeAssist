# Ambient Context Layer for Lulo/Pinchy Clippy (macOS)

Goal: make the assistant useful for “what I’m doing right now” without becoming creepy. Context is gathered only from explicit user actions, shown locally first, and sent only when the user sends the chat message.

## Product defaults

- **No stealth capture.** No background screenshots, no polling selected text, no automatic clipboard scraping.
- **Explicit capture buttons:** `Include screenshot`, `Include clipboard`, `Include selected text`, and `What am I looking at?`.
- **Visible capture state:** while any screen/selection capture flow is active, show a red/visible indicator in the chat window or menu bar popover.
- **Local-only until send:** captured context is a draft attachment. It stays on-device, appears in the composer preview, and is not uploaded until the user presses Send.
- **Preview and remove:** every context chip needs a remove button; screenshots should show a thumbnail/blurred preview with “Remove”.
- **Smallest useful context:** prefer active app + window title before screenshot; prefer selected text before full screen.
- **No clipboard mutation:** do not simulate Cmd-C to get selected text unless the user explicitly chooses a fallback that warns it may touch clipboard. Accessibility selected-text APIs are preferred.

## macOS permission model

### Active app name

- **Permission:** none for `NSWorkspace.shared.frontmostApplication`.
- **Gives:** app name, bundle id, process id.
- **Use:** lightweight context for `What am I looking at?`.

### Window title

- **Permission:** best-effort. `CGWindowListCopyWindowInfo` can return the current app/window metadata, but titles for other apps may be unavailable unless Screen Recording is granted.
- **Prompt:** do not prompt automatically. If titles are missing and the user wants richer context, show an explanation and an `Enable Screen Recording` button.

### Clipboard text

- **Permission:** no TCC permission for direct pasteboard read, but macOS may show pasteboard privacy notices depending on OS/version and source app.
- **UX requirement:** read only from `Include clipboard`; never poll. Show exact text preview/truncation before send.
- **Sensitive data risk:** high. Clipboard often contains passwords, tokens, addresses, or copied private messages. Default to not included.

### Selected text

- **Permission:** Accessibility.
- **Prompt:** `AXIsProcessTrustedWithOptions(...prompt: true)` may open the macOS Accessibility permission flow. The user must approve the app in System Settings and may need to restart the app.
- **Strategy:** use `kAXFocusedUIElementAttribute` + `kAXSelectedTextAttribute` from the frontmost app. Do not synthesize keystrokes by default.
- **Fallback:** if Accessibility fails, suggest manual paste or clipboard include. Avoid automatic Cmd-C.

### Screenshot / screen understanding

- **Permission:** Screen Recording.
- **Prompt:** `CGRequestScreenCaptureAccess()` shows the system prompt; the user must approve in System Settings and may need to restart the app.
- **Strategy:** only from `Include screenshot` or `What am I looking at?` after confirmation. Use active-window capture when possible, not full display.
- **Indicator:** red/visible indicator while capturing and while screenshot is attached to the draft.
- **Privacy:** screenshot bytes remain local draft data until Send. Current prototype chat posting is text-only, so approved screenshots are represented as local draft metadata rather than uploaded image bytes until binary/multipart bridge support is added.

## Chat UI integration points

### “What am I looking at?”

Default first pass:

1. Attach active app name, bundle id, and best-effort window title.
2. If the user has selected text and Accessibility is enabled, offer `Include selected text` as a one-click follow-up.
3. If the assistant needs pixels, ask/show `Include screenshot` rather than silently capturing.

Suggested composer chip:

- `Looking at: Safari — “Stripe Dashboard”` with remove/edit.

### “Include clipboard”

1. User clicks button.
2. App reads plain text once.
3. Composer gets a local chip: `Clipboard: 428 chars` with expandable preview.
4. Send request includes a text attachment only if chip remains attached.

### “Include selected text”

1. User clicks button.
2. If Accessibility missing, show permission explainer + `Open Accessibility Settings`.
3. If granted, read selected text once via AX.
4. Composer gets local chip: `Selected text: 1,204 chars` with preview/remove.

### “Include screenshot”

1. User clicks button.
2. If Screen Recording missing, show permission explainer + `Open Screen Recording Settings`.
3. Red/visible indicator turns on.
4. Capture active window by default; full-display capture should require an explicit scope chooser.
5. App opens a local preview sheet with the captured thumbnail plus `Cancel` and `Attach screenshot` actions.
6. Only `Attach screenshot` creates a draft chip. `Cancel` discards the PNG bytes immediately.
7. Composer gets a screenshot chip with remove.
8. Indicator remains visible while capturing, while the preview sheet is open, and while screenshot context is attached.

## Prototype Swift services

Added under `Sources/AmbientContext`:

- `AmbientPermissions` — passive checks and explicit permission prompt helpers for Accessibility and Screen Recording.
- `ActiveWindowService` — frontmost app metadata and best-effort window title.
- `ClipboardService` — one-shot, user-initiated plain-text clipboard read.
- `SelectedTextService` — one-shot, user-initiated Accessibility selected-text read.
- `ScreenshotCaptureService` — guarded screenshot service. It checks user initiation and Screen Recording, captures the active window by default using the CoreGraphics window API, and returns PNG bytes only to the local preview flow. Cursor capture is intentionally unsupported until a ScreenCaptureKit pass.
- `AmbientContextCoordinator` — small integration facade for chat actions.

The executable `ambient-context-demo` only prints permission status and frontmost app metadata. It intentionally does **not** read clipboard, selected text, or screenshots.

## Suggested send payload shape

```json
{
  "message": "What should I do next?",
  "context": {
    "activeWindow": {
      "appName": "Safari",
      "bundleIdentifier": "com.apple.Safari",
      "windowTitle": "Stripe Dashboard"
    },
    "clipboardText": null,
    "selectedText": null,
    "screenshot": null
  },
  "privacy": {
    "userInitiated": true,
    "localPreviewShown": true,
    "sentOnlyAfterUserPressedSend": true
  }
}
```

## Implementation notes / next steps

- Add binary image upload support to `OpenClawBridge`/Gateway payloads before approved screenshot PNG bytes are sent to any model. Keep the existing preview/attach/remove gate in front of that upload.
- Use SwiftUI/NSPanel composer controls for context chips.
- Add app-level state: `ContextDraft`, `CaptureIndicatorState`, `PermissionExplainerState`.
- Replace the deprecated CoreGraphics active-window capture seam with ScreenCaptureKit for modern macOS capture, cursor compositing, and robust window/display selection.
- Add truncation limits for text attachments before model send, with a local “send full text?” affordance.
- Add redaction hints for clipboard (`looks like password/API key`) before send.
- Keep tests/mocks around the coordinator so UI behavior can be verified without touching real system context.
