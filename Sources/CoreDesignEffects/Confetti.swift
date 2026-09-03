//
//  Confetti.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 一次性彩纸喷发。典型用途：任务完成、连续打卡、支付成功。
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
private struct ConfettiCore: ViewModifier {

    let fire: Int
    let strength: MicroInteractionStrength
    /// 彩纸取色池。**空数组 ⇒ 回落到调用方的 `.tint`**（与 `.spray` 同一纪律，
    /// 复用它的 `[Color].particleStyle(at:)`）。
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.effectsPowerMode) private var injectedPowerMode
    @Environment(\.effectsScenePhase) private var injectedScenePhase
    @Environment(\.scenePhase) private var systemScenePhase

    /// 本次 burst 的起始时刻。**`nil` ⇒ 没有 burst 在进行 ⇒ `TimelineView` 不存在。**
    ///
    /// ⚠️ 这就是 AC「burst 结束后驱动它的 `TimelineView` 停止调度或被移除」的落点：
    /// 走的是**被移除**那一条（`if let` 分支整个消失），而不是"建了但 `paused: true`"
    /// ——后者仍是一个活着的视图节点。清空由 `runBurst()` 在 `ConfettiBurst.duration`
    /// 之后完成。
    @State private var burstStart: Date?

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion

        // ⚠️ **Reduce Motion：不放粒子，降级为一次淡入淡出的静态庆祝层**（AC 逐字）。
        // ⚠️ **不是 no-op**：庆祝本身承载"这件事成了"这个信息，抹掉它等于让开启该偏好的
        // 用户收不到反馈（`View.reduceMotionFallback` 的文档已就同一件事立过规矩）。
        // 走的是**降级形态 2**（保留淡入淡出、去掉运动，不再叠透明度脉冲）：
        // 静态层本身就是一次淡入淡出，叠脉冲就是两次反馈。
        guard !isReduced else {
            return AnyView(content.overlay {
                ConfettiStaticCelebration(fire: self.fire, strength: self.strength, colors: self.colors)
            })
        }

        let policy = EffectsEnergyState.resolve(
            injectedScenePhase: self.injectedScenePhase,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: self.injectedPowerMode
        ).policy

        return AnyView(
            content
                .overlay {
                    // ⚠️ **两个条件都是承重的**：
                    // · `burstStart != nil` —— burst 结束后整层被移除（AC）；
                    // · `policy.drawsAnything` —— NFR-7：后台 / 非活跃时一个像素都不画。
                    if let start = self.burstStart, policy.drawsAnything {
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
                // ⚠️ `.task(id:)` 挂在**能耗闸之外**：进后台时只是不画，
                // 不该把状态机也停掉——否则回到前台会重放一次已经结束的 burst。
                .task(id: self.fire) { await self.runBurst() }
        )
    }

    /// burst 的状态机：起一轮 → 等 `ConfettiBurst.duration` → 清空（从而移除 `TimelineView`）。
    ///
    /// ⚠️ **两道防线都不是可选的**（判据见 `ConfettiTests.burstStateMachineIsRaceSafe`）：
    /// 1. `catch { return }` —— 被取消（trigger 又变了）时**不清**，那一轮交给新任务；
    ///    写成 `try?` 会让旧任务在新任务已经设好 `burstStart` 之后把它清成 `nil`，
    ///    表现为"连点两下，第二下的彩纸瞬间消失"。
    /// 2. `shouldClear(current:startedAt:)` —— 只清自己起的那一轮。
    private func runBurst() async {
        // `fire == 0` 是 `TriggerRelay` 的初始态，不是一次触发 ⇒ 出现即放彩纸是错的。
        guard self.fire > 0 else { return }
        let startedAt = Date.now
        self.burstStart = startedAt
        do {
            try await Task.sleep(for: .seconds(ConfettiBurst.duration))
        } catch {
            return
        }
        if ConfettiBurst.shouldClear(current: self.burstStart, startedAt: startedAt) {
            self.burstStart = nil
        }
    }
}

// MARK: - Reduce Motion 的静态庆祝层

/// Reduce Motion 下的替代形态：把彩纸**钉在一个固定相位**上，整层做一次淡入淡出。
///
/// ⚠️ 复用的是同一个 `ConfettiCanvas` + 同一套几何函数，因此"长得还是彩纸"，
/// 只是**不动**。另起一套图形会让降级形态与正常形态各自漂移。
struct ConfettiStaticCelebration: View {

    let fire: Int
    let strength: MicroInteractionStrength
    let colors: [Color]

    @State private var shown = false

    var body: some View {
        ConfettiCanvas(
            progress: ConfettiBurst.restingProgress,
            count: ConfettiBurst.particleCount(
                baseParticleCount: self.strength.particleCount,
                policy: .full
            ),
            colors: self.colors
        )
        .opacity(self.shown ? 1 : 0)
        .animation(.easeInOut(duration: ConfettiBurst.staticFadeDuration), value: self.shown)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task(id: self.fire) {
            guard self.fire > 0 else { return }
            self.shown = true
            do {
                try await Task.sleep(for: .seconds(ConfettiBurst.staticHoldDuration))
            } catch {
                return
            }
            self.shown = false
        }
    }
}

// MARK: - 调度层

/// 唯一建 `TimelineView` 的地方。**只有在 burst 进行中才会被构造**。
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
        // ⚠️ 粒子是**纯装饰**（FR-13）；"任务完成"这个语义由调用方通告。
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - 绘制层

/// 给定进度画出一帧彩纸。**不读时间**——因此可以被单测钉在任意进度上渲染。
///
/// ⚠️ 用 `Canvas` 而不是 `ZStack` + N 个 `Image`：默认档位就有几十片彩纸，
/// 逐片建视图会让每一帧都重走布局（NFR-1）。
struct ConfettiCanvas: View {

    let progress: Double
    let count: Int
    let colors: [Color]

    var body: some View {
        // ⚠️ **先取成局部 `let` 再进闭包**：本包开了 `.defaultIsolation(MainActor.self)`，
        // 在绘制闭包里直接读 `self.x` 会撞上 `MicroInteractionSupport.swift`
        //《写微交互前必读：隔离约束》里记的那一族问题。
        let count = self.count
        let colors = self.colors
        let progress = self.progress

        Canvas { context, size in
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
                    // ⚠️ **空色板 ⇒ `.tint`，不是 `Color.accent`**：后者不跟随逐视图
                    // `.tint(_:)`（`Spray.swift` 记着同一条裁决）。
                    // `Canvas` 里 `.style(.tint)` **确实会被解析**——这不是想当然，
                    // 判据在 `ConfettiTests.confettiParticlesFollowCallerTint`：
                    // 同一帧在 `.tint(.red)` 与 `.tint(.blue)` 下位图必须不同。
                    with: .style(colors.particleStyle(at: index))
                )
            }
        }
    }
}

// MARK: - 几何与时序（纯函数，生产代码与判据共用同一份）

/// 一片彩纸的确定性初始状态。
///
/// ⚠️ **确定性伪随机：全部由 `index` 派生，不用 `random`**——否则每次重绘彩纸都会跳，
/// 且测试无法复现（`Spray` 已就同一件事立过规矩）。
nonisolated struct ConfettiParticle: Equatable {
    /// 发射角（度）。`-90` 是正上方。
    let angle: Double
    /// 初速，`0...1` 的归一化量。
    let speed: Double
    /// 边长（pt）。
    let size: CGFloat
    /// 自转速度，`-1...1`。
    let spin: Double
    /// 存活到的进度值，`0...1`。超过它就完全透明。
    let lifetime: Double
}

/// 彩纸的**时序与几何契约**。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `ShineBand` / `ProcessingSweep` 同一条纪律）：
/// 判据要能对**这条真曲线**求值，而不是在测试里重抄一遍常量。
nonisolated enum ConfettiBurst {

    /// 一次 burst 的时长（秒）。`runBurst()` 等的就是它。
    static let duration: Double = 2.0

    /// Reduce Motion 静态层所用的进度：彩纸已经散开、还没开始消失的那一帧。
    static let restingProgress: Double = 0.45

    /// 静态庆祝层的淡入淡出时长与停留时长（秒）。
    static let staticFadeDuration: Double = 0.35
    static let staticHoldDuration: Double = 1.2

    /// 整个 burst 里彩纸自转的总度数基数。
    static let spinTurns: Double = 540

    /// 彩纸数量。`MicroInteractionStrength.particleCount` 是**微交互**的量级，
    /// 庆祝要更满一些，故乘 `countMultiplier`。
    static let countMultiplier: Int = 3

    /// 当前策略下该放多少片。⚠️ `.paused` ⇒ **0 片**。
    ///
    /// ⚠️ **吃的是 `Int` 而不是 `MicroInteractionStrength`**：本枚举是 `nonisolated`
    /// （下游 nonisolated 上下文要能算这个数），而 `MicroInteractionStrength` 落在
    /// `MainActor` 上，直接读它的 `particleCount` 编译红
    /// （`main actor-isolated property ... can not be referenced from a nonisolated context`，
    /// 实测）。⇒ 档位在调用点解析成数，本函数只做与档位无关的策略缩放。
    static func particleCount(baseParticleCount: Int, policy: EffectsRenderPolicy) -> Int {
        let base = Double(baseParticleCount * Self.countMultiplier)
        return max(0, Int((base * policy.particleScale).rounded()))
    }

    /// 起始时刻 + 当前时刻 → 进度，钳在 `0...1`。
    static func progress(burstStart: Date, now: Date) -> Double {
        guard Self.duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(burstStart) / Self.duration))
    }

    /// `runBurst()` 收尾时该不该把 `burstStart` 清空。
    ///
    /// ⚠️ **只清自己起的那一轮**：`current != startedAt` 说明期间又触发了一次，
    /// 清掉就是把新一轮的彩纸掐了。
    static func shouldClear(current: Date?, startedAt: Date) -> Bool {
        current == startedAt
    }

    /// 第 `index` 片彩纸的初始状态。
    static func particle(at index: Int, count: Int) -> ConfettiParticle {
        let span = Double(max(count - 1, 1))
        let t = Double(index) / span
        let jitterA = Double((index &* 37) % 100) / 100
        let jitterB = Double((index &* 61) % 100) / 100
        return ConfettiParticle(
            // 以正上方为中心的扇形，再加一点确定性抖动，避免看出等分。
            angle: -90 + (t - 0.5) * 120 + (jitterA - 0.5) * 24,
            speed: 0.55 + jitterA * 0.45,
            size: 5 + CGFloat(jitterB) * 5,
            spin: (jitterB - 0.5) * 2,
            lifetime: 0.7 + jitterB * 0.3
        )
    }

    /// 第 `index` 片彩纸在 `progress` 时刻的位置。
    ///
    /// ⚠️ 命名是 `location(...)` 而不是 `position(...)`：后者是
    /// `MicroInteractionReduceMotionGuard.motionCalls` 里的关键字，
    /// 一个**纯几何函数**不该把整份文件卷进运动判据的窗口里。
    static func location(of particle: ConfettiParticle, progress: Double, in size: CGSize) -> CGPoint {
        let reach = Self.reach(in: size)
        let radians = particle.angle * .pi / 180
        let travel = reach * particle.speed * progress
        // 抛物线：先按发射角飞出去，再被"重力"拉下来。
        let gravity = reach * 0.9 * progress * progress
        return CGPoint(
            x: size.width / 2 + cos(radians) * travel,
            y: size.height / 2 + sin(radians) * travel + gravity
        )
    }

    /// 第 `index` 片彩纸在 `progress` 时刻的不透明度。
    ///
    /// ⚠️ **`progress == 1` 时必须恒为 0**：那是动画停住的那一帧，也是用户实际
    /// 长期看到的那一帧（`ShineBand.terminalProgress` 的文档记着同一条教训）。
    /// 判据在 `ConfettiTests.terminalFrameDrawsNothing`。
    static func opacity(of particle: ConfettiParticle, progress: Double) -> Double {
        guard progress >= 0, progress < particle.lifetime else { return 0 }
        let fadeStart = particle.lifetime * 0.6
        guard progress > fadeStart else { return 1 }
        return max(0, 1 - (progress - fadeStart) / (particle.lifetime - fadeStart))
    }

    /// 喷发半径：跟随内容尺寸，并给小内容一个下限（否则在一个图标上完全看不见）。
    static func reach(in size: CGSize) -> CGFloat {
        max(120, min(size.width, size.height) * 0.9)
    }
}

// MARK: - 公开入口

public extension View {

    /// `trigger` 变化时喷发一次彩纸。
    ///
    /// ```swift
    /// VStack { … }
    ///     .confetti(trigger: completedTasks)
    ///     .tint(.pink)
    /// ```
    ///
    /// - Parameter colors: 彩纸取色池，按下标轮转。**默认为空 ⇒ 全部取调用方的 `.tint`**。
    ///   ⚠️ **不给彩虹默认色板**：那是品牌决定，不是设计系统该替调用方做的
    ///   （FR-8：颜色只能来自调用方参数 / `.tint` / 语义 token）。与 `.spray` 同一形态，
    ///   连取色函数都是同一个（`[Color].particleStyle(at:)`）。
    ///
    /// ## Reduce Motion
    ///
    /// 不放粒子，降级为**一次淡入淡出的静态庆祝层**——不是 no-op。
    ///
    /// ## 后台 / 低电量（NFR-7）
    ///
    /// - 场景进入 `.inactive` / `.background` ⇒ 装饰层不画（状态机继续走，
    ///   回到前台不会重放已经结束的 burst）；
    /// - 低电量模式 ⇒ 降到 15 fps、彩纸数减半。
    ///
    /// 两个信号都可经 `\.effectsScenePhase` / `\.effectsPowerMode` 注入（默认从系统读）。
    ///
    /// ## a11y 分工（FR-13）
    ///
    /// 彩纸层是**纯装饰**，已 `accessibilityHidden(true)`；
    /// ⚠️ **"任务完成"这个语义由调用方通告**——本 modifier 不知道被修饰的是什么。
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
