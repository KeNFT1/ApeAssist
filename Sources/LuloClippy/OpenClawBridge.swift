import Foundation
import SwiftUI

@MainActor
final class OpenClawBridge: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hi Ken — I’m ApeAssist, your native macOS AI sidekick. The OpenClaw bridge is wired for the local Gateway and risky actions still require explicit approval cards.")
    ]
    @Published private(set) var isSending = false
    @Published private(set) var isCheckingConnectivity = false
    @Published private(set) var connectivityStatus: OpenClawClient.ConnectivityCheck?
    @Published private(set) var configuration = OpenClawBridgeConfiguration.current()
    @Published private(set) var pendingActions: [PendingAction] = []
    @Published var mediaPreview: MediaPreviewRequest?

    func reloadConfiguration() {
        configuration = OpenClawBridgeConfiguration.current()
        connectivityStatus = nil
    }

    func saveBearerToken(_ token: String) throws {
        try KeychainGatewayTokenStore().saveToken(token)
        UserDefaults.standard.removeObject(forKey: SettingsKey.token)
        reloadConfiguration()
    }

    func deleteBearerToken() throws {
        try KeychainGatewayTokenStore().deleteToken()
        UserDefaults.standard.removeObject(forKey: SettingsKey.token)
        reloadConfiguration()
    }

    func checkConnectivity() async {
        reloadConfiguration()
        isCheckingConnectivity = true
        defer { isCheckingConnectivity = false }
        connectivityStatus = await makeClient().checkConnectivity()
    }

    func send(_ text: String) async {
        reloadConfiguration()
        messages.append(ChatMessage(role: .user, text: text))
        isSending = true
        defer { isSending = false }

        if let proposal = PendingAction.placeholderProposal(for: text) {
            enqueuePendingAction(proposal)
            messages.append(ChatMessage(role: .assistant, text: "I spotted a potentially risky action and paused for confirmation. Review the approval card before anything proceeds."))
            return
        }

        guard configuration.postingEnabled else {
            messages.append(ChatMessage(role: .assistant, text: "Placeholder bridge received: \"\(text)\"\n\nEnable POST mode in Settings or set LULO_OPENCLAW_ENABLE_POST=true when the local OpenClaw endpoint is ready. Risky actions will still require explicit approval cards."))
            return
        }

        do {
            let response = try await makeClient().sendMessage(text)
            messages.append(ChatMessage(role: .assistant, text: response.text))
            if !response.media.isEmpty {
                mediaPreview = MediaPreviewRequest(artifacts: response.media)
            }
            if let proposal = PendingAction.placeholderProposal(for: response.text) {
                enqueuePendingAction(proposal)
            }
        } catch {
            messages.append(ChatMessage(role: .assistant, text: "Bridge request failed: \(error.localizedDescription)"))
        }
    }

    func approve(_ action: PendingAction) {
        updatePendingAction(action.id, status: .approved)
        messages.append(ChatMessage(role: .assistant, text: "Approved once: \(action.title)\n\nGateway approval dispatch is not wired yet, so no external action was executed."))
    }

    func deny(_ action: PendingAction) {
        updatePendingAction(action.id, status: .denied)
        messages.append(ChatMessage(role: .assistant, text: "Denied: \(action.title)"))
    }

    private func enqueuePendingAction(_ action: PendingAction) {
        pendingActions.insert(action, at: 0)
    }

    private func updatePendingAction(_ id: PendingAction.ID, status: PendingActionStatus) {
        guard let index = pendingActions.firstIndex(where: { $0.id == id }) else { return }
        pendingActions[index].status = status
    }

    private func makeClient() -> OpenClawClient {
        OpenClawClient(
            configuration: .init(
                httpBaseURL: configuration.httpBaseURL,
                webSocketURL: configuration.webSocketURL,
                agentTarget: configuration.agentTarget,
                sessionTarget: configuration.sessionTarget,
                authToken: configuration.bearerToken.nilIfEmpty,
                modelOverride: configuration.modelOverride.nilIfEmpty
            )
        )
    }
}

enum OpenClawBackendMode: String, CaseIterable, Identifiable, Sendable {
    case local
    case remoteTailscale

    var id: String { rawValue }

    var label: String {
        switch self {
        case .local: "This Mac"
        case .remoteTailscale: "Mac mini over Tailscale"
        }
    }
}

struct OpenClawBridgeConfiguration: Sendable {
    let backendMode: OpenClawBackendMode
    let httpBaseURL: URL
    let webSocketURL: URL
    let sessionTarget: String
    let agentTarget: String
    let bearerToken: String
    let modelOverride: String
    let postingEnabled: Bool

    var modeDescription: String {
        postingEnabled ? "Posting to \(backendMode.label): \(httpBaseURL.absoluteString) as \(agentTarget)" : "Dry-run bridge placeholder"
    }

    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard,
        tokenStore: GatewayTokenStore = KeychainGatewayTokenStore()
    ) -> OpenClawBridgeConfiguration {
        let backendMode = OpenClawBackendMode(rawValue: environment["APEASSIST_OPENCLAW_BACKEND_MODE"]
            ?? defaults.string(forKey: SettingsKey.backendMode)
            ?? SettingsKey.defaultBackendMode) ?? .local
        let configuredEndpoint = backendMode == .remoteTailscale
            ? (defaults.string(forKey: SettingsKey.remoteEndpoint) ?? SettingsKey.defaultRemoteEndpoint)
            : (defaults.string(forKey: SettingsKey.endpoint) ?? SettingsKey.defaultEndpoint)
        let httpBase = environment["LULO_OPENCLAW_HTTP_BASE_URL"]
            ?? environment["LULO_OPENCLAW_ENDPOINT"]
            ?? configuredEndpoint
        let httpURL = URL(string: httpBase) ?? URL(string: SettingsKey.defaultEndpoint)!

        let ws = environment["LULO_OPENCLAW_WS_URL"]
            ?? (backendMode == .remoteTailscale ? Self.webSocketURLString(fromHTTP: httpURL) : defaults.string(forKey: SettingsKey.webSocketURL))
            ?? SettingsKey.defaultWebSocketURL
        let wsURL = URL(string: ws) ?? URL(string: SettingsKey.defaultWebSocketURL)!

        let session = environment["LULO_OPENCLAW_SESSION"]
            ?? defaults.string(forKey: SettingsKey.session)
            ?? SettingsKey.defaultSession
        let agent = environment["LULO_OPENCLAW_AGENT"]
            ?? defaults.string(forKey: SettingsKey.agentTarget)
            ?? SettingsKey.defaultAgentTarget
        GatewayTokenMigration.migrateUserDefaultsTokenIfNeeded(defaults: defaults, tokenStore: tokenStore)
        let token = environment["LULO_OPENCLAW_TOKEN"]
            ?? tokenStore.loadToken()
            ?? Self.gatewayTokenFromLocalOpenClawConfig()
            ?? ""
        let modelOverride = environment["LULO_OPENCLAW_MODEL"]
            ?? defaults.string(forKey: SettingsKey.modelOverride)
            ?? ""
        let enabledText = environment["LULO_OPENCLAW_ENABLE_POST"]
            ?? defaults.string(forKey: SettingsKey.postingEnabled)
            ?? "true"
        let enabled = ["1", "true", "yes", "on"].contains(enabledText.lowercased())

        return OpenClawBridgeConfiguration(
            backendMode: backendMode,
            httpBaseURL: httpURL,
            webSocketURL: wsURL,
            sessionTarget: session,
            agentTarget: agent,
            bearerToken: token,
            modelOverride: modelOverride,
            postingEnabled: enabled
        )
    }

    private static func webSocketURLString(fromHTTP url: URL) -> String? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch components?.scheme?.lowercased() {
        case "https": components?.scheme = "wss"
        case "http": components?.scheme = "ws"
        default: return nil
        }
        return components?.url?.absoluteString
    }

    private static func gatewayTokenFromLocalOpenClawConfig() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent(".openclaw/openclaw.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gateway = object["gateway"] as? [String: Any],
              let auth = gateway["auth"] as? [String: Any],
              let token = auth["token"] as? String,
              !token.isEmpty
        else { return nil }
        return token
    }
}

enum SettingsKey {
    static let backendMode = "openclaw.backendMode"
    static let endpoint = "openclaw.endpoint"
    static let remoteEndpoint = "openclaw.remoteEndpoint"
    static let webSocketURL = "openclaw.webSocketURL"
    static let session = "openclaw.session"
    static let agentTarget = "openclaw.agentTarget"
    static let modelOverride = "openclaw.modelOverride"
    static let token = "openclaw.token"
    static let postingEnabled = "openclaw.postingEnabled"
    static let postingDefaultMigrated = "openclaw.postingDefaultMigrated"

    static let defaultEndpoint = "http://127.0.0.1:18789"
    static let defaultRemoteEndpoint = "http://mac-mini.tailnet-name.ts.net:18789"
    static let defaultWebSocketURL = "ws://127.0.0.1:18789"
    static let defaultSession = "agent:main:clippy:local"
    static let defaultAgentTarget = "openclaw/default"
    static let defaultBackendMode = OpenClawBackendMode.local.rawValue

    static var defaultValues: [String: Any] {
        [
            backendMode: defaultBackendMode,
            endpoint: defaultEndpoint,
            remoteEndpoint: defaultRemoteEndpoint,
            webSocketURL: defaultWebSocketURL,
            session: defaultSession,
            agentTarget: defaultAgentTarget,
            modelOverride: "",
            token: "",
            postingEnabled: "true",
            postingDefaultMigrated: false
        ]
    }

    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: defaultValues)

        // Older prototype builds registered POST as dry-run/false. Flip that one-time default
        // so the local Gateway bridge works out of the box, while still respecting a later
        // explicit user toggle back to false.
        if defaults.bool(forKey: postingDefaultMigrated) == false {
            defaults.set("true", forKey: postingEnabled)
            defaults.set(true, forKey: postingDefaultMigrated)
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: ChatRole
    let text: String
}

struct MediaPreviewRequest: Identifiable, Equatable {
    let id = UUID()
    let artifacts: [MediaArtifact]
}

enum ChatRole: Equatable {
    case user
    case assistant

    var displayName: String {
        switch self {
        case .user: "You"
        case .assistant: "ApeAssist"
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
