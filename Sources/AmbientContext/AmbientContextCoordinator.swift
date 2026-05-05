import Foundation

public struct ChatContextDraft: Sendable, Equatable {
    public var activeWindow: ActiveWindowContext?
    public var clipboard: ClipboardContext?
    public var selectedText: SelectedTextContext?
    public var screenshotPNGData: Data?

    public init(
        activeWindow: ActiveWindowContext? = nil,
        clipboard: ClipboardContext? = nil,
        selectedText: SelectedTextContext? = nil,
        screenshotPNGData: Data? = nil
    ) {
        self.activeWindow = activeWindow
        self.clipboard = clipboard
        self.selectedText = selectedText
        self.screenshotPNGData = screenshotPNGData
    }
}

public final class AmbientContextCoordinator {
    private let activeWindowService: ActiveWindowProviding
    private let clipboardService: ClipboardReading
    private let selectedTextService: SelectedTextReading
    private let screenshotService: ScreenshotCapturing

    public init(
        activeWindowService: ActiveWindowProviding = ActiveWindowService(),
        clipboardService: ClipboardReading = ClipboardService(),
        selectedTextService: SelectedTextReading = SelectedTextService(),
        screenshotService: ScreenshotCapturing = ScreenshotCaptureService()
    ) {
        self.activeWindowService = activeWindowService
        self.clipboardService = clipboardService
        self.selectedTextService = selectedTextService
        self.screenshotService = screenshotService
    }

    public func whatAmILookingAtDraft() -> ChatContextDraft {
        ChatContextDraft(activeWindow: activeWindowService.currentActiveWindow())
    }

    public func includeClipboardDraft() throws -> ChatContextDraft {
        ChatContextDraft(clipboard: try clipboardService.readPlainText(userInitiated: true))
    }

    public func includeSelectedTextDraft() throws -> ChatContextDraft {
        ChatContextDraft(selectedText: try selectedTextService.readSelectedText(userInitiated: true))
    }

    public func includeScreenshotDraft(scope: ScreenshotCaptureRequest.Scope = .activeWindow) throws -> ChatContextDraft {
        let png = try screenshotService.capturePNGData(.init(scope: scope, userInitiated: true))
        return ChatContextDraft(activeWindow: activeWindowService.currentActiveWindow(), screenshotPNGData: png)
    }
}
