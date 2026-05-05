import AppKit
import CoreGraphics

public protocol ScreenshotCapturing {
    /// Produces PNG data for a screenshot. Implementations must require explicit user initiation.
    func capturePNGData(_ request: ScreenshotCaptureRequest) throws -> Data
}

public final class ScreenshotCaptureService: ScreenshotCapturing {
    public init() {}

    /// Captures PNG bytes only for an explicit user-initiated request.
    ///
    /// The chat UI owns the visible indicator and preview/approval sheet. This service is
    /// deliberately small and synchronous so it cannot run as a background watcher.
    public func capturePNGData(_ request: ScreenshotCaptureRequest) throws -> Data {
        guard request.userInitiated else { throw AmbientContextError.userInitiationRequired }
        guard CGPreflightScreenCaptureAccess() else { throw AmbientContextError.permissionMissing("Screen Recording") }
        guard request.includeCursor == false else {
            throw AmbientContextError.captureNotImplemented("Screenshot capture is available without cursor only. Cursor compositing needs a follow-up ScreenCaptureKit implementation.")
        }

        let image: CGImage?
        switch request.scope {
        case .activeWindow:
            image = try captureActiveWindowImage()
        case .fullDisplay(let displayID):
            image = CGDisplayCreateImage(displayID)
        }

        guard let image else {
            throw AmbientContextError.captureNotImplemented("Could not capture the requested screenshot. Try a full-display capture or grant Screen Recording and relaunch ApeAssist.")
        }

        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw AmbientContextError.captureNotImplemented("Captured the screenshot but could not encode it as PNG.")
        }
        return pngData
    }

    private func captureActiveWindowImage() throws -> CGImage? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw AmbientContextError.noFocusedApplication
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        guard let windowID = windowInfo.first(where: { entry in
            guard let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t else { return false }
            guard ownerPID == frontmostApp.processIdentifier else { return false }
            guard (entry[kCGWindowLayer as String] as? Int) == 0 else { return false }
            let bounds = (entry[kCGWindowBounds as String] as? NSDictionary)
                .flatMap { CGRect(dictionaryRepresentation: $0) } ?? .zero
            return bounds.width > 1 && bounds.height > 1
        })?[kCGWindowNumber as String] as? CGWindowID else {
            throw AmbientContextError.captureNotImplemented("No capturable active window was found. Full-display capture can be added behind an explicit scope chooser.")
        }

        return CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
    }
}
