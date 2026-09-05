//
//  Rotate3DTransition.swift
//  CoreDesignEffects
//
//  空间翻滚转场 / A free-axis 3D tumble transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时绕任意轴翻滚，同时向纵深退一点。
///
/// ```swift
/// if showsDetail {
///     DetailPanel().transition(.rotate3D)
/// }
/// ```
///
/// ## 与 `.flip` 的分工（两者都是 3D 旋转，别合并）
///
/// | | `.flip` | `.rotate3D` |
/// |---|---|---|
/// | 角度 | **钉死** 90°（恰好侧对镜头） | 调用方给，默认 75° |
/// | 轴 | 默认水平 | 默认**斜向** `.tilted` |
/// | 附带 | 只有淡入淡出 | 还向纵深缩小（`Rotate3D.depthScale`） |
/// | 读作 | "这张卡翻面了" | "这块东西翻滚着离开 / 飞进来" |
///
/// ⚠️ 两者共用 `TransitionAxis3D`，**不各自定义一份轴枚举**。
///
/// ## Reduce Motion
///
/// 旋转与缩放**一并**门控到恒等值，只剩淡入淡出。
/// ⚠️ 「缩放也算运动」这一条是 `#250` 第 1 轮 `Jump` 的原缺陷形态
///（`offset` 门控了、`scaleEffect` 没门控，而当时的守卫全绿放行）
/// ⇒ 本文件两处运动各自带门控，由
/// `MicroInteractionReduceMotionGuard.everyMotionCallIsGated` 逐实参检查。
///
/// 系统那道 `TransitionProperties.hasMotion` 闸与本层门控的分工，见 `FlipTransition`。
public struct Rotate3DTransition: Transition {

    /// 两端的旋转角。
    public let angle: Angle

    /// 绕哪个轴转。
    public let axis: TransitionAxis3D

    /// 默认旋转角（度）。
    ///
    /// ⚠️ **不取 90°**：那正好是 `.flip` 的取值，两个转场会在默认形态上撞脸。
    /// 75° 留出一点正面，翻滚感更强而不至于完全侧对镜头。
    /// ⚠️ `public` 是因为它被 `public` 签名当默认实参用（同 `FlipTransition.quarterTurn`）。
    public nonisolated static let defaultDegrees: Double = 75

    public init(angle: Angle = .degrees(Rotate3DTransition.defaultDegrees), axis: TransitionAxis3D = .tilted) {
        self.angle = angle
        self.axis = axis
    }

    /// 系统那道 Reduce Motion 闸：**必须是 `true`**。理由与判据见 `FlipTransition.properties`。
    public nonisolated static var properties: TransitionProperties { .init(hasMotion: true) }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            Rotate3DChrome(
                phaseValue: TransitionCurve.value(of: phase),
                degrees: self.angle.degrees,
                axis: self.axis
            )
        )
    }
}

// MARK: - 层 2：读 Reduce Motion

/// 唯一职责：把 `\.accessibilityReduceMotion` 降成一个普通 `Bool` 实参。见 `FlipChrome`。
struct Rotate3DChrome: ViewModifier {

    let phaseValue: Double
    let degrees: Double
    let axis: TransitionAxis3D

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            Rotate3DMotion(
                phaseValue: self.phaseValue,
                degrees: self.degrees,
                axis: self.axis,
                isReduced: self.reduceMotion
            )
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

struct Rotate3DMotion: ViewModifier, Animatable {

    var phaseValue: Double
    let degrees: Double
    let axis: TransitionAxis3D
    let isReduced: Bool

    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(self.isReduced ? 0 : Rotate3D.angle(at: self.phaseValue, degrees: self.degrees)),
                axis: self.axis.vector,
                perspective: Rotate3D.perspective
            )
            .scaleEffect(self.isReduced ? 1 : Rotate3D.scale(at: self.phaseValue))
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum Rotate3D {

    static let perspective: CGFloat = 0.7

    /// 两端向纵深缩到多小。
    static let depthScale: CGFloat = 0.82

    /// 相位值 → 旋转角（度）。**恒等恰为 0**，两端 ±`degrees`（有符号，进出方向相反）。
    static func angle(at phaseValue: Double, degrees: Double) -> Double {
        max(-1, min(1, phaseValue)) * degrees
    }

    /// 相位值 → 缩放。**恒等恰为 1**，两端 `depthScale`。
    static func scale(at phaseValue: Double) -> CGFloat {
        1 - (1 - Self.depthScale) * CGFloat(TransitionCurve.distance(phaseValue))
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == Rotate3DTransition {

    /// 空间翻滚转场（默认 75°、斜向轴）。
    ///
    /// ```swift
    /// DetailPanel().transition(.rotate3D)
    /// ```
    static var rotate3D: Rotate3DTransition { Rotate3DTransition() }

    /// 空间翻滚转场，可指定角度与轴。
    ///
    /// ⚠️ 与无参 `rotate3D` 按 `Host.member` 去重，**算同一种转场**（#251）。
    static func rotate3D(
        angle: Angle = .degrees(Rotate3DTransition.defaultDegrees),
        axis: TransitionAxis3D = .tilted
    ) -> Rotate3DTransition {
        Rotate3DTransition(angle: angle, axis: axis)
    }
}

#Preview("rotate3D") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("TUMBLE")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .surface(.content)
                    .transition(.rotate3D)
            }
        }
        .frame(height: 140)

        Button("切换") { withAnimation(.easeInOut(duration: 0.6)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
