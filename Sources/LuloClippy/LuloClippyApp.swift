import SwiftUI
import AppKit

@main
struct LuloClippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        SettingsKey.registerDefaults()
    }

    var body: some Scene {
        MenuBarExtra("ApeAssist", systemImage: "bubble.left.and.bubble.right.fill") {
            MenuBarControls()
                .environmentObject(appDelegate.appState)
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("ApeAssist Chat", id: "chat") {
            ChatPanelView()
                .environmentObject(appDelegate.bridge)
                .environmentObject(appDelegate.appState)
                .frame(minWidth: 420, minHeight: 520)
        }
        .defaultSize(width: 460, height: 580)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.bridge)
                .environmentObject(appDelegate.appState)
                .frame(width: 620, height: 620)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var appState = AppState()
    lazy var bridge = OpenClawBridge()
    private var buddyController: FloatingBuddyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buddyController = FloatingBuddyController(appState: appState, bridge: bridge)
        appState.showBuddy = { [weak self] in self?.buddyController?.show() }
        appState.hideBuddy = { [weak self] in self?.buddyController?.hide() }
        appState.voiceInteraction.installPushToTalkShortcut()
        Task { await appState.notifications.refreshAuthorizationStatus() }
        buddyController?.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.voiceInteraction.removePushToTalkShortcut()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var buddyVisible = true
    @Published var assistantStatus: AssistantStatus = .idle
    @Published var animationSpeed = 1.0
    @Published var showAnimationDebug = false

    let voiceInteraction = VoiceInteractionController()
    let notifications = NotificationUXController()

    var showBuddy: (() -> Void)?
    var hideBuddy: (() -> Void)?

    init() {
        voiceInteraction.configure(appState: self)
    }

    func setBuddyVisible(_ visible: Bool) {
        buddyVisible = visible
        visible ? showBuddy?() : hideBuddy?()
    }

    func setStatus(_ status: AssistantStatus) {
        assistantStatus = status
    }

    func speakBriefly(duration: Duration = .seconds(1.8)) {
        assistantStatus = .talking
        Task { @MainActor in
            try? await Task.sleep(for: duration)
            if assistantStatus == .talking {
                assistantStatus = .idle
            }
        }
    }

    func finishBridgeTurn(hasPendingApproval: Bool) {
        if hasPendingApproval {
            assistantStatus = .needsConfirmation
        } else {
            speakBriefly()
        }
    }

    func reconcileApprovalStatus(hasPendingApproval: Bool) {
        if hasPendingApproval {
            assistantStatus = .needsConfirmation
        } else if assistantStatus == .needsConfirmation {
            speakBriefly(duration: .seconds(1.2))
        }
    }

    func speakLocalPreview(_ text: String) {
        voiceInteraction.speakPreview(text)
    }
}
