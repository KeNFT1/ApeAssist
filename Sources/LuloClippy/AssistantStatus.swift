import Foundation
import SwiftUI

/// UI-facing state machine for the floating Lulo sprite.
enum AssistantStatus: String, CaseIterable, Equatable, Identifiable {
    case idle
    case wave
    case listening
    case thinking
    case needsConfirmation
    case talking

    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle: "Idle"
        case .wave: "Wave"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .needsConfirmation: "Needs approval"
        case .talking: "Talking"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: "paperclip"
        case .wave: "hand.wave.fill"
        case .listening: "mic.fill"
        case .thinking: "brain.head.profile"
        case .needsConfirmation: "exclamationmark.shield.fill"
        case .talking: "speaker.wave.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .secondary
        case .wave: .orange
        case .listening: .green
        case .thinking: .purple
        case .needsConfirmation: .red
        case .talking: .blue
        }
    }

    var spriteAnimationName: String {
        switch self {
        case .idle: "idle"
        case .wave: "wave"
        case .listening, .thinking, .needsConfirmation: "thinking"
        case .talking: "talking"
        }
    }
}
