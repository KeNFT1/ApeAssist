import AppKit
import ApplicationServices

public protocol SelectedTextReading {
    func readSelectedText(userInitiated: Bool) throws -> SelectedTextContext
}

public final class SelectedTextService: SelectedTextReading {
    public init() {}

    /// Best-effort selected text capture through Accessibility.
    /// This does not synthesize keystrokes or copy text to the clipboard.
    public func readSelectedText(userInitiated: Bool) throws -> SelectedTextContext {
        guard userInitiated else { throw AmbientContextError.userInitiationRequired }
        guard AXIsProcessTrusted() else { throw AmbientContextError.permissionMissing("Accessibility") }
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { throw AmbientContextError.noFocusedApplication }

        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)
        var focusedElement: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusedResult == .success, let element = focusedElement else {
            throw AmbientContextError.noSelectedText
        }

        var selectedText: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
        guard selectedResult == .success, let text = selectedText as? String, !text.isEmpty else {
            throw AmbientContextError.noSelectedText
        }

        return SelectedTextContext(text: text)
    }
}
