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

    /// ⚠️ **抓「shader 完全忽略 `time`」** —— 单帧比较抓不到它：一个把 `time` 形参
    /// 收下却不用的 shader，空间上照样变化，上一条测试照样通过（#261 终审 I-3）。
    /// 同类型形参**换序**也是同理——`.float(t), .float(frequency), .float(octaves)`
    /// 三个都是 `float`，换序照样编译；本条能抓到其中把 `time` 换走的那些排列。
    @Test("动画背景在两个时刻的输出不同 —— shader 真的吃了 time")
    func timeActuallyAdvances() throws {
        // 同一个 shader、同一尺寸，只有时间原点不同。
        let now = Date()
        let ramp = ShaderRamp(tint: .blue, reduceTransparency: false)
        let library = ShaderLibrary.bundle(.module)

        func frame(secondsAgo: TimeInterval) throws -> [UInt32] {
            try Self.render(
                ProceduralBackground(
                    base: ramp.low,
                    motion: .lively,
                    originOverride: now.addingTimeInterval(-secondsAgo)
                ) { size, t in
                    library.coreDesignPlasma(
                        .float2(size), .float(t), .float(11), .float(3),
                        .color(ramp.low), .color(ramp.mid), .color(ramp.high)
                    )
                }
                .frame(width: 64, height: 64)
            )
        }

        #expect(
            try frame(secondsAgo: 0) != frame(secondsAgo: 30),
            """
            两个时刻渲染结果完全相同 ⇒ shader 没有真正使用 `time` 形参。
            ⚠️ 常见原因：`.float(...)` 实参顺序与 `[[stitchable]]` 形参不匹配
            （同为 `float` 时换序照样编译）；或时间被 `Float` 精度吃掉
            （见 `ProceduralBackground.origin`）。
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

    /// ⚠️⚠️ **rim 那一行改过三次，前两次都错，而它一直是零回归覆盖**
    ///（第 4 轮终审 I-2）。`glassRefracts` 用的是**不透明** `LinearGradient`
    /// ⇒ 第 2 版「`sample.a == 0` 时 rim 整条消失」在那里**不可能暴露**；
    /// 且 `render(_:)` 只取 RGB 三个字节、**从不采样 alpha** ⇒ 第 1 版的
    /// 「边缘 25% 透明环」对它也天然不可见。三个版本它都放行。
    ///
    /// ⇒ 本条以**透明内容**为被折射层，并**采样 alpha**：圆角边界一圈必须出现
    ///   `alpha > 0` 的 rim 像素。
    @Test("rim 高光在透明内容上仍然显影（前两版都会在这条上判红）")
    func rimShowsOnTransparentContent() throws {
        // SF Symbol 四周 alpha = 0，正是第 2 版失效的那类内容。
        let content = Image(systemName: "bolt.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)

        // ⚠️⚠️ **对照必须隔离 rim**：拿「加不加 glass」比是**错的**——折射本身会把
        // 不透明像素位移进原本透明的区域，不透明像素数从 209 涨到 740（实测），
        // 这个变化**完全淹没** rim 的贡献。我的第一版断言正是这么写的，
        // 而它对第 2 版的 rim bug **判绿**（变异实测），检出力为零。
        // ⇒ 正确对照：**同样的折射、只有 rim 不同**（`.clear` vs 有色）。
        let noRim = try Self.renderAlpha(
            content.refractiveGlass(corner: 12, strength: .pronounced, rim: .clear)
        )
        let withRim = try Self.renderAlpha(
            content.refractiveGlass(corner: 12, strength: .pronounced, rim: .accent)
        )
        #expect(noRim.count == withRim.count)

        // 第 2 版 `mix(sample, half4(rim.rgb, sample.a), k)` 保住了 `sample.a`
        // ⇒ 透明处 alpha 恒为 0 ⇒ 两者的 alpha 分布**完全相同** ⇒ 本条判红。
        // 第 3 版的预乘 source-over 会在边界一圈抬高 alpha ⇒ 两者不同。
        let opaqueWithout = noRim.filter { $0 > 8 }.count
        let opaqueWith = withRim.filter { $0 > 8 }.count
        #expect(opaqueWith > opaqueWithout,
                "rim 在透明内容上没有抬高任何 alpha（\(opaqueWithout) → \(opaqueWith)）—— 这正是第 2 版的失效形态")
    }

    // MARK: - Helpers

    /// 只取 alpha 通道的全图网格扫描。⚠️ 与 `render(_:)` 分开是有意的：
    /// 后者取 RGB，对「alpha 被改坏」这一类缺陷天然不可见。
    private static func renderAlpha(_ view: some View) throws -> [UInt8] {
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
        var out: [UInt8] = []
        for y in stride(from: 0, to: cg.height, by: 2) {
            for x in stride(from: 0, to: cg.width, by: 2) {
                out.append(ptr[y * bytesPerRow + x * bytesPerPixel + 3])
            }
        }
        return out
    }

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
