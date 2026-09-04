//
//  PolarMoveTransition.swift
//  CoreDesignEffects
//
//  任意方向的平移转场 / A polar (angle + distance) move transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图沿**任意极角**平移进出（同侧：从哪来、回哪去）。
///
/// ```swift
/// if showsHint {
///     HintBubble().transition(.move(angle: .degrees(-60), distance: 120))
/// }
/// ```
///
/// ## ⚠️⚠️ 类型名不叫 `MoveTransition`，这不是笔误
///
/// `SwiftUICore` **已有** `public struct MoveTransition` 与
/// `extension Transition where Self == MoveTransition { static func move(edge:) }`。
/// 同名类型在下游同时 `import SwiftUI` 与 `import CoreDesignEffects` 时会**歧义**
/// （本模块内部倒是能靠 shadowing 编译过去——这恰恰是最坏的形态：
/// 库自己 `swift build` 全绿，红的是调用方）。
/// ⇒ 类型名取 `PolarMoveTransition`（极坐标：角 + 距离，正是它与系统那个的差别）。
///
/// **静态成员仍叫 `move`**，与系统那个构成**重载**而不是覆盖：
///
/// | 写法 | 解析到 |
/// |---|---|
/// | `.move(edge: .top)` | `SwiftUICore.MoveTransition`（系统的，**不受影响**） |
/// | `.move(angle:distance:)` | 本类型 |
/// | `.move` | 本类型（系统没有无参形态） |
///
/// 实参标签不同 ⇒ 重载解析无歧义。
///
/// ⚠️⚠️ **守住这张表的是 `scripts/downstream-probe`，不是库内判据**（`#267` 终审 C-4）：
/// 库内的 `TransitionClusterTests.systemMoveEdgeStillResolvesToSwiftUI` 写的是
/// `let system: MoveTransition = .move(edge: .top)` —— **显式结果类型标注按返回类型
/// 消歧了**。实测：给本文件加一条 `static func move(edge: Edge) -> PolarMoveTransition`，
/// `swift build` 与那条判据**全绿**，而真实外部消费者报
/// `error: ambiguous use of 'move(edge:)'`。
/// ⇒ 真正的守卫是 probe 里的 `systemMoveEdgeKeepsResolvingToSwiftUI` /
/// `systemMoveEdgeIsUnambiguousWithoutAnyAnnotation`（`TransitionClusterProbe.swift`）——
/// 它们跑在**另一个模块**里，才复现得出下游那两种写法。库内那条只剩"我们没把
/// 系统那个截胡"这一句，别再当成改名守卫。
///
/// ## 与 `.skid` / `.swoosh` 的分界
///
/// 本转场是**线性、同侧、无附加效果**的那一条：只有位移与淡入淡出。
/// 要过冲用 `.skid`，要穿行 + 动态模糊用 `.swoosh`。
///
/// ## Reduce Motion
///
/// 位移门控到 `0`，只剩淡入淡出。走**降级形态 2**。
/// 系统那道 `TransitionProperties.hasMotion` 闸与本层门控的分工，见 `FlipTransition`。
public struct PolarMoveTransition: Transition {

    /// 平移方向（极角）。0° 指向右、90° 指向下（SwiftUI 的 y 轴朝下）。
    public let angle: Angle

    /// 平移距离（pt）。
    public let distance: CGFloat

    /// 默认方向：向下。
    ///
    /// ⚠️ `public` 是因为它被 `public` 签名当默认实参用（同 `FlipTransition.quarterTurn`）。
    public nonisolated static let defaultDegrees: Double = 90

    public init(
        angle: Angle = .degrees(PolarMoveTransition.defaultDegrees),
        distance: CGFloat = TransitionTravel.regular.points
    ) {
        self.angle = angle
        self.distance = distance
    }

    /// 系统那道 Reduce Motion 闸：**必须是 `true`**。理由与判据见 `FlipTransition.properties`。
    public static var properties: TransitionProperties { .init(hasMotion: true) }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            PolarMoveChrome(
                phaseValue: TransitionCurve.value(of: phase),
                radians: self.angle.radians,
                distance: self.distance
            )
        )
    }
}

// MARK: - 层 2：读 Reduce Motion

/// 唯一职责：把 `\.accessibilityReduceMotion` 降成一个普通 `Bool` 实参。见 `FlipChrome`。
struct PolarMoveChrome: ViewModifier {

    let phaseValue: Double
    let radians: Double
    let distance: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            PolarMoveMotion(
                phaseValue: self.phaseValue,
                radians: self.radians,
                distance: self.distance,
                isReduced: self.reduceMotion
            )
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

struct PolarMoveMotion: ViewModifier, Animatable {

    var phaseValue: Double
    let radians: Double
    let distance: CGFloat
    let isReduced: Bool

    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        let travel = PolarMove.travel(at: self.phaseValue, radians: self.radians, distance: self.distance)
        return content
            .offset(
                x: self.isReduced ? 0 : travel.width,
                y: self.isReduced ? 0 : travel.height
            )
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum PolarMove {

    /// 相位值 → 位移。**恒等恰为 `.zero`**，两端整段距离。
    ///
    /// ⚠️ 走 `TransitionCurve.distance`（已取绝对值）⇒ **同侧**进出。
    static func travel(at phaseValue: Double, radians: Double, distance: CGFloat) -> CGSize {
        let amount = CGFloat(TransitionCurve.distance(phaseValue)) * distance
        return CGSize(width: cos(radians) * amount, height: sin(radians) * amount)
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == PolarMoveTransition {

    /// 平移转场（默认向下 90°、`TransitionTravel.regular` 的距离）。
    ///
    /// ```swift
    /// HintBubble().transition(.move)
    /// ```
    static var move: PolarMoveTransition { PolarMoveTransition() }

    /// 平移转场，可指定极角与距离。
    ///
    /// ⚠️ 与无参 `move` 按 `Host.member` 去重，**算同一种转场**（#251：计数单位是
    /// 「一种 transition」不是「一个静态成员」）。
    /// ⚠️ 与系统的 `.move(edge:)` 是**重载**关系而非覆盖，见 `PolarMoveTransition` 类型文档。
    static func move(
        angle: Angle = .degrees(PolarMoveTransition.defaultDegrees),
        distance: CGFloat = TransitionTravel.regular.points
    ) -> PolarMoveTransition {
        PolarMoveTransition(angle: angle, distance: distance)
    }
}

#Preview("move") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("MOVE")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .surface(.content)
                    .transition(.move(angle: .degrees(-45), distance: TransitionTravel.long.points))
            }
        }
        .frame(height: 160)

        Button("切换") { withAnimation(.easeInOut(duration: 0.6)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
