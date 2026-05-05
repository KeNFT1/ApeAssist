import Foundation
import CoreGraphics

public struct ActiveWindowContext: Sendable, Equatable {
    public let appName: String?
    public let bundleIdentifier: String?
    public let processIdentifier: pid_t?
    public let windowTitle: String?

    public init(appName: String?, bundleIdentifier: String?, processIdentifier: pid_t?, windowTitle: String?) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.windowTitle = windowTitle
    }
}

public struct ClipboardContext: Sendable, Equatable {
    public let plainText: String
    public let characterCount: Int
    public let capturedAt: Date

    public init(plainText: String, capturedAt: Date = Date()) {
        self.plainText = plainText
        self.characterCount = plainText.count
        self.capturedAt = capturedAt
    }
}

public struct SelectedTextContext: Sendable, Equatable {
    public let text: String
    public let source: String

    public init(text: String, source: String = "accessibility-selected-text") {
        self.text = text
        self.source = source
    }
}

public struct ScreenshotCaptureRequest: Sendable, Equatable {
    public enum Scope: Sendable, Equatable {
        case activeWindow
        case fullDisplay(CGDirectDisplayID)
    }

    public let scope: Scope
    public let includeCursor: Bool
    public let userInitiated: Bool

    public init(scope: Scope = .activeWindow, includeCursor: Bool = false, userInitiated: Bool) {
        self.scope = scope
        self.includeCursor = includeCursor
        self.userInitiated = userInitiated
    }
}

public enum AmbientContextError: Error, Equatable, LocalizedError {
    case permissionMissing(String)
    case noFocusedApplication
    case noSelectedText
    case userInitiationRequired
    case captureNotImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .permissionMissing(let permission): return "Missing permission: \(permission)"
        case .noFocusedApplication: return "No focused application is available."
        case .noSelectedText: return "No selected text was found."
        case .userInitiationRequired: return "This capture must be initiated by an explicit user action."
        case .captureNotImplemented(let detail): return detail
        }
    }
}
