import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var bridge: OpenClawBridge
    @EnvironmentObject private var appState: AppState

    @AppStorage(SettingsKey.endpoint) private var endpoint = SettingsKey.defaultEndpoint
    @AppStorage(SettingsKey.webSocketURL) private var webSocketURL = SettingsKey.defaultWebSocketURL
    @AppStorage(SettingsKey.session) private var session = SettingsKey.defaultSession
    @AppStorage(SettingsKey.agentTarget) private var agentTarget = SettingsKey.defaultAgentTarget
    @AppStorage(SettingsKey.modelOverride) private var modelOverride = ""
    @AppStorage(SettingsKey.token) private var token = ""
    @AppStorage(SettingsKey.postingEnabled) private var postingEnabled = "false"

    var body: some View {
        Form {
            Section("OpenClaw Bridge") {
                TextField("Gateway HTTP base URL", text: $endpoint)
                    .textFieldStyle(.roundedBorder)
                TextField("Gateway WebSocket URL", text: $webSocketURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Session target", text: $session)
                    .textFieldStyle(.roundedBorder)
                TextField("Agent target", text: $agentTarget)
                    .textFieldStyle(.roundedBorder)
                TextField("Model override (optional)", text: $modelOverride)
                    .textFieldStyle(.roundedBorder)
                SecureField("Bearer token (optional; local ~/.openclaw config is used when blank)", text: $token)
                    .textFieldStyle(.roundedBorder)
                Toggle("Enable HTTP POST", isOn: postingBinding)
                LabeledContent("Current mode", value: bridge.configuration.modeDescription)
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
                    Label(status.message, systemImage: status.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(status.ok ? .green : .orange)
                } else {
                    Text("Connectivity check calls GET /v1/models only; it does not send a chat turn. Chat POST is enabled by default for the local Gateway.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .onChange(of: endpoint) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: webSocketURL) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: session) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: agentTarget) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: modelOverride) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: token) { _, _ in bridge.reloadConfiguration() }
        .onChange(of: postingEnabled) { _, _ in bridge.reloadConfiguration() }
    }

    private var postingBinding: Binding<Bool> {
        Binding(
            get: { ["1", "true", "yes", "on"].contains(postingEnabled.lowercased()) },
            set: { postingEnabled = $0 ? "true" : "false" }
        )
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
