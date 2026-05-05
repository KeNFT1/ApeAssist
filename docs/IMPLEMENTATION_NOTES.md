# Implementation Notes

- Built as Swift Package Manager executable target `LuloClippy` to keep the scaffold command-line buildable.
- `NSPanel` is used for the buddy instead of a normal SwiftUI window because it gives better control over floating level, all-spaces behavior, transparency, and accessory-app behavior.
- The desktop buddy now uses `LuloSpriteView`, which loads `Resources/Sprites/lulo-sprite-sheet.png` and its JSON metadata as SwiftPM package resources. The sheet is expected to be a 4x4 grid with idle/wave/thinking/talking rows.
- `AssistantStatus` is the lightweight UI state machine. Chat sends set thinking while the bridge is busy, then talking briefly after a reply. Voice can later map microphone activation to `listening` without changing the sprite API.
- The bridge never sends externally unless `LULO_OPENCLAW_ENABLE_POST=true` or the Settings toggle enables POST mode.
- Settings are intentionally placeholders; secrets should move to Keychain before this becomes production-grade.
