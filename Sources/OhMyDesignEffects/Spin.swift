import OhMyDesign
import SwiftUI

private struct SpinCore: ViewModifier {
    let fire: Int
    let clockwise: SpinDirection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let direction = self.clockwise

        return content
            .keyframeAnimator(
                initialValue: SpinTurn.initialTurns,
                trigger: self.fire
            ) { view, turns in
                view.rotationEffect(.degrees(SpinTurn.angle(turns: turns, isReduced: isReduced)))
            } keyframes: { _ in
                SpinTurn.track(direction: direction)
            }
            .reduceMotionFallback(active: isReduced, trigger: self.fire)
    }
}

enum SpinTurn {
    nonisolated static let initialTurns: Double = 0

    nonisolated static func track(direction: SpinDirection) -> some Keyframes<Double> {
        KeyframeTrack {
            CubicKeyframe(360 * direction.sign, duration: 0.55)
        }
    }

    nonisolated static func angle(turns: Double, isReduced: Bool) -> Double {
        (isReduced ? 0 : turns).truncatingRemainder(dividingBy: 360)
    }
}

/// 旋转方向。
public nonisolated enum SpinDirection: Sendable, CaseIterable {
    case clockwise, counterClockwise

    nonisolated var sign: Double {
        switch self {
        case .clockwise: 1
        case .counterClockwise: -1
        }
    }
}

public extension View {
    /// `trigger` 变化时旋转一整圈。
    func spin(
        trigger: some Equatable,
        direction: SpinDirection = .clockwise
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) { SpinCore(fire: $0, clockwise: direction) }
        )
    }
}

#Preview("spin") {
    @Previewable @State var n = 0
    VStack(spacing: 32) {
        HStack(spacing: 40) {
            ForEach(Array(SpinDirection.allCases.enumerated()), id: \.offset) { _, d in
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                    .spin(trigger: n, direction: d)
            }
        }
        Button("触发") { n += 1 }
    }
    .padding(40)
}
