//
//  SwooshTransition.swift
//  CoreDesignEffects
//
//  带动态模糊的穿行转场 / A directional swoosh with motion blur.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图**穿行而过**：从一侧飞进来、从另一侧飞出去，途中带一层随速度增强的动态模糊。
///
/// ```swift
/// if let card = current {
///     CardView(card).transition(.swoosh)
/// }
/// ```
///
/// ## 「穿行」不是「同侧进出」——这是它与 `.move` / `.skid` 的分界
///
/// 位移取**有符号**的相位值：`.willAppear` 从 `edge` 那一侧进来、`.didDisappear`
/// 朝**对侧**出去，读作"一样东西被推走、另一样顶上来"（同 SwiftUI 自带的 `.push`）。
///
/// - `.move` / `.skid` 是**同侧**进出（进来的方向倒放回去），读作"这块内容出现 / 收起"；
/// - `.swoosh` 是穿行，读作"翻页"。
///
/// ⚠️ 两种语义都要，别把它们合并成一个带 Bool 开关的转场（J-1）。
///
/// ## 动态模糊
///
/// 模糊半径正比于「离恒等有多远」（`Swoosh.blurRadius`），恒等**恰为 0**——
/// 转场停住后不能留一点点糊，那是**永久**的。
///
/// ⚠️ 模糊在 `MicroInteractionReduceMotionGuard.motionCalls` 的关键字表里**没有**
/// （`blur(` 不是位移 / 旋转 / 缩放）⇒ 守卫对它无话可说。但它是这条转场"速度感"的
/// 一半，Reduce Motion 下留着它就等于把"快速掠过"这个观感留给了明确要求减弱动态效果
/// 的用户 ⇒ **本文件仍然逐表达式门控它**，并由
/// `TransitionClusterTests.reduceMotionLeavesExactlyTheCrossFade`（把降级那一帧与"只加
/// `.opacity`"的对照版逐字节比较）钉住——模糊留在里面会让那条相等断言判红。
///
/// ## Reduce Motion
///
/// 位移、拉伸、模糊三处**一并**门控到恒等值，只剩淡入淡出。走**降级形态 2**。
/// 系统那道 `TransitionProperties.hasMotion` 闸与本层门控的分工，见 `FlipTransition`。
public struct SwooshTransition: Transition {

    /// 进场从哪一侧来（出场去对侧）。
    public let edge: Edge

    /// 行程档位。
    public let travel: TransitionTravel

    public init(edge: Edge = .trailing, travel: TransitionTravel = .regular) {
        self.edge = edge
        self.travel = travel
    }

    /// 系统那道 Reduce Motion 闸：**必须是 `true`**。理由与判据见 `FlipTransition.properties`。
    public static var properties: TransitionProperties { .init(hasMotion: true) }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            SwooshChrome(
                phaseValue: TransitionCurve.value(of: phase),
                edge: self.edge,
                points: self.travel.points
            )
        )
    }
}

// MARK: - 层 2：读 Reduce Motion

/// 唯一职责：把 `\.accessibilityReduceMotion` 降成一个普通 `Bool` 实参。见 `FlipChrome`。
struct SwooshChrome: ViewModifier {

    let phaseValue: Double
    let edge: Edge
    let points: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            SwooshMotion(
                phaseValue: self.phaseValue,
                edge: self.edge,
                points: self.points,
                isReduced: self.reduceMotion
            )
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

struct SwooshMotion: ViewModifier, Animatable {

    var phaseValue: Double
    let edge: Edge
    let points: CGFloat
    let isReduced: Bool

    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        let stretch = Swoosh.stretch(at: self.phaseValue, along: self.edge)
        let travel = Swoosh.travel(at: self.phaseValue, along: self.edge, points: self.points)
        return content
            .scaleEffect(
                x: self.isReduced ? 1 : stretch.width,
                y: self.isReduced ? 1 : stretch.height
            )
            .offset(
                x: self.isReduced ? 0 : travel.width,
                y: self.isReduced ? 0 : travel.height
            )
            .blur(radius: self.isReduced ? 0 : Swoosh.blurRadius(at: self.phaseValue))
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum Swoosh {

    /// 两端的最大模糊半径（pt）。
    static let maximumBlur: CGFloat = 6

    /// 沿运动方向拉伸多少（1.0 = 不拉）。
    static let maximumStretch: CGFloat = 0.16

    /// 相位值 → 位移。**恒等恰为 `.zero`**。
    ///
    /// ⚠️ **有符号**：`.willAppear`（`-1`）落在 `edge` 那一侧、`.didDisappear`（`+1`）
    /// 落在对侧 ⇒ 穿行。取 `abs` 会让它退化成同侧进出（那是 `.move` 的语义）。
    static func travel(at phaseValue: Double, along edge: Edge, points: CGFloat) -> CGSize {
        let clamped = CGFloat(max(-1, min(1, phaseValue)))
        let unit = TransitionCurve.direction(of: edge)
        return CGSize(width: -unit.width * clamped * points, height: -unit.height * clamped * points)
    }

    /// 相位值 → 沿运动方向的拉伸。**恒等恰为 `(1, 1)`**。
    static func stretch(at phaseValue: Double, along edge: Edge) -> CGSize {
        let amount = Self.maximumStretch * CGFloat(TransitionCurve.distance(phaseValue))
        let unit = TransitionCurve.direction(of: edge)
        return CGSize(
            width: 1 + amount * abs(unit.width),
            height: 1 + amount * abs(unit.height)
        )
    }

    /// 相位值 → 模糊半径（pt）。**恒等恰为 0**。
    static func blurRadius(at phaseValue: Double) -> CGFloat {
        Self.maximumBlur * CGFloat(TransitionCurve.distance(phaseValue))
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == SwooshTransition {

    /// 带动态模糊的穿行转场（默认从右侧进、左侧出）。
    ///
    /// ```swift
    /// CardView(card).transition(.swoosh)
    /// ```
    static var swoosh: SwooshTransition { SwooshTransition() }

    /// 带动态模糊的穿行转场，可指定进场边与行程。
    ///
    /// ⚠️ 与无参 `swoosh` 按 `Host.member` 去重，**算同一种转场**（#251）。
    static func swoosh(edge: Edge = .trailing, travel: TransitionTravel = .regular) -> SwooshTransition {
        SwooshTransition(edge: edge, travel: travel)
    }
}

#Preview("swoosh") {
    @Previewable @State var index = 0
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            Text(verbatim: "#\(index)")
                .font(.largeTitle.bold())
                .padding(CoreSpacing.xxl)
                .surface(.content)
                .transition(.swoosh)
                .id(index)
        }
        .frame(height: 140)

        Button("下一页") { withAnimation(.easeInOut(duration: 0.5)) { index += 1 } }
    }
    .padding(CoreSpacing.huge)
}
