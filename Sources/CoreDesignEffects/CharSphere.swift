//
//  CharSphere.swift
//  CoreDesignEffects
//
//  自转的字球 / A slowly rotating sphere of glyphs.
//

import CoreDesign
import SwiftUI

/// 一颗**自转的字球**：调用方给一组字，它们按球面 Fibonacci 铺满球面并随球自转，
/// 背面的字被剔除以免与正面糊在一起。典型用途：多语言 / 多品类的品牌区块。
///
/// ```swift
/// CharSphere(["道", "德", "经"])
///     .tint(.indigo)
///     .frame(width: 280, height: 280)
/// ```
///
/// ## 平台支持（AD-E）
///
/// **iOS 与 macOS 完全一致，没有平台分支**——理由与 `DotSphere` 逐字相同
///（上游的 `import UIKit` 只为拆颜色分量，`Color.mix(with:by:)` 之后不再需要）。
/// 逐条见 `docs/components/char-sphere.md`。
///
/// ## 字表是**调用方的数据，不是本件的文案**（FR-7）
///
/// ⚠️ `characters` **没有默认值**，本件不自带任何字表：上游的默认值是《道德经》第一章，
/// 那是一段内容决定，与"给调用方一个好看的默认色板"是同一类越界（AD-D / FR-8 已就
/// 色板立过规矩）。字表为空 ⇒ 一个字都不画（**不**回落到某个占位符号）。
/// ⚠️ 同理它是**内容不是 UI 文案** ⇒ 类型是 `[String]` 而不是
/// `[LocalizedStringResource]`（公约 FR-7 的边界逐字：调用方传入的数据文案不强制本地化类型）。
///
/// ## 取色 / Reduce Motion / 后台与低电量 / a11y
///
/// 与 `DotSphere` **共用同一份实现**（`SphereSurface`），逐条见那边的类型文档：
/// 空色板 ⇒ 取 `.tint`；Reduce Motion ⇒ 冻结在某一帧（降级形态 2）；
/// `.inactive` / `.background` ⇒ 整层不建；低电量 ⇒ 降帧 + 字数减半；字球是纯装饰。
public struct CharSphere: View {

    /// 默认字数（球面上的点位数，不是字表长度）。
    public static let defaultCount: Int = 240

    /// 默认自转周期（秒 / 圈）。
    public static let defaultRotationPeriod: Double = SphereField.rotationPeriod

    private let characters: [String]
    private let count: Int
    private let colors: [Color]
    private let rotationPeriod: Double

    /// - Parameters:
    ///   - characters: 字表。每个点位按**确定性散列**分到其中一个字
    ///     （不是 `Int.random`——那会让每次渲染都不同）。**空数组 ⇒ 什么都不画**。
    ///   - count: 点位数。上限 1000，超出截断（字形比圆点贵得多）。
    ///   - colors: 循环渐变的色板。**默认为空 ⇒ 取调用方的 `.tint`**。
    ///   - rotationPeriod: 转一圈用多少秒。**非法值（`<= 0` / `NaN` / `±∞`）退化为静止**
    ///     ——见 `EffectsPresentation.frozenIfPeriodIsDegenerate(_:)`。
    public init(
        _ characters: [String],
        count: Int = CharSphere.defaultCount,
        colors: [Color] = [],
        rotationPeriod: Double = CharSphere.defaultRotationPeriod
    ) {
        self.characters = characters
        self.count = count
        self.colors = colors
        self.rotationPeriod = rotationPeriod
    }

    /// ⚠️ **薄封装**，同 `DotSphere`：判据见 `spheresDelegateToSharedSurface`。
    public var body: some View {
        SphereSurface(
            mark: .glyphs(self.characters, fontSize: 11),
            count: self.count,
            colors: self.colors,
            rotationPeriod: self.rotationPeriod
        )
    }
}

#Preview("CharSphere · tint") {
    CharSphere(["道", "可", "道", "非", "常", "名"])
        .tint(.accent)
        .frame(width: 300, height: 300)
        .background(Color.surfaceRaised)
}

#Preview("CharSphere · 拉丁字母 + 双色") {
    CharSphere(["S", "h", "i", "p"], count: 160, colors: [.accent, .secondaryAccent])
        .frame(width: 300, height: 300)
        .background(Color.surfaceRaised)
}
