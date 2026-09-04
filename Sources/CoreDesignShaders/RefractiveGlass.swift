//
//  RefractiveGlass.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

// MARK: - RefractiveGlassModifier

/// 把内容渲染成一片折射玻璃：圆角矩形区域内做透镜位移 + 边缘高光。
///
/// ⚠️ **与 Apple 的 `.glassEffect()` 是两回事，别混**：
/// · `.glassEffect()` 是 iOS 26 的 **Liquid Glass** 材质，系统实现、随外观自动适配，
///   本仓 `BottomInputBar` / `Carousel` / `SegmentedControl` 用的是它；
/// · ⚠️ **本 modifier 曾自述"自研的 Metal 折射"，该声称已撤回**（终审 C-3）：
/// `CoreDesignShaders.metal` 自己立过一条闸——「在 `RefractiveGlass` 的 provenance
/// 追溯完成前**不得对外宣称原创**」，而**发布本身就是最强形式的宣称**。
/// 本 modifier 的折射数学，把内容当被折射的背景做几何弯折。
/// ⚠️⚠️ **#281 追溯结论**：主体**仍未指认到具名上游**，且上一版所称
/// 「2025 年 SwiftUI `layerEffect` "liquid glass" 一族的通行形态」**已被证伪**
/// ——逐个读完具名的 SwiftUI-Metal 玻璃库后，没有找到这样一族。
/// ⇒ 裁定仍是 **`待追溯`（不是「自研」）**，分档由**强指纹改判低指纹**
/// （强档三条判据逐条不成立；逐常量 grep 零命中）⇒ **不再阻断 `epic → main`**。
/// ⚠️ 该改判**须由 `epic → main` 评审显式确认**，不确认则回落 `不落地`，
/// 本 modifier 与 `GlassSymbol` 一并撤回。承接 issue **#281**。
/// 调用的 `cd::roundedBoxSDF` 已追到 **Inigo Quilez，MIT**（须署名）。
/// **需要系统材质就用 `.glassEffect()`**；本 modifier 只在需要可控折射强度/色散时用。
/// ⇒ 命名刻意避开 `glass` 单独成词，防止与系统 API 混淆。
struct RefractiveGlassModifier: ViewModifier {

    let corner: CGFloat
    let strength: RefractiveGlassStrength
    let rim: Color

    /// ⚠️ 用 `layerEffect` 自带的 `isEnabled` 关效果，**不要用 `if` 分支**
    /// （#261 终审 I-4）：`ViewModifier.body` 里的 `if` 同样产出 `_ConditionalContent`，
    /// 翻转时 View 身份照样切换——与写在 View body 里没有区别。`isEnabled` 正是为此存在。
    let isEnabled: Bool

    func body(content: Content) -> some View {
        // ⚠️ 闭包是 `@Sendable`：把要捕获的值先在这里取出，不在闭包里读 MainActor 隔离的东西。
        let library = ShaderLibrary.bundle(.module)
        let corner = Float(self.corner)
        let refraction = self.strength.refraction
        let dispersion = self.strength.dispersion
        let rim = self.rim
        let enabled = self.isEnabled
        let maxOffset = CGFloat(refraction) * 2

        return content.visualEffect { view, proxy in
            view.layerEffect(
                library.coreDesignRefractiveGlass(
                    .float2(proxy.size),
                    .float(corner),
                    .float(refraction),
                    .float(dispersion),
                    .color(rim)
                ),
                // 需求上的最大位移 = refraction × (1 + dispersion)；`pronounced` 档为 26 × 1.45 ≈ 38。
                // ⚠️ **上一行描述的是需求，下面代码取的是更大的余量**（第 5 轮终审 S）：
                // 实际是 `refraction * 2`（pronounced = 52），不是 38。
                // 余量更大是对的，但别照上一行的需求值"优化"回 38。
                // 给小了的表现是边缘一圈采到 layer 外 ⇒ 玻璃边缘出现暗环 / 透明环。
                maxSampleOffset: CGSize(width: maxOffset, height: maxOffset),
                isEnabled: enabled
            )
        }
    }
}

// MARK: - Strength

/// 折射强度。⚠️ 语义枚举，不暴露"位移像素数 + 色散系数"两个裸旋钮。
public nonisolated enum RefractiveGlassStrength: Sendable, CaseIterable {
    case subtle, regular, pronounced

    nonisolated var refraction: Float {
        switch self {
        case .subtle: 6
        case .regular: 14
        case .pronounced: 26
        }
    }

    /// 色散（三通道分离）。⚠️ `subtle` 档为 0——弱折射配色散会显脏。
    nonisolated var dispersion: Float {
        switch self {
        case .subtle: 0
        case .regular: 0.25
        case .pronounced: 0.45
        }
    }
}

// MARK: - View

public extension View {

    /// 把本视图渲染成一片折射玻璃。
    ///
    /// ```swift
    /// Image("photo")
    ///     .resizable()
    ///     .refractiveGlass(corner: CoreRadius.large)
    /// ```
    ///
    /// ⚠️ **不吃时间**：折射由几何驱动而非动画，因此不需要 Reduce Motion 降级
    /// （按 FR-12，`layerEffect` 类冻结时间输入、保留空间输入——这里没有时间输入）。
    ///
    /// - Parameters:
    ///   - corner: 玻璃面板的圆角。默认取本仓的 `CoreRadius.medium`。
    ///   - strength: 折射强度档位。
    ///   - rim: 边缘高光色。默认由 `Color.accent` 推导；传 `.clear` 关掉高光。
    ///     ⚠️ 不能走 `.tint` 通路的理由见 `Plasma.init`。
    ///   - isEnabled: 关掉效果时**保持 View 身份不变**（走 `layerEffect` 的 `isEnabled`，
    ///     不是 `if` 分支）。
    func refractiveGlass(
        corner: CGFloat = CoreRadius.medium,
        strength: RefractiveGlassStrength = .regular,
        rim: Color = .accent.opacity(0.55),
        isEnabled: Bool = true
    ) -> some View {
        self.modifier(
            RefractiveGlassModifier(
                corner: corner, strength: strength, rim: rim, isEnabled: isEnabled
            )
        )
    }
}

// MARK: - Preview

#Preview("RefractiveGlass") {
    VStack(spacing: 24) {
        ForEach(Array(RefractiveGlassStrength.allCases.enumerated()), id: \.offset) { _, s in
            ZStack {
                LinearGradient(
                    colors: [.accent, .accentSubtleBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text("CoreDesign").font(.largeTitle.bold())
            }
            .frame(height: 120)
            .refractiveGlass(strength: s)
            .overlay(alignment: .topLeading) {
                Text(String(describing: s)).font(.caption.monospaced()).padding(6)
            }
        }
    }
    .padding()
}
