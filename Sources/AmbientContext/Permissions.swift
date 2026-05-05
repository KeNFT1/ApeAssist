import AppKit
import ApplicationServices
import CoreGraphics

public struct AmbientPermissionStatus: Sendable, Equatable {
    public let accessibilityTrusted: Bool
    public let screenRecordingGranted: Bool

    public init(accessibilityTrusted: Bool, screenRecordingGranted: Bool) {
        self.accessibilityTrusted = accessibilityTrusted
        self.screenRecordingGranted = screenRecordingGranted
    }
}

public enum AmbientPermissions {
    /// Passive check. Does not prompt the user.
    public static func currentStatus() -> AmbientPermissionStatus {
        AmbientPermissionStatus(
            accessibilityTrusted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
    }

    /// Shows the system Accessibility prompt / opens System Settings if not already trusted.
    /// Call only from an explicit user action such as "Enable selected text".
    @discardableResult
    public static func requestAccessibilityPrompt() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Shows the macOS Screen Recording permission prompt.
    /// Call only from an explicit user action such as "Enable screenshot context".
    @discardableResult
    public static func requestScreenRecordingPrompt() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public static var accessibilitySettingsURL: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public static var screenRecordingSettingsURL: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }
}
