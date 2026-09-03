//
//  Confetti.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 一次性彩纸喷发。典型用途：任务完成、连续打卡、支付成功。
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
///
/// ⚠️ **`internal` 而不是 `private`**：本类型是 `.confetti(trigger:)` 的**真实渲染路径**，
/// 而那条路径此前**零机器覆盖**（#252 PR #269 第 1 轮终审 I-3：终审同时施加
/// 「`ConfettiLayer` 的 `progress:` 写死成 `1`」与「`colors:` 改成 `colors: []`」
/// 两枚变异，42/42 仍然全绿——所有位图判据吃的都是更里面的 `ConfettiCanvas`，
/// 接线只由三条 `code.contains(...)` 字符串检查守着）。
/// ⇒ 提为 `internal`，让 `@testable` 的判据能直接渲染它，见 `initialBurstStart`。
struct ConfettiCore: ViewModifier {

    let fire: Int
    let strength: MicroInteractionStrength
    /// 彩纸取色池。**空数组 ⇒ 回落到调用方的 `.tint`**（与 `.spray` 同一纪律，
    /// 复用它的 `[Color].particleStyle(at:)`）。
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    /// 本次 burst 的起始时刻。**`nil` ⇒ 没有 burst 在进行 ⇒ `TimelineView` 不存在。**
    ///
    /// ⚠️ 这就是 AC「burst 结束后驱动它的 `TimelineView` 停止调度或被移除」的落点：
    /// 走的是**被移除**那一条（`if let` 分支整个消失），而不是"建了但 `paused: true`"
    /// ——后者仍是一个活着的视图节点。清空由 `runBurst()` 在 `ConfettiBurst.duration`
    /// 之后完成。
    @State private var burstStart: Date?

    /// **判据用的渲染缝**：`burstStart` 的初值。
    ///
    /// ⚠️ **生产路径永远不传它**（`.confetti(trigger:)` 不暴露这个参数，默认 `nil`）。
    /// 它存在的唯一理由与 `\.scenePhaseOverride` / `\.lowPowerModeOverride` 两个可注入键
    /// **完全同源**：判据无法从外部把 `burstStart` 推到"burst 进行中"
    /// ⇒ `body` 里那段真正的接线（`progress` / `colors` / `count` / `minimumInterval`）
    /// 一个像素都渲不出来，只能靠字符串检查守——而终审已实证那守不住
    /// （见类型文档 I-3）。给一个初值，整条渲染路径就变成可断言的。
    ///
    /// ⚠️ **不能靠 `.task` 自己把 `burstStart` 设好**，两个平台各有各的坑：
    /// macOS 的 `ImageRenderer` 下 `.task` **不跑**（`burstStart` 恒为 `nil`）；
    /// 而 iOS Simulator 下它**会被调度**——实测 `fire > 0` 时同一个视图连渲 8 次
    /// 得到 8 张互不相同的位图（差 4–22 字节），`fire: 0`（`runBurst()` 见它即早退）
    /// 时稳定为 0 字节差。⇒ 判据用 `fire: 0` + 本参数把状态钉死，两端都确定性可比。
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
        // ⚠️⚠️ **能耗闸必须在 Reduce Motion 闸之前，这里不再各写一遍**
        // （#252 PR #269 第 1 轮终审 I-1 / I-2）。
        //
        // 上一版把 `guard !isReduced` 写在 `resolve(...)` **之前** ⇒ Reduce Motion
        // 开启时 `policy` 根本不被求值 ⇒ 两个能耗键对 Confetti **完全无效**：
        // `.inactive`（App 切换器 / 通知中心 / 来电覆盖）下系统仍在合成这一层，
        // 开启「减弱动态效果」的用户恰好在 NFR-7 规定该停摆的状态下拿到
        // 静态庆祝层 + 1.55 s 透明度动画（当时 `staticHoldDuration = 1.2` +
        // `staticFadeDuration = 0.35`——⚠️ 前者已随第 2 轮终审 C-1 一并删除，
        // 这个数**在当前树里无法由任何常量重建**，故在此括注留档）；
        // 且静态层里 `policy` 写死 `.full`，
        // 低电量下粒子数也不减。
        //
        // ⇒ 顺序现在由 `EffectsEnergyState.presentation(reduceMotion:)` 固定，
        // 与 `ProcessingSweepDriver` 共用同一份。
        let state = EffectsEnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: EffectsPowerMode.lifted(from: self.lowPowerModeOverride)
        )
        let policy = state.policy
        let presentation = state.presentation(reduceMotion: self.reduceMotion)

        // ⚠️⚠️⚠️ **单出口：`content` 与 `.task(id:)` 恒在，两道闸只决定 overlay 里画什么。**
        //
        // （#252 PR #269 第 2 轮终审 C-1。**这条是本文件最容易被改坏的地方**。）
        //
        // 上一版把 Reduce Motion 分支写成 `guard !isReduced else { return AnyView(…) }`
        // ⇒ `body` 有**两个** `AnyView` 出口，而 `isReduced` 由 `presentation` 派生、
        // `presentation` 又依赖 `scenePhase`。对开启「减弱动态效果」的用户：
        //
        // | scenePhase | presentation | 走哪个出口 |
        // |---|---|---|
        // | `.active` | `.resting` | 出口 A（静态层，**没有 `.task`**） |
        // | `.inactive` / `.background` | `.none` | 出口 B（`.task` + 空 overlay） |
        //
        // ⇒ 每次后台往返，`content` 被包进**底层类型不同**的两个 `AnyView`，两条后果：
        // 1. **庆祝重放**：静态层只存在于出口 A ⇒ 回前台是**新插入**的实例，
        //    它自带的 `@State shown` 复位、`.task(id: fire)` 重跑，而 `TriggerRelay.fire`
        //    只增不减、触发过一次就永远 `> 0` ⇒ 此后每次切回 App 都放一次彩纸；
        // 2. **调用方内容子树被销毁重建**：`.confetti` 包的是**任意调用方内容**，
        //    换身份等于把整棵被修饰子树里的 `@State` / 动画 / `.task` 全部重置。
        //
        // ⇒ 现在只有**一个**出口、**一种** `body` 形状：`content` 恰好出现一次、
        // `.task(id:)` 恰好挂一次、全文件不再需要 `AnyView`。分支只发生在 `overlay`
        // 闭包**内部**（与 `ScanningOverlay` / `GlowSweep` / `LightSweep` 同形态：
        // 它们的 `AnyView` 分支也只活在 `content.overlay { … }` 里面）。
        //
        // ⚠️ 判据：`ConfettiTests.confettiKeepsOneShapeAcrossScenePhase`
        //（`content` × 1、`.task(` × 1、`AnyView` × 0、`return` × 1 —— 四条一起才堵得住，
        // 逐条的理由写在那条判据的文档里）。
        return content
            .overlay {
                switch presentation {
                case .none:
                    // NFR-7 停摆：一个像素都不画。
                    EmptyView()
                case .resting:
                    // ⚠️ **Reduce Motion：不放粒子，降级为一次淡入淡出的静态庆祝层**（AC 逐字）。
                    // ⚠️ **不是 no-op**：庆祝本身承载"这件事成了"这个信息，抹掉它等于让开启该
                    // 偏好的用户收不到反馈（`View.reduceMotionFallback` 已就同一件事立过规矩）。
                    // 走**降级形态 2**（保留淡入淡出、去掉运动，不再叠透明度脉冲）。
                    //
                    // ⚠️⚠️ **触发源是 `burstStart`，不是静态层自己的 `.task(id: fire)`**
                    //（C-1 的另一半）：`burstStart` 由**恒在**的 `.task(id: self.fire)` 驱动，
                    // 因此这一层被后台往返移除再插回也不会重放——它是 `burstStart` 的纯函数。
                    // ⚠️ `policy` 传进去而不是写死 `.full`：低电量下粒子数同样要减半。
                    ConfettiStaticCelebration(
                        active: self.burstStart != nil,
                        strength: self.strength,
                        colors: self.colors,
                        policy: policy
                    )
                case .animated:
                    // burst 结束后 `burstStart` 被清空 ⇒ 整个 `TimelineView` 分支消失（AC）。
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
            // ⚠️ `.task(id:)` 挂在**两道闸之外**：进后台时只是不画，
            // 不该把状态机也停掉——否则回到前台会重放一次已经结束的 burst。
            // ⚠️ 这句话此前**只在非 Reduce Motion 路径上成立**（RM 路径根本没有这个
            // `.task`，见上面那张表）；单出口之后它才在两条路径上都成立。
            .task(id: self.fire) { await self.runBurst() }
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
///
/// ⚠️⚠️ **本类型没有自己的状态机，是 `active` 的纯函数**（#252 PR #269 第 2 轮终审 C-1）。
///
/// 上一版它自带 `@State shown` + `.task(id: fire)`，而它**只存在于 `ConfettiCore` 的
/// Reduce Motion 分支里**——那个分支会随 `scenePhase` 出现/消失 ⇒ 每次后台往返本类型
/// 都是**新插入**的实例 ⇒ `shown` 复位、`.task(id: fire)` 重跑，而 `fire` 触发过一次
/// 就永远 `> 0`（`TriggerRelay.fire` 只增不减）⇒ 开启「减弱动态效果」的用户此后每次
/// 切回 App 都会看到一次彩纸。
///
/// ⇒ 触发源改由 `ConfettiCore` 的 `burstStart` 状态机供给（`active: burstStart != nil`），
/// 那个状态机挂在**恒在**的 `.task(id: self.fire)` 上、不随 `scenePhase` 重建。
/// 本类型被移除再插回是无害的：它画什么完全由传进来的 `active` 决定。
///
/// ⚠️ 这也顺带把"静态庆祝持续多久"与 burst 本身统一成一个常量
/// （`ConfettiBurst.duration`，两端各 `staticFadeDuration` 的淡入淡出），
/// 不再有一份只服务本类型的 `staticHoldDuration`。
struct ConfettiStaticCelebration: View {

    /// 是否处于"正在庆祝"。**由 `ConfettiCore.burstStart` 供给，本类型不自己计时。**
    let active: Bool

    let strength: MicroInteractionStrength
    let colors: [Color]

    /// ⚠️ **由调用方传入，不在这里写死 `.full`**（#252 PR #269 第 1 轮终审 I-1）：
    /// 写死 `.full` 时"低电量 ⇒ 粒子数减半"这条在 Reduce Motion 路径上完全失效。
    /// 本层永远不会在 `.paused` 下被构造（那道闸在 `ConfettiCore` 里先行裁决），
    /// 但 `.reduced` 会传进来。
    let policy: EffectsRenderPolicy

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

    /// 静态庆祝层的淡入淡出时长（秒）。
    ///
    /// ⚠️ **停留时长不在这里**：静态层的可见时长与 burst 本身共用 `duration`
    /// （它由 `ConfettiStaticCelebration.active` ← `ConfettiCore.burstStart` 驱动）。
    /// 上一版另有一个 `staticHoldDuration`，那是因为静态层当时自带 `.task(id: fire)`
    /// 计时——而那正是 Reduce Motion 路径下"后台往返即重放"的成因
    /// （#252 PR #269 第 2 轮终审 C-1）。
    ///
    /// ⚠️⚠️ **删掉 `staticHoldDuration` 的副产品：静态庆祝变长了 52%，且尚未被裁决**
    /// （#252 PR #269 第 4 轮终审 S2-4，终审复核过口径）。逐字记账：
    ///
    /// | | 旧（自带计时器） | 新（共用 `duration`） |
    /// |---|---|---|
    /// | 常量 | `staticHoldDuration = 1.2` + `staticFadeDuration = 0.35` | `duration = 2.0` + `staticFadeDuration = 0.35` |
    /// | **完全消失于** | **1.55 s** | **2.35 s**（+52%） |
    ///
    /// ⚠️ **口径**：淡入的 0.35 s 与"停留"是**重叠**的（`.opacity` 从 0 动到 1 的同时
    /// 停留计时已经在走），⇒ 可见总时长 = `duration + staticFadeDuration`，
    /// 淡出那一段在 `active` 转 `false` 之后才开始。
    /// ⚠️ **`duration = 2.0` 不是"可见时长"**：它是 `active` 停留的终点，
    /// 用它直接与旧的 1.55 s 相比会得到 +29%——那个数是错的。
    ///
    /// ⇒ **这是一个用户可见的产品取值，本 PR 未就它做过设计裁决**，只是删掉独立常量
    /// 之后落到的结果。已上报待裁决：要么接受 2.35 s，要么给静态层单独一条时长
    /// （⚠️ 若走后者，**不得**把计时器还给静态层——C-1 的成因正是那个计时器；
    /// 只能由 `ConfettiCore` 的状态机按呈现档位取不同的 sleep 时长）。
    static let staticFadeDuration: Double = 0.35

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
    /// 两个信号都可经 `\.scenePhaseOverride` / `\.lowPowerModeOverride` 注入（默认从系统读）。
    ///
    /// ⚠️ **能耗闸在 Reduce Motion 闸之前**：上面这两条对开启了「减弱动态效果」的用户
    /// **同样成立**（静态庆祝层在 `.inactive` / `.background` 下同样整层不建，
    /// 在低电量下同样减半粒子数）。裁决在
    /// `EffectsEnergyState.presentation(reduceMotion:)`，与三个"处理中"效果共用同一份。
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
