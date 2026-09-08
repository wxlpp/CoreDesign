import OhMyDesign
import SwiftUI

// MARK: - 转场本体

/// 视图弹进来：从很小放大、**越过原尺寸**再回落坐定；离开时反过来。
public struct BoingTransition: Transition {
    /// 弹多狠。
    public let strength: MicroInteractionStrength

    public init(strength: MicroInteractionStrength = .regular) {
        self.strength = strength
    }

    /// 系统那道 Reduce Motion 闸：**必须是 `true`**。理由与判据见 `FlipTransition.properties`。
    public nonisolated static var properties: TransitionProperties { .init(hasMotion: true) }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            BoingChrome(
                phaseValue: TransitionCurve.value(of: phase),
                amplitude: Boing.amplitude(for: self.strength)
            )
        )
    }
}

// MARK: - 层 2：读 Reduce Motion

struct BoingChrome: ViewModifier {
    let phaseValue: Double
    let amplitude: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            BoingMotion(
                phaseValue: self.phaseValue,
                amplitude: self.amplitude,
                isReduced: self.reduceMotion
            )
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

struct BoingMotion: ViewModifier, Animatable {
    var phaseValue: Double
    let amplitude: Double
    let isReduced: Bool

    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(self.isReduced ? 1 : Boing.scale(at: self.phaseValue, amplitude: self.amplitude))
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum Boing {
    static let cycles: Double = 1.25

    static func amplitude(for strength: MicroInteractionStrength) -> Double {
        switch strength {
        case .subtle: 0.35
        case .regular: 0.6
        case .pronounced: 0.85
        }
    }

    static func scale(at phaseValue: Double, amplitude: Double) -> CGFloat {
        CGFloat(1 - TransitionCurve.elastic(phaseValue, amplitude: amplitude, cycles: Self.cycles))
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == BoingTransition {
    /// 弹性缩放转场。
    static var boing: BoingTransition { BoingTransition() }

    /// 弹性缩放转场，可指定强度。
    static func boing(strength: MicroInteractionStrength) -> BoingTransition {
        BoingTransition(strength: strength)
    }
}

#Preview("boing") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("BOING")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .surface(.content)
                    .transition(.boing(strength: .pronounced))
            }
        }
        .frame(height: 140)

        Button("切换") { withAnimation(.easeInOut(duration: 0.7)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
