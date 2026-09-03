//
//  Rise.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 从视图上方浮起并淡出的一小段文字（"+1" 那种）。
private struct RiseModifier<T: Equatable & Sendable>: ViewModifier {
    let trigger: T
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
                    .keyframeAnimator(initialValue: RiseState(), trigger: self.trigger) { view, state in
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
                    // ⚠️ **不** `accessibilityHidden`——与其它微交互不同，本效果**承载内容**
                    // （"+1" 是信息，不是装饰）。它对 VoiceOver 可读，但调用方仍应把权威数值
                    // 放在被修饰的视图上（FR-13 的分工）。
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
    ///   ——它是**组件自带的 UI 文案**（公约 A 类），必须可本地化（FR-7）。
    func rise(
        trigger: some Equatable & Sendable,
        text: LocalizedStringKey,
        strength: MicroInteractionStrength = .regular,
        color: Color = .accent
    ) -> some View {
        self.modifier(
            RiseModifier(trigger: trigger, text: text, strength: strength, textColor: color)
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
