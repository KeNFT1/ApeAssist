import Foundation
import AppKit

public struct MediaArtifact: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case image
        case file
        case url
        case unsupported
    }

    public let id: UUID
    public let locator: String
    public let sourceDescription: String
    public let kind: Kind

    public init(id: UUID = UUID(), locator: String, sourceDescription: String, kind: Kind) {
        self.id = id
        self.locator = locator
        self.sourceDescription = sourceDescription
        self.kind = kind
    }

    public var url: URL? {
        if let parsed = URL(string: locator), parsed.scheme != nil {
            return parsed
        }
        if locator.hasPrefix("/") || locator.hasPrefix("~") {
            let expanded = (locator as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        return nil
    }

    public var isLocalFile: Bool { url?.isFileURL == true }

    public var displayName: String {
        if let url {
            return url.lastPathComponent.isEmpty ? locator : url.lastPathComponent
        }
        return locator
    }

    public var existsLocally: Bool {
        guard let url, url.isFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    public var loadableImage: NSImage? {
        guard let url else { return nil }
        if url.isFileURL {
            return NSImage(contentsOf: url)
        }
        // Keep network previews conservative: remote URLs can be opened/copied, but we do not
        // synchronously fetch them into the clipboard from the UI.
        return nil
    }
}

enum MediaExtractor {
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"]
    private static let mediaExtensions: Set<String> = imageExtensions.union(["svg", "pdf", "mp4", "mov", "m4v", "webm", "mp3", "wav", "zip"])
    private static let mediaKeys: Set<String> = [
        "url", "uri", "path", "file", "filename", "file_path", "filepath", "local_path",
        "localpath", "image", "image_url", "imageurl", "media", "media_url", "mediaurl",
        "output", "download_url", "downloadurl"
    ]

    static func extract(text: String, rawJSON: Data? = nil) -> [MediaArtifact] {
        var candidates: [(String, String)] = []
        candidates.append(contentsOf: extractFromText(text))
        if let rawJSON {
            candidates.append(contentsOf: extractFromJSON(rawJSON))
        }

        var seen = Set<String>()
        return candidates.compactMap { locator, source in
            let normalized = sanitize(locator)
            guard isLikelyMediaLocator(normalized), !seen.contains(normalized) else { return nil }
            seen.insert(normalized)
            return MediaArtifact(locator: normalized, sourceDescription: source, kind: classify(normalized))
        }
    }

    private static func extractFromText(_ text: String) -> [(String, String)] {
        var results: [(String, String)] = []

        // Markdown images/links: ![alt](file-or-url) and [file](file-or-url).
        results.append(contentsOf: regexMatches(in: text, pattern: #"!?\[[^\]]*\]\(([^\)\s]+)\)"#).map { ($0, "markdown link") })

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.range(of: #"^MEDIA\s*:?\s*(.+)$"#, options: [.regularExpression, .caseInsensitive]) != nil,
               let value = trimmed.replacingOccurrences(of: #"^MEDIA\s*:?\s*"#, with: "", options: [.regularExpression, .caseInsensitive], range: nil).components(separatedBy: .whitespaces).first {
                results.append((value, "MEDIA line"))
            }

            if trimmed.hasPrefix("/") || trimmed.hasPrefix("~/") || trimmed.hasPrefix("file://") || trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                results.append((trimmed.components(separatedBy: .whitespaces).first ?? trimmed, "text line"))
            }
        }

        // Bare local paths and URLs embedded in prose.
        results.append(contentsOf: regexMatches(in: text, pattern: #"(file://[^\s\)\]\}\>\"']+)"#).map { ($0, "file URL") })
        results.append(contentsOf: regexMatches(in: text, pattern: #"(https?://[^\s\)\]\}\>\"']+)"#).map { ($0, "URL") })
        results.append(contentsOf: regexMatches(in: text, pattern: #"((?:~|/)[^\n\r\t\)\]\}\>\"']+\.(?:png|jpe?g|gif|webp|heic|tiff?|bmp|svg|pdf|mp4|mov|m4v|webm|mp3|wav|zip))"#).map { ($0, "path") })

        return results
    }

    private static func extractFromJSON(_ data: Data) -> [(String, String)] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var results: [(String, String)] = []
        walkJSON(object, keyHint: nil, results: &results)
        return results
    }

    private static func walkJSON(_ value: Any, keyHint: String?, results: inout [(String, String)]) {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                walkJSON(child, keyHint: key, results: &results)
            }
            return
        }
        if let array = value as? [Any] {
            for child in array { walkJSON(child, keyHint: keyHint, results: &results) }
            return
        }
        guard let string = value as? String else { return }
        let normalizedKey = keyHint?.lowercased().replacingOccurrences(of: "-", with: "_")
        if normalizedKey.map(mediaKeys.contains) == true || isLikelyMediaLocator(string) {
            results.append((string, normalizedKey.map { "JSON \($0)" } ?? "JSON string"))
        }
    }

    private static func regexMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            let capture = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
            guard let swiftRange = Range(capture, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    private static func sanitize(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "`'\"<>.,;")))
    }

    private static func isLikelyMediaLocator(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        if let url = URL(string: value), let scheme = url.scheme?.lowercased(), ["http", "https", "file"].contains(scheme) {
            return hasMediaExtension(url.path) || scheme == "file" || url.path.contains("/media/")
        }
        if value.hasPrefix("/") || value.hasPrefix("~/") {
            let expanded = (value as NSString).expandingTildeInPath
            return hasMediaExtension(expanded) || FileManager.default.fileExists(atPath: expanded)
        }
        return false
    }

    private static func classify(_ value: String) -> MediaArtifact.Kind {
        guard let url = MediaArtifact(locator: value, sourceDescription: "", kind: .unsupported).url else { return .unsupported }
        if hasImageExtension(url.path) { return .image }
        if url.isFileURL { return .file }
        if ["http", "https"].contains(url.scheme?.lowercased() ?? "") { return .url }
        return .unsupported
    }

    private static func hasImageExtension(_ path: String) -> Bool {
        imageExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }

    private static func hasMediaExtension(_ path: String) -> Bool {
        mediaExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }
}
