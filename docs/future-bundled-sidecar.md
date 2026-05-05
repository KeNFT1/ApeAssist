# Future bundled backend sidecar (Tier 2)

Tier 1.5 keeps ApeAssist cleanly packaged while requiring a separately running local OpenClaw Gateway. A later Tier 2 release can bundle/manage a backend sidecar, but should do it deliberately rather than hiding a fragile process spawn in the UI.

## Proposed architecture

- Ship `ApeAssist.app` plus a version-pinned OpenClaw sidecar payload inside `Contents/Resources/OpenClawSidecar/` or as a companion installer package.
- On first run, create an app-scoped config directory under `~/Library/Application Support/ApeAssist/`.
- Generate or import a Gateway bearer token and store it in Keychain (`app.apeassist.gateway`).
- Run the sidecar through `launchd` as a user LaunchAgent, not as a random child process, so it survives app restarts and has observable logs.
- Bind only to `127.0.0.1` by default.
- Enable only the HTTP routes ApeAssist needs (`/v1/responses` first), keeping operator-scope WebSocket access behind an explicit pairing/permission step.
- Surface sidecar health in Settings: version, port, auth, logs location, restart button, and uninstall/stop instructions.

## Safety requirements before bundling

- No hardcoded secrets in the app bundle.
- Explicit user consent before installing a LaunchAgent or modifying Gateway config.
- Signed/notarized app and signed sidecar artifacts.
- Clear failure recovery if the port is occupied or OpenClaw is already installed.
- Uninstall path that removes LaunchAgent files but preserves user data unless explicitly requested.

## Not included in Tier 1.5

- No embedded OpenClaw binary/runtime.
- No automatic global OpenClaw config edits.
- No login item/LaunchAgent installation by default.
- No native operator WebSocket bridge for tool approvals yet.
