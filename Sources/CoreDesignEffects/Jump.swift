//
//  Jump.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 下蹲 → 起跳 → 落地，带挤压拉伸。典型用途：成功、点赞、达成。
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
private struct JumpCore: ViewModifier {
    let fire: Int
    let strength: MicroInteractionStrength

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 一次跳跃的相位。⚠️ 用具名枚举而不是 `[CGFloat]`——挤压与位移**不同步**
    /// （下蹲时压扁、腾空时拉长），两条轨道各自取值才写得清楚。
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

        /// (横向缩放, 纵向缩放) 的偏移比例。
        var squash: (x: CGFloat, y: CGFloat) {
            switch self {
            case .rest: (0, 0)
            case .squat: (0.5, -0.5)     // 压扁
            case .launch: (-0.35, 0.35)  // 拉长
            case .apex: (0, 0)
            case .land: (0.3, -0.3)      // 落地再压一下
            }
        }
    }

    func body(content: Content) -> some View {
        // ⚠️ 先取成局部值——下面的动画闭包是 `@Sendable`，读不到 MainActor 隔离的属性。
        let isReduced = self.reduceMotion
        let strength = self.strength

        return content
            .phaseAnimator(Phase.allCases, trigger: self.fire) { view, phase in
                let d = strength.displacement
                let k = strength.scaleDelta
                // ⚠️ **缩放也必须被 Reduce Motion 门控**（#262 终审 C1）：FR-11 逐字写的是
                // 「含位移 / 旋转 / **缩放**的效果」——初版只门控了 `offset`，结果 RM 下
                // 用户同时收到"压扁-拉长-再压扁"的形变**和**降级用的透明度脉冲。
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
    ///
    /// ⚠️ 承载状态语义时（如"已完成"）**a11y 通告由调用方负责**（FR-13）。
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
