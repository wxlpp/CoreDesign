import CoreDesign
import SwiftUI
import Synchronization

struct ConfettiCore: ViewModifier {
    let fire: Int
    let strength: MicroInteractionStrength
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    @State private var burstStart: Date?

    @State private var consumedFire = 0

    let initialBurstStart: Date?

    init(
        fire: Int,
        strength: MicroInteractionStrength,
        colors: [Color],
        initialBurstStart: Date? = nil
    ) {
        self.fire = fire
        self.strength = strength
        self.colors = colors
        self.initialBurstStart = initialBurstStart
        self._burstStart = State(initialValue: initialBurstStart)
    }

    func body(content: Content) -> some View {
        let state = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        )
        let policy = state.policy
        let presentation = state.presentation(reduceMotion: self.reduceMotion)
        let holdPresentation = EnergyState(scenePhase: .active, isLowPower: state.isLowPower)
            .presentation(reduceMotion: self.reduceMotion)

        return content
            .overlay {
                switch presentation {
                case .hidden:
                    EmptyView()
                case .resting:
                    ConfettiStaticCelebration(
                        active: self.burstStart != nil,
                        strength: self.strength,
                        colors: self.colors,
                        policy: policy
                    )
                case .animated:
                    if let start = self.burstStart {
                        ConfettiLayer(
                            burstStart: start,
                            count: ConfettiBurst.particleCount(
                                baseParticleCount: self.strength.particleCount,
                                policy: policy
                            ),
                            colors: self.colors,
                            minimumInterval: policy.minimumInterval
                        )
                    }
                }
            }
            .task(id: self.fire) { await self.runBurst(presentation: holdPresentation) }
    }

    private func runBurst(presentation: MotionPresentation) async {
        let startedAt: Date
        if self.fire > self.consumedFire {
            self.consumedFire = self.fire
            startedAt = Date.now
            self.burstStart = startedAt
        } else if self.consumedFire > 0, let inFlight = self.burstStart {
            startedAt = inFlight
        } else {
            return
        }
        let hold = ConfettiBurst.holdDuration(presentation: presentation)
        let remaining = max(0, hold - Date.now.timeIntervalSince(startedAt))
        do {
            try await Task.sleep(for: .seconds(remaining))
        } catch {
            return
        }
        if ConfettiBurst.shouldClear(current: self.burstStart, startedAt: startedAt) {
            self.burstStart = nil
        }
    }
}

// MARK: - Reduce Motion 的静态庆祝层

struct ConfettiStaticCelebration: View {
    let active: Bool

    let strength: MicroInteractionStrength
    let colors: [Color]

    let policy: RenderPolicy

    var body: some View {
        ConfettiCanvas(
            progress: ConfettiBurst.restingProgress,
            count: ConfettiBurst.particleCount(
                baseParticleCount: self.strength.particleCount,
                policy: self.policy
            ),
            colors: self.colors
        )
        .opacity(self.active ? 1 : 0)
        .animation(.easeInOut(duration: ConfettiBurst.staticFadeDuration), value: self.active)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - 调度层

struct ConfettiLayer: View {
    let burstStart: Date
    let count: Int
    let colors: [Color]
    let minimumInterval: Double?

    var body: some View {
        TimelineView(.animation(minimumInterval: self.minimumInterval)) { context in
            ConfettiCanvas(
                progress: ConfettiBurst.progress(burstStart: self.burstStart, now: context.date),
                count: self.count,
                colors: self.colors
            )
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - 渲染存活读数（基准专用观测点）

/// `ConfettiCanvas` **真的画出了粒子**的帧数。
@_spi(CoreDesignBenchmark)
public nonisolated enum ConfettiRenderProbe {
    private static let counter = Atomic<Int>(0)
    private static let lastFilled = Atomic<Int>(0)

    /// 至今画出过粒子的帧数。基准取**窗口前后的差值**。
    public static var drawnFrames: Int { Self.counter.load(ordering: .relaxed) }

    /// 最近一次「画出了粒子」的那一帧**填了多少片**。
    public static var lastFilledParticles: Int { Self.lastFilled.load(ordering: .relaxed) }

    static func recordDrawnFrame(filled: Int) {
        Self.counter.wrappingAdd(1, ordering: .relaxed)
        Self.lastFilled.store(filled, ordering: .relaxed)
    }
}

// MARK: - 绘制层

struct ConfettiCanvas: View {
    let progress: Double
    let count: Int
    let colors: [Color]

    var body: some View {
        let count = self.count
        let colors = self.colors
        let progress = self.progress

        Canvas { context, size in
            var filled = 0
            for index in 0..<max(0, count) {
                let particle = ConfettiBurst.particle(at: index, count: count)
                let alpha = ConfettiBurst.opacity(of: particle, progress: progress)
                guard alpha > 0 else { continue }
                let point = ConfettiBurst.location(of: particle, progress: progress, in: size)

                var layer = context
                layer.opacity = alpha
                layer.translateBy(x: point.x, y: point.y)
                layer.rotate(by: .degrees(particle.spin * progress * ConfettiBurst.spinTurns))
                layer.fill(
                    Path(CGRect(
                        x: -particle.size / 2,
                        y: -particle.size / 4,
                        width: particle.size,
                        height: particle.size / 2
                    )),
                    with: .style(colors.particleStyle(at: index))
                )
                filled += 1
            }
            if filled > 0 { ConfettiRenderProbe.recordDrawnFrame(filled: filled) }
        }
    }
}

// MARK: - 几何与时序（纯函数，生产代码与判据共用同一份）

nonisolated struct ConfettiParticle: Equatable {
    let angle: Double
    let speed: Double
    let size: CGFloat
    let spin: Double
    let lifetime: Double
}

nonisolated enum ConfettiBurst {
    static let duration: Double = 2.0

    static let restingProgress: Double = 0.45

    static let staticHoldDuration: Double = 1.2

    static let staticFadeDuration: Double = 0.35

    static let spinTurns: Double = 540

    static let countMultiplier: Int = 3

    static func particleCount(baseParticleCount: Int, policy: RenderPolicy) -> Int {
        let base = Double(baseParticleCount * Self.countMultiplier)
        return max(0, Int((base * policy.particleScale).rounded()))
    }

    static func progress(burstStart: Date, now: Date) -> Double {
        guard Self.duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(burstStart) / Self.duration))
    }

    static func shouldClear(current: Date?, startedAt: Date) -> Bool {
        current == startedAt
    }

    static func holdDuration(presentation: MotionPresentation) -> Double {
        switch presentation {
        case .resting: Self.staticHoldDuration
        case .animated, .hidden: Self.duration
        }
    }

    static func particle(at index: Int, count: Int) -> ConfettiParticle {
        let span = Double(max(count - 1, 1))
        let t = Double(index) / span
        let jitterA = Double((index &* 37) % 100) / 100
        let jitterB = Double((index &* 61) % 100) / 100
        return ConfettiParticle(
            angle: -90 + (t - 0.5) * 120 + (jitterA - 0.5) * 24,
            speed: 0.55 + jitterA * 0.45,
            size: 5 + CGFloat(jitterB) * 5,
            spin: (jitterB - 0.5) * 2,
            lifetime: 0.7 + jitterB * 0.3
        )
    }

    static func location(of particle: ConfettiParticle, progress: Double, in size: CGSize) -> CGPoint {
        let reach = Self.reach(in: size)
        let radians = particle.angle * .pi / 180
        let travel = reach * particle.speed * progress
        let gravity = reach * 0.9 * progress * progress
        return CGPoint(
            x: size.width / 2 + cos(radians) * travel,
            y: size.height / 2 + sin(radians) * travel + gravity
        )
    }

    static func opacity(of particle: ConfettiParticle, progress: Double) -> Double {
        guard progress >= 0, progress < particle.lifetime else { return 0 }
        let fadeStart = particle.lifetime * 0.6
        guard progress > fadeStart else { return 1 }
        return max(0, 1 - (progress - fadeStart) / (particle.lifetime - fadeStart))
    }

    static func reach(in size: CGSize) -> CGFloat {
        max(120, min(size.width, size.height) * 0.9)
    }
}

// MARK: - 公开入口

public extension View {
    /// `trigger` 变化时喷发一次彩纸。
    ///
    /// - Parameter colors: 彩纸取色池，按下标轮转。**默认为空 ⇒ 全部取调用方的 `.tint`**。
    ///   ⚠️ **不给彩虹默认色板**：那是品牌决定，不是设计系统该替调用方做的
    ///   （FR-8：颜色只能来自调用方参数 / `.tint` / 语义 token）。与 `.spray` 同一形态，
    ///   连取色函数都是同一个（`[Color].particleStyle(at:)`）。
    func confetti(
        trigger: some Equatable,
        strength: MicroInteractionStrength = .regular,
        colors: [Color] = []
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) {
                ConfettiCore(fire: $0, strength: strength, colors: colors)
            }
        )
    }
}

#Preview("confetti") {
    @Previewable @State var completed = 0
    VStack(spacing: 40) {
        Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(.tint)
        Button("完成一项") { completed += 1 }
        Text("completed: \(completed)").font(.caption.monospaced())
    }
    .padding(60)
    .confetti(trigger: completed, strength: .pronounced)
}
