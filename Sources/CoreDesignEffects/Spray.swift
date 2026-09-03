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
    /// 粒子取色池。**空数组 ⇒ 回落到调用方的 `.tint`**（见 `particleColor(at:)`）。
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let count = self.strength.particleCount
        let reach = self.strength.displacement * 6
        let symbol = self.symbol
        let colors = self.colors

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

                        // ⚠️ **空色板 ⇒ `.tint`，不是 `Color.accent`**（#262 第 1 轮 review）：
                        // `Color.accent` 就是 `Color.accentColor`，**不跟随逐视图 `.tint(_:)`**
                        //（CLAUDE.md FR-12 段的原话）⇒ 调用方 `.tint(.pink)` 对默认粒子色静默失效。
                        // 初版把这条记成「SwiftUI 无公开 API 把 `.tint` 解析成 `Color`」的妥协
                        // ——**那个前提是错的**：粒子要的是 `ShapeStyle`，不是 `Color`，
                        // `.foregroundStyle(.tint)` 本来就成立，不需要"解析成具体色值"。
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

    /// 取第 `index` 个粒子的颜色；**空色板返回 `nil`**，表示"没有显式色，用 `.tint`"。
    ///
    /// - 色板**非空** ⇒ 按下标轮转取其中一色（调用方参数，FR-8 的第 1 种合法来源）；
    /// - 色板**为空** ⇒ `nil` ⇒ 由 `particleStyle(at:)` 回落到 `.tint`
    ///   （FR-8 的第 2 种合法来源），而**不是** `Color.accent`——后者不跟随逐视图 `.tint(_:)`。
    ///
    /// ⚠️ 抽成 `internal` 函数而不是写在 `body` 里，是为了让「空 ⇒ tint、非空 ⇒ 轮转」
    /// 这条规则**可被单测直接断言**：`.tint` 在静息位图上不可观测
    /// （粒子静息 opacity 为 0），渲染层测不出它。
    /// ⚠️ 返回 `Color?` 而不是 `AnyShapeStyle`：后者**不是 `Equatable`**，单测断言不了它。
    func particleColor(at index: Int) -> Color? {
        self.isEmpty ? nil : self[index % self.count]
    }

    /// 见 `particleColor(at:)`。空色板回落到 `.tint`。
    func particleStyle(at index: Int) -> AnyShapeStyle {
        guard let color = self.particleColor(at: index) else { return AnyShapeStyle(TintShapeStyle()) }
        return AnyShapeStyle(color)
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
    /// - Parameter colors: 粒子取色池，按下标轮转。**默认为空 ⇒ 全部取调用方的 `.tint`**。
    ///   ⚠️ 不给彩虹默认色板：那是品牌决定，不是设计系统该替调用方做的
    ///   （FR-8：颜色只能来自调用方参数 / `.tint` / 语义 token）。
    ///
    ///   ⚠️ **参数名是 `colors:` 而不是 `palette:`**——#250 的 AC 逐字写的是
    ///   `.spray(trigger:symbol:colors:)`。初版以「`colors:` 与 SwiftUI 渐变的
    ///   `colors:` 撞名但语义不同」为由改了名，那不足以抵消**与自己的规格不一致**
    ///   （#262 第 1 轮 review）。
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
