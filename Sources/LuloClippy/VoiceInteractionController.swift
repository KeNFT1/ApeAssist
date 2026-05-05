import AppKit
import AVFoundation
import Foundation

/// User-driven voice UX seam for Lulo.
///
/// This intentionally does not record audio or start transcription. It only exposes
/// push-to-talk state and local macOS speech playback so capture/transcription can
/// be added later behind an explicit permission flow.
@MainActor
final class VoiceInteractionController: NSObject, ObservableObject {
    @Published private(set) var isPushToTalkHeld = false
    @Published private(set) var lastTranscript: String?

    private weak var appState: AppState?
    private let speechPlayback = SpeechPlaybackController()
    private var localMonitor: Any?

    func configure(appState: AppState) {
        self.appState = appState
    }

    /// App-focused prototype shortcut: hold Option+Space while Lulo is focused.
    /// Replace with a global Carbon hotkey or a shortcut package once rebinding UX lands.
    func installPushToTalkShortcut() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            let handled = Self.isPushToTalkEvent(event)
            if handled {
                Task { @MainActor in
                    self?.handleShortcutEvent(event)
                }
                return nil
            }
            return event
        }
    }

    func removePushToTalkShortcut() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
    }

    func beginPushToTalk() {
        guard !isPushToTalkHeld else { return }
        stopSpeaking()
        isPushToTalkHeld = true
        appState?.setStatus(.listening)
        // Future work: start capture/transcription only after explicit microphone/speech permission UX.
    }

    func endPushToTalk() {
        guard isPushToTalkHeld else { return }
        isPushToTalkHeld = false
        appState?.setStatus(.thinking)
        // Future work: stop capture, submit transcript through OpenClawBridge, then choose idle/talking.
        appState?.setStatus(.idle)
    }

    func speakPreview(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState?.setStatus(.talking)
        speechPlayback.speak(trimmed) { [weak self] in
            Task { @MainActor in
                if self?.appState?.assistantStatus == .talking {
                    self?.appState?.setStatus(.idle)
                }
            }
        }
    }

    func stopSpeaking() {
        speechPlayback.stop()
        if appState?.assistantStatus == .talking {
            appState?.setStatus(.idle)
        }
    }

    private func handleShortcutEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown: beginPushToTalk()
        case .keyUp: endPushToTalk()
        default: break
        }
    }

    private static func isPushToTalkEvent(_ event: NSEvent) -> Bool {
        event.keyCode == 49 && event.modifierFlags.contains(.option)
    }
}

/// Local macOS speech hook. External/OpenClaw TTS should remain a separate, opt-in adapter.
@MainActor
final class SpeechPlaybackController: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(AVSpeechUtterance(string: text))
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            finish()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            finish()
        }
    }

    private func finish() {
        onFinish?()
        onFinish = nil
    }
}
