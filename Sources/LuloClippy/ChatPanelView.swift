import SwiftUI
import AppKit
import AmbientContext

struct ChatPanelView: View {
    @EnvironmentObject private var bridge: OpenClawBridge
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""
    @State private var contextDrafts: [ContextDraftChip] = []
    @State private var contextNotice: String?
    @State private var screenshotPreview: ScreenshotPreviewDraft?
    @State private var isScreenshotCaptureActive = false
    private let ambientContext = AmbientContextCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(bridge.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: bridge.messages.count) { _, _ in
                    if let last = bridge.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            Divider()

            contextToolbar

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask ApeAssist…", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .onSubmit(send)

                Button("Send", action: send)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bridge.isSending)
            }
            .padding()
        }
        .sheet(item: $screenshotPreview) { preview in
            ScreenshotPreviewSheet(
                preview: preview,
                onAttach: { attachScreenshotPreview(preview) },
                onCancel: { cancelScreenshotPreview() }
            )
        }
        .sheet(item: $bridge.mediaPreview) { preview in
            MediaPreviewSheet(preview: preview) {
                bridge.mediaPreview = nil
            }
        }
    }

    private var contextToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("What am I looking at?", action: includeActiveWindowContext)
                Button("Include clipboard", action: includeClipboardContext)
                Button("Include selected text", action: includeSelectedTextContext)
                Button("Include screenshot", action: includeScreenshotContext)
                Button("Enable Screen Recording", action: requestScreenRecordingPermission)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if visibleContextIndicatorActive {
                HStack(spacing: 8) {
                    Text("●")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Visible context indicator")

                    if isScreenshotCaptureActive {
                        Text("Capturing screenshot…")
                            .font(.caption.bold())
                    } else if screenshotPreview != nil {
                        Text("Screenshot preview open — not attached yet")
                            .font(.caption.bold())
                    }

                    ForEach(contextDrafts) { chip in
                        HStack(spacing: 4) {
                            Text(chip.label)
                                .lineLimit(1)
                            Button("Remove") { contextDrafts.removeAll { $0.id == chip.id } }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(chip.isScreenshot ? Color.red.opacity(0.14) : Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            if let contextNotice {
                Text(contextNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var visibleContextIndicatorActive: Bool {
        isScreenshotCaptureActive || screenshotPreview != nil || !contextDrafts.isEmpty
    }

    private var header: some View {
        HStack(spacing: 12) {
            LuloSpriteView(status: appState.assistantStatus, frameSize: 48, speedMultiplier: appState.animationSpeed)
            VStack(alignment: .leading, spacing: 2) {
                Text("ApeAssist")
                    .font(.title2.bold())
                HStack(spacing: 6) {
                    Label(appState.assistantStatus.label, systemImage: appState.assistantStatus.systemImage)
                        .foregroundStyle(appState.assistantStatus.tint)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(bridge.configuration.modeDescription)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if bridge.isSending {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let contextText = contextDrafts.map(\.promptText).joined(separator: "\n")
        let outgoing = contextText.isEmpty ? text : "\(text)\n\n[Local context explicitly included by user]\n\(contextText)"
        draft = ""
        contextDrafts = []
        contextNotice = nil
        screenshotPreview = nil
        appState.setStatus(.thinking)
        Task {
            await bridge.send(outgoing)
            if bridge.pendingActions.contains(where: { $0.status == .pending }) {
                appState.setStatus(.needsConfirmation)
            } else {
                appState.speakBriefly()
            }
        }
    }

    private func includeActiveWindowContext() {
        let context = ambientContext.whatAmILookingAtDraft().activeWindow
        let appName = context?.appName ?? "Unknown app"
        let title = context?.windowTitle ?? "window title unavailable"
        contextDrafts.append(.init(label: "Looking at: \(appName)", promptText: "Active app: \(appName)\nWindow title: \(title)\nBundle id: \(context?.bundleIdentifier ?? "unknown")"))
        contextNotice = "Context is local-only until you press Send."
    }

    private func includeClipboardContext() {
        do {
            guard let clipboard = try ambientContext.includeClipboardDraft().clipboard else {
                contextNotice = "Clipboard is empty or has no plain text."
                return
            }
            let preview = String(clipboard.plainText.prefix(4_000))
            contextDrafts.append(.init(label: "Clipboard: \(clipboard.characterCount) chars", promptText: "Clipboard text:\n\(preview)"))
            contextNotice = "Clipboard was read once from your button click; preview/remove before Send."
        } catch {
            contextNotice = error.localizedDescription
        }
    }

    private func includeSelectedTextContext() {
        do {
            let selected = try ambientContext.includeSelectedTextDraft().selectedText
            guard let selected else { return }
            contextDrafts.append(.init(label: "Selected text: \(selected.text.count) chars", promptText: "Selected text:\n\(String(selected.text.prefix(4_000)))"))
            contextNotice = "Selected text is local-only until Send."
        } catch {
            contextNotice = "Selected text needs Accessibility approval, or no selected text was available. \(error.localizedDescription)"
        }
    }

    private func includeScreenshotContext() {
        guard !isScreenshotCaptureActive else { return }
        isScreenshotCaptureActive = true
        contextNotice = "Capturing screenshot locally from your button click…"

        Task { @MainActor in
            await Task.yield()
            do {
                let screenshotDraft = try ambientContext.includeScreenshotDraft()
                guard let pngData = screenshotDraft.screenshotPNGData,
                      let image = NSImage(data: pngData)
                else {
                    contextNotice = "Screenshot capture returned no previewable image. Nothing was attached."
                    isScreenshotCaptureActive = false
                    return
                }

                let activeWindow = screenshotDraft.activeWindow
                screenshotPreview = ScreenshotPreviewDraft(
                    image: image,
                    pngData: pngData,
                    appName: activeWindow?.appName,
                    windowTitle: activeWindow?.windowTitle
                )
                contextNotice = "Screenshot captured locally. Review the preview before attaching; it will not be sent unless you press Send."
            } catch {
                contextNotice = screenshotErrorMessage(error)
            }
            isScreenshotCaptureActive = false
        }
    }

    private func attachScreenshotPreview(_ preview: ScreenshotPreviewDraft) {
        let appName = preview.appName ?? "current app"
        let title = preview.windowTitle ?? "window title unavailable"
        contextDrafts.append(
            .init(
                label: "Screenshot: \(appName)",
                promptText: "Screenshot preview was explicitly approved by the user for: \(appName) — \(title). Image bytes remain local in this prototype text bridge until binary upload support is added.",
                isScreenshot: true
            )
        )
        screenshotPreview = nil
        contextNotice = "Screenshot attached to the local draft. Remove it or press Send; screenshots are never sent automatically."
    }

    private func cancelScreenshotPreview() {
        screenshotPreview = nil
        contextNotice = "Screenshot discarded. Nothing was attached."
    }

    private func requestScreenRecordingPermission() {
        _ = AmbientPermissions.requestScreenRecordingPrompt()
        if let url = AmbientPermissions.screenRecordingSettingsURL {
            NSWorkspace.shared.open(url)
        }
        contextNotice = "Approve Screen Recording for ApeAssist in System Settings, then relaunch if macOS asks."
    }

    private func screenshotErrorMessage(_ error: Error) -> String {
        if case AmbientContextError.permissionMissing(let permission) = error, permission == "Screen Recording" {
            return "Screen Recording permission is missing. Click Enable Screen Recording, approve ApeAssist in System Settings, then relaunch if macOS asks."
        }
        return "Screenshot was not attached. \(error.localizedDescription)"
    }
}

private struct ContextDraftChip: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let promptText: String
    var isScreenshot = false
}

private struct ScreenshotPreviewDraft: Identifiable, Equatable {
    let id = UUID()
    let image: NSImage
    let pngData: Data
    let appName: String?
    let windowTitle: String?

    static func == (lhs: ScreenshotPreviewDraft, rhs: ScreenshotPreviewDraft) -> Bool {
        lhs.id == rhs.id
    }
}

private struct ScreenshotPreviewSheet: View {
    let preview: ScreenshotPreviewDraft
    let onAttach: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("●")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Screenshot preview indicator")
                Text("Review screenshot before attaching")
                    .font(.headline)
            }

            Text("Captured from \(preview.appName ?? "current app")\(preview.windowTitle.map { " — \($0)" } ?? ""). This stays local unless you attach it and press Send.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(nsImage: preview.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 560, maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25))
                }
                .accessibilityLabel("Screenshot preview thumbnail")

            HStack {
                Text(ByteCountFormatter.string(fromByteCount: Int64(preview.pngData.count), countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Attach screenshot", action: onAttach)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
    }
}

private struct MediaPreviewSheet: View {
    let preview: MediaPreviewRequest
    let onClose: () -> Void
    @State private var selectedID: MediaArtifact.ID?
    @State private var statusText: String?

    private var selectedArtifact: MediaArtifact? {
        let id = selectedID ?? preview.artifacts.first?.id
        return preview.artifacts.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generated media")
                        .font(.headline)
                    Text("Preview, copy, or open the media from ApeAssist’s latest reply.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }

            if preview.artifacts.count > 1 {
                Picker("Media", selection: Binding(
                    get: { selectedID ?? preview.artifacts.first?.id },
                    set: { selectedID = $0 }
                )) {
                    ForEach(preview.artifacts) { artifact in
                        Text(artifact.displayName).tag(Optional(artifact.id))
                    }
                }
                .pickerStyle(.menu)
            }

            if let artifact = selectedArtifact {
                mediaBody(for: artifact)

                VStack(alignment: .leading, spacing: 4) {
                    Text(artifact.displayName)
                        .font(.subheadline.bold())
                    Text(artifact.locator)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(3)
                    if artifact.isLocalFile && !artifact.existsLocally {
                        Label("Local file was not found. You can still copy the path.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if let statusText {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button("Copy image") { copyImage(artifact) }
                        .disabled(artifact.loadableImage == nil)
                    Button("Copy file") { copyFile(artifact) }
                        .disabled(!artifact.existsLocally)
                    Button("Copy path/URL") { copyText(artifact.locator) }
                    Spacer()
                    if artifact.isLocalFile {
                        Button("Reveal in Finder") { reveal(artifact) }
                            .disabled(!artifact.existsLocally)
                    } else {
                        Button("Open externally") { open(artifact) }
                            .disabled(artifact.url == nil)
                    }
                    Button("Close", action: onClose)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                Text("No supported media locator was found in the response.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
    }

    @ViewBuilder
    private func mediaBody(for artifact: MediaArtifact) -> some View {
        if let image = artifact.loadableImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 680, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25))
                }
                .accessibilityLabel("Generated image preview")
        } else {
            ContentUnavailableView(
                artifact.kind == .image ? "Image preview unavailable" : "File preview unavailable",
                systemImage: artifact.kind == .image ? "photo" : "doc",
                description: Text(artifact.isLocalFile ? "The file may be missing or unsupported by AppKit." : "Remote media can be copied or opened externally.")
            )
            .frame(maxWidth: 680, minHeight: 260, maxHeight: 320)
        }
    }

    private func copyImage(_ artifact: MediaArtifact) {
        guard let image = artifact.loadableImage else {
            statusText = "No copyable image preview is available."
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        statusText = "Copied image to clipboard."
    }

    private func copyFile(_ artifact: MediaArtifact) {
        guard let url = artifact.url, artifact.existsLocally else {
            statusText = "File is missing; copied the path instead."
            copyText(artifact.locator)
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        statusText = "Copied file reference to clipboard."
    }

    private func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        statusText = "Copied path/URL."
    }

    private func reveal(_ artifact: MediaArtifact) {
        guard let url = artifact.url, artifact.existsLocally else {
            statusText = "File is missing; cannot reveal it."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        statusText = "Opened Finder."
    }

    private func open(_ artifact: MediaArtifact) {
        guard let url = artifact.url else {
            statusText = "No openable URL is available."
            return
        }
        NSWorkspace.shared.open(url)
        statusText = "Opened externally."
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role.displayName)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(message.text)
                    .textSelection(.enabled)
            }
            .padding(10)
            .background(message.role == .user ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if message.role != .user { Spacer(minLength: 48) }
        }
    }
}
