import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #252：庆祝与处理中动效 + NFR-7 可注入能耗 environment
//
// ⚠️ **本文件的重心是 NFR-7**，不是"四个效果长得好不好看"。
// PRD 逐字写着「**必须可测，不接受"或文档声明"**」，而这条 AC 的难点在于
// `ProcessInfo.isLowPowerModeEnabled` 与 `\.scenePhase` **在单测里都不可切换**。
// ⇒ 实现把两个信号做成可注入的 `EnvironmentValues`，本文件注入伪值、断言**渲染行为**：
//
// · `\.effectsScenePhase = .background` ⇒ 三个常驻效果**一个像素都不画**（与裸内容逐字节相同）；
// · `\.effectsPowerMode = .lowPower` ⇒ **同一相位**下位图与满电时不同（光晕那一层被去掉）。
//
// ⚠️ **低电量那条必须钉相位**：降帧本身拍不进静态帧（`ImageRenderer` 拍的是一帧），
// 而若走 `TimelineView` 的活相位，两次渲染落在不同时刻上，位图必然不同 ⇒ 断言恒真。
// ⇒ 判据吃的是 `ProcessingSweepBody(kind:phase:)`——同一个 `phase`、只换注入值。

// MARK: - 纯函数层：能耗状态 → 渲染策略

@Suite("NFR-7 能耗状态与渲染策略")
struct EffectsEnergyStateTests {

    @Test("后台 / 非活跃 ⇒ 停摆；低电量 ⇒ 降级；其余 ⇒ 满帧")
    func policyMapping() {
        #expect(EffectsEnergyState(scenePhase: .active, powerMode: .standard).policy == .full)
        #expect(EffectsEnergyState(scenePhase: .active, powerMode: .lowPower).policy == .reduced)
        #expect(EffectsEnergyState(scenePhase: .inactive, powerMode: .standard).policy == .paused)
        #expect(EffectsEnergyState(scenePhase: .background, powerMode: .standard).policy == .paused)
        // ⚠️ 后台 + 低电量仍是 `.paused`，不是 `.reduced`——停摆比降帧更省，别把它降错方向。
        #expect(EffectsEnergyState(scenePhase: .background, powerMode: .lowPower).policy == .paused)
    }

    @Test("注入值优先，`nil` 才从系统读")
    func injectionWinsOverSystem() {
        // ① 注入的场景阶段盖过系统值。
        let injected = EffectsEnergyState.resolve(
            injectedScenePhase: .background,
            systemScenePhase: .active,
            injectedPowerMode: .standard
        )
        #expect(injected.scenePhase == .background, "注入的 scenePhase 没有盖过系统值 —— NFR-7 的判据整条落空")
        #expect(injected.policy == .paused)

        // ② 注入为 `nil` ⇒ 用系统值。
        let fallback = EffectsEnergyState.resolve(
            injectedScenePhase: nil,
            systemScenePhase: .inactive,
            injectedPowerMode: .standard
        )
        #expect(fallback.scenePhase == .inactive, "注入 nil 时没有回落到系统值")

        // ③ 能耗档位同理，且 `.standard` 与 `nil` 必须可区分
        //（前者是宿主明确说"按常规供电渲染"，不该被系统读数覆盖）。
        let explicitStandard = EffectsEnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, injectedPowerMode: .standard
        )
        #expect(explicitStandard.powerMode == .standard)
        let injectedLowPower = EffectsEnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, injectedPowerMode: .lowPower
        )
        #expect(injectedLowPower.policy == .reduced, "注入的低电量没有生效")
    }

    @Test("`nil` 能耗注入 ⇒ 真的去读 ProcessInfo（默认从系统读）")
    func defaultPowerModeReadsSystem() {
        let expected: EffectsPowerMode =
            ProcessInfo.processInfo.isLowPowerModeEnabled ? .lowPower : .standard
        #expect(EffectsPowerMode.current == expected)
        let resolved = EffectsEnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, injectedPowerMode: nil
        )
        #expect(resolved.powerMode == expected, "注入 nil 时没有从 ProcessInfo 读 —— 默认值不是系统值")
    }

    @Test("策略旋钮：停摆不画、低电量去光晕并降帧、满帧不限速")
    func policyKnobs() {
        #expect(EffectsRenderPolicy.full.drawsAnything)
        #expect(EffectsRenderPolicy.reduced.drawsAnything)
        #expect(!EffectsRenderPolicy.paused.drawsAnything)

        #expect(EffectsRenderPolicy.full.usesGlow)
        #expect(!EffectsRenderPolicy.reduced.usesGlow, "低电量还开着离屏模糊 —— 那是最贵的一层")
        #expect(!EffectsRenderPolicy.paused.usesGlow)

        #expect(EffectsRenderPolicy.full.minimumInterval == nil)
        if let interval = EffectsRenderPolicy.reduced.minimumInterval {
            #expect(interval > 0, "降帧间隔必须为正，否则 TimelineView 会当成不限速")
        } else {
            Issue.record("低电量没有降帧间隔 —— NFR-7 的『降帧』落空")
        }

        #expect(EffectsRenderPolicy.full.particleScale == 1)
        #expect(EffectsRenderPolicy.reduced.particleScale > 0)
        #expect(EffectsRenderPolicy.reduced.particleScale < 1)
        #expect(EffectsRenderPolicy.paused.particleScale == 0)
    }
}

// MARK: - 渲染层：注入伪值 ⇒ 位图断言

@Suite("NFR-7 注入伪值断言渲染行为")
@MainActor
struct EffectsEnergyRenderTests {

    /// 被包裹的示例内容。**尺寸固定**，两侧基线才可比。
    static func sampleContent() -> some View {
        RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 180, height: 120)
    }

    /// ⚠️ **suite 级暖机**：与 `ConfettiTests.canvasWarmUp` 同一理由——本仓实测过
    /// 「同一个视图渲两次、第一次是异类」的进程级首帧伪影
    /// （`MicroInteractionAPITests.processWarmUp` 记的是文本那一次，`Canvas` 另有一层）。
    /// 这里的三个容器走的是渐变 + `blur` 的离屏合成路径，同样先跑热再比。
    private static let layerWarmUp: Bool = {
        for kind in ProcessingSweepKind.allCases {
            let probe = ProcessingSweepBody(kind: kind, phase: ProcessingSweep.restingPhase)
                .frame(width: 180, height: 120)
                .background(Color.surfaceRaised)
                .environment(\.effectsScenePhase, .active)
            for _ in 0..<4 { _ = MicroInteractionAPITests.stablePixels(probe) }
        }
        return true
    }()

    static func pixels(_ view: some View) -> Data? {
        _ = Self.layerWarmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    /// 三个公开容器包同一段内容后的位图。
    static func wrapped(_ kind: ProcessingSweepKind, phase: ScenePhase) -> Data? {
        let content = Self.sampleContent()
        let view: AnyView = switch kind {
        case .scanning: AnyView(ScanningOverlay { content })
        case .glow: AnyView(GlowSweep { content })
        case .light: AnyView(LightSweep { content })
        }
        return Self.pixels(view.environment(\.effectsScenePhase, phase))
    }

    /// ⚠️⚠️ **这是本 task 的核心判据**：注入"App 进了后台"，三个常驻效果必须
    /// **一个像素都不画**——与只包了一层 `overlay { EmptyView() }` 的裸内容逐字节相同。
    ///
    /// ⚠️ 基线**刻意也套一层 `overlay`**：`MicroInteractionAPITests.eachEffectRestsClean`
    /// 的文档记着「基线与被测项的视图包装层数必须一致，否则会全体等量偏差」
    /// ——那条教训在这里同样适用。
    @Test("注入 .background / .inactive ⇒ 三个容器整层不画（与空 overlay 逐字节相同）")
    func backgroundedContainersDrawNothing() {
        let baseline = Self.pixels(Self.sampleContent().overlay { EmptyView() })
        #expect(baseline != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(baseline?.contains(where: { $0 != 0 }) == true,
                "基线位图全 0 —— 相等断言会恒真")

        for kind in ProcessingSweepKind.allCases {
            for phase in [ScenePhase.background, .inactive] {
                #expect(Self.wrapped(kind, phase: phase) == baseline,
                        "\(kind) 在 \(phase) 下仍然画了东西 —— NFR-7 的停摆没有落地")
            }
            // ⚠️ **互锁**：`.active` 必须画得出东西，否则上面那条相等断言是恒真的
            //（"什么都不画"与"这个效果压根没实现"在位图上不可分辨）。
            #expect(Self.wrapped(kind, phase: .active) != baseline,
                    "\(kind) 在 .active 下也什么都没画 —— 上面的停摆断言是恒真的")
        }
    }

    /// 低电量方向的渲染判据。**必须钉相位**——理由见文件头。
    @Test("注入 .lowPower ⇒ 同一相位下位图与满电不同（光晕那层被去掉）")
    func lowPowerChangesRenderingAtSamePhase() {
        func pixels(_ kind: ProcessingSweepKind, _ mode: EffectsPowerMode) -> Data? {
            Self.pixels(
                ProcessingSweepBody(kind: kind, phase: ProcessingSweep.restingPhase)
                    .frame(width: 180, height: 120)
                    .background(Color.surfaceRaised)
                    .environment(\.effectsScenePhase, .active)
                    .environment(\.effectsPowerMode, mode)
            )
        }
        for kind in ProcessingSweepKind.allCases {
            let full = pixels(kind, .standard)
            let low = pixels(kind, .lowPower)
            #expect(full != nil && low != nil, "\(kind) 渲染失败，下面的不等断言会静默变绿")
            #expect(full?.contains(where: { $0 != 0 }) == true, "\(kind) 位图全 0")
            #expect(full != low,
                    "\(kind) 在低电量下与满电渲染完全一致 —— 注入的 \\.effectsPowerMode 没有影响渲染")
        }
    }
}

// MARK: - 三个"处理中"容器的契约

@Suite("处理中动效的相位与委托契约")
@MainActor
struct ProcessingSweepTests {

    static func source(_ fileName: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/CoreDesignEffects/\(fileName)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("相位恒落在 [0, 1)，往复进度恒落在 [0, 1]")
    func phaseAndPingPongStayInRange() {
        for step in 0..<200 {
            let date = Date(timeIntervalSinceReferenceDate: Double(step) * 0.037 - 3)
            let phase = ProcessingSweep.phase(at: date)
            #expect(phase >= 0 && phase < 1, "相位越界：\(phase)")
            let progress = ProcessingSweep.pingPong(phase)
            #expect(progress >= 0 && progress <= 1, "往复进度越界：\(progress)")
        }
        // 静止相位落在正中间——Reduce Motion 下停在"最像这个效果"的那一帧。
        #expect(abs(ProcessingSweep.pingPong(ProcessingSweep.restingPhase) - 0.5) < 0.0001)
        // 退化输入不崩、不 NaN。
        #expect(ProcessingSweep.phase(at: .now, period: 0) == 0)
        #expect(!ProcessingSweep.ringRadius(for: .zero).isNaN)
        #expect(ProcessingSweep.ringRadius(for: .zero) == 0)
    }

    /// ⚠️ 这条钉的是「往复形态」这个设计决定本身：**任何相位都有可见像素**。
    /// 若哪天改回"扫出去再从另一头进来"，就会出现整段看不见任何东西的相位区间，
    /// 上面 `backgroundedContainersDrawNothing` 的互锁会退化成时序抽奖。
    @Test("任何相位都画得出东西（往复形态的承重前提）")
    func everyPhaseDrawsSomething() {
        let baseline = EffectsEnergyRenderTests.pixels(
            Color.surfaceRaised.frame(width: 180, height: 120)
        )
        #expect(baseline != nil)
        for kind in ProcessingSweepKind.allCases {
            for step in 0..<8 {
                let phase = CGFloat(step) / 8
                let drawn = EffectsEnergyRenderTests.pixels(
                    ProcessingSweepBody(kind: kind, phase: phase)
                        .frame(width: 180, height: 120)
                        .background(Color.surfaceRaised)
                        .environment(\.effectsScenePhase, .active)
                )
                #expect(drawn != baseline, "\(kind) 在相位 \(phase) 上什么都没画")
            }
        }
    }

    /// ⚠️⚠️ **容器形态的真正风险点**（与 `Shine` 容器被钉死的是同一个洞）：
    /// 容器若自己实现一遍动画，`MicroInteractionReduceMotionGuard` 仍然全绿
    /// ——容器文件不含运动关键字就根本不进它的射程 ⇒ Reduce Motion 与 NFR-7 的降级
    /// 只覆盖驱动层、不覆盖容器。
    @Test("三个容器必须委托给 ProcessingSweepDriver，不得自建动画或绘制")
    func containersDelegateToDriver() throws {
        let forbidden = [
            "TimelineView(", "Canvas(", "keyframeAnimator(", "phaseAnimator(",
            "AngularGradient(", "LinearGradient(", ".mask(", "accessibilityReduceMotion",
        ]
        for fileName in ["ScanningOverlay.swift", "GlowSweep.swift", "LightSweep.swift"] {
            let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source(fileName))
            #expect(code.contains("ProcessingSweepDriver("),
                    "\(fileName) 没有委托给 ProcessingSweepDriver —— RM / NFR-7 降级会绕过它")
            let offenders = forbidden.filter { code.contains($0) }
            #expect(offenders.isEmpty,
                    "\(fileName) 里出现了自建的动画/绘制实现 \(offenders) —— 会绕过驱动层的降级")
        }
    }

    /// AC 逐字列的是 `ScanningOverlay { }` / `GlowSweep { }` / `LightSweep { }`
    /// ——**容器视图形态**（大写、尾随闭包），不是 modifier。
    @Test("三个容器形态存在且可用尾随闭包构造")
    func containerFormsExist() {
        #expect(MicroInteractionAPITests.stablePixels(ScanningOverlay { Text("x") }) != nil)
        #expect(MicroInteractionAPITests.stablePixels(GlowSweep { Text("x") }) != nil)
        #expect(MicroInteractionAPITests.stablePixels(LightSweep { Text("x") }) != nil)
    }
}

// MARK: - Confetti

@Suite("Confetti 的时序、取色与终帧契约")
@MainActor
struct ConfettiTests {

    static func framed(_ view: some View) -> some View {
        view.frame(width: 200, height: 200).background(Color.surfaceRaised)
    }

    /// ⚠️⚠️ **`Canvas` 有自己的一层进程级首帧伪影，`stablePixels` 的暖机盖不住它**
    /// （本 PR 实测，形态与 `MicroInteractionAPITests.processWarmUp` 记的那次同源）。
    ///
    /// 实测：把**同一个** `ConfettiCanvas` 视图渲两次（各自都走过 `stablePixels`
    /// 的"预渲一次 + 真渲一次"），`a1 == a2` 为 **false**——第一张是异类。
    /// 后果不是理论上的：我第一版的 `.tint` 判据因此**放过了一枚真变异**
    /// （把取色改成 `Color.accentColor`、`colors` 参数整个不用，测试照样全绿），
    /// 因为"色板不同 ⇒ 位图不同"这条实际量到的是首帧伪影，不是颜色。
    ///
    /// ⇒ 本 suite 的每次取像素前先把 **`Canvas` 这条路径**跑热。
    private static let canvasWarmUp: Bool = {
        let probe = ConfettiCanvas(progress: 0.3, count: 36, colors: [])
            .frame(width: 200, height: 200)
            .background(Color.surfaceRaised)
        for _ in 0..<8 { _ = MicroInteractionAPITests.stablePixels(probe) }
        return true
    }()

    static func pixels(_ view: some View) -> Data? {
        _ = Self.canvasWarmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    static func canvas(progress: Double, colors: [Color] = []) -> some View {
        Self.framed(ConfettiCanvas(progress: progress, count: 36, colors: colors))
    }

    static var emptyBaseline: Data? {
        Self.pixels(Self.framed(Color.clear))
    }

    /// ⚠️ **终帧态**：`keyframeAnimator` / `TimelineView` 停住的那一帧是用户实际长期
    /// 看到的那一帧（`ShineBand.terminalProgress` 的文档记着同一条教训）。
    /// 彩纸在 `progress == 1` 必须**一片都不剩**——否则 burst 结束后画面上会永久挂着彩纸。
    @Test("终帧（progress = 1）一片彩纸都不画")
    func terminalFrameDrawsNothing() {
        let empty = Self.emptyBaseline
        #expect(empty != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(empty?.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 相等断言恒真")

        #expect(Self.pixels(Self.canvas(progress: 1)) == empty,
                "progress = 1 时还有彩纸 —— burst 结束后会永久残留")
        // ⚠️ **互锁**：中途必须画得出彩纸，否则上一条是恒真的。
        #expect(Self.pixels(Self.canvas(progress: 0.25)) != empty,
                "progress = 0.25 都画不出彩纸 —— 上一条相等断言是恒真的")
        // Reduce Motion 静态层用的那一帧同样必须**看得见**（降级不是 no-op）。
        #expect(Self.pixels(Self.canvas(progress: ConfettiBurst.restingProgress)) != empty,
                "Reduce Motion 静态庆祝层是空的 —— 那就是 no-op")
    }

    /// AC：「**Confetti 粒子颜色默认取自调用方 `.tint`**，不自带彩虹色板」。
    ///
    /// ⚠️ 这条**不能**只在取色函数那一层断言（`.spray` 当年只能那样，因为它的粒子
    /// 静息 opacity 为 0、渲染层测不出来）：`Canvas` 里的 `.style(.tint)` **是否真的
    /// 被解析**是一个额外的、可能悄悄不成立的前提。⇒ 直接量位图。
    @Test("默认（空色板）彩纸色跟随调用方 .tint；给了色板则不跟随")
    func confettiParticlesFollowCallerTint() {
        let red = Self.pixels(Self.canvas(progress: 0.3).tint(.red))
        let blue = Self.pixels(Self.canvas(progress: 0.3).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(red != blue,
                "空色板时彩纸色没有跟随 .tint —— Canvas 里的 .style(.tint) 没被解析")

        // ⚠️ 反向 + 互锁两条一起写，两个失效方向各堵一边（变异实证见下）：
        // · 把取色换成 `AnyShapeStyle(Color.accentColor)`（`colors` 参数整个失效）
        //   ⇒ `red != blue` 与 `explicitRedTint != red` **两条同时红**；
        // · 只把"空色板"的回落换成 `Color.accent`（保留 `colors` 语义）
        //   ⇒ `red != blue` 红。
        //
        // ⚠️⚠️ **照录一次差点放过变异的经过**：上一版没有 `canvasWarmUp`，
        // `Color.accentColor` 那枚变异**全绿通过**——当时量到的差异是 `Canvas` 的
        // 首帧伪影而不是颜色，我还据此在这里写下过一句"`Color.accentColor` 也跟随
        // `.tint(_:)`"的错误结论。装上暖机后重测：它**不跟随**，两条判据都开火。
        let explicitRedTint = Self.pixels(Self.canvas(progress: 0.3, colors: [.green]).tint(.red))
        let explicitBlueTint = Self.pixels(Self.canvas(progress: 0.3, colors: [.green]).tint(.blue))
        #expect(explicitRedTint == explicitBlueTint,
                "给了显式色板还跟着 .tint 变 —— 调用方参数没有优先，取色多半绕过了 colors")
        // 且显式色板与"回落 .tint"必须真的画出不同的东西（否则上一条可以恒真）。
        #expect(explicitRedTint != red, "显式色板与回落 .tint 画出的东西一样 —— colors 参数没进渲染")

        // 取色函数层（与 `.spray` 共用同一实现）的契约同样钉住。
        #expect([Color]().particleColor(at: 0) == nil, "空色板必须回落到 .tint，而不是取某个具体色")
        #expect([Color.red, .blue].particleColor(at: 2) == .red, "非空色板必须按下标轮转")
    }

    @Test("进度被钳在 0...1；退化输入不产生 NaN")
    func progressIsClamped() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        #expect(ConfettiBurst.progress(burstStart: start, now: start) == 0)
        #expect(ConfettiBurst.progress(burstStart: start, now: start.addingTimeInterval(-5)) == 0)
        #expect(ConfettiBurst.progress(burstStart: start, now: start.addingTimeInterval(999)) == 1)
        let mid = ConfettiBurst.progress(
            burstStart: start, now: start.addingTimeInterval(ConfettiBurst.duration / 2)
        )
        #expect(abs(mid - 0.5) < 0.0001)

        for index in 0..<64 {
            let particle = ConfettiBurst.particle(at: index, count: 64)
            let point = ConfettiBurst.location(of: particle, progress: 0.5, in: .zero)
            #expect(!point.x.isNaN && !point.y.isNaN, "零尺寸内容上算出了 NaN 坐标")
            #expect(!ConfettiBurst.opacity(of: particle, progress: 0.5).isNaN)
        }
    }

    /// ⚠️ **状态机的两道防线**——`runBurst()` 用的就是这个函数。
    /// 少一道，连点两下时旧任务会把新一轮的 `burstStart` 清成 `nil`，
    /// 表现为"第二下的彩纸瞬间消失"。
    @Test("burst 状态机只清自己起的那一轮")
    func burstStateMachineIsRaceSafe() {
        let mine = Date(timeIntervalSinceReferenceDate: 100)
        let theirs = Date(timeIntervalSinceReferenceDate: 200)
        #expect(ConfettiBurst.shouldClear(current: mine, startedAt: mine))
        #expect(!ConfettiBurst.shouldClear(current: theirs, startedAt: mine),
                "期间又触发了一次，旧任务却要清 —— 会把新一轮的彩纸掐掉")
        #expect(!ConfettiBurst.shouldClear(current: nil, startedAt: mine))
    }

    @Test("彩纸数量随策略缩放；停摆时为 0")
    func particleCountFollowsPolicy() {
        let base = MicroInteractionStrength.regular.particleCount
        let full = ConfettiBurst.particleCount(baseParticleCount: base, policy: .full)
        let reduced = ConfettiBurst.particleCount(baseParticleCount: base, policy: .reduced)
        let paused = ConfettiBurst.particleCount(baseParticleCount: base, policy: .paused)
        #expect(full > 0)
        #expect(reduced > 0)
        #expect(reduced < full, "低电量没有减少彩纸数")
        #expect(paused == 0, "停摆时还在算彩纸")
    }

    /// ⚠️ **AC「burst 结束后驱动它的 `TimelineView` 停止调度或被移除」的结构判据**。
    ///
    /// 走的是"被移除"那条：`TimelineView` 只存在于 `ConfettiLayer` 里，而
    /// `ConfettiLayer` 只在 `if let start = self.burstStart` 分支里被构造，
    /// `runBurst()` 在 `ConfettiBurst.duration` 之后把它清成 `nil`。
    ///
    /// ⚠️ **本条如实登记覆盖限度**：`ImageRenderer` 拍的是静态帧、`.task` 在单测里不跑，
    /// "两秒后那个节点真的消失了"这件事**没有**端到端的机器判据。
    /// 能钉住的是三段结构 + 一条"没有 burst 时逐字节等于裸视图"的渲染判据（见下一条）。
    @Test("TimelineView 只在 burst 进行中存在")
    func timelineOnlyExistsDuringBurst() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(
            try ProcessingSweepTests.source("Confetti.swift")
        )
        // ① 全文件只有一处 `TimelineView(`，且它在 `ConfettiLayer` 里。
        let occurrences = code.components(separatedBy: "TimelineView(").count - 1
        #expect(occurrences == 1, "Confetti.swift 里有 \(occurrences) 处 TimelineView —— 移除判据只覆盖得了一处")
        guard let layerRange = code.range(of: "struct ConfettiLayer: View {") else {
            Issue.record("找不到 ConfettiLayer 声明")
            return
        }
        #expect(code.range(of: "TimelineView(")!.lowerBound > layerRange.lowerBound,
                "TimelineView 不在 ConfettiLayer 里")
        // ② `ConfettiLayer` 只在 `burstStart` 非空时被构造。
        #expect(code.contains("if let start = self.burstStart, policy.drawsAnything {"),
                "ConfettiLayer 的构造不再受 burstStart / 能耗策略双重门控")
        // ③ 状态机等的是 `ConfettiBurst.duration`，并在其后清空。
        #expect(code.contains("try await Task.sleep(for: .seconds(ConfettiBurst.duration))"))
        #expect(code.contains("self.burstStart = nil"), "没有任何地方把 burstStart 清空 —— 层永不移除")
    }

    // ⚠️ **"没有 burst 时与裸视图逐字节相同"这条判据不在本 suite**，
    // 它由 `MicroInteractionAPITests.eachEffectRestsClean` 承担（`#252` 已把
    // `.confetti` 加进它的九件套清单，三种内容各测一遍）。
    //
    // ⚠️ 照录成因：我先在这里写了一条同义的重复判据，基线取
    // `framed(Text("x")).modifier(EmptyModifier())`、被测项取 `framed(Text("x")).confetti(...)`
    // ——**两侧的视图包装层数不同**（`.confetti` 多出 `TriggerRelay` + `ConfettiCore` + `overlay`）。
    // 它在全量跑里绿、`swift test --filter ConfettiTests` 单跑时**稳定判红**（实测两次）。
    // 那正是 `eachEffectRestsClean` 文档里逐字写着的失效形态
    //（「基线与被测项的视图包装层数必须一致，否则会全体等量偏差」「绿不绿取决于当次调度」）。
    // ⇒ 删掉重复判据，不在这里再造一个同款陷阱。

    /// AC：「Reduce Motion：Confetti 不播放粒子，降级为**一次淡入淡出的静态庆祝层**」。
    ///
    /// ⚠️ **不是 no-op**——`#250` 第 1 轮正是因为"Reduce Motion 下变成 no-op"被打回。
    @Test("Reduce Motion 分支渲染的是静态庆祝层，不是 no-op")
    func reduceMotionFallsBackToStaticCelebration() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(
            try ProcessingSweepTests.source("Confetti.swift")
        )
        guard let guardRange = code.range(of: "guard !isReduced else {"),
              let end = code.range(of: "}", range: guardRange.upperBound..<code.endIndex)
        else {
            Issue.record("找不到 Reduce Motion 早退分支")
            return
        }
        let branch = String(code[guardRange.upperBound..<end.upperBound])
        #expect(branch.contains("ConfettiStaticCelebration("),
                "Reduce Motion 分支没有渲染静态庆祝层 —— 降级成了 no-op")
        // 静态层用的那一帧真的画得出东西 —— 在 `terminalFrameDrawsNothing` 里已断言。
        #expect(ConfettiBurst.restingProgress > 0 && ConfettiBurst.restingProgress < 1,
                "静态庆祝层的相位落在了终帧或起帧上 —— 那一帧要么空要么全挤在中心")
        // 静态层不叠透明度脉冲（降级形态 2：两次反馈是错的）。
        #expect(!code.contains("reduceMotionFallback("),
                "Confetti 走的是降级形态 2，不该再叠 reduceMotionFallback 的脉冲")
    }
}
