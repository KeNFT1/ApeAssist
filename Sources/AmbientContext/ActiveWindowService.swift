import AppKit
import CoreGraphics

public protocol ActiveWindowProviding {
    func currentActiveWindow() -> ActiveWindowContext
}

public final class ActiveWindowService: ActiveWindowProviding {
    public init() {}

    /// Returns frontmost app metadata. Window title is best-effort: many apps require
    /// Screen Recording permission before macOS exposes other apps' window names.
    public func currentActiveWindow() -> ActiveWindowContext {
        let app = NSWorkspace.shared.frontmostApplication
        let pid = app?.processIdentifier
        let title = pid.flatMap { Self.frontmostWindowTitle(processIdentifier: $0) }

        return ActiveWindowContext(
            appName: app?.localizedName,
            bundleIdentifier: app?.bundleIdentifier,
            processIdentifier: pid,
            windowTitle: title
        )
    }

    private static func frontmostWindowTitle(processIdentifier pid: pid_t) -> String? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        return windowInfo.first { entry in
            guard let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t else { return false }
            guard ownerPID == pid else { return false }
            // Layer 0 approximates normal app windows and avoids menus/tooltips.
            return (entry[kCGWindowLayer as String] as? Int) == 0
        }?[kCGWindowName as String] as? String
    }
}
