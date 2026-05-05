import SwiftUI
import AppKit

@MainActor
final class FloatingBuddyController: NSObject {
    private let appState: AppState
    private let bridge: OpenClawBridge
    private var panel: NSPanel?

    init(appState: AppState, bridge: OpenClawBridge) {
        self.appState = appState
        self.bridge = bridge
        super.init()
        buildPanel()
    }

    func show() {
        if panel == nil { buildPanel() }
        panel?.orderFrontRegardless()
        appState.buddyVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        appState.buddyVisible = false
    }

    private func buildPanel() {
        let contentView = FloatingBuddyView()
            .environmentObject(appState)
            .environmentObject(bridge)

        let panel = FloatingBuddyPanel(
            contentRect: NSRect(x: 120, y: 160, width: 360, height: 520),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.acceptsMouseMovedEvents = true

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        self.panel = panel
    }
}

private final class FloatingBuddyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct FloatingBuddyView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bridge: OpenClawBridge
    @State private var isHovering = false
    @State private var miniChatVisible = false
    @State private var assistantBubbleVisible = false
    @State private var initialMessageCount = 0
    @State private var draft = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var buddyAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.82)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button {
                    withAnimation(buddyAnimation) {
                        miniChatVisible.toggle()
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            statusAura
                            LuloSpriteView(
                                status: appState.assistantStatus,
                                frameSize: 150,
                                speedMultiplier: appState.animationSpeed
                            )
                        }
                        .frame(width: 168, height: 154)
                        .animation(buddyAnimation, value: appState.assistantStatus)

                        Text("Lulo")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .shadow(color: .white.opacity(0.8), radius: 2)
                        Label(appState.assistantStatus.label, systemImage: appState.assistantStatus.systemImage)
                            .font(.caption)
                            .foregroundStyle(appState.assistantStatus.tint)
                            .shadow(color: .white.opacity(0.8), radius: 2)
                            .contentTransition(.opacity)
                            .animation(.easeOut(duration: reduceMotion ? 0.01 : 0.18), value: appState.assistantStatus)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Click Lulo to ask a quick question")
                .accessibilityLabel("Floating Lulo desktop buddy. Click to ask a quick question.")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.regularMaterial.opacity(isHovering ? 0.86 : 0.18), in: Circle())
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0.18)
                .help("Quit Lulo Clippy")
                .accessibilityLabel("Quit Lulo Clippy")
                .padding(.top, 20)
                .padding(.trailing, 18)
            }
            .frame(width: 190, height: 194)

            if shouldShowAssistantBubble, let latestAssistantText {
                assistantSpeechBubble(latestAssistantText)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
            }

            if miniChatVisible {
                miniChat
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if appState.showAnimationDebug {
                HStack(spacing: 8) {
                    ForEach(AssistantStatus.allCases) { status in
                        Button {
                            appState.setStatus(status)
                        } label: {
                            Image(systemName: status.systemImage)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(status.tint)
                        .help(status.label)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .top)
        .background(Color.clear)
        .onHover { isHovering = $0 }
        .onAppear { initialMessageCount = bridge.messages.count }
        .onChange(of: bridge.messages.count) { _, newCount in
            guard newCount > initialMessageCount,
                  bridge.messages.last?.role == .assistant
            else { return }

            withAnimation(buddyAnimation) {
                assistantBubbleVisible = true
            }
        }
    }

    private var shouldShowAssistantBubble: Bool {
        assistantBubbleVisible || appState.assistantStatus == .talking || appState.assistantStatus == .thinking
    }

    private var statusAura: some View {
        let opacity: Double = reduceMotion ? 0.10 : (appState.assistantStatus == .idle ? 0.08 : 0.18)
        return Circle()
            .fill(appState.assistantStatus.tint.opacity(opacity))
            .frame(width: appState.assistantStatus == .idle ? 112 : 130, height: appState.assistantStatus == .idle ? 112 : 130)
            .blur(radius: 16)
            .scaleEffect(appState.assistantStatus == .thinking ? 1.08 : 1.0)
            .accessibilityHidden(true)
    }

    private func assistantSpeechBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            BubbleTail()
                .fill(.regularMaterial)
                .frame(width: 18, height: 22)
                .offset(x: 2, y: 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(appState.assistantStatus == .thinking ? "Thinking…" : "Pinchy")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) { assistantBubbleVisible = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Hide speech bubble")
                }

                Text(appState.assistantStatus == .thinking ? "Working on it…" : text)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(6)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 276, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10))
            )
            .shadow(color: .black.opacity(0.20), radius: 16, x: 0, y: 8)
        }
        .frame(width: 320, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lulo speech bubble")
    }

    private var miniChat: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TextField("Ask Lulo…", text: $draft)
                    .textFieldStyle(.plain)
                    .onSubmit(sendMiniChat)
                    .disabled(bridge.isSending)

                Button {
                    sendMiniChat()
                } label: {
                    Image(systemName: bridge.isSending ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bridge.isSending)
            }

            if let latestAssistantText {
                ScrollView {
                    Text(latestAssistantText)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 92)
                .padding(8)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text(bridge.configuration.postingEnabled ? "Sends to local OpenClaw" : "Dry-run until POST is enabled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
    }

    private var latestAssistantText: String? {
        bridge.messages.last(where: { $0.role == .assistant })?.text
    }

    private func sendMiniChat() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !bridge.isSending else { return }
        draft = ""
        appState.setStatus(.thinking)
        Task {
            await bridge.send(text)
            if bridge.pendingActions.contains(where: { $0.status == .pending }) {
                appState.setStatus(.needsConfirmation)
            } else {
                appState.speakBriefly()
            }
        }
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
