import OhMyDesign
import SwiftUI

/// 以路径弧长推进，避免长胶囊的角向遮罩在长边上突然加速。
struct PerimeterGlowTrail<S: InsettableShape>: View {
    let shape: S
    let phase: CGFloat

    var body: some View {
        Canvas { context, size in
            // 相邻片段轻微重叠并替换 alpha，避免圆头叠加产生一串亮点。
            context.blendMode = .copy
            let path = self.shape.inset(by: ProcessingSweep.ringLineWidth / 2)
                .path(in: CGRect(origin: .zero, size: size))
            let count = 24
            let step: CGFloat = 0.18 / CGFloat(count)
            for index in 0..<count {
                let brightness = Double(index + 1) / Double(count)
                let end = self.phase - 0.18 + CGFloat(index + 1) * step
                for range in Self.ranges(endingAt: end, length: step * 1.08) {
                    context.stroke(
                        path.trimmedPath(from: range.lowerBound, to: range.upperBound),
                        with: .color(Color.maskOpaque.opacity(brightness * brightness)),
                        style: StrokeStyle(lineWidth: ProcessingSweep.ringLineWidth + 1,
                                           lineCap: .butt)
                    )
                }
            }
        }
    }

    static func ranges(endingAt phase: CGFloat, length: CGFloat) -> [ClosedRange<CGFloat>] {
        let end = phase - floor(phase)
        let start = end - length
        if start < 0 {
            return [(1 + start)...1, 0...end]
        }
        return [start...end]
    }
}
