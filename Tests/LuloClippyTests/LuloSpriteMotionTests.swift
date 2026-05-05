import Testing
@testable import LuloClippy

@Suite("Lulo sprite motion")
struct LuloSpriteMotionTests {
    @Test func reducedMotionRemovesSpatialMovement() {
        let motion = LuloSpriteMotion.sample(
            status: .talking,
            time: 123.45,
            speedMultiplier: 1.0,
            reduceMotion: true
        )

        #expect(motion.bob == 0)
        #expect(motion.scaleX == 1)
        #expect(motion.scaleY == 1)
        #expect(motion.rotationDegrees == 0)
    }

    @Test func talkingMotionIsMoreAnimatedThanIdle() {
        let time = 0.25
        let idle = LuloSpriteMotion.sample(
            status: .idle,
            time: time,
            speedMultiplier: 1.0,
            reduceMotion: false
        )
        let talking = LuloSpriteMotion.sample(
            status: .talking,
            time: time,
            speedMultiplier: 1.0,
            reduceMotion: false
        )

        #expect(abs(talking.bob) > abs(idle.bob))
        #expect(abs(talking.scaleX - 1) > abs(idle.scaleX - 1))
    }

    @Test func thinkingAndConfirmationHaveDifferentSilhouettes() {
        let time = 0.33
        let thinking = LuloSpriteMotion.sample(
            status: .thinking,
            time: time,
            speedMultiplier: 1.0,
            reduceMotion: false
        )
        let confirmation = LuloSpriteMotion.sample(
            status: .needsConfirmation,
            time: time,
            speedMultiplier: 1.0,
            reduceMotion: false
        )

        #expect(thinking != confirmation)
        #expect(abs(confirmation.rotationDegrees) != abs(thinking.rotationDegrees))
    }
}
