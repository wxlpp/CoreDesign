//
//  SkidTransition.swift
//  CoreDesignEffects
//
//  刹车打滑转场 / A skidding slide-in transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图从一侧滑进来，**冲过头一点**再刹住，途中车身跟着甩一个小角度；离开时原路退出。
///
/// ```swift
/// if let toastItem {
///     ToastRow(toastItem).transition(.skid)
/// }
/// ```
///
/// ## 与 `.swoosh` / `.move` 的分界
///
/// | | 方向 | 曲线 | 附带 |
/// |---|---|---|---|
/// | `.move` | 同侧进出 | 线性 | 无 |
/// | `.skid` | **同侧**进出 | **阻尼余弦**（冲过头再回） | 甩尾旋转 |
/// | `.swoosh` | 穿行（进出异侧） | 线性 | 动态模糊 + 拉伸 |
///
/// 位移取 `TransitionCurve.elastic` ⇒ 与 `.boing` 是**同一条曲线**、只是作用在
/// 位移与旋转而不是缩放上。曲线只有一份（`TransitionSupport.swift`），不各写一遍。
///
/// ## ⚠️ 过冲同样只能靠 `Animatable`
///
/// 理由与 `.boing` 逐字相同：只把最终 offset 交给 SwiftUI 插值，两端之间是直线，
/// "冲过头"整个消失。`SkidMotion` 的 `animatableData` 绑在**相位值**上。
///
/// ## Reduce Motion
///
/// 位移与旋转**一并**门控到恒等值，只剩淡入淡出。走**降级形态 2**。
/// 系统那道 `TransitionProperties.hasMotion` 闸与本层门控的分工，见 `FlipTransition`。
public struct SkidTransition: Transition {

    /// 从哪一侧滑进来（同侧退出）。
    public let edge: Edge

    /// 行程档位。
    public let travel: TransitionTravel

    public init(edge: Edge = .leading, travel: TransitionTravel = .regular) {
        self.edge = edge
        self.travel = travel
    }

    /// 系统那道 Reduce Motion 闸：**必须是 `true`**。理由与判据见 `FlipTransition.properties`。
    public static var properties: TransitionProperties { .init(hasMotion: true) }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            SkidChrome(
                phaseValue: TransitionCurve.value(of: phase),
                edge: self.edge,
                points: self.travel.points
            )
        )
    }
}

// MARK: - 层 2：读 Reduce Motion

/// 唯一职责：把 `\.accessibilityReduceMotion` 降成一个普通 `Bool` 实参。见 `FlipChrome`。
struct SkidChrome: ViewModifier {

    let phaseValue: Double
    let edge: Edge
    let points: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            SkidMotion(
                phaseValue: self.phaseValue,
                edge: self.edge,
                points: self.points,
                isReduced: self.reduceMotion
            )
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

struct SkidMotion: ViewModifier, Animatable {

    var phaseValue: Double
    let edge: Edge
    let points: CGFloat
    let isReduced: Bool

    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        let travel = Skid.travel(at: self.phaseValue, along: self.edge, points: self.points)
        return content
            .rotationEffect(.degrees(self.isReduced ? 0 : Skid.tilt(at: self.phaseValue, along: self.edge)))
            .offset(
                x: self.isReduced ? 0 : travel.width,
                y: self.isReduced ? 0 : travel.height
            )
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum Skid {

    /// 阻尼余弦走几个周期。0.8 ⇒ 冲过头一次再刹住，不会来回抖。
    static let cycles: Double = 0.8

    /// 甩尾的最大角度（度）。
    static let maximumTilt: Double = 7

    /// 相位值 → 位移。**恒等恰为 `.zero`**，两端整段行程，中途冲过头（反号）。
    ///
    /// ⚠️ **同侧进出**：这里用的是 `TransitionCurve.elastic`，它吃的是
    /// `distance`（已取绝对值）⇒ `.willAppear` 与 `.didDisappear` 得到同一个方向，
    /// 就是"从哪来回哪去"。要穿行请用 `.swoosh`。
    static func travel(at phaseValue: Double, along edge: Edge, points: CGFloat) -> CGSize {
        let amount = CGFloat(TransitionCurve.elastic(phaseValue, amplitude: 1, cycles: Self.cycles))
        let unit = TransitionCurve.direction(of: edge)
        return CGSize(width: unit.width * amount * points, height: unit.height * amount * points)
    }

    /// 相位值 → 甩尾角（度）。**恒等恰为 0**。
    ///
    /// ⚠️ 与位移**同相**（同一条 `elastic`）⇒ 冲过头的时候车身也跟着往回甩，
    /// 而不是各自为政。竖直方向进出时甩尾方向要反过来，否则看起来像在"倒着甩"。
    static func tilt(at phaseValue: Double, along edge: Edge) -> Double {
        let amount = TransitionCurve.elastic(phaseValue, amplitude: 1, cycles: Self.cycles)
        let unit = TransitionCurve.direction(of: edge)
        let sign: Double = unit.width != 0 ? Double(unit.width) : -Double(unit.height)
        return amount * sign * Self.maximumTilt
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == SkidTransition {

    /// 刹车打滑转场（默认从左侧滑入）。
    ///
    /// ```swift
    /// ToastRow(item).transition(.skid)
    /// ```
    static var skid: SkidTransition { SkidTransition() }

    /// 刹车打滑转场，可指定进场边与行程。
    ///
    /// ⚠️ 与无参 `skid` 按 `Host.member` 去重，**算同一种转场**（#251）。
    static func skid(edge: Edge = .leading, travel: TransitionTravel = .regular) -> SkidTransition {
        SkidTransition(edge: edge, travel: travel)
    }
}

#Preview("skid") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("SKID")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .surface(.content)
                    .transition(.skid)
            }
        }
        .frame(height: 140)

        Button("切换") { withAnimation(.easeInOut(duration: 0.7)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
