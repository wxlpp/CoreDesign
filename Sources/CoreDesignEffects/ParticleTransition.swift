import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时，内容轻微缩放淡出，同时一圈粒子向外飞散（进入时反向汇聚）。
public struct ParticleTransition: Transition {
    /// 一次转场放多少颗粒子。
    public let count: Int

    /// 粒子取色池，按下标轮转。**空 ⇒ 全部取调用方的 `.tint`**。
    public let colors: [Color]

    /// 默认粒子数。
    public nonisolated static let defaultCount: Int = 18

    /// ## ⚠️⚠️ `hasMotion` 取 `true`，这是一次**有代价**的定案，代价照录
    public nonisolated static let properties: TransitionProperties = TransitionProperties(hasMotion: true)

    public init(count: Int = ParticleTransition.defaultCount, colors: [Color] = []) {
        self.count = count
        self.colors = colors
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            ParticleTransitionChrome(phase: phase, count: self.count, colors: self.colors)
        )
    }
}

struct ParticleTransitionChrome: ViewModifier {
    let phase: TransitionPhase
    let count: Int
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let phase = self.phase

        guard !isReduced else {
            return AnyView(content.opacity(ParticleBurst.contentOpacity(phase: phase)))
        }

        let progress = ParticleBurst.progress(phase: phase)
        let drawsParticles = self.count > 0
        let count = self.count
        let colors = self.colors

        return AnyView(content
            .scaleEffect(ParticleBurst.contentScale(phase: phase))
            .opacity(ParticleBurst.contentOpacity(phase: phase))
            .overlay {
                if drawsParticles {
                    ParticleBurstLayer(progress: progress, count: count, colors: colors)
                }
            })
    }
}

// MARK: - 绘制层

struct ParticleBurstLayer: View, Animatable {
    var progress: Double
    let count: Int
    let colors: [Color]

    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }

    var body: some View {
        let count = self.count
        let colors = self.colors
        let progress = self.progress

        Canvas { context, size in
            for index in 0..<max(0, count) {
                let particle = ParticleBurst.particle(at: index, count: count)
                let alpha = ParticleBurst.opacity(of: particle, progress: progress)
                guard alpha > 0 else { continue }
                let point = ParticleBurst.location(of: particle, progress: progress, in: size)

                var layer = context
                layer.opacity = alpha
                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - particle.radius,
                        y: point.y - particle.radius,
                        width: particle.radius * 2,
                        height: particle.radius * 2
                    )),
                    with: .style(colors.particleStyle(at: index))
                )
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - 几何与相位（纯函数，生产代码与判据共用同一份）

nonisolated struct ParticleBurstDot: Equatable {
    let angle: Double
    let spread: Double
    let radius: CGFloat
    let lifetime: Double
}

nonisolated enum ParticleBurst {
    static let scaleDelta: CGFloat = 0.12

    static let reachRatio: CGFloat = 0.75
    static let minimumReach: CGFloat = 60

    static func progress(phase: TransitionPhase) -> Double {
        abs(phase.value)
    }

    static func contentOpacity(phase: TransitionPhase) -> Double {
        max(0, 1 - Self.progress(phase: phase))
    }

    static func contentScale(phase: TransitionPhase) -> CGFloat {
        1 + CGFloat(phase.value) * Self.scaleDelta
    }

    static func particle(at index: Int, count: Int) -> ParticleBurstDot {
        let span = Double(max(count - 1, 1))
        let t = Double(index) / span
        let jitterA = Double((index &* 41) % 100) / 100
        let jitterB = Double((index &* 67) % 100) / 100
        return ParticleBurstDot(
            angle: t * 360 + (jitterA - 0.5) * 28,
            spread: 0.5 + jitterA * 0.5,
            radius: 1.5 + CGFloat(jitterB) * 2.5,
            lifetime: 0.75 + jitterB * 0.25
        )
    }

    static func location(of particle: ParticleBurstDot, progress: Double, in size: CGSize) -> CGPoint {
        let reach = Self.reach(in: size)
        let radians = particle.angle * .pi / 180
        let travel = reach * particle.spread * progress
        return CGPoint(
            x: size.width / 2 + cos(radians) * travel,
            y: size.height / 2 + sin(radians) * travel
        )
    }

    static func opacity(of particle: ParticleBurstDot, progress: Double) -> Double {
        guard progress > 0, progress < particle.lifetime else { return 0 }
        let fadeStart = particle.lifetime * 0.35
        guard progress > fadeStart else { return progress / max(fadeStart, 0.0001) }
        return max(0, 1 - (progress - fadeStart) / (particle.lifetime - fadeStart))
    }

    static func reach(in size: CGSize) -> CGFloat {
        max(Self.minimumReach, min(size.width, size.height) * Self.reachRatio)
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == ParticleTransition {
    /// 粒子消散 / 汇聚转场。
    static var particle: ParticleTransition { ParticleTransition() }

    /// 粒子消散 / 汇聚转场，可指定粒子数与取色池。
    ///
    /// - Parameter colors: 取色池，按下标轮转。**默认为空 ⇒ 全部取调用方的 `.tint`**。
    ///   ⚠️ 不给彩虹默认色板：那是品牌决定，不是设计系统该替调用方做的（FR-8）。
    static func particle(count: Int = ParticleTransition.defaultCount, colors: [Color] = []) -> ParticleTransition {
        ParticleTransition(count: count, colors: colors)
    }
}

#Preview("ParticleTransition") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("PRO")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, CoreSpacing.xxl)
                    .padding(.vertical, CoreSpacing.md)
                    .background(Color.accent, in: Capsule())
                    .foregroundStyle(Color.contentOnAccent)
                    .transition(.particle)
            }
        }
        .frame(height: 120)

        Button("切换") { withAnimation(.easeInOut(duration: 0.6)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
