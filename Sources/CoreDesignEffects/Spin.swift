//
//  Spin.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 整圈旋转一次。典型用途：刷新、重试、切换。
///
/// ⚠️ 与 `CoreDesign` 的 `SpinningModifier` 不是一回事：那个是**持续**的加载遮罩
/// （material + 居中 `ProgressIndicator`），本效果是 `trigger` 驱动的**一次性**旋转。
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
private struct SpinCore: ViewModifier {
    let fire: Int
    let clockwise: SpinDirection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // ⚠️ 先取成局部值——下面的动画闭包是 `@Sendable`，读不到 MainActor 隔离的属性。
        let isReduced = self.reduceMotion
        let direction = self.clockwise

        return content
            .keyframeAnimator(initialValue: 0.0, trigger: self.fire) { view, turns in
                // ⚠️⚠️ **取模不是多余的**（第 5 轮终审 C5-1，实测）：
                // `keyframeAnimator` 动画结束后**停在最后一个 keyframe 值，不回
                // `initialValue`**（评审用活体 `NSHostingView` 探针证明），
                // 而 `rotationEffect(.degrees(360))` **不是恒等变换**——
                // 实测 `Text("x")` 上残留 33/112 px 差异、maxΔ 24/255，
                // `Text("Refresh")` 上 35 px ⇒ 任何 `Text(...).spin()` 在**第一次转完
                // 之后**字形边缘永久带上约 9% 的重采样软化，直到视图销毁重建。
                // 360° ≡ 0° 视觉无跳变，取模后终态是 `rotationEffect(0)`（实测恒等）。
                //
                // ⚠️ 这个残留是**第 3 轮的处置引入的**：当时删掉"归零帧"的理由是
                // 「每次 trigger 变化都从 `initialValue` 重新开始」——那句是真的，
                // 但**不蕴含「本次结束后回到 `initialValue`」**。前提是半真的。
                view.rotationEffect(.degrees(
                    (isReduced ? 0 : turns).truncatingRemainder(dividingBy: 360)
                ))
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(360 * direction.sign, duration: 0.55)
                }
            }
            .reduceMotionFallback(active: isReduced, trigger: self.fire)
    }
}

/// 旋转方向。⚠️ **不用 `Bool`**（J-1 禁未豁免 Bool 参数）——`clockwise: true` 在调用处
/// 读不出含义，语义枚举可以。
public enum SpinDirection: Sendable, CaseIterable {
    case clockwise, counterClockwise

    var sign: Double { self == .clockwise ? 1 : -1 }
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
