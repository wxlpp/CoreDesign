import OhMyDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时像一张卡片那样翻过去：带透视的 3D 旋转 + 淡入淡出。
public struct FlipTransition: Transition {
    /// 绕哪个轴翻。命名按"内容看起来往哪个方向转"，见 `TransitionAxis3D`。
    public let axis: TransitionAxis3D

    /// 两端的翻转角（度）。90° = 恰好侧对镜头。
    public nonisolated static let quarterTurn: Double = 90

    public init(axis: TransitionAxis3D = .horizontal) {
        self.axis = axis
    }

    /// 系统那道 Reduce Motion 闸的开关。**必须是 `true`。**
    public nonisolated static var properties: TransitionProperties { .init(hasMotion: true) }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(FlipChrome(phaseValue: TransitionCurve.value(of: phase), axis: self.axis))
    }
}

// MARK: - 层 2：读 Reduce Motion

struct FlipChrome: ViewModifier {
    let phaseValue: Double
    let axis: TransitionAxis3D

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            FlipMotion(phaseValue: self.phaseValue, axis: self.axis, isReduced: self.reduceMotion)
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

struct FlipMotion: ViewModifier, Animatable {
    var phaseValue: Double
    let axis: TransitionAxis3D
    let isReduced: Bool

    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(self.isReduced ? 0 : Flip.angle(at: self.phaseValue)),
                axis: self.axis.vector,
                perspective: Flip.perspective
            )
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum Flip {
    static let perspective: CGFloat = 0.55

    static func angle(at phaseValue: Double) -> Double {
        let clamped = max(-1, min(1, phaseValue))
        return clamped * FlipTransition.quarterTurn
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == FlipTransition {
    /// 卡片翻面转场（水平翻）。
    static var flip: FlipTransition { FlipTransition() }

    /// 卡片翻面转场，可指定翻转轴。
    static func flip(axis: TransitionAxis3D) -> FlipTransition {
        FlipTransition(axis: axis)
    }
}

#Preview("flip") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("FLIP")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .surface(.content)
                    .transition(.flip)
            }
        }
        .frame(height: 140)

        Button("切换") { withAnimation(.easeInOut(duration: 0.6)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
