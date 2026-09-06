import CoreDesign
import SwiftUI

private struct PingCore: ViewModifier {
    let fire: Int
    let strength: MicroInteractionStrength
    let ringColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let color = self.ringColor
        let rings = self.strength == .subtle ? 1 : (self.strength == .regular ? 2 : 3)

        guard !isReduced else {
            return AnyView(content.reduceMotionFallback(active: true, trigger: self.fire))
        }

        return AnyView(content
            .background {
                ZStack {
                    ForEach(0..<rings, id: \.self) { index in
                        Circle()
                            .strokeBorder(color, lineWidth: CoreBorderWidth.thin)
                            .keyframeAnimator(
                                initialValue: RingState(),
                                trigger: self.fire
                            ) { view, state in
                                view
                                    .scaleEffect(state.scale)
                                    .opacity(state.opacity)
                            } keyframes: { _ in
                                let delay = Double(index) * 0.16
                                KeyframeTrack(\.scale) {
                                    LinearKeyframe(1.0, duration: delay)
                                    CubicKeyframe(2.2, duration: 0.7)
                                }
                                KeyframeTrack(\.opacity) {
                                    LinearKeyframe(0, duration: delay)
                                    LinearKeyframe(0.75, duration: 0.05)
                                    CubicKeyframe(0, duration: 0.65)
                                }
                            }
                    }
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            })
    }

    private struct RingState {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }
}

public extension View {
    /// `trigger` 变化时，从视图背后扩散一组圆环。
    ///
    /// - Parameter color: 环的颜色。默认 `Color.accent`（第 3 层语义 token）。
    ///   ⚠️ 与 shader 不同，这里**可以**走 `.tint`（`strokeBorder(.tint)`）——
    ///   但那样调用方就无法单独调环色而不影响内容色，故仍取参数、默认语义 token。
    func ping(
        trigger: some Equatable,
        strength: MicroInteractionStrength = .regular,
        color: Color = .accent
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) {
                PingCore(fire: $0, strength: strength, ringColor: color)
            }
        )
    }
}

#Preview("ping") {
    @Previewable @State var n = 0
    VStack(spacing: 48) {
        Image(systemName: "bell.fill")
            .font(.system(size: 32))
            .foregroundStyle(.tint)
            .ping(trigger: n, strength: .pronounced)
        Button("触发") { n += 1 }
    }
    .padding(60)
}
