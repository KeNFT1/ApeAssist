import AppKit
import SwiftUI

struct LuloSpriteView: View {
    let status: AssistantStatus
    let frameSize: CGFloat
    let speedMultiplier: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spriteSheet = LuloSpriteSheet.loadDefault()

    private var frames: [Int] {
        spriteSheet?.frames(for: status) ?? [0]
    }

    private var frameDuration: Double {
        let base: Double
        switch status {
        case .idle: base = 0.58
        case .thinking, .listening, .needsConfirmation: base = 0.24
        case .talking: base = 0.16
        case .wave: base = 0.20
        }
        return max(0.05, base / max(0.25, speedMultiplier))
    }

    private var timelineInterval: Double {
        reduceMotion ? max(0.25, frameDuration) : min(frameDuration, 1.0 / 30.0)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: timelineInterval)) { context in
            let motion = LuloSpriteMotion.sample(
                status: status,
                time: context.date.timeIntervalSinceReferenceDate,
                speedMultiplier: speedMultiplier,
                reduceMotion: reduceMotion
            )

            let frame = currentFrameIndex(at: context.date)
            let stabilizationOffset = spriteSheet?.horizontalStabilizationOffset(
                forFrame: frame,
                renderedSize: frameSize
            ) ?? 0

            spriteContent(frame: frame)
                .frame(width: frameSize, height: frameSize)
                .scaleEffect(x: motion.scaleX, y: motion.scaleY, anchor: .bottom)
                .rotationEffect(.degrees(motion.rotationDegrees), anchor: .bottom)
                .offset(x: stabilizationOffset, y: motion.bob)
                .shadow(color: .black.opacity(motion.shadowOpacity), radius: 7, x: 0, y: 5)
                .animation(.smooth(duration: 0.18), value: status)
                .accessibilityLabel("Lulo sprite, \(status.label.lowercased())")
        }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
    }

    @ViewBuilder
    private func spriteContent(frame: Int) -> some View {
        if let image = spriteSheet?.image(forFrame: frame) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Text("🦞")
                .font(.system(size: frameSize * 0.55))
        }
    }

    private func currentFrameIndex(at date: Date) -> Int {
        let tick = max(0, Int(date.timeIntervalSinceReferenceDate / frameDuration))
        return frames[tick % max(frames.count, 1)]
    }
}

private struct LuloSpriteSheet {
    let source: CGImage
    let columns: Int
    let rows: Int
    let metadata: LuloSpriteSheetMetadata?
    let animations: [String: [Int]]
    let preSlicedFrames: [Int: NSImage]

    static func loadDefault() -> LuloSpriteSheet? {
        guard
            let imageURL = Bundle.module.url(forResource: "lulo-sprite-sheet", withExtension: "png", subdirectory: "Sprites"),
            let image = NSImage(contentsOf: imageURL),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let metadata = loadMetadata()
        let columns = metadata?.columns ?? 4
        let rows = metadata?.rows ?? 4
        return LuloSpriteSheet(
            source: cgImage,
            columns: columns,
            rows: rows,
            metadata: metadata,
            animations: metadata?.animations ?? [
                "idle": [0, 1, 2, 3],
                "wave": [4, 5, 6, 7],
                "thinking": [8, 9, 10, 11],
                "talking": [12, 13, 14, 15]
            ],
            preSlicedFrames: loadPreSlicedFrames(count: columns * rows)
        )
    }

    func frames(for status: AssistantStatus) -> [Int] {
        animations[status.spriteAnimationName] ?? animations["idle"] ?? [0]
    }

    func image(forFrame index: Int) -> NSImage? {
        let clamped = min(max(index, 0), columns * rows - 1)
        if let preSlicedFrame = preSlicedFrames[clamped] {
            return preSlicedFrame
        }

        let cellWidth = source.width / columns
        let cellHeight = source.height / rows
        let column = clamped % columns
        let row = clamped / columns
        let rect = CGRect(
            x: CGFloat(column * cellWidth),
            y: CGFloat(row * cellHeight),
            width: CGFloat(cellWidth),
            height: CGFloat(cellHeight)
        )

        guard let crop = source.cropping(to: rect) else { return nil }
        return NSImage(cgImage: crop, size: NSSize(width: CGFloat(cellWidth), height: CGFloat(cellHeight)))
    }

    func horizontalStabilizationOffset(forFrame index: Int, renderedSize: CGFloat) -> CGFloat {
        let frameCount = columns * rows
        guard frameCount > 0 else { return 0 }
        let clamped = min(max(index, 0), frameCount - 1)
        let centers = metadataFrameContentCentersX ?? Self.defaultFrameContentCentersX
        guard clamped < centers.count else { return 0 }

        let cellWidth = CGFloat(source.width / columns)
        let targetCenter = cellWidth / 2
        let scale = renderedSize / cellWidth
        return (targetCenter - centers[clamped]) * scale
    }

    private var metadataFrameContentCentersX: [CGFloat]? {
        guard let frameContentBounds = metadata?.frameContentBounds,
              frameContentBounds.count >= columns * rows
        else { return nil }

        return frameContentBounds.map { bounds in
            (CGFloat(bounds[0]) + CGFloat(bounds[2])) / 2
        }
    }

    private static let defaultFrameContentCentersX: [CGFloat] = [
        156.5, 125.5, 96.5, 57.5,
        167.5, 144.0, 141.5, 77.0,
        158.0, 121.0, 140.5, 59.5,
        163.0, 133.5, 137.5, 88.5
    ]

    private static func loadMetadata() -> LuloSpriteSheetMetadata? {
        guard
            let url = Bundle.module.url(forResource: "lulo-sprite-sheet", withExtension: "json", subdirectory: "Sprites"),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return try? JSONDecoder().decode(LuloSpriteSheetMetadata.self, from: data)
    }

    private static func loadPreSlicedFrames(count: Int) -> [Int: NSImage] {
        var frames: [Int: NSImage] = [:]
        for index in 0..<count {
            let name = String(format: "lulo-%02d", index)
            guard
                let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Sprites/Frames"),
                let image = NSImage(contentsOf: url)
            else {
                continue
            }
            frames[index] = image
        }
        return frames
    }
}

private struct LuloSpriteSheetMetadata: Decodable {
    let columns: Int
    let rows: Int
    let animations: [String: [Int]]
    let frameContentBounds: [[Int]]?
}
