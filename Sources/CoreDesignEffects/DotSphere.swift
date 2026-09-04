//
//  DotSphere.swift
//  CoreDesignEffects
//
//  自转的点球 / A slowly rotating sphere of dots.
//

import CoreDesign
import SwiftUI

/// 一颗**自转的点球**：N 个点按球面 Fibonacci（Vogel 螺旋）铺满球面，
/// 单轴透视让近侧的点更大更实。典型用途：引导页 / 空态 / 品牌区块的背景。
///
/// ```swift
/// ZStack {
///     DotSphere()                     // 空色板 ⇒ 全部取调用方的 .tint
///     content
/// }
/// .tint(.indigo)
/// ```
///
/// ## 平台支持（AD-E）
///
/// **iOS 与 macOS 完全一致，没有平台分支。** 上游 `SWDotSphere` 的 `import UIKit`
/// 只为把 `Color` 拆成 RGB 分量做插值；本仓的取色纪律（AD-D）本来就不许写
/// `Color(red:green:blue:)`，插值改走 `Color.mix(with:by:)` 之后那个依赖直接消失。
/// 三维投影本身是纯算术。⇒ 本件在 macOS 上是**同一份代码、同样能用**，
/// 不是"能编译但空转"。逐条见 `docs/components/dot-sphere.md`。
///
/// ## 取色：**不自带调色板**（FR-8）
///
/// - `colors` 非空 ⇒ 按时间在色板之间循环渐变，逐点延迟让浪**从下往上洗**；
/// - `colors` 为空 ⇒ 回落到调用方的 **`.tint`**（与 `.spray` / `.confetti` /
///   `AnimatedMeshGradient` 同一纪律）。这一档下点云是一张 alpha 遮罩，
///   **不凭空造色相**，只把调用方那一个色相铺成有景深的点云。
///
/// ## Reduce Motion
///
/// **冻结在某一帧**：自转相位与色波都钉死，球照常画。走**降级形态 2**
///（保留"长什么样"、只去掉运动、不叠透明度脉冲）。⚠️ 不是 no-op——这是一块背景面。
///
/// ## 后台 / 低电量（NFR-7）
///
/// 与 `AnimatedMeshGradient` / `Confetti` 共用同一道闸：
/// `.inactive` / `.background` ⇒ **整层不建**；低电量 ⇒ 降到 15 fps 且**点数减半**。
/// ⚠️ 「`.inactive` 下这块背景面会在可见窗口里变空白」这条**已知限度**逐字适用，
/// 完整记账见 `AnimatedMeshGradient` 的类型文档与 `EffectsEnergyState.policy`。
///
/// ## a11y（FR-13）
///
/// 点云是**纯装饰**，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`。
public struct DotSphere: View {

    /// 默认点数。
    ///
    /// ⚠️ `public` 且住在本类型上（同 `ParticleTransition.defaultCount` 的理由）：
    /// 它被 `public init` 当默认实参用，而 Swift 不允许默认实参引用 internal 符号。
    public static let defaultCount: Int = 800

    /// 默认自转周期（秒 / 圈）。
    public static let defaultRotationPeriod: Double = SphereField.rotationPeriod

    private let count: Int
    private let colors: [Color]
    private let rotationPeriod: Double

    /// - Parameters:
    ///   - count: 点数。**超出上限（3000）会被截断而不是断言**——库代码对数据规模
    ///     抛断言就是让宿主 App crash（AD-F）。负数与 0 都退化为"不画"。
    ///   - colors: 循环渐变的色板。**默认为空 ⇒ 取调用方的 `.tint`**。
    ///   - rotationPeriod: 转一圈用多少秒。`<= 0` 退化为静止。
    public init(
        count: Int = DotSphere.defaultCount,
        colors: [Color] = [],
        rotationPeriod: Double = DotSphere.defaultRotationPeriod
    ) {
        self.count = count
        self.colors = colors
        self.rotationPeriod = rotationPeriod
    }

    /// ⚠️ **薄封装**：降级路径、能耗闸与绘制全部在 `SphereSurface` 里，本类型只定形态。
    /// 「本文件里没有运动关键字」不是逃逸位——`CrossPlatformRenderTests.spheresDelegateToSharedSurface`
    /// 逐条断言本文件既出现 `SphereSurface(`、又不出现任何自建动画 / 绘制调用。
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
