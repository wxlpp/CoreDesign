//
//  Plasma.swift
//  CoreDesignShaders
//
//  程序化等离子背景 / Procedural plasma background.
//

import CoreDesign
import SwiftUI

// MARK: - Plasma

/// 程序化等离子背景。铺满可用空间，适合作 onboarding / paywall / 启动页的底层。
///
/// ```swift
/// ZStack {
///     Plasma()
///         .ignoresSafeArea()
///     content
/// }
/// ```
///
/// ⚠️ **本类型不持有任何色相**——渲染色全部由 `tint` 一路推导（见下方 `init` 的说明）。
/// `.metal` 侧同样零硬编码色，两侧都受 `EffectsColorLiteralGuard` 约束（FR-8）。
///
/// ⚠️ **自研实现，非移植**：等离子是公开的图形学配方（正弦叠加 + 调色斜坡），属思路层。
/// 逐条差异化依据见 `docs/shader-provenance.md`《第三条出路：自研实现》。
public struct Plasma: View {

    // MARK: - 语义档位

    /// 视觉密度。
    ///
    /// ⚠️ 这是**一个语义枚举**，不是"频率 + 叠加层数"两个独立旋钮——本仓的调参惯例是
    /// 单一来源（对照 `ButtonRoleStyleRole`：它是 role 的 `color` / `activeColor` /
    /// `disabledColor` 的唯一来源，新增 role 扩枚举而不是各自定义调色板）。
    public enum Density: Sendable, CaseIterable {
        case subtle, regular, dense

        /// 展开成 shader 需要的两个数值。⚠️ **展开在 Swift 侧**，公开面只有档位。
        var field: (frequency: Float, octaves: Float) {
            switch self {
            case .subtle: (4.0, 1)
            case .regular: (7.0, 2)
            case .dense: (11.0, 3)
            }
        }
    }

    /// 运动速度。⚠️ 同理不暴露时间缩放，只给语义档位。
    public enum Motion: Sendable, CaseIterable {
        case calm, regular, lively

        var speed: Double {
            switch self {
            case .calm: 0.12
            case .regular: 0.28
            case .lively: 0.55
            }
        }
    }

    // MARK: - Properties

    private let tint: Color
    private let density: Density
    private let motion: Motion

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// 动画时间的原点。
    ///
    /// ⚠️ **必须以视图出现的时刻为原点，不能直接用 `timeIntervalSinceReferenceDate`**——
    /// 后者当前约 **8.1 亿**，乘上速度后进 `Float` 是 ~2.3e8，而 `Float` 在该量级上的
    /// 精度约 **16 个单位**：`sin(p.x + t)` 里的 `p.x`（0…11）会被舍入**整个吃掉**，
    /// 每个像素算出同一个值。**表现是"画面纯色 / 完全不动"，而编译、metallib 加载、
    /// 参数签名全部正常**——一个只在真渲染时才暴露的失败面（本 task 实测踩到）。
    @State private var origin = Date()

    // MARK: - Init

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.accent`（第 3 层语义 token，
    ///     指向宿主 App 的 `Color.accentColor`）。
    ///
    ///     ⚠️ **这里不能走 `.tint` 通路，与 `.core` control style 的规矩不同**——
    ///     那条规矩（CLAUDE.md《系统控件 `.core` style》：强调色一律经 `TintShapeStyle`
    ///     取、不得写死 `Color.accent`）成立的前提是 `ShapeStyle` 能直接喂给 SwiftUI 绘制。
    ///     Metal 需要的是**具体的颜色分量**，而 SwiftUI **没有公开 API 能把 `.tint`
    ///     读成 `Color`**（`EnvironmentValues` 上无对应键）。⇒ 只能走 FR-8 的第①条合法
    ///     来源「调用方参数」，默认值取第③条「语义 token」。**这不是漏了 `.tint` 通路。**
    ///   - density: 视觉密度。
    ///   - motion: 运动速度。
    public init(
        tint: Color = .accent,
        density: Density = .regular,
        motion: Motion = .regular
    ) {
        self.tint = tint
        self.density = density
        self.motion = motion
    }

    // MARK: - Body

    public var body: some View {
        // ⚠️ 底色用 `low` 而不是 `.clear`：shader 未生效时（例如用原生 `swift build`
        // 构建、bundle 里没有 metallib）至少还是一块合理的纯色，而不是透出后面的内容
        // ——但这**不是**在掩盖失败：`CoreDesignShaders.assertShaderLibraryLoadable`
        // 会在测试里判红，这里只是让首帧与降级形态不难看。
        let ramp = self.ramp

        TimelineView(.animation(paused: self.reduceMotion)) { timeline in
            let t = self.elapsed(at: timeline.date)

            ramp.low
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.bundle(.module).coreDesignPlasma(
                            .float2(proxy.size),
                            .float(t),
                            .float(self.density.field.frequency),
                            .float(self.density.field.octaves),
                            .color(ramp.low),
                            .color(ramp.mid),
                            .color(ramp.high)
                        )
                    )
                }
        }
        .accessibilityHidden(true)   // FR-13：纯装饰层
    }

    // MARK: - Private

    /// 三档调色斜坡，全部由 `tint` 推导。
    ///
    /// 手法与 `InteractionColors` 的 `accentHover` / `accentPressed` 一致
    /// （`Color.mix(with:by:)` 对基色本身调制），而不是各取一个固定色阶。
    ///
    /// ⚠️ **Reduce Transparency 开启时收窄斜坡**：三档相互靠拢 + 抬高不透明度，
    /// 让背景读起来更接近一块实色（FR-12）。
    private var ramp: (low: Color, mid: Color, high: Color) {
        let spread = self.reduceTransparency ? 0.12 : 0.34
        return (
            low: self.tint.mix(with: .surfaceCanvas, by: 0.5 + spread),
            mid: self.tint,
            high: self.tint.mix(with: .contentPrimary, by: spread)
        )
    }

    /// Reduce Motion 下**冻结在某一帧**（保留视觉、去掉运动，FR-12），
    /// 而不是停止渲染或换成静态图。
    ///
    /// ⚠️ 相对 `origin` 计时的理由见该属性的注释——**不要**改回绝对纪元时间。
    private func elapsed(at date: Date) -> Float {
        guard !self.reduceMotion else { return 0 }
        return Float(date.timeIntervalSince(self.origin) * self.motion.speed)
    }
}

// MARK: - Preview

#Preview("Plasma — 密度") {
    VStack(spacing: 0) {
        ForEach(Array(Plasma.Density.allCases.enumerated()), id: \.offset) { _, density in
            Plasma(density: density)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: density))
                        .font(.caption.monospaced())
                        .padding(8)
                }
        }
    }
    .ignoresSafeArea()
}

#Preview("Plasma — 调用方自带 tint") {
    Plasma(tint: .green, density: .dense, motion: .lively)
        .ignoresSafeArea()
}
