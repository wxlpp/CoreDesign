//
//  Spray.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 向上喷出一束 SF Symbol 粒子。典型用途：点赞、收藏、庆祝。
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
private struct SprayCore: ViewModifier {
    let fire: Int
    let symbol: String
    let strength: MicroInteractionStrength
    let palette: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let count = self.strength.particleCount
        let reach = self.strength.displacement * 6
        let symbol = self.symbol
        let palette = self.palette.isEmpty ? [Color.accent] : self.palette

        // ⚠️ **Reduce Motion 下整层不渲染，降级为脉冲**（#262 终审 C2）。
        // 初版只把位移归零——结果 12–22 个粒子**全堆在内容中心**并继续缩放淡出，
        // 一坨符号盖住内容，**比原动效更糟**。缩放同样属于 FR-11 的"缩放"。
        guard !isReduced else {
            return AnyView(content.reduceMotionFallback(active: true, trigger: self.fire))
        }

        return AnyView(content
            .overlay {
                // ⚠️ 粒子是**纯装饰**（FR-13）；"点赞成功"这个语义由调用方通告。
                ZStack {
                    ForEach(0..<count, id: \.self) { index in
                        // ⚠️ 确定性伪随机：用 index 派生角度与距离，**不用 `random`**——
                        // 否则每次重绘粒子都会跳，且测试无法复现。
                        let t = Double(index) / Double(max(count - 1, 1))
                        let angle = -90.0 + (t - 0.5) * 70.0        // 以正上方为中心的锥形
                        let spread = 0.55 + (Double((index * 37) % 100) / 100.0) * 0.45

                        Image(systemName: symbol)
                            .font(.system(size: CoreControlMetrics.iconSize(for: .mini)))
                            .foregroundStyle(palette[index % palette.count])
                            .keyframeAnimator(
                                initialValue: ParticleState(),
                                trigger: self.fire
                            ) { view, state in
                                view
                                    .offset(
                                        x: cos(angle * .pi / 180) * reach * spread * state.travel,
                                        y: sin(angle * .pi / 180) * reach * spread * state.travel
                                    )
                                    .scaleEffect(state.scale)
                                    .opacity(state.opacity)
                            } keyframes: { _ in
                                KeyframeTrack(\.travel) {
                                    CubicKeyframe(1.0, duration: 0.75)
                                }
                                KeyframeTrack(\.scale) {
                                    SpringKeyframe(1.0, duration: 0.2, spring: .bouncy)
                                    LinearKeyframe(0.5, duration: 0.55)
                                }
                                KeyframeTrack(\.opacity) {
                                    LinearKeyframe(1, duration: 0.1)
                                    LinearKeyframe(0, duration: 0.65)
                                }
                            }
                    }
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            })
    }

    private struct ParticleState {
        var travel: CGFloat = 0
        var scale: CGFloat = 0
        var opacity: Double = 0
    }
}

public extension View {

    /// `trigger` 变化时向上喷出一束符号粒子。
    ///
    /// ```swift
    /// Button { likes += 1 } label: { Image(systemName: "heart.fill") }
    ///     .spray(trigger: likes, symbol: "heart.fill")
    /// ```
    ///
    /// - Parameter palette: 粒子取色。**默认只有 `Color.accent` 一色**——
    ///   ⚠️ 不给彩虹默认色板：那是品牌决定，不是设计系统该替调用方做的
    ///   （FR-8：颜色只能来自调用方参数 / `.tint` / 语义 token）。
    func spray(
        trigger: some Equatable,
        symbol: String,
        strength: MicroInteractionStrength = .regular,
        palette: [Color] = [.accent]
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) {
                SprayCore(fire: $0, symbol: symbol, strength: strength, palette: palette)
            }
        )
    }
}

#Preview("spray") {
    @Previewable @State var likes = 0
    VStack(spacing: 60) {
        Button {
            likes += 1
        } label: {
            Image(systemName: "heart.fill").font(.system(size: 32))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .spray(trigger: likes, symbol: "heart.fill", strength: .pronounced)

        Text("likes: \(likes)").font(.caption.monospaced())
    }
    .padding(60)
}
