import AppKit

public protocol ClipboardReading {
    func readPlainText(userInitiated: Bool) throws -> ClipboardContext?
}

public final class ClipboardService: ClipboardReading {
    public init() {}

    /// Reads plain text only after a user gesture such as clicking "Include clipboard".
    /// The returned value should be held locally and previewed before any chat send.
    public func readPlainText(userInitiated: Bool) throws -> ClipboardContext? {
        guard userInitiated else { throw AmbientContextError.userInitiationRequired }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return nil
        }
        return ClipboardContext(plainText: text)
    }
}
