import Foundation
@preconcurrency import UserNotifications

/// Notification permission/status seam for Lulo.
///
/// The app may refresh status freely, but it must only request permission from an
/// explicit user action (for example, the Settings button wired to
/// `requestNotificationPermission()`).
@MainActor
final class NotificationUXController: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastPermissionError: String?

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            lastPermissionError = nil
        } catch {
            lastPermissionError = error.localizedDescription
        }
        await refreshAuthorizationStatus()
    }

    /// Safe local notification hook. Callers should provide a stable identifier for dedupe.
    func notify(title: String, body: String, identifier: String = UUID().uuidString) async {
        await refreshAuthorizationStatus()
        guard authorizationStatus.allowsLocalNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

extension UNAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Authorized"
        case .provisional: "Provisional"
        @unknown default: "Unknown"
        }
    }

    var allowsLocalNotifications: Bool {
        self == .authorized || self == .provisional
    }
}
