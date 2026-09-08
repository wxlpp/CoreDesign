import OhMyDesign
import SwiftUI

private struct SprayCore: ViewModifier {
    let fire: Int
    let symbol: String
    let strength: MicroInteractionStrength
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let count = self.strength.particleCount
        let reach = self.strength.displacement * 6
        let symbol = self.symbol
        let colors = self.colors

        guard !isReduced else {
            return AnyView(content.reduceMotionFallback(active: true, trigger: self.fire))
        }

        return AnyView(content
            .overlay {
                ZStack {
                    ForEach(0..<count, id: \.self) { index in
                        let t = Double(index) / Double(max(count - 1, 1))
                        let angle = -90.0 + (t - 0.5) * 70.0
                        let spread = 0.55 + (Double((index * 37) % 100) / 100.0) * 0.45

                        Image(systemName: symbol)
                            .font(.system(size: CoreControlMetrics.iconSize(for: .mini)))
                            .foregroundStyle(colors.particleStyle(at: index))
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

extension [Color] {
    func particleColor(at index: Int) -> Color? {
        self.isEmpty ? nil : self[index % self.count]
    }

    func particleStyle(at index: Int) -> AnyShapeStyle {
        guard let color = self.particleColor(at: index) else { return AnyShapeStyle(TintShapeStyle()) }
        return AnyShapeStyle(color)
    }
}

public extension View {
    /// `trigger` 变化时向上喷出一束符号粒子。
    ///
    /// - Parameter colors: 粒子取色池，按下标轮转。**默认为空 ⇒ 全部取调用方的 `.tint`**。
    ///   ⚠️ 不给彩虹默认色板：那是品牌决定，不是设计系统该替调用方做的
    ///   （FR-8：颜色只能来自调用方参数 / `.tint` / 语义 token）。
    func spray(
        trigger: some Equatable,
        symbol: String,
        strength: MicroInteractionStrength = .regular,
        colors: [Color] = []
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) {
                SprayCore(fire: $0, symbol: symbol, strength: strength, colors: colors)
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
