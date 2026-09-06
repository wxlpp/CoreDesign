import CoreDesign
import SwiftUI

private struct RiseCore: ViewModifier {
    let fire: Int
    let text: LocalizedStringKey
    let strength: MicroInteractionStrength
    let textColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let reach = self.strength.displacement * 3
        let text = self.text
        let color = self.textColor

        return content
            .overlay(alignment: .top) {
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .keyframeAnimator(initialValue: RiseState(), trigger: self.fire) { view, state in
                        view
                            .offset(y: isReduced ? -reach * 0.5 : state.lift)
                            .opacity(state.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.lift) {
                            LinearKeyframe(0, duration: 0.02)
                            CubicKeyframe(-reach, duration: 0.85)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: 0.1)
                            LinearKeyframe(1, duration: 0.35)
                            LinearKeyframe(0, duration: 0.42)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    private struct RiseState {
        var lift: CGFloat = 0
        var opacity: Double = 0
    }
}

public extension View {
    /// `trigger` 变化时，从视图上方浮起一段文字。
    ///
    /// - Parameter text: 浮起的文字。⚠️ 类型是 `LocalizedStringKey` 而非 `String`
    ///   ——它是**调用方传入的界面文案**（公约第 4 节 **B 类**），必须可本地化（FR-7）。
    func rise(
        trigger: some Equatable,
        text: LocalizedStringKey,
        strength: MicroInteractionStrength = .regular,
        color: Color = .accent
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) {
                RiseCore(fire: $0, text: text, strength: strength, textColor: color)
            }
        )
    }
}

#Preview("rise") {
    @Previewable @State var score = 0
    VStack(spacing: 60) {
        Text("\(score)")
            .font(.largeTitle.bold().monospacedDigit())
            .rise(trigger: score, text: "+1")
        Button("加分") { score += 1 }
    }
    .padding(60)
}
