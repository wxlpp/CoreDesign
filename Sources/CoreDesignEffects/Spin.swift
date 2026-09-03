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
            // ⚠️ 初值 / 轨道 / 取角三者都取自 `SpinTurn`，**不在此处写字面量**
            //（#262 第 4 轮 review S-1）：终帧判据要能对**这条真轨道**求值，
            // 见 `SpinTurn` 的文档。
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

/// Spin 的**角度契约**——从 `SpinCore.body` 里抽出来的纯数据部分。
///
/// ⚠️ **抽出来的唯一理由是可测性**（#262 第 4 轮 review S-1）。
///
/// 上一版的终帧判据写的是
/// `#expect((360.0 * sign).truncatingRemainder(dividingBy: 360) == 0)`
/// ——那是一条**纯算术恒等式**，一行生产代码都没读到：把下面 `angle` 里的
/// `truncatingRemainder` 删掉（就是 C5-1 修掉的那枚缺陷本身），它照样全绿。
///
/// ⇒ 轨道与取角函数抽成 internal：测试用 `KeyframeTimeline` 对**这条真轨道**
/// 求 `value(time: duration)` 拿到终帧转角，再喂给**这个真函数**，
/// 最后把结果角度施加到视图上与裸视图比位图。
///
/// ⚠️ **不要把字面量写回 `SpinCore`**——那会让终帧判据重新变成"测试自说自话"。
enum SpinTurn {

    /// 静息（动画尚未开始）时的转角。
    nonisolated static let initialTurns: Double = 0

    /// 一次整圈旋转的 keyframe 轨道。
    nonisolated static func track(direction: SpinDirection) -> some Keyframes<Double> {
        KeyframeTrack {
            CubicKeyframe(360 * direction.sign, duration: 0.55)
        }
    }

    /// 轨道取值 → 实际施加到视图上的角度。
    ///
    /// ⚠️⚠️ **取模不是多余的**（第 5 轮终审 C5-1，实测）：
    /// `keyframeAnimator` 动画结束后**停在最后一个 keyframe 值，不回
    /// `initialValue`**（评审用活体 `NSHostingView` 探针证明），
    /// 而 `rotationEffect(.degrees(360))` **不是恒等变换**——
    /// 实测 `Text("x")` 上残留 33/112 px 差异、maxΔ 24/255，
    /// `Text("Refresh")` 上 35 px ⇒ 任何 `Text(...).spin()` 在**第一次转完
    /// 之后**字形边缘永久带上约 9% 的重采样软化，直到视图销毁重建。
    /// 360° ≡ 0° 视觉无跳变，取模后终态是 `rotationEffect(0)`（实测恒等）。
    ///
    /// ⚠️ 这个残留是**第 3 轮的处置引入的**：当时删掉"归零帧"的理由是
    /// 「每次 trigger 变化都从 `initialValue` 重新开始」——那句是真的，
    /// 但**不蕴含「本次结束后回到 `initialValue`」**。前提是半真的。
    nonisolated static func angle(turns: Double, isReduced: Bool) -> Double {
        (isReduced ? 0 : turns).truncatingRemainder(dividingBy: 360)
    }
}

/// 旋转方向。⚠️ **不用 `Bool`**（J-1 禁未豁免 Bool 参数）——`clockwise: true` 在调用处
/// 读不出含义，语义枚举可以。
public enum SpinDirection: Sendable, CaseIterable {
    case clockwise, counterClockwise

    // ⚠️ `nonisolated`：`SpinTurn.track(direction:)` 是 nonisolated 的
    //（keyframe 闭包读不到 MainActor 隔离的成员，见 `MicroInteractionSupport` 的隔离约束），
    // 它要读这个值。枚举本身 `Sendable`、该属性是纯计算，脱离 MainActor 没有风险。
    // ⚠️ 用 `switch` 而不是 `self == .clockwise`：本包 `defaultIsolation(MainActor)`
    // 下隐式合成的 `Equatable` conformance 也是 MainActor 隔离的，
    // 在 nonisolated 上下文里用它会报 `#IsolatedConformances`。
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
