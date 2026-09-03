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
                view.rotationEffect(.degrees(isReduced ? 0 : turns))
            } keyframes: { _ in
                // ⚠️ 不需要"归零帧"：`keyframeAnimator` 每次 trigger 变化都从
                // `initialValue` 重新开始（#262 终审 Suggestion 指出初版那帧建立在错误前提上）。
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
