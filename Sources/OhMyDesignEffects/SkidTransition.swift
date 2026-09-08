import OhMyDesign
import SwiftUI

// MARK: - 转场本体

/// 视图从一侧滑进来，**冲过头一点**再刹住，途中车身跟着甩一个小角度；离开时原路退出。
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
    public nonisolated static var properties: TransitionProperties { .init(hasMotion: true) }

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
    static let cycles: Double = 0.8

    static let maximumTilt: Double = 7

    static func travel(at phaseValue: Double, along edge: Edge, points: CGFloat) -> CGSize {
        let amount = CGFloat(TransitionCurve.elastic(phaseValue, amplitude: 1, cycles: Self.cycles))
        let unit = TransitionCurve.direction(of: edge)
        return CGSize(width: unit.width * amount * points, height: unit.height * amount * points)
    }

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
    static var skid: SkidTransition { SkidTransition() }

    /// 刹车打滑转场，可指定进场边与行程。
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
