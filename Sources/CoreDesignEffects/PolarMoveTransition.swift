import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图沿**任意极角**平移进出（同侧：从哪来、回哪去）。
public struct PolarMoveTransition: Transition {
    /// 平移方向（极角）。0° 指向右、90° 指向下（SwiftUI 的 y 轴朝下）。
    public let angle: Angle

    /// 平移距离（pt）。
    public let distance: CGFloat

    /// 默认方向：向下。
    public nonisolated static let defaultDegrees: Double = 90

    public init(
        angle: Angle = .degrees(PolarMoveTransition.defaultDegrees),
        distance: CGFloat = TransitionTravel.regular.points
    ) {
        self.angle = angle
        self.distance = distance
    }

    /// 系统那道 Reduce Motion 闸：**必须是 `true`**。理由与判据见 `FlipTransition.properties`。
    public nonisolated static var properties: TransitionProperties { .init(hasMotion: true) }

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
    static func travel(at phaseValue: Double, radians: Double, distance: CGFloat) -> CGSize {
        let amount = CGFloat(TransitionCurve.distance(phaseValue)) * distance
        return CGSize(width: cos(radians) * amount, height: sin(radians) * amount)
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == PolarMoveTransition {
    /// 平移转场（默认向下 90°、`TransitionTravel.regular` 的距离）。
    static var move: PolarMoveTransition { PolarMoveTransition() }

    /// 平移转场，可指定极角与距离。
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
