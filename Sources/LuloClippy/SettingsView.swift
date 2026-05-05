import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var bridge: OpenClawBridge
    @EnvironmentObject private var appState: AppState

    @AppStorage(SettingsKey.backendMode) private var backendMode = SettingsKey.defaultBackendMode
    @AppStorage(SettingsKey.endpoint) private var endpoint = SettingsKey.defaultEndpoint
    @AppStorage(SettingsKey.remoteEndpoint) private var remoteEndpoint = SettingsKey.defaultRemoteEndpoint
    @AppStorage(SettingsKey.webSocketURL) private var webSocketURL = SettingsKey.defaultWebSocketURL
    @AppStorage(SettingsKey.session) private var session = SettingsKey.defaultSession
    @AppStorage(SettingsKey.agentTarget) private var agentTarget = SettingsKey.defaultAgentTarget
    @AppStorage(SettingsKey.modelOverride) private var modelOverride = ""
    @AppStorage(SettingsKey.postingEnabled) private var postingEnabled = "true"
    @State private var tokenInput = ""
    @State private var tokenSaveMessage: String?

    var body: some View {
        Form {
            Section("OpenClaw Bridge") {
                Picker("Where is OpenClaw running?", selection: $backendMode) {
                    ForEach(OpenClawBackendMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                if selectedBackendMode == .remoteTailscale {
                    TextField("Tailscale Gateway URL", text: $remoteEndpoint)
                        .textFieldStyle(.roundedBorder)
                    Text("Use your Mac mini's Tailscale endpoint, for example http://<mac-mini-tailscale-ip>:18789. Keep Tailscale connected on both Macs and save the Gateway bearer token below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Gateway HTTP base URL", text: $endpoint)
                        .textFieldStyle(.roundedBorder)
                    TextField("Gateway WebSocket URL", text: $webSocketURL)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Session target", text: $session)
                    .textFieldStyle(.roundedBorder)
                TextField("Agent target", text: $agentTarget)
                    .textFieldStyle(.roundedBorder)
                TextField("Model override (optional)", text: $modelOverride)
                    .textFieldStyle(.roundedBorder)
                SecureField("Gateway bearer token", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save Token to Keychain") { saveToken() }
                        .disabled(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove Saved Token") { removeToken() }
                    if let tokenSaveMessage {
                        Text(tokenSaveMessage)
                            .font(.caption)
                            .foregroundStyle(tokenSaveMessage.contains("failed") ? .red : .secondary)
                    }
                }
                Text("Secrets are stored in macOS Keychain. Legacy UserDefaults tokens are migrated automatically; environment variable LULO_OPENCLAW_TOKEN still overrides for local dev.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Enable HTTP POST to /v1/responses", isOn: postingBinding)
                LabeledContent("Current mode", value: bridge.configuration.modeDescription)
                LabeledContent("Auth", value: bridge.configuration.bearerToken.isEmpty ? "No token saved/detected" : "Token available")
                HStack {
                    Button(bridge.isCheckingConnectivity ? "Checking…" : "Check Gateway") {
                        Task { await bridge.checkConnectivity() }
                    }
                    .disabled(bridge.isCheckingConnectivity)

                    if bridge.isCheckingConnectivity {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if let status = bridge.connectivityStatus {
                    GatewayStatusView(status: status)
                } else {
                Text("Check Gateway probes the configured backend and /v1/responses setup without sending a chat turn.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SetupInstructionsView(status: bridge.connectivityStatus)
            }

            VoiceSettingsSection(appState: appState, controller: appState.voiceInteraction)

            NotificationSettingsSection(controller: appState.notifications)

            Section("Next Permissions") {
                PermissionRow(title: "Accessibility", detail: "Needed later for clicking/typing into other apps.")
                PermissionRow(title: "Screen Recording", detail: "Needed later for visual context/screenshot analysis.")
                PermissionRow(title: "Microphone", detail: "Needed later for voice input and wake/listen modes. Not requested automatically.")
            }

            Section("Sprite Animation") {
                Picker("Preview state", selection: $appState.assistantStatus) {
                    ForEach(AssistantStatus.allCases) { status in
                        Label(status.label, systemImage: status.systemImage).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                Slider(value: $appState.animationSpeed, in: 0.5...2.0) {
                    Text("Animation speed")
                } minimumValueLabel: {
                    Text("0.5×")
                } maximumValueLabel: {
                    Text("2×")
                }
                LabeledContent("Speed", value: appState.animationSpeed.formatted(.number.precision(.fractionLength(1))) + "×")
                Toggle("Show debug controls under floating buddy", isOn: $appState.showAnimationDebug)
            }

            Section("Status") {
                Text("This is a lightweight native scaffold. The always-on-top buddy, menu bar controls, chat panel, and endpoint/session/channel placeholders are present; external posting remains opt-in.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .onChange(of: backendMode) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: endpoint) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: remoteEndpoint) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: webSocketURL) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: session) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: agentTarget) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: modelOverride) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: postingEnabled) { _, _ in bridge.reloadConfiguration() }
        .task {
            GatewayTokenMigration.migrateUserDefaultsTokenIfNeeded()
            tokenInput = KeychainGatewayTokenStore().loadToken() ?? ""
            bridge.reloadConfiguration()
        }
    }

    private var selectedBackendMode: OpenClawBackendMode {
        OpenClawBackendMode(rawValue: backendMode) ?? .local
    }

    private var postingBinding: Binding<Bool> {
        Binding(
            get: { ["1", "true", "yes", "on"].contains(postingEnabled.lowercased()) },
            set: { postingEnabled = $0 ? "true" : "false" }
        )
    }

    private func saveToken() {
        do {
            try bridge.saveBearerToken(tokenInput)
            tokenInput = KeychainGatewayTokenStore().loadToken() ?? ""
            tokenSaveMessage = "Saved to Keychain."
        } catch {
            tokenSaveMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func removeToken() {
        do {
            try bridge.deleteBearerToken()
            tokenInput = ""
            tokenSaveMessage = "Removed saved token."
        } catch {
            tokenSaveMessage = "Remove failed: \(error.localizedDescription)"
        }
    }
}

private struct VoiceSettingsSection: View {
    let appState: AppState
    @ObservedObject var controller: VoiceInteractionController

    var body: some View {
        Section("Voice") {
            LabeledContent("Push-to-talk", value: controller.isPushToTalkHeld ? "Listening" : "Hold Option+Space")
            HStack {
                Button("Start Listening Preview") { controller.beginPushToTalk() }
                    .disabled(controller.isPushToTalkHeld)
                Button("Stop") { controller.endPushToTalk() }
                    .disabled(!controller.isPushToTalkHeld)
                Button("Speak Local Preview") { appState.speakLocalPreview("ApeAssist local speech preview.") }
            }
            Text("This is only a UX seam: ApeAssist does not record audio or transcribe yet. Local speech uses macOS AVSpeechSynthesizer; external TTS is not called.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GatewayStatusView: View {
    let status: OpenClawClient.ConnectivityCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusRow("Backend", ok: status.backendOnline, good: "Online", bad: "Offline")
            statusRow("Auth", ok: status.authOK, good: "OK", bad: "Missing/invalid token")
            statusRow("Responses", ok: status.responsesStatus.isUsable, good: "/v1/responses usable", bad: status.responsesStatus.label)
            Text(status.message)
                .font(.caption)
                .foregroundStyle(status.ok ? .green : .orange)
        }
        .font(.caption)
    }

    private func statusRow(_ title: String, ok: Bool, good: String, bad: String) -> some View {
        Label("\(title): \(ok ? good : bad)", systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(ok ? .green : .orange)
    }
}

private struct SetupInstructionsView: View {
    let status: OpenClawClient.ConnectivityCheck?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if status?.backendOnline == false {
                Text("Backend missing: start OpenClaw Gateway locally, then re-check.")
            }
            if status?.authOK == false {
                Text("Auth missing: paste your Gateway bearer token above and save it to Keychain.")
            }
            if let status, !status.responsesStatus.isUsable, status.authOK {
                Text("Endpoint issue: enable OpenClaw Gateway's OpenResponses endpoint: gateway.http.endpoints.responses.enabled = true.")
            }
            if status == nil {
                Text("Prerequisites: local OpenClaw Gateway at http://127.0.0.1:18789, valid bearer token when auth is enabled, and /v1/responses enabled for live chat.")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct NotificationSettingsSection: View {
    @ObservedObject var controller: NotificationUXController

    var body: some View {
        Section("Notifications") {
            LabeledContent("Permission", value: controller.authorizationStatus.displayName)
            Text("ApeAssist can notify you for useful local events like completed tasks or bridge status. Permission is requested only when you click the button below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh Status") {
                    Task { await controller.refreshAuthorizationStatus() }
                }
                Button("Request Notification Permission") {
                    Task { await controller.requestNotificationPermission() }
                }
                .disabled(controller.authorizationStatus != .notDetermined)
            }

            if let error = controller.lastPermissionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task {
            await controller.refreshAuthorizationStatus()
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}
