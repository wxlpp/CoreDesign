import OhMyDesign
import SwiftUI

/// 一颗**自转的点球**：N 个点按球面 Fibonacci（Vogel 螺旋）铺满球面，
/// 单轴透视让近侧的点更大更实。典型用途：引导页 / 空态 / 品牌区块的背景。
public struct DotSphere: View {
    /// 默认点数。
    public nonisolated static let defaultCount: Int = 800

    /// 默认自转周期（秒 / 圈）。
    public nonisolated static let defaultRotationPeriod: Double = SphereField.rotationPeriod

    private let count: Int
    private let colors: [Color]
    private let rotationPeriod: Double

    /// - Parameters:
    ///   - count: 点数。**超出上限（3000）会被截断而不是断言**——库代码对数据规模
    ///     抛断言就是让宿主 App crash（AD-F）。负数与 0 都退化为"不画"。
    ///   - colors: 循环渐变的色板。**默认为空 ⇒ 取调用方的 `.tint`**。
    ///   - rotationPeriod: 转一圈用多少秒。**非法值（`<= 0` / `NaN` / `±∞`）退化为静止**
    ///     ——见 `MotionPresentation.frozenIfPeriodIsDegenerate(_:)`。
    public init(
        count: Int = DotSphere.defaultCount,
        colors: [Color] = [],
        rotationPeriod: Double = DotSphere.defaultRotationPeriod
    ) {
        self.count = count
        self.colors = colors
        self.rotationPeriod = rotationPeriod
    }

    /// 薄封装：降级路径、能耗闸与绘制全部在 `SphereSurface` 里，本类型只定形态。
    public var body: some View {
        SphereSurface(
            mark: .dots(diameter: 3),
            count: self.count,
            colors: self.colors,
            rotationPeriod: self.rotationPeriod
        )
    }
}

#Preview("DotSphere · tint") {
    DotSphere()
        .tint(.accent)
        .frame(width: 300, height: 300)
        .background(Color.surfaceRaised)
}

#Preview("DotSphere · 双色渐变 + 稀疏") {
    DotSphere(count: 300, colors: [.accent, .secondaryAccent])
        .frame(width: 300, height: 300)
        .background(Color.surfaceRaised)
}
