# Lulo / Pinchy Clippy for macOS — Product Architecture

## 1. Product intent

Lulo is a native macOS ambient AI companion: a small, visible, trustworthy character that makes Pinchy/OpenClaw feel like a real desktop copilot instead of a chat window hidden inside Telegram or a terminal.

The product goal is not “another chatbot.” It is Ken’s main control surface for asking Pinchy to look at the Mac, reason across local/project context, launch OpenClaw capabilities, and do useful work with clear consent boundaries.

### Design principles

- **Ambient, not annoying:** visible when useful, quiet when not.
- **Action-first:** make common tasks faster than opening Telegram, a browser, or a terminal.
- **Native trust:** feel like a Mac app with explicit permissions, local-first defaults, and inspectable actions.
- **Character + utility:** the floating companion creates presence, but the product wins by being genuinely capable.
- **Human-confirmed external actions:** draft, preview, and ask before sending, posting, trading, deleting, or spending.
- **OpenClaw as the brain:** the macOS app is the polished local shell; Gateway/Pinchy provide tools, memory, subagents, browser control, messaging, reminders, and integrations.

## 2. Target user

Primary user: **Ken** — technical, direct, fast-moving, already runs OpenClaw and wants low-friction help across coding, projects, family/admin context, trading dashboards, browser research, reminders, and everyday Mac work.

This is optimized first for one power user on one Mac. Multi-user polish can come later.

## 3. Product shape

Lulo has four surfaces:

1. **Floating character**
   - Small draggable animated companion, always-on-top by default.
   - Expresses state: idle, listening, thinking, working, needs confirmation, blocked, success.
   - Can be hidden to menu bar or summoned with a hotkey.

2. **Chat panel**
   - Native conversation panel attached to the character or opened as a normal window.
   - Supports text, images/screenshots, files, voice transcripts, tool progress, approvals, and final artifacts.
   - Becomes Ken’s preferred Pinchy/OpenClaw chat surface.

3. **Command palette**
   - Global hotkey, e.g. `⌘⇧Space`.
   - Fast actions: “Ask Pinchy,” “Screenshot and ask,” “Summarize this page,” “Open project,” “Create reminder,” “Run coding agent,” “Check trading dashboard.”
   - Fuzzy search over commands, recent tasks, projects, and saved workflows.

4. **Proactive nudges**
   - Small, consent-aware notifications from Pinchy: calendar warning, urgent email, stalled job, changed repo state, trading dashboard anomaly, reminder due.
   - Must be rate-limited and explain why it appeared.

## 4. Architecture overview

```text
macOS App: Lulo
  ├─ Floating character / window manager
  ├─ Chat UI / transcript store
  ├─ Command palette
  ├─ Permission broker
  ├─ Capture services: screenshot, selected text, active app/window metadata
  ├─ Voice input/output
  ├─ Local notification scheduler
  └─ OpenClaw Gateway client

OpenClaw Gateway / Pinchy
  ├─ Agent session API
  ├─ Tool execution: browser, files, messages, reminders, calendar, email, TTS, etc.
  ├─ Memory and project context
  ├─ Subagents / taskflow / durable jobs
  ├─ Approval workflow
  └─ Streaming events back to Lulo
```

### Recommended app stack

- **Swift + SwiftUI** for native UX, menu bar, window layering, permissions, screenshots, notifications, accessibility, and global shortcuts.
- **AppKit bridge** where SwiftUI is insufficient: borderless floating windows, accessibility APIs, screen recording prompts, menu bar behavior.
- **Local persistence:** SQLite or Core Data for local UI transcripts, preferences, permission grants, and cached command metadata.
- **OpenClaw communication:** HTTP + Server-Sent Events or WebSocket against local Gateway.
- **Optional helper:** privileged helper should be avoided for MVP. Use macOS permission APIs first.

## 5. MVP

The MVP should prove that Lulo is a better home for Pinchy than Telegram for desktop work.

### MVP features

#### Floating companion

- Draggable always-on-top character.
- Click opens/closes chat.
- Right-click/menu bar controls:
  - Hide/show
  - New chat
  - Screenshot and ask
  - Preferences
  - Quit
- Basic state animations:
  - idle
  - listening/typing
  - thinking
  - working
  - needs approval
  - done/error

#### Chat with Pinchy/OpenClaw

- Start a local OpenClaw session from the app.
- Stream assistant text and tool progress.
- Send text prompts.
- Attach current screenshot or selected region.
- Show final responses and artifacts/links.
- Support approval cards for sensitive actions:
  - approve once
  - reject
  - edit instruction

#### Screenshot-aware help

- “Screenshot and ask” hotkey/action.
- Capture full screen or selected region.
- Send image to OpenClaw with user prompt.
- User story examples:
  - “What am I looking at?”
  - “Debug this error.”
  - “Summarize this dashboard.”
  - “Turn this UI into implementation notes.”

#### Command palette

- Global hotkey opens a small input.
- MVP commands:
  - Ask Pinchy
  - Screenshot and ask
  - Open chat
  - Summarize frontmost browser tab
  - Create reminder
  - Run project task
- Commands can map to prompt templates sent to Gateway.

#### Permissions and preferences

- First-run onboarding explains:
  - OpenClaw connection
  - screen capture permission
  - microphone permission if voice is enabled
  - notifications permission
  - accessibility permission if selected-text/app automation is enabled
- App defaults to minimal access.
- Clear local toggles for:
  - screenshots
  - active app/window metadata
  - selected text
  - notifications
  - microphone
  - voice playback
  - proactive nudges

### MVP non-goals

- No autonomous trading.
- No unattended external messages.
- No always-recording microphone.
- No unrestricted screen watching.
- No full workflow builder.
- No app store distribution requirement.
- No multi-device sync.

## 6. v1 features

v1 turns the MVP into Ken’s daily driver.

### Richer interaction model

- Character can dock to screen edges and avoid covering active controls.
- Multiple visual moods or skins.
- Notification bubble anchored to character.
- Conversation history search.
- Pin important chats/tasks.
- Drag files/images onto character to ask about them.
- Drag text snippets onto character.
- Inline artifact preview: markdown, images, PDFs, logs, diffs.

### Deeper Mac context

With explicit permissions:

- Active app name, window title, and URL for supported browsers.
- Selected text capture.
- Clipboard-aware “use clipboard?” prompt.
- Finder selection awareness.
- Current repo detection from active terminal/editor path, when available.
- Optional accessibility actions, always previewed when non-trivial.

### Browser bridge

- Frontmost tab summarization.
- “Research this” from current page.
- “Fill this form” with preview before submission.
- “Watch this page for changes” via OpenClaw/browser automation.
- Login-aware browser automation remains mediated by OpenClaw browser tools.

### Project mode

- Detect or choose project context:
  - WordSprout
  - OpenClaw setup
  - trading automations
  - lulo-clippy
  - property/admin tasks
- Each project can define:
  - root path
  - common commands
  - docs/context files
  - allowed tools
  - default model/agent style
- “Run coding agent on this issue” launches a subagent and streams summarized progress.

### Reminders and calendar

- Natural-language reminders through Apple Reminders/OpenClaw.
- Calendar lookahead nudges.
- Contextual reminders:
  - “Remind me when I’m back at this project.”
  - “Remind me tomorrow morning to check this dashboard.”
- Ask before creating external/shared calendar events.

### Voice

- Push-to-talk voice input.
- Optional wake hotkey, not always-on wake word for v1.
- Streaming transcription.
- Voice replies for storytime/summaries when requested or enabled.
- Quiet mode respects meetings/focus state.

### Proactive nudges

- Rule-based and OpenClaw-heartbeat-backed nudges:
  - urgent unread email
  - upcoming calendar event
  - failed/stalled background job
  - CI failure
  - important repo diff reminder
  - trading dashboard drift/anomaly
- Every nudge includes:
  - source
  - why now
  - action buttons
  - mute/snooze option

## 7. Dream-state features

Dream-state Lulo feels like a small operating-system-level companion without becoming creepy or unsafe.

### Ambient workspace memory

- Understands “what Ken was doing” across sessions by project, not by unrestricted surveillance.
- Builds timeline cards from explicit events:
  - chats
  - files Ken attached
  - tasks run
  - reminders created
  - approved actions
  - project summaries
- Can answer:
  - “Where did we leave off on WordSprout?”
  - “What was that blinds estimate?”
  - “What broke in Strategy D last week?”

### Agentic task cockpit

- Visual dashboard of running OpenClaw tasks/subagents.
- Pause, resume, kill, inspect logs.
- Convert chat into durable tasks.
- “Do this while I sleep, summarize in the morning.”
- Human approval queue with batched decisions.

### Spatial/visual companion

- Character reacts to desktop context without reading everything.
- Can point at UI elements in screenshots.
- Can produce annotated screenshots and visual diffs.
- Optional screen-edge “peek” and “thinking bubble.”

### Personalized workflows

- User-authored recipes:
  - “morning brief”
  - “debug screenshot”
  - “launch coding sprint”
  - “prep property estimate”
  - “trading risk review”
- Workflows are inspectable YAML/JSON behind the scenes.

### Multi-surface Pinchy

- Lulo on Mac, Telegram when mobile, maybe web later.
- Same OpenClaw memory and task state.
- Handoff: “continue this on Telegram” or “open on Mac.”

### Strong local autonomy, bounded by policy

- Can locally organize files, draft docs, run tests, inspect logs, and prepare reports without asking every time.
- Still asks before external/destructive/financial actions.
- Learns Ken’s preferences from accepted/rejected suggestions.

## 8. Interaction model

### Floating character behavior

States:

- **Idle:** small, quiet, maybe subtle breathing/idle animation.
- **Available:** hover glow or tooltip: “Ask Pinchy.”
- **Listening:** microphone/push-to-talk indicator.
- **Thinking:** animated eyes/spinner.
- **Working:** progress ring, optional current task label.
- **Needs confirmation:** distinct color/badge; click opens approval card.
- **Blocked:** asks for missing permission/input.
- **Done:** short success animation, then returns idle.

Rules:

- Never cover fullscreen video/games by default.
- Respect Focus/Do Not Disturb with reduced nudges.
- Hide during screen sharing unless explicitly allowed.
- Easy panic action: “hide and stop listening.”

### Chat model

A chat turn can include:

- user text
- screenshot/image
- file references
- selected text
- active app metadata
- project context
- user-selected command template

Assistant output can include:

- streamed text
- tool status events
- approval requests
- generated files/artifacts
- suggested next actions
- errors with recovery options

### Command palette model

Command palette input examples:

- `ask why is this test failing`
- `screenshot explain this chart`
- `remind tomorrow 9 check seller docs`
- `code fix issue 123 in WordSprout`
- `browser summarize current tab`
- `trade review dashboards no orders`

Palette resolves to one of:

- plain chat prompt
- prompt + screenshot
- OpenClaw tool workflow
- local app action
- reminder/calendar action
- project task/subagent request

### Proactive nudge model

Nudges should be sparse and actionable.

Example nudge:

> Strategy D finished with 0 positions opened. Slowest phase was Bloomberg vol velocity again (~490s). Open summary?
>
> Buttons: Open summary · Snooze trading nudges · Ask why

Nudge policy:

- Default max: 2-4 proactive nudges/day unless urgent.
- Batch low-priority items.
- No late-night nudges except urgent user-configured categories.
- Each nudge has mute/snooze.

### Permissions UX

Use progressive disclosure:

- Ask for permission when the user first uses a feature.
- Explain exactly what access enables.
- Show whether context will be sent to OpenClaw.
- Allow one-shot context sharing:
  - “Use this screenshot once”
  - “Use selected text once”
  - “Use active tab URL once”
- Persistent grants are explicit and revocable.

### Voice UX

MVP/v1 voice should be push-to-talk.

- Hold hotkey or click mic.
- Visible recording indicator.
- Show transcript before sending if configured.
- No hidden wake word.
- Voice output only when enabled, requested, or appropriate for long summaries/story mode.

## 9. Safety and privacy model

### Context access levels

Define four levels of what Lulo can see:

1. **None**
   - User typed only.
   - Default for normal chat.

2. **Explicit attachment**
   - User attaches screenshot/file/text.
   - Sent for this turn only.

3. **Foreground metadata**
   - Active app, window title, browser URL, selected Finder path.
   - Requires permission and visible indicator.

4. **Foreground content**
   - Screenshot, selected text, page content, clipboard, files.
   - Requires explicit user action or approved workflow.

Avoid building “constant screen watcher” as a default. If later added, make it opt-in, locally processed where possible, and obvious.

### Action risk classes

Every action routed through Gateway should be classified.

#### Safe / reversible

Can run without per-action confirmation after initial app trust:

- read local project files in approved roots
- summarize attached content
- create draft text
- run tests/lints in project directory
- open URLs/apps
- create local notes/docs inside workspace
- search web

#### Sensitive / asks first

Requires confirmation card:

- sending messages/emails
- posting publicly
- creating/modifying calendar events that invite others
- buying/selling/trading/placing orders
- payments/crypto transactions
- deleting files outside trash/recoverable operations
- changing system settings
- accessing private data outside granted scope
- installing software or changing persistent services

#### Blocked by default

Should not be allowed without explicit advanced configuration:

- autonomous trading execution
- bulk exfiltration of personal data
- hidden recording/screen capture
- bypassing app/site security controls
- destructive deletes without recoverability

### External action confirmation

Confirmation card must show:

- action type
- destination/recipient/account
- exact content or command
- files/data included
- risk label
- buttons: Approve once, Edit, Reject

Current macOS scaffold:

- `ActionRisk` classifies approval-required actions as `externalSend`, `browserOrAppClick`, `fileDeletion`, `tradingOrFinancial`, or `configChange`.
- `PendingAction` carries title, summary, details, status, and an optional future `gatewayApprovalID` so the UI can map cleanly to Gateway approval events later.
- `PendingActionCard` appears inline in the chat transcript; `ConfirmationSheet` provides a larger details view with **Approve once** and **Deny** controls.
- `OpenClawBridge` has a conservative local placeholder detector for risky text while the Gateway approval protocol is still stubbed. Approval/denial updates local UI state only and never performs the external/destructive/financial action yet.
- The floating buddy can enter `needsConfirmation` state so the desktop character visibly reflects that progress is blocked on Ken.

For trading/financial actions:

- Dashboard analysis is allowed.
- Suggestions are allowed.
- Draft orders are allowed.
- Actual orders require explicit manual confirmation every time.
- No “approve all future trades” in standard UI.

### Privacy boundaries

- Local app transcripts are stored locally unless Gateway/session storage is configured.
- Do not send screenshots/files to external services directly from app; route through OpenClaw policy.
- Redaction pass for screenshots can be a v1 feature:
  - detect obvious passwords/API keys/SSNs/seed phrases
  - warn before sending
- Screen sharing mode hides Lulo and suppresses sensitive nudges by default.

### Auditability

- Local action history:
  - when context was captured
  - what was sent to Gateway
  - what tools/actions were requested
  - approvals/rejections
- User can clear local history.
- Export debug bundle for development.

## 10. Ken-specific user stories

### Coding

1. **Screenshot error debugging**
   - Ken sees a test failure or Xcode/terminal error.
   - Hits hotkey: Screenshot and ask.
   - Lulo sends screenshot plus active project metadata.
   - Pinchy explains likely cause and offers “run tests” or “spawn coding agent.”

2. **Subagent coding task**
   - Ken opens command palette: `code fix failing auth test in WordSprout`.
   - Lulo asks for project if ambiguous.
   - OpenClaw spawns a coding subagent.
   - Lulo shows progress: files changed, tests run, final summary.
   - Ken can open diff or ask follow-up.

3. **PR / CI check**
   - Lulo nudges: “CI failed on the PR; failure is in checkout flow tests.”
   - Buttons: Open logs · Ask Pinchy · Ignore.

### Browser and research

4. **Summarize active tab**
   - Ken reads a long doc/article.
   - Palette: `summarize this`.
   - Lulo shares active URL/page text with Gateway after permission.
   - Pinchy returns concise summary and action items.

5. **Form helper**
   - Ken is filling a property/admin form.
   - Lulo can draft field values from known context.
   - It never submits without Ken clicking submit/approve.

6. **Design inspiration capture**
   - Ken opens a website he likes.
   - Screenshot and ask: “turn this into DESIGN.md inspiration for the app.”
   - Pinchy produces a local doc in the project.

### Screenshots and visual work

7. **Dashboard interpretation**
   - Ken screenshots a trading/analytics dashboard.
   - Pinchy identifies signals, anomalies, and questions.
   - Lulo offers “save summary” or “watch this dashboard,” but not “trade automatically.”

8. **UI implementation notes**
   - Ken screenshots an app design.
   - Pinchy extracts layout, typography, component hierarchy, and implementation plan.

### Reminders / personal admin

9. **Natural reminder**
   - Ken says: “Remind me tomorrow at 9 to check seller docs.”
   - Lulo drafts Apple Reminder details.
   - If local reminder only, create directly after confirmation/preference.

10. **Contextual reminder**
   - Ken says: “When I’m back in lulo-clippy, remind me to finish permissions UX.”
   - Lulo stores project-context reminder.
   - When project is active later, gentle nudge appears.

### Family / project context

11. **Memory-backed context**
   - Ken asks: “What did we decide about the blinds estimate?”
   - Pinchy searches memory/docs, answers with caveats and links/source files.

12. **Privacy-safe family help**
   - Ken asks for a draft message to a family member.
   - Pinchy drafts it.
   - Lulo requires explicit confirmation before sending through any messaging channel.

### Trading dashboards, safely

13. **Morning risk review**
   - Palette: `trade review dashboards`.
   - Pinchy pulls local trading reports/dashboards.
   - Returns account/risk summary, anomalies, and suggested checks.
   - It does not place trades.

14. **Strategy D health nudge**
   - Lulo nudges when a run completes/fails/stalls.
   - “Open summary” shows positions opened, skipped candidates, slow phases, errors.
   - “Investigate” can spawn an analysis task.

15. **Manual trade draft**
   - Pinchy may draft a proposed trade/order from analysis.
   - Confirmation card says: “Financial action — manual approval required.”
   - Ken must approve each order externally or through a highly explicit one-time card.

## 11. Local API contract to OpenClaw Gateway

This contract is suggested, not implementation-mandatory. Prefer a small stable API that maps to existing OpenClaw session/tool primitives.

### Authentication

Local-only MVP:

- Gateway listens on localhost or authenticated LAN route.
- Lulo stores a local API token in Keychain.
- Pairing flow:
  1. Lulo discovers Gateway or user enters URL.
  2. Gateway shows/presents pairing code.
  3. Lulo exchanges code for token.

Headers:

```http
Authorization: Bearer <lulo_token>
X-Lulo-Client-Version: 0.1.0
```

### Start or resume session

```http
POST /api/lulo/v1/sessions
Content-Type: application/json
```

Request:

```json
{
  "clientSessionId": "uuid",
  "mode": "main_chat",
  "title": "Lulo Chat",
  "project": {
    "id": "lulo-clippy",
    "path": "/Users/pinchy/.openclaw/workspace/lulo-clippy"
  },
  "clientCapabilities": {
    "streaming": true,
    "approvals": true,
    "screenshots": true,
    "voice": true,
    "notifications": true
  }
}
```

Response:

```json
{
  "sessionId": "oc_session_id",
  "streamUrl": "/api/lulo/v1/sessions/oc_session_id/events"
}
```

### Send chat turn

```http
POST /api/lulo/v1/sessions/{sessionId}/turns
```

Request:

```json
{
  "turnId": "uuid",
  "text": "What is wrong with this error?",
  "attachments": [
    {
      "id": "att_1",
      "type": "image/png",
      "name": "screenshot.png",
      "source": "upload",
      "purpose": "user_explicit_screenshot"
    }
  ],
  "context": {
    "accessLevel": "explicit_attachment",
    "activeApp": "Terminal",
    "windowTitle": "npm test",
    "projectPath": "/Users/pinchy/.openclaw/workspace/example"
  },
  "requestedAction": "answer_or_suggest"
}
```

Response:

```json
{
  "accepted": true,
  "turnId": "uuid"
}
```

### Upload attachment

```http
POST /api/lulo/v1/attachments
Content-Type: multipart/form-data
```

Response:

```json
{
  "attachmentId": "att_1",
  "sha256": "...",
  "size": 123456,
  "mimeType": "image/png"
}
```

### Event stream

```http
GET /api/lulo/v1/sessions/{sessionId}/events
Accept: text/event-stream
```

Event examples:

```json
{ "type": "assistant.delta", "text": "I see the failure..." }
```

```json
{
  "type": "tool.status",
  "tool": "exec",
  "status": "running",
  "summary": "Running tests"
}
```

```json
{
  "type": "approval.requested",
  "approvalId": "appr_123",
  "risk": "external_message",
  "title": "Send message?",
  "details": {
    "recipient": "Ken",
    "contentPreview": "...",
    "attachments": []
  },
  "actions": ["approve_once", "reject", "edit"]
}
```

```json
{
  "type": "artifact.created",
  "artifact": {
    "id": "art_1",
    "name": "summary.md",
    "mimeType": "text/markdown",
    "url": "/api/lulo/v1/artifacts/art_1"
  }
}
```

```json
{ "type": "assistant.done", "turnId": "uuid" }
```

### Respond to approval

```http
POST /api/lulo/v1/approvals/{approvalId}
```

Request:

```json
{
  "decision": "approve_once",
  "editedInstruction": null,
  "clientConfirmedAt": "2026-05-04T22:00:00-07:00"
}
```

Response:

```json
{ "accepted": true }
```

### Commands registry

```http
GET /api/lulo/v1/commands
```

Response:

```json
{
  "commands": [
    {
      "id": "screenshot.ask",
      "title": "Screenshot and ask",
      "input": "prompt_optional",
      "requires": ["screen_capture"],
      "risk": "safe"
    },
    {
      "id": "reminder.create",
      "title": "Create reminder",
      "input": "natural_language",
      "requires": [],
      "risk": "local_write"
    },
    {
      "id": "trading.review",
      "title": "Review trading dashboard",
      "input": "optional",
      "requires": ["project_or_file_context"],
      "risk": "analysis_only"
    }
  ]
}
```

### Run command

```http
POST /api/lulo/v1/commands/{commandId}/run
```

Request:

```json
{
  "sessionId": "oc_session_id",
  "input": "check Strategy D health",
  "context": {
    "projectPath": "/Users/pinchy/.openclaw/workspace/polymarket-arb"
  }
}
```

### Nudge feed

Lulo can either subscribe to Gateway nudges or let Gateway call a local app endpoint. For simplicity, use Gateway event stream while the app is running.

```http
GET /api/lulo/v1/nudges/events
Accept: text/event-stream
```

Nudge event:

```json
{
  "type": "nudge",
  "id": "nudge_123",
  "priority": "normal",
  "source": "trading.strategy_d",
  "title": "Strategy D completed",
  "body": "0 positions opened; Bloomberg vol velocity was slow again (~490s).",
  "actions": [
    { "id": "open_summary", "label": "Open summary" },
    { "id": "ask_why", "label": "Ask why" },
    { "id": "snooze", "label": "Snooze" }
  ]
}
```

### Permission state sync

Lulo should own macOS permissions; Gateway should receive only the resulting context. Still, Gateway can expose policy status.

```http
GET /api/lulo/v1/policy
```

Response:

```json
{
  "gatewayPolicy": {
    "externalActionsRequireApproval": true,
    "financialActionsRequireApproval": true,
    "destructiveActionsRequireApproval": true,
    "autonomousTradingAllowed": false
  },
  "recommendedClientSettings": {
    "hideDuringScreenShare": true,
    "maxNudgesPerDay": 4
  }
}
```

## 12. Data model sketch

Local app tables/entities:

- `Conversation`
  - id, title, createdAt, updatedAt, gatewaySessionId, projectId
- `Message`
  - id, conversationId, role, text, createdAt, metadata
- `Attachment`
  - id, conversationId, path/blobRef, mimeType, source, sha256, retentionPolicy
- `PermissionGrant`
  - capability, status, scope, grantedAt, lastUsedAt
- `Command`
  - id, title, source, risk, requires, lastUsedAt
- `Nudge`
  - id, source, priority, title, body, createdAt, dismissedAt, snoozedUntil
- `Approval`
  - id, gatewayApprovalId, risk, title, details, decision, decidedAt
- `Project`
  - id, name, path, aliases, defaultCommands

## 13. Build plan

### Phase 0 — Spike

- SwiftUI floating borderless window.
- Menu bar app.
- Global hotkey.
- Hardcoded Gateway URL.
- Simple chat request/response against a mock endpoint.

Success: Ken can summon a floating character, type a message, and get a streamed response.

### Phase 1 — MVP integration

- Real Gateway session API adapter.
- SSE/WebSocket streaming.
- Screenshot capture and attachment upload.
- Basic approvals UI.
- Command palette with 5-6 commands.
- Preferences for permissions.

Success: Ken can use Lulo for screenshot debugging and routine Pinchy chat instead of Telegram.

### Phase 2 — Daily-driver v1

- Project detection.
- Browser active-tab bridge.
- Drag/drop files.
- Local transcript search.
- Reminders integration.
- Proactive nudge feed.
- Push-to-talk voice.

Success: Lulo becomes the default desktop entry point for coding/project/admin help.

### Phase 3 — Companion polish

- Character animation system.
- Better status visualization.
- Task cockpit.
- Workflow recipes.
- Privacy/audit dashboard.
- Redaction warnings.

Success: Lulo feels alive, safe, and deeply useful.

## 14. Open questions

- What should the character look like: Clippy homage, lobster/Pinchy, or original Lulo creature?
- Should chat history live only locally, or mirror to OpenClaw session history?
- Which Gateway APIs already exist and can be wrapped versus requiring new endpoints?
- Should voice use local Whisper first or existing OpenClaw TTS/STT skills?
- How much proactive behavior does Ken actually want during work hours?
- Should Lulo be Mac-only forever or designed for mobile/web companion surfaces later?

## 15. Practical first implementation recommendation

Build the smallest lovable desktop loop:

1. Floating character + menu bar.
2. Chat window to Gateway.
3. Screenshot and ask.
4. Approval cards.
5. Command palette.

Do not start with complex autonomy, always-on vision, or full workflow orchestration. If the first version makes it delightful and faster for Ken to ask Pinchy “what’s going on here?” while looking at code, dashboards, and browser pages, the product has a strong foundation.
