//
//  GlassSymbol.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 渲染成折射玻璃的 SF Symbol。适合作 App 图标位、空态插图、成就徽章。
///
/// ```swift
/// GlassSymbol("sparkles")
/// GlassSymbol("bolt.fill", tint: .orange, strength: .pronounced)
/// ```
///
/// ⚠️ **不是 `.refractiveGlass()` 的薄封装**：它额外负责符号自身的**填充与背衬**——
/// 只对一个描边符号做折射看不出效果（折射需要有内容可弯折），所以这里先把符号铺成
/// 一层由 `tint` 推导的渐变，再施加折射。
///
/// ⚠️ 与 `Card` 的取舍相反：`Card` 是薄封装、刻意不重造背景；本类型**必须**自带背衬，
/// 否则效果不成立。
public struct GlassSymbol: View {

    private let systemName: String
    private let tint: Color
    private let strength: RefractiveGlassStrength
    private let accessibilityLabel: Text?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - systemName: SF Symbol 名。
    ///   - tint: 渐变背衬的基色。⚠️ 不能走 `.tint` 通路，理由见 `Plasma.init`。
    ///   - strength: 折射强度。
    ///   - accessibilityLabel: 无障碍标签。**默认 `nil` = 当作纯装饰**（FR-13）。
    ///
    ///     ⚠️ **这个参数是终审 I-3 补的**：初版硬写 `.accessibilityHidden(true)` 且
    ///     **无法从外部撤销**（元素已被移出 a11y 树，外层 `.accessibilityLabel(_:)`
    ///     无元素可附着），而本类型自述的用例里就有「成就徽章」——那正是承载语义的
    ///     一类。⇒ 默认仍是装饰，但**给得回来**。
    public init(
        _ systemName: String,
        tint: Color = .accent,
        strength: RefractiveGlassStrength = .regular,
        accessibilityLabel: Text? = nil
    ) {
        self.systemName = systemName
        self.tint = tint
        self.strength = strength
        self.accessibilityLabel = accessibilityLabel
    }

    /// 是否当作纯装饰处理（FR-13）。
    ///
    /// ⚠️ 抽成 `static` 纯函数只为**可断言**——第 3 轮终审 I-5：上一轮那个 suite
    /// 叫「FR-12 / FR-13」，而 FR-13 一条断言都没有。
    static func isDecorative(accessibilityLabel: Text?) -> Bool {
        accessibilityLabel == nil
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)

        Image(systemName: self.systemName)
            .resizable()
            .scaledToFit()
            .foregroundStyle(
                LinearGradient(
                    colors: [ramp.high, ramp.mid, ramp.low],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // ⚠️ Reduce Transparency 下关掉折射：折射本质上是"透过看"，
            // 对该偏好的用户应退回实心符号（FR-12）。
            // ⚠️ 走 `isEnabled` 而**不是 `if` 分支**——后者会切换 View 身份
            // （#261 终审 I-4：包在 `ViewModifier` 里同样是 `_ConditionalContent`，没有区别）。
            .refractiveGlass(
                corner: CoreRadius.large,
                strength: self.strength,
                rim: ramp.high.opacity(0.55),
                isEnabled: !self.reduceTransparency
            )
            // ⚠️ **终审 I-3**：初版硬写 `.accessibilityHidden(true)` 并注释
            // 「承载语义时由调用方给 label」——**那在 SwiftUI 里不成立**：元素已被
            // 移出 a11y 树，外层 `.accessibilityLabel(_:)` 无元素可附着。而本类型
            // 自述的用例里就有「成就徽章」，那正是承载语义的一类
            // ⇒ 一个默认且**不可撤销**的 a11y 黑洞。改为可撤销：
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(Self.isDecorative(accessibilityLabel: self.accessibilityLabel))
            .accessibilityLabel(self.accessibilityLabel ?? Text(verbatim: ""))
            // ⚠️ 有 label 时补 `.isImage` trait（终审 S）：本类型自述的用例里有
            // 「成就徽章」，缺 trait 时 VoiceOver 会念出 label 但不播报元素类型。
            .accessibilityAddTraits(Self.isDecorative(accessibilityLabel: self.accessibilityLabel)
                                    ? [] : .isImage)
    }
}

#Preview("GlassSymbol") {
    HStack(spacing: 20) {
        GlassSymbol("sparkles")
        GlassSymbol("bolt.fill", strength: .pronounced)
        GlassSymbol("cube.transparent", tint: .purple)
    }
    .frame(height: 96)
    .padding()
}
