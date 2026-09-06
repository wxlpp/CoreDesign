import CoreDesign
import SwiftUI

private struct ShakeCore: ViewModifier {
    let fire: Int
    let strength: MicroInteractionStrength

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let strength = self.strength

        return content
            .keyframeAnimator(
                initialValue: CGFloat.zero,
                trigger: self.fire
            ) { view, offset in
                view.offset(x: isReduced ? 0 : offset)
            } keyframes: { _ in
                let a = strength.displacement
                KeyframeTrack {
                    CubicKeyframe(a, duration: 0.06)
                    CubicKeyframe(-a * 0.75, duration: 0.08)
                    CubicKeyframe(a * 0.45, duration: 0.08)
                    CubicKeyframe(-a * 0.22, duration: 0.08)
                    CubicKeyframe(0, duration: 0.06)
                }
            }
            .reduceMotionFallback(active: isReduced, trigger: self.fire)
    }
}

public extension View {
    /// `trigger` 的值每次变化时，横向抖动一次。
    func shake(
        trigger: some Equatable,
        strength: MicroInteractionStrength = .regular
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) { ShakeCore(fire: $0, strength: strength) }
        )
    }
}

#Preview("shake") {
    @Previewable @State var attempts = 0
    VStack(spacing: 24) {
        ForEach(Array(MicroInteractionStrength.allCases.enumerated()), id: \.offset) { _, s in
            Text(String(describing: s))
                .padding()
                .surface(.content)
                .shake(trigger: attempts, strength: s)
        }
        Button("触发") { attempts += 1 }
    }
    .padding()
}
