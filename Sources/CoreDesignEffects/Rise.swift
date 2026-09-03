//
//  Rise.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 从视图上方浮起并淡出的一小段文字（"+1" 那种）。
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
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
                            // RM-FORM-2: 本效果的反馈**本身**就是"淡入 → 上浮 → 淡出"，
                            // 去掉上浮后仍留有完整的淡入淡出，再叠一次透明度脉冲会变成
                            // 两次反馈。⇒ 走形态 2：静止位移 + 保留原有的淡入淡出。
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
                    // ⚠️ **按装饰层处理**（#262 终审 I4）：初版留它对 VoiceOver 可读，
                    // 理由是"+1 是内容"——但同一段注释又说"权威数值应放在被修饰的视图上"，
                    // 那这段文字对 VO 就是**冗余**，且 overlay 常驻视图树（首尾 opacity 0），
                    // 会在 VO 滑动顺序里留下一个幽灵元素。
                    // ⇒ 与 `.shake` / `.jump` 对齐：隐藏，**通告由调用方负责**（FR-13）。
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
    ///   ——它是**组件自带的 UI 文案**（公约 A 类），必须可本地化（FR-7）。
    ///
    /// ⚠️ `LocalizedStringKey` 在本模块内解析走 **`Bundle.main`**——App 调用方没问题，
    /// 但来自另一个 package 的调用方，其本地化不会生效。
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
