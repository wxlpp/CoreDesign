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
private struct SpinModifier<T: Equatable & Sendable>: ViewModifier {
    let trigger: T
    let clockwise: SpinDirection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // ⚠️ 先取成局部值——下面的动画闭包是 `@Sendable`，读不到 MainActor 隔离的属性。
        let isReduced = self.reduceMotion
        let direction = self.clockwise

        return content
            .keyframeAnimator(initialValue: 0.0, trigger: self.trigger) { view, turns in
                view.rotationEffect(.degrees(isReduced ? 0 : turns))
            } keyframes: { _ in
                KeyframeTrack {
                    // 单个 cubic 关键帧 + 缓入缓出：起步与收尾都不突兀。
                    CubicKeyframe(360 * direction.sign, duration: 0.55)
                    CubicKeyframe(0, duration: 0)   // 归零，供下次触发
                }
            }
            .reduceMotionFallback(active: isReduced, trigger: self.trigger)
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
        trigger: some Equatable & Sendable,
        direction: SpinDirection = .clockwise
    ) -> some View {
        self.modifier(SpinModifier(trigger: trigger, clockwise: direction))
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
