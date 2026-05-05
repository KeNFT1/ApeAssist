# Lulo / Pinchy Clippy → OpenClaw Bridge

## Prototype added

- Swift source: `Sources/LuloClippy/OpenClawClient.swift`
- App integration: `Sources/LuloClippy/OpenClawBridge.swift` now uses `OpenClawClient` when POST mode is enabled.
- Primary API: `OpenClawClient.sendMessage(_:) async throws -> MessageResponse`
- Settings probe: `OpenClawClient.checkConnectivity()` calls `GET /v1/models` only, so it checks base URL/auth without creating an agent chat turn.
- Configurable values:
  - `httpBaseURL` — default `http://127.0.0.1:18789`
  - `webSocketURL` — default `ws://127.0.0.1:18789`
  - `agentTarget` — default `openclaw/default`
  - `sessionTarget` — default `agent:main:clippy:local`
  - `authToken` — optional placeholder only; do not commit real tokens
  - `modelOverride` — optional `x-openclaw-model`

The current implementation is intentionally stub-safe: it keeps dry-run mode on by default, uses OpenClaw's documented OpenResponses-compatible HTTP endpoint only after explicit opt-in, and does not implement a full operator WebSocket client yet.

Response parsing handles both common OpenResponses final formats:

- top-level `output_text`
- item-based `output[].content[].text` for assistant `message` items

HTTP errors are surfaced in the chat bubble with concise hints for auth failures and disabled `/v1/responses` routes.

## Exact local endpoints discovered

Source docs inspected first under `/opt/homebrew/lib/node_modules/openclaw/docs`.

### Primary send endpoint — discovered

`POST /v1/responses`

- Full local URL: `http://127.0.0.1:18789/v1/responses`
- Same Gateway port as WS + HTTP multiplex.
- Disabled by default; must enable:

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

Auth:

```http
Authorization: Bearer <gateway-token-or-password>
```

Routing headers:

```http
x-openclaw-session-key: agent:main:clippy:local
x-openclaw-model: <optional provider/model override>
```

Request shape used by prototype:

```json
{
  "model": "openclaw/default",
  "input": "hello from clippy",
  "instructions": null,
  "stream": false,
  "user": "agent:main:clippy:local"
}
```

Relevant docs:

- `/opt/homebrew/lib/node_modules/openclaw/docs/gateway/openresponses-http-api.md`
- `/opt/homebrew/lib/node_modules/openclaw/docs/gateway/openai-http-api.md`

### Alternate compatibility endpoint — discovered

`POST /v1/chat/completions`

- Full local URL: `http://127.0.0.1:18789/v1/chat/completions`
- Disabled by default; must enable `gateway.http.endpoints.chatCompletions.enabled`.
- Supports SSE with `stream: true`.
- Uses `model: "openclaw/default"` / `openclaw/<agentId>` and same auth headers.

### Native Gateway WebSocket — discovered

Root WS URL:

```text
ws://127.0.0.1:18789
```

Protocol:

- JSON text frames.
- Gateway first sends `connect.challenge` event.
- First client request must be `method: "connect"`.
- Operator client should request at least `operator.read` + `operator.write` for chat/session use.
- Common session methods:
  - `sessions.create`
  - `sessions.send`
  - `sessions.steer`
  - `sessions.abort`
  - `sessions.messages.subscribe`
  - `sessions.messages.unsubscribe`
- Streaming event families:
  - `session.message`
  - `session.tool`
  - `sessions.changed`
  - `chat`

Relevant docs/source:

- `/opt/homebrew/lib/node_modules/openclaw/docs/gateway/protocol.md`
- `/Users/pinchy/.openclaw/workspace/openclaw/src/gateway/server-methods/sessions.ts`
- `/Users/pinchy/.openclaw/workspace/openclaw/src/gateway/server.chat.gateway-server-chat.test.ts`

Discovered `sessions.send` params from tests/source:

```json
{
  "key": "agent:main:dashboard:test-send",
  "message": "hello from dashboard",
  "idempotencyKey": "idem-sessions-send-1"
}
```

## Recommended client plan

### Phase 1 — implemented now

Use `POST /v1/responses` non-streaming. This is the simplest stable bridge for a macOS pet/assistant app:

```swift
let client = OpenClawClient(configuration: .init(
    httpBaseURL: URL(string: "http://127.0.0.1:18789")!,
    sessionTarget: "agent:main:clippy:local",
    authToken: nil // inject from Keychain/user settings, never source
))

let reply = try await client.sendMessage("What should I do next?")
```

### Phase 2 — SSE streaming

Add `sendMessageStream(_:) -> AsyncThrowingStream<String, Error>` over `POST /v1/responses` with `stream: true` or `/v1/chat/completions` with `stream: true`.

Expected SSE semantics from docs:

- Response content type: `text/event-stream`
- Chunks: `data: <json>`
- Terminator: `data: [DONE]`

Implementation sketch:

1. Build the same request with `stream: true`.
2. Use `URLSession.bytes(for:)`.
3. Parse line-delimited SSE.
4. Decode OpenResponses delta events if present; otherwise accumulate raw text-compatible deltas.
5. Yield partial text into the Clippy speech bubble.

### Phase 3 — native WS control plane

Use WS when Clippy needs richer app state: session list, active run status, abort/steer, tool events, or shared Control UI behavior.

Handshake outline:

```json
{
  "type": "req",
  "id": "connect-1",
  "method": "connect",
  "params": {
    "minProtocol": 3,
    "maxProtocol": 3,
    "client": {
      "id": "lulo-clippy",
      "version": "0.1.0",
      "platform": "macos",
      "mode": "operator"
    },
    "role": "operator",
    "scopes": ["operator.read", "operator.write"],
    "caps": [],
    "commands": [],
    "permissions": {},
    "auth": { "token": "<from Keychain/settings>" },
    "locale": "en-US",
    "userAgent": "lulo-clippy/0.1.0"
  }
}
```

Then:

1. `sessions.resolve` or `sessions.create` for `agent:main:clippy:local`.
2. `sessions.messages.subscribe` for streaming transcript events.
3. `sessions.send` with `{ key, message, idempotencyKey }`.
4. Accumulate `session.message` events until run completion; optionally call `agent.wait`.

## Unknown / next lookup needed

- Exact OpenResponses streaming event JSON variants were not fully pinned from docs; docs only guarantee SSE framing and `[DONE]` termination. Next lookup: inspect Gateway OpenResponses HTTP handler source/tests before implementing delta parsing.
- Whether Ken wants Clippy to talk to the default main session or an isolated `agent:main:clippy:local` session is product/config choice. Prototype defaults to isolated Clippy session to avoid contaminating active chat context.
- Auth UX: decide between local no-auth/private mode, shared Gateway token stored in Keychain, or device-pairing/operator token flow before shipping WebSocket operator access.
