#if os(iOS)
import SwiftUI
import Testing
import UIKit

@testable import CoreDesignShaders

// ⚠️ **这一条守的是"能画"，不是"能加载"**——两者是不同的失败面。
//
// `assertShaderLibraryLoadable` 只证明 metallib 在 bundle 里、函数名解析得到；
// 它**证不了** `.colorEffect(...)` 的实参与 `[[stitchable]]` 形参**位次与类型对得上**。
// 签名不匹配时 SwiftUI **不报错、只是不渲染**——这正是本 target 最坏的失败形态。
//
// 判据：渲染一帧，采样若干像素。shader 生效时输出是随位置变化的调色斜坡 ⇒ **像素必有差异**；
// 未生效时整块是底色 `ramp.low` ⇒ **所有像素相同**。
@Suite("Plasma 渲染 —— 证明 shader 真的执行了")
@MainActor
struct PlasmaRenderTests {

    @Test("渲染结果不是纯色 —— shader 参数位次与类型匹配")
    func plasmaActuallyRenders() throws {
        let renderer = ImageRenderer(
            content: Plasma(tint: .blue, density: .dense)
                .frame(width: 64, height: 64)
        )
        renderer.scale = 1

        let image = try #require(renderer.uiImage, "ImageRenderer 未产出图像")
        let samples = Self.sample(image, at: [
            CGPoint(x: 4, y: 4), CGPoint(x: 32, y: 8),
            CGPoint(x: 12, y: 40), CGPoint(x: 56, y: 56),
        ])

        #expect(samples.count == 4)
        #expect(
            Set(samples).count > 1,
            """
            所有采样点颜色相同 ⇒ shader 没有执行（或 ImageRenderer 不执行 shader）。
            ⚠️ 若确认是 ImageRenderer 的限制而非 shader 问题，**不要删掉这条测试**——
            换一种能真正走 GPU 的渲染路径，或把它降级为宿主 App 的视觉冒烟并留痕。
            静默删除会让"签名不匹配 ⇒ 静默无渲染"这个失败面重新无人守。
            """
        )
    }

    private static func sample(_ image: UIImage, at points: [CGPoint]) -> [UInt32] {
        guard let cg = image.cgImage,
              let data = cg.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return [] }
        let bpr = cg.bytesPerRow
        let bpp = cg.bitsPerPixel / 8
        return points.compactMap { p in
            let x = Int(p.x), y = Int(p.y)
            guard x < cg.width, y < cg.height else { return nil }
            let o = y * bpr + x * bpp
            return (UInt32(ptr[o]) << 16) | (UInt32(ptr[o + 1]) << 8) | UInt32(ptr[o + 2])
        }
    }
}
#endif
