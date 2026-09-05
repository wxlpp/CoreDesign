//
//  Shake.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 水平抖动，振幅逐次衰减。典型用途：输入校验失败。
/// ⚠️ **非泛型**——泛型只停在 `TriggerRelay`，理由见其文档。
private struct ShakeCore: ViewModifier {
    let fire: Int
    let strength: MicroInteractionStrength

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // ⚠️ 先取成局部值——下面的动画闭包是 `@Sendable`，读不到 MainActor 隔离的属性。
        let isReduced = self.reduceMotion
        let strength = self.strength

        return content
            .keyframeAnimator(
                initialValue: CGFloat.zero,
                trigger: self.fire
            ) { view, offset in
                view.offset(x: isReduced ? 0 : offset)
            } keyframes: { _ in
                // 衰减序列：右 → 左 → 右 → 左 → 归位，每次幅度减半。
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
    ///
    /// ```swift
    /// PinCode(...)
    ///     .shake(trigger: failedAttempts)
    /// ```
    ///
    /// ⚠️ **本效果承载状态语义**（"这次输入错了"），不是纯装饰
    /// ⇒ **a11y 通告由调用方负责**（FR-13）：抖动对 VoiceOver 用户不可见，
    /// 调用方须自行 `accessibilityValue` / `AccessibilityNotification.Announcement`。
    /// 本 modifier **不会**替你播报。
    ///
    /// ⚠️ Reduce Motion 开启时降级为一次透明度脉冲——**不是什么都不做**，
    /// 否则该偏好的用户收不到"失败了"这个反馈。
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
