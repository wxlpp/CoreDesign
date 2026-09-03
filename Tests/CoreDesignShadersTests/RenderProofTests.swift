#if os(iOS)
import SwiftUI
import Testing
import UIKit

@testable import CoreDesignShaders

// ⚠️ **本 suite 守的是「能画」，不是「能加载」——两者是不同的失败面。**
//
// `assertShaderLibraryLoadable` 只证明 metallib 在 bundle 里、函数名解析得到；
// 它**证不了** `.colorEffect(...)` / `.layerEffect(...)` 的实参与 `[[stitchable]]`
// 形参的**位次与类型对得上**。签名不匹配时 SwiftUI **不报错、只是不渲染**
// ——这是本 target 最坏的失败形态。
//
// ⚠️ 本 suite 还守着一个只在真渲染时暴露的坑：`Plasma` 落地时曾出现
// **每个像素完全相同**，而编译、metallib 加载、签名绑定全绿。根因是把
// `timeIntervalSinceReferenceDate`（~8.1e8）喂进 `Float`，在该量级上精度约 16 个单位，
// 空间项被整个舍入吃掉。⇒ **删掉本 suite 等于把那个坑重新放回去。**
@Suite("渲染证明 —— shader 真的执行且输出随位置变化")
@MainActor
struct RenderProofTests {

    /// ⚠️ 用枚举而不是 `AnyView` 作参数化实参——`AnyView` **不是 `Sendable`**，
    /// 直接当 `arguments:` 会编译失败（`conformance of 'AnyView' to 'Sendable' is unavailable`）。
    enum Background: String, CaseIterable, Sendable {
        case plasma, starfield, dotGrid, fractalClouds, inkSmoke, liquidChrome

        @MainActor
        @ViewBuilder var view: some View {
            switch self {
            case .plasma: Plasma(tint: .blue, density: .dense)
            case .starfield: Starfield(tint: .white, density: .dense)
            case .dotGrid: DotGrid(tint: .blue, spacing: .tight)
            case .fractalClouds: FractalClouds(tint: .blue, density: .turbulent)
            case .inkSmoke: InkSmoke(tint: .blue, density: .heavy)
            case .liquidChrome: LiquidChrome(tint: .blue, density: .fine)
            }
        }
    }

    @Test("六个程序化背景各自渲染出非纯色结果", arguments: Background.allCases)
    func backgroundsRender(_ background: Background) throws {
        let samples = try Self.render(background.view.frame(width: 64, height: 64))
        #expect(
            Set(samples).count > 1,
            """
            \(background.rawValue)：所有采样点颜色相同 ⇒ shader 没有执行，或输出与位置无关。
            ⚠️ 先查这两条再改测试：① `.colorEffect` 实参位次/类型是否与 `[[stitchable]]`
            形参一致（不匹配 = 静默无渲染）；② 是否把绝对纪元时间喂进了 `Float`
            （见 `ProceduralBackground.origin` 的注释）。
            """
        )
    }

    @Test("refractiveGlass 改变了内容层的像素")
    func glassRefracts() throws {
        let content = LinearGradient(
            colors: [.blue, .white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: 64, height: 64)

        let plain = try Self.render(content)
        let glassed = try Self.render(
            content.refractiveGlass(corner: 12, strength: .pronounced)
        )

        #expect(plain.count == glassed.count)
        #expect(
            plain != glassed,
            "施加 refractiveGlass 前后像素完全一致 ⇒ layerEffect 没有生效"
        )
    }

    // MARK: - Helpers

    /// ⚠️ **全图网格扫描，不是几个固定采样点**：初版用 6 个固定点，`Starfield` 判红
    /// ——而那不是 shader 的问题，是**星星按设计就稀疏**（只有一部分格子有星），
    /// 6 个点全落在空天区。稀疏效果需要足够的采样密度才谈得上"输出随位置变化"。
    /// ⚠️ 修法是**加密采样**而不是放宽断言——放宽会让这条守卫对真正的"静默无渲染"失灵。
    private static func render(_ view: some View) throws -> [UInt32] {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.uiImage, "ImageRenderer 未产出图像")
        guard let cg = image.cgImage,
              let data = cg.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            throw RenderProbeError.noPixelData
        }
        let bytesPerRow = cg.bytesPerRow
        let bytesPerPixel = cg.bitsPerPixel / 8
        var out: [UInt32] = []
        out.reserveCapacity(256)
        for y in stride(from: 0, to: cg.height, by: 4) {
            for x in stride(from: 0, to: cg.width, by: 4) {
                let o = y * bytesPerRow + x * bytesPerPixel
                out.append(
                    (UInt32(ptr[o]) << 16) | (UInt32(ptr[o + 1]) << 8) | UInt32(ptr[o + 2])
                )
            }
        }
        return out
    }

    private enum RenderProbeError: Error { case noPixelData }
}
#endif
