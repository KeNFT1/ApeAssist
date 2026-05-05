import CoreGraphics
import Foundation

/// Small, deterministic motion layer that sits on top of the sprite frames.
/// Keeping this logic pure makes the animation tuning easy to test without
/// requiring SwiftUI rendering or AppKit image resources.
struct LuloSpriteMotion: Equatable {
    var bob: CGFloat
    var scaleX: CGFloat
    var scaleY: CGFloat
    var rotationDegrees: Double
    var shadowOpacity: Double

    static let still = LuloSpriteMotion(
        bob: 0,
        scaleX: 1,
        scaleY: 1,
        rotationDegrees: 0,
        shadowOpacity: 0.18
    )

    static func sample(
        status: AssistantStatus,
        time: TimeInterval,
        speedMultiplier: Double,
        reduceMotion: Bool
    ) -> LuloSpriteMotion {
        let speed = max(0.25, min(speedMultiplier, 2.5))

        if reduceMotion {
            let phase = sine(time, cyclesPerSecond: 0.45 * speed)
            let opacity = status == .idle ? 0.16 : 0.18 + (phase + 1) * 0.025
            return LuloSpriteMotion(
                bob: 0,
                scaleX: 1,
                scaleY: 1,
                rotationDegrees: 0,
                shadowOpacity: opacity
            )
        }

        switch status {
        case .idle:
            let breath = sine(time, cyclesPerSecond: 0.28 * speed)
            let bob = sine(time + 0.35, cyclesPerSecond: 0.18 * speed)
            return LuloSpriteMotion(
                bob: CGFloat(-2.8 * bob),
                scaleX: CGFloat(1.0 + 0.010 * breath),
                scaleY: CGFloat(1.0 + 0.018 * breath),
                rotationDegrees: 0.8 * sine(time + 0.8, cyclesPerSecond: 0.10 * speed),
                shadowOpacity: 0.16 + (breath + 1) * 0.018
            )

        case .wave:
            let wave = sine(time, cyclesPerSecond: 0.72 * speed)
            return LuloSpriteMotion(
                bob: CGFloat(-2.0 - 1.6 * abs(wave)),
                scaleX: 1.012,
                scaleY: 1.012,
                rotationDegrees: 3.0 * wave,
                shadowOpacity: 0.20
            )

        case .listening:
            let pulse = sine(time, cyclesPerSecond: 0.72 * speed)
            return LuloSpriteMotion(
                bob: CGFloat(-1.5 * pulse),
                scaleX: CGFloat(1.0 + 0.014 * pulse),
                scaleY: CGFloat(1.0 + 0.014 * pulse),
                rotationDegrees: 0,
                shadowOpacity: 0.18 + (pulse + 1) * 0.025
            )

        case .thinking:
            let ponder = sine(time, cyclesPerSecond: 0.42 * speed)
            let tick = sine(time + 0.2, cyclesPerSecond: 0.84 * speed)
            return LuloSpriteMotion(
                bob: CGFloat(-2.0 + -1.7 * ponder),
                scaleX: CGFloat(1.0 + 0.006 * tick),
                scaleY: CGFloat(1.0 + 0.012 * tick),
                rotationDegrees: 2.2 * ponder,
                shadowOpacity: 0.19 + (tick + 1) * 0.02
            )

        case .needsConfirmation:
            let alert = sine(time, cyclesPerSecond: 1.15 * speed)
            return LuloSpriteMotion(
                bob: CGFloat(-1.0 - 1.0 * abs(alert)),
                scaleX: CGFloat(1.0 + 0.008 * abs(alert)),
                scaleY: CGFloat(1.0 + 0.008 * abs(alert)),
                rotationDegrees: 1.6 * alert,
                shadowOpacity: 0.24
            )

        case .talking:
            let syllable = sine(time, cyclesPerSecond: 1.55 * speed)
            let bob = sine(time, cyclesPerSecond: 0.78 * speed)
            return LuloSpriteMotion(
                bob: CGFloat(-2.2 - 2.0 * max(0, bob)),
                scaleX: CGFloat(1.0 + 0.018 * syllable),
                scaleY: CGFloat(1.0 - 0.014 * syllable),
                rotationDegrees: 1.2 * sine(time + 0.4, cyclesPerSecond: 0.55 * speed),
                shadowOpacity: 0.20 + (syllable + 1) * 0.018
            )
        }
    }

    private static func sine(_ time: TimeInterval, cyclesPerSecond: Double) -> Double {
        sin(time * cyclesPerSecond * 2 * .pi)
    }
}
