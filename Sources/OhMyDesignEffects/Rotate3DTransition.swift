import OhMyDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时绕任意轴翻滚，同时向纵深退一点。
public struct Rotate3DTransition: Transition {
    /// 两端的旋转角。
    public let angle: Angle

    /// 绕哪个轴转。
    public let axis: TransitionAxis3D

    /// 默认旋转角（度）。
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

    static let depthScale: CGFloat = 0.82

    static func angle(at phaseValue: Double, degrees: Double) -> Double {
        max(-1, min(1, phaseValue)) * degrees
    }

    static func scale(at phaseValue: Double) -> CGFloat {
        1 - (1 - Self.depthScale) * CGFloat(TransitionCurve.distance(phaseValue))
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == Rotate3DTransition {
    /// 空间翻滚转场（默认 75°、斜向轴）。
    static var rotate3D: Rotate3DTransition { Rotate3DTransition() }

    /// 空间翻滚转场，可指定角度与轴。
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
