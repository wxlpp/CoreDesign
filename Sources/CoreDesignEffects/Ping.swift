//
//  Ping.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 从视图背后扩散的同心圆环。典型用途：新消息、实时状态、位置定位。
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
private struct PingCore: ViewModifier {
    let fire: Int
    let strength: MicroInteractionStrength
    let ringColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let color = self.ringColor
        let rings = self.strength == .subtle ? 1 : (self.strength == .regular ? 2 : 3)

        // ⚠️ **终审 I-1**：初版只门控了 `scaleEffect`，没门控 `.opacity`，也没调
        // `reduceMotionFallback`。后果是 RM + `.pronounced` 时三个环停在 scale 1
        //（几何完全重合）、各自在 50 ms 内阶跃变亮再衰减 ⇒ **给 Reduce Motion 用户的
        // 正是闪烁**，而被修饰的内容本身零反馈。与 Spray / Shine 对齐走早退。
        guard !isReduced else {
            return AnyView(content.reduceMotionFallback(active: true, trigger: self.fire))
        }

        return AnyView(content
            .background {
                // ⚠️ 环在**背后**，且 `accessibilityHidden` —— 纯装饰层（FR-13）。
                ZStack {
                    ForEach(0..<rings, id: \.self) { index in
                        Circle()
                            .strokeBorder(color, lineWidth: CoreBorderWidth.thin)
                            .keyframeAnimator(
                                initialValue: RingState(),
                                trigger: self.fire
                            ) { view, state in
                                view
                                    .scaleEffect(state.scale)
                                    .opacity(state.opacity)
                            } keyframes: { _ in
                                // 每一环延迟出发，形成"一圈追一圈"。
                                let delay = Double(index) * 0.16
                                KeyframeTrack(\.scale) {
                                    LinearKeyframe(1.0, duration: delay)
                                    CubicKeyframe(2.2, duration: 0.7)
                                }
                                KeyframeTrack(\.opacity) {
                                    LinearKeyframe(0, duration: delay)
                                    LinearKeyframe(0.75, duration: 0.05)
                                    CubicKeyframe(0, duration: 0.65)
                                }
                            }
                    }
                }
                .accessibilityHidden(true)
                // ⚠️ **终审 I-3**：`.background { }` 的内容在 SwiftUI 里是可命中的，
                // 且 `scaleEffect` 是几何变换、**会影响命中测试**——环放大到 2.2× 时
                // 描边区域伸出内容 frame 之外，在动画的 ~0.7 s 内可以截走本该落到
                // 相邻视图的点击。Spray / Shine / Rise 三个都成对给了这一行。
                .allowsHitTesting(false)
            })
    }

    /// ⚠️ 两条轨道（缩放 / 透明度）时序不同，必须各自成 `KeyframeTrack`
    /// ——环要先淡入再一边放大一边淡出，用单一标量表达不了。
    private struct RingState {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }
}

public extension View {

    /// `trigger` 变化时，从视图背后扩散一组圆环。
    ///
    /// - Parameter color: 环的颜色。默认 `Color.accent`（第 3 层语义 token）。
    ///   ⚠️ 与 shader 不同，这里**可以**走 `.tint`（`strokeBorder(.tint)`）——
    ///   但那样调用方就无法单独调环色而不影响内容色，故仍取参数、默认语义 token。
    func ping(
        trigger: some Equatable,
        strength: MicroInteractionStrength = .regular,
        color: Color = .accent
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) {
                PingCore(fire: $0, strength: strength, ringColor: color)
            }
        )
    }
}

#Preview("ping") {
    @Previewable @State var n = 0
    VStack(spacing: 48) {
        Image(systemName: "bell.fill")
            .font(.system(size: 32))
            .foregroundStyle(.tint)
            .ping(trigger: n, strength: .pronounced)
        Button("触发") { n += 1 }
    }
    .padding(60)
}
