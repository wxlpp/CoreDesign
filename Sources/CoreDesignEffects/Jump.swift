import CoreDesign
import SwiftUI

private struct JumpCore: ViewModifier {
    let fire: Int
    let strength: MicroInteractionStrength

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: CaseIterable {
        case rest, squat, launch, apex, land

        var offsetY: CGFloat {
            switch self {
            case .rest, .land: 0
            case .squat: 0.18
            case .launch: -0.55
            case .apex: -1.0
            }
        }

        var squash: (x: CGFloat, y: CGFloat) {
            switch self {
            case .rest: (0, 0)
            case .squat: (0.5, -0.5)
            case .launch: (-0.35, 0.35)
            case .apex: (0, 0)
            case .land: (0.3, -0.3)
            }
        }
    }

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let strength = self.strength

        return content
            .phaseAnimator(Phase.allCases, trigger: self.fire) { view, phase in
                let d = strength.displacement
                let k = strength.scaleDelta
                view
                    .scaleEffect(
                        x: isReduced ? 1 : 1 + phase.squash.x * k,
                        y: isReduced ? 1 : 1 + phase.squash.y * k,
                        anchor: .bottom
                    )
                    .offset(y: isReduced ? 0 : phase.offsetY * d)
            } animation: { phase in
                switch phase {
                case .apex: .easeOut(duration: 0.18)
                case .land: .spring(duration: 0.28, bounce: 0.45)
                default: .easeInOut(duration: 0.12)
                }
            }
            .reduceMotionFallback(active: isReduced, trigger: self.fire)
    }
}

public extension View {
    /// `trigger` 变化时跳一次。
    func jump(
        trigger: some Equatable,
        strength: MicroInteractionStrength = .regular
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) { JumpCore(fire: $0, strength: strength) }
        )
    }
}

#Preview("jump") {
    @Previewable @State var n = 0
    VStack(spacing: 32) {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 48))
            .foregroundStyle(.tint)
            .jump(trigger: n)
        Button("触发") { n += 1 }
    }
    .padding(40)
}
