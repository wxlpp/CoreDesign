import OhMyDesign
import SwiftUI

/// 一颗**自转的字球**：调用方给一组字，它们按球面 Fibonacci 铺满球面并随球自转，
/// 背面的字被剔除以免与正面糊在一起。典型用途：多语言 / 多品类的品牌区块。
public struct CharSphere: View {
    /// 默认字数（球面上的点位数，不是字表长度）。
    public nonisolated static let defaultCount: Int = 240

    /// 默认自转周期（秒 / 圈）。
    public nonisolated static let defaultRotationPeriod: Double = SphereField.rotationPeriod

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
    ///     ——见 `MotionPresentation.frozenIfPeriodIsDegenerate(_:)`。
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

    /// 薄封装，同 `DotSphere`：绘制全部在 `SphereSurface` 里。
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
