import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #253：文本与展示动效（TypewriterText / AnimatedMeshGradient / BeforeAfterSlider / ParticleTransition）
//
// ⚠️ **本文件的四组判据各有一条"承重"断言**，其余是它的非退化前置（互锁）：
//
// | 组件 | 承重判据 | 形态 |
// |---|---|---|
// | `TypewriterText` | Reduce Motion ⇒ 直接显示完整文本 | 纯函数 + 源码（调用点只喂给它） |
// | `AnimatedMeshGradient` | 空色板 ⇒ 取调用方 `.tint`；后台 ⇒ 一个像素都不画 | 位图 |
// | `BeforeAfterSlider` | Reduce Motion ⇒ 不做入场摆动、拖拽照常；把手命中区 ≥ 44pt | 纯函数 + 源码 + 位图 |
// | `ParticleTransition` | Reduce Motion ⇒ 只留淡入淡出（**不是 no-op**）；恒等相位不画粒子 | 纯函数 + 位图 |
//
// ⚠️ **`\.accessibilityReduceMotion` 不可注入**（`EnvironmentValues` 上它是只读的系统偏好，
// 写它编译红——`EffectsPresentation` 的文档已实测过这条）。⇒ 凡 Reduce Motion 方向的判据
// 只能落在**纯函数**（"给定这个布尔值，这个函数返回什么"）与**源码**（"调用点是否真的
// 只用这个结论"）两条链上，位图路结构上不可达。本文件两条都写，缺一条就只剩函数体、
// 调用点可以自己再判一遍（#252 PR #269 第 2 轮终审 I-A 逐字记着这个失效形态）。
//
// ⚠️ **触控目标判据不放进 `CoreDesignTests.TouchTargetTests`**（`253.md` 逐字）：
// 那会让 `CoreDesignTests` 的依赖图包含 `CoreDesignEffects`，判红
// `shipswift-foundation` #245 立的 NFR-5② 隔离判据
// （`swift package describe` 里 `CoreDesignTests` 的依赖必须恰为 `["CoreDesign"]`）。
// ⇒ 在本 target 内**同形态**实现：`#if os(iOS)` + `ImageRenderer` 量渲染高度。

// MARK: - TypewriterText

@Suite("TypewriterText 的揭示契约")
@MainActor
struct TypewriterTextTests {

    static func source(_ fileName: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CoreDesignEffects/\(fileName)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// ⚠️⚠️ **承重判据**：AC「Reduce Motion ⇒ 直接显示完整文本」。
    @Test("Reduce Motion ⇒ 揭示数直接跳到全文，与已打了多少字无关")
    func reduceMotionRevealsEverything() {
        for typed in [0, 1, 4, 99] {
            #expect(TypewriterReveal.plan(total: 12, typed: typed, reduceMotion: true).revealed == 12,
                    "Reduce Motion 下 typed=\(typed) 没有直接给出全文 —— 用户会看到一段被截断的文字")
        }
        // Reduce Motion 下还必须**不起计时器**——只把画面补全、却让状态机继续逐字跑，
        // 那是白烧一条每 40ms 醒一次的任务。
        #expect(TypewriterReveal.plan(total: 12, typed: 0, reduceMotion: true).types == false)
        // ⚠️ **互锁**：非 Reduce Motion 下它必须**不是**恒等于 total，
        // 否则上面那条对「直接返回 total」的实现也恒真。
        #expect(TypewriterReveal.plan(total: 12, typed: 0, reduceMotion: false).types == true)
        #expect(TypewriterReveal.plan(total: 12, typed: 4, reduceMotion: false).revealed == 4)
        #expect(TypewriterReveal.plan(total: 12, typed: 0, reduceMotion: false).revealed == 0)
    }

    @Test("揭示数被钳在 0...total（退化输入不越界）")
    func revealedCountIsClamped() {
        #expect(TypewriterReveal.plan(total: 5, typed: -3, reduceMotion: false).revealed == 0)
        #expect(TypewriterReveal.plan(total: 5, typed: 99, reduceMotion: false).revealed == 5)
        #expect(TypewriterReveal.plan(total: 0, typed: 3, reduceMotion: false).revealed == 0)
        #expect(TypewriterReveal.plan(total: 0, typed: 3, reduceMotion: true).revealed == 0)
    }

    /// 逐**字符**（`Character`，即字素簇）而不是逐 UTF-8 字节——否则 emoji / 组合字
    /// 会被拆成半个字符。
    @Test("前缀按字素簇取，不拆 emoji 与组合字")
    func prefixIsGraphemeSafe() {
        let text = "a👨‍👩‍👧b"
        #expect(TypewriterReveal.characterCount(of: text) == 3)
        #expect(TypewriterReveal.prefix(of: text, count: 2) == "a👨‍👩‍👧")
        #expect(TypewriterReveal.prefix(of: text, count: 0) == "")
        #expect(TypewriterReveal.prefix(of: text, count: 99) == text)
        #expect(TypewriterReveal.prefix(of: text, count: -1) == "")
    }

    @Test("三档速度的每字间隔严格递减（fast < regular < slow）")
    func speedIsMonotonic() {
        #expect(TypewriterSpeed.fast.secondsPerCharacter < TypewriterSpeed.regular.secondsPerCharacter)
        #expect(TypewriterSpeed.regular.secondsPerCharacter < TypewriterSpeed.slow.secondsPerCharacter)
        #expect(TypewriterSpeed.fast.secondsPerCharacter > 0, "间隔为 0 会让打字机瞬间打完")
    }

    /// ⚠️⚠️ **承重判据的另一半：调用点**。纯函数只钉「给定 `reduceMotion` 返回什么」，
    /// **调用点是否真的用这个结论**是另一条链，而它在位图上不可观测
    /// （`\.accessibilityReduceMotion` 不可注入）。
    /// ⇒ 与 `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`
    /// 同一形态：本文件里 `reduceMotion` 的每一次出现都必须正好是喂给纯函数那一次。
    @Test("调用点：TypewriterText.swift 里 reduceMotion 只喂给 TypewriterReveal.plan")
    func reduceMotionIsOnlyConsumedByTheRevealGate() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("TypewriterText.swift"))
        #expect(code.contains("accessibilityReduceMotion"),
                "TypewriterText 没有读 Reduce Motion —— AC 的降级无从谈起")
        let reads = code.components(separatedBy: "self.reduceMotion").count - 1
        let fed = code.components(separatedBy: "reduceMotion: self.reduceMotion").count - 1
        #expect(fed >= 1, "TypewriterText 没有把 reduceMotion 喂给揭示闸 —— 多半是被换成了字面量")
        #expect(reads == fed,
                "TypewriterText.swift 里 `self.reduceMotion` 出现 \(reads) 次、只有 \(fed) 次喂给闸 —— 多出来的是调用点自己又判了一遍")
        // ⚠️ **闸函数自己的函数体要先挖掉再查**：`plan(total:typed:reduceMotion:)`
        // 就住在同一份文件里，它体内那句 `guard !reduceMotion` 是**闸本身**，不是调用点
        //（能耗闸那几个文件的闸函数在 `EffectsEnergy.swift`，所以它们不会撞上这条）。
        // 挖掉之后剩下的每一处裸 `reduceMotion` 才是真正的逃逸位。
        let callSites = ConfettiTests.removingRegion(after: "static func plan(", in: code)
        #expect(callSites != code, "没能挖掉闸函数的函数体 —— 下面的断言会把闸本身报成违规")
        let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: callSites)
        #expect(strays.isEmpty, "裸写的 reduceMotion（去掉 `self.` 就能绕过上面的字面计数）：\n\(strays.joined(separator: "\n"))")
    }

    /// 揭示是**真的**接到渲染上的：不同揭示数必须画出不同的东西。
    @Test("揭示数真的接到渲染：0 字与全文的位图不同，且布局尺寸不变")
    func revealedCountReachesRendering() {
        let full = "Hello typewriter"
        func body(_ revealed: Int) -> Data? {
            MicroInteractionAPITests.stablePixels(
                TypewriterBody(text: full, revealed: revealed)
                    .frame(width: 220, height: 40)
                    .background(Color.surfaceRaised)
            )
        }
        let none = body(0)
        let all = body(TypewriterReveal.characterCount(of: full))
        #expect(none != nil && all != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(none != all, "0 字与全文渲染完全相同 —— revealed 根本没接到 Text 上")
        #expect(none?.count == all?.count,
                "两者位图字节数不同 —— 说明揭示过程会改变布局尺寸（打字时行宽会跳）")
    }

    @Test("公开入口：LocalizedStringResource 与 verbatim 两条都在，且可渲染")
    func publicInitsExist() {
        #expect(MicroInteractionAPITests.stablePixels(TypewriterText("Hello").frame(width: 200, height: 30)) != nil)
        #expect(MicroInteractionAPITests.stablePixels(
            TypewriterText(verbatim: "run-time content", speed: .fast).frame(width: 200, height: 30)
        ) != nil)
    }
}

// MARK: - AnimatedMeshGradient

@Suite("AnimatedMeshGradient 的取色、能耗与冻结契约")
@MainActor
struct AnimatedMeshGradientTests {

    static func source(_ fileName: String) throws -> String {
        try TypewriterTextTests.source(fileName)
    }

    /// ⚠️ **`MeshGradient` 有自己的一层进程级首帧伪影**（与 `ConfettiTests.canvasWarmUp`
    /// 同源：本仓实测过「同一个视图渲两次、第一次是异类」）。先把这条渲染路径跑热。
    private static let meshWarmUp: Bool = {
        let probe = AnimatedMeshBody(phase: MeshDrift.restingPhase, colors: [], alternateColors: [])
            .frame(width: 160, height: 120)
            .background(Color.surfaceRaised)
            .environment(\.scenePhaseOverride, .active)
        for _ in 0..<8 { _ = MicroInteractionAPITests.stablePixels(probe) }
        return true
    }()

    static func pixels(_ view: some View) -> Data? {
        _ = Self.meshWarmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    static func body(
        phase: CGFloat = MeshDrift.restingPhase,
        colors: [Color] = [],
        alternateColors: [Color] = [],
        lowPower: Bool? = nil
    ) -> some View {
        AnimatedMeshBody(phase: phase, colors: colors, alternateColors: alternateColors)
            .frame(width: 160, height: 120)
            .background(Color.surfaceRaised)
            .environment(\.scenePhaseOverride, .active)
            .environment(\.lowPowerModeOverride, lowPower)
    }

    /// ⚠️⚠️ **承重判据**：AC「不自带调色板，9 色 × 2 组全部由调用方传入或取 `.tint`」。
    @Test("空色板 ⇒ 取调用方 .tint；给了色板 ⇒ 不再跟随 .tint")
    func emptyPaletteFollowsCallerTint() {
        let red = Self.pixels(Self.body().tint(.red))
        let blue = Self.pixels(Self.body().tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(red?.contains(where: { $0 != 0 }) == true, "位图全 0 —— 断言恒真")
        #expect(red != blue, "空色板下换 .tint 位图不变 —— 说明取色没有走 .tint（多半是写死了 Color.accent）")

        // 反面：显式色板必须**压过** `.tint`，否则"调用方传入"这条路是假的。
        let palette = Array(repeating: Color.surfaceRaised, count: 4) + Array(repeating: Color.contentPrimary, count: 5)
        let paletteRed = Self.pixels(Self.body(colors: palette).tint(.red))
        let paletteBlue = Self.pixels(Self.body(colors: palette).tint(.blue))
        #expect(paletteRed != nil, "渲染失败")
        #expect(paletteRed == paletteBlue, "给了色板还跟着 .tint 变 —— 调用方参数没有生效")
    }

    @Test("两组色板真的都接到渲染上：只换 alternateColors 位图必须变")
    func alternatePaletteReachesRendering() {
        let base = Array(repeating: Color.surfaceRaised, count: 9)
        let alt = Array(repeating: Color.contentPrimary, count: 9)
        // 相位取在两组之间混合最深处，否则混合系数为 0 时两者天然相同。
        let phase = MeshDrift.blendPeakPhase
        let single = Self.pixels(Self.body(phase: phase, colors: base))
        let dual = Self.pixels(Self.body(phase: phase, colors: base, alternateColors: alt))
        #expect(single != nil && dual != nil, "渲染失败")
        #expect(single != dual, "第二组色板对渲染无影响 —— alternateColors 是死参数")
    }

    /// 色板长度契约：不足 9 补齐、超过 9 截断——否则 `MeshGradient` 会因
    /// `colors.count != width * height` 直接崩。
    @Test("色板恒被规整到 9 个（不足循环补齐、超出截断）")
    func paletteIsNormalisedToNineSlots() {
        #expect(MeshDrift.normalised([]).isEmpty, "空色板必须原样为空（那是 .tint 形态的信号）")
        #expect(MeshDrift.normalised([.surfaceRaised]).count == MeshDrift.colorSlots)
        #expect(MeshDrift.normalised(Array(repeating: Color.surfaceRaised, count: 20)).count == MeshDrift.colorSlots)
        #expect(MeshDrift.points(phase: 0).count == MeshDrift.colorSlots,
                "网格点数必须与色位数一致，否则 MeshGradient 崩")
        for p in [CGFloat(0), 0.25, 0.5, 0.87, 1] {
            for point in MeshDrift.points(phase: p) {
                #expect(point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1,
                        "相位 \(p) 上网格点越界：\(point)")
            }
        }
    }

    /// NFR-7 停摆方向：注入"App 进了后台"⇒ 一个像素都不画。
    @Test("注入 .background / .inactive ⇒ 整层不画（与空视图逐字节相同）")
    func backgroundedGradientDrawsNothing() {
        func wrapped(_ phase: ScenePhase) -> Data? {
            Self.pixels(
                AnimatedMeshGradient()
                    .frame(width: 160, height: 120)
                    .background(Color.surfaceRaised)
                    .environment(\.scenePhaseOverride, phase)
            )
        }
        let baseline = Self.pixels(
            Color.clear.frame(width: 160, height: 120).background(Color.surfaceRaised)
        )
        #expect(baseline != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(baseline?.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 相等断言恒真")

        for phase in [ScenePhase.background, .inactive] {
            #expect(wrapped(phase) == baseline, "\(phase) 下仍然画了东西 —— NFR-7 的停摆没有落地")
        }
        #expect(wrapped(.active) != baseline, "\(ScenePhase.active) 下也什么都没画 —— 上面的停摆断言是恒真的")
    }

    /// NFR-7 低电量方向：**必须钉相位**，否则两次渲染落在不同时刻上，不等断言恒真。
    @Test("注入 .lowPower ⇒ 同一相位下位图与满电不同（柔化那层被去掉）")
    func lowPowerChangesRenderingAtSamePhase() {
        let full = Self.pixels(Self.body(lowPower: false))
        let low = Self.pixels(Self.body(lowPower: true))
        #expect(full != nil && low != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(full?.contains(where: { $0 != 0 }) == true, "位图全 0")
        #expect(full != low, "低电量与满电渲染完全一致 —— 注入的 \\.lowPowerModeOverride 没有影响渲染")
    }

    /// 相位真的接到渲染上：两个不同相位必须画出不同的东西。
    /// ⚠️ 它同时是"冻结在某一帧"这条 AC 的**非退化前置**——若任何相位都画同一张图，
    /// "冻结"就是无意义的。
    @Test("相位真的接到渲染：不同相位位图不同，静止相位画得出东西")
    func phaseReachesRendering() {
        let resting = Self.pixels(Self.body(phase: MeshDrift.restingPhase))
        let other = Self.pixels(Self.body(phase: MeshDrift.restingPhase + 0.25))
        #expect(resting != nil && other != nil, "渲染失败")
        #expect(resting != other, "换相位位图不变 —— 网格点没有随相位漂移")
    }

    @Test("相位恒落在 [0, 1)")
    func phaseStaysInRange() {
        for offset in [0.0, 0.3, 1.9, -2.7, 12345.6] {
            let p = MeshDrift.phase(at: Date(timeIntervalSinceReferenceDate: offset))
            #expect(p >= 0 && p < 1, "相位越界：\(p)")
        }
    }

    /// ⚠️⚠️ **AC「Reduce Motion ⇒ 冻结在某一帧」的调用点判据**。
    ///
    /// 位图路结构上不可达（`\.accessibilityReduceMotion` 不可注入）⇒ 只能钉源码：
    /// 静止分支必须画 `AnimatedMeshBody` 且相位取 `MeshDrift.restingPhase`
    /// ——**不是 `EmptyView()`**（那就是 no-op，#250 第 1 轮因此被打回）。
    @Test("Reduce Motion 分支渲染的是钉在静止相位上的网格，不是 no-op")
    func reduceMotionFreezesOnARealFrame() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("AnimatedMeshGradient.swift"))
        guard let restingRange = code.range(of: "case .resting:") else {
            Issue.record("AnimatedMeshGradient 里找不到 `.resting` 分支 —— 两道闸的共享裁决点没接上")
            return
        }
        let tail = String(code[restingRange.upperBound...])
        // 分支体到下一个 `case` 为止。
        let branch = tail.components(separatedBy: "case .animated:").first ?? tail
        #expect(branch.contains("AnimatedMeshBody("),
                "Reduce Motion 分支没有画 AnimatedMeshBody —— 降级成了 no-op")
        #expect(branch.contains("MeshDrift.restingPhase"),
                "Reduce Motion 分支没有把相位钉在 MeshDrift.restingPhase 上 —— 那不是「冻结在某一帧」")
        #expect(!branch.contains("TimelineView("),
                "Reduce Motion 分支里还建了 TimelineView —— 冻结没有落地")
    }

    /// `TimelineView` 只许出现在**动画**分支：停摆与静止两档都不该有活着的调度器。
    @Test("TimelineView 只在 .animated 分支里存在")
    func timelineOnlyExistsInTheAnimatedBranch() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("AnimatedMeshGradient.swift"))
        #expect(code.contains("TimelineView("), "整份文件都没有 TimelineView —— 这个效果根本没在动")
        // 驱动层的 `switch` 体内不得直接出现 `TimelineView(`：它被关在 `AnimatedMeshTimeline` 里。
        guard let switchRange = code.range(of: "switch presentation {") else {
            Issue.record("找不到共享裁决点 `switch presentation {` —— 两道闸的顺序无人守")
            return
        }
        let afterSwitch = String(code[switchRange.upperBound...])
        let switchBody = afterSwitch.components(separatedBy: "struct AnimatedMeshTimeline").first ?? afterSwitch
        #expect(!switchBody.contains("TimelineView("),
                "驱动层的 switch 体里直接建了 TimelineView —— 停摆/静止两档会跟着建出调度器")
    }
}

// MARK: - BeforeAfterSlider

@Suite("BeforeAfterSlider 的摆动、拖拽与触控目标契约")
@MainActor
struct BeforeAfterSliderTests {

    static func source(_ fileName: String) throws -> String {
        try TypewriterTextTests.source(fileName)
    }

    static func slider(
        fraction: CGFloat = BeforeAfterSweep.initialFraction,
        labels: BeforeAfterSliderLabels = .standard
    ) -> some View {
        BeforeAfterSliderBody(
            fraction: fraction,
            labels: labels,
            before: Color.surfaceRaised,
            after: Color.contentPrimary
        )
        .frame(width: 240, height: 140)
    }

    static func pixels(_ view: some View) -> Data? {
        MicroInteractionAPITests.stablePixels(view)
    }

    /// ⚠️⚠️ **承重判据**：AC「Reduce Motion ⇒ 停止自动摆动，但**保留拖拽**」。
    @Test("Reduce Motion ⇒ 没有入场摆动；关闭时才有")
    func introSweepIsGatedByReduceMotion() {
        #expect(BeforeAfterSweep.introSweep(reduceMotion: true) == nil,
                "Reduce Motion 下仍然安排了入场摆动 —— FR-11 的正面违反")
        // ⚠️ **互锁**：非 Reduce Motion 下必须**有**摆动，否则上面那条对
        //「永远返回 nil」的实现也恒真（而那就是把这个效果整个删掉）。
        let sweep = BeforeAfterSweep.introSweep(reduceMotion: false)
        #expect(sweep != nil, "非 Reduce Motion 下也没有入场摆动 —— 上面那条断言是恒真的")
        #expect(sweep?.duration ?? 0 > 0, "摆动时长为 0 —— 等于没有摆动")
        #expect(sweep?.peak != BeforeAfterSweep.initialFraction,
                "摆动的峰值就是初始位置 —— 分隔线一动不动")
        #expect(sweep?.settle == BeforeAfterSweep.initialFraction,
                "摆动结束后没有回到初始位置")
    }

    /// ⚠️ **拖拽不受 Reduce Motion 门控**：`fraction(dragX:width:)` 是纯几何，
    /// 它的签名里**没有** `reduceMotion` 这个参数——这本身就是"拖拽照常"的判据。
    @Test("拖拽位置是纯几何：钳在 0...1，且随手指单调")
    func dragFractionIsPureGeometry() {
        #expect(BeforeAfterSweep.fraction(dragX: -50, width: 200) == 0)
        #expect(BeforeAfterSweep.fraction(dragX: 500, width: 200) == 1)
        #expect(abs(BeforeAfterSweep.fraction(dragX: 50, width: 200) - 0.25) < 0.0001)
        // 退化输入：宽度 0 不得产生 NaN。
        let degenerate = BeforeAfterSweep.fraction(dragX: 10, width: 0)
        #expect(!degenerate.isNaN, "宽度为 0 时算出了 NaN")
        #expect(degenerate >= 0 && degenerate <= 1)
    }

    /// ⚠️⚠️ **承重判据的另一半：调用点**。同 `TypewriterText` 的理由。
    @Test("调用点：BeforeAfterSlider.swift 里 reduceMotion 只喂给 BeforeAfterSweep.introSweep")
    func reduceMotionIsOnlyConsumedByTheSweepGate() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("BeforeAfterSlider.swift"))
        #expect(code.contains("accessibilityReduceMotion"),
                "BeforeAfterSlider 没有读 Reduce Motion —— AC 的降级无从谈起")
        let reads = code.components(separatedBy: "self.reduceMotion").count - 1
        let fed = code.components(separatedBy: "introSweep(reduceMotion: self.reduceMotion)").count - 1
        #expect(fed >= 1, "BeforeAfterSlider 没有把 reduceMotion 喂给入场摆动闸")
        #expect(reads == fed,
                "BeforeAfterSlider.swift 里 `self.reduceMotion` 出现 \(reads) 次、只有 \(fed) 次喂给闸")
        // ⚠️ 同上：先挖掉闸函数自己的函数体，理由见 `TypewriterTextTests` 里那条。
        let callSites = ConfettiTests.removingRegion(after: "static func introSweep(", in: code)
        #expect(callSites != code, "没能挖掉闸函数的函数体 —— 下面的断言会把闸本身报成违规")
        let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: callSites)
        #expect(strays.isEmpty, "裸写的 reduceMotion：\n\(strays.joined(separator: "\n"))")
    }

    /// ⚠️ 与三个"处理中"薄封装同一条纪律：本文件进了
    /// `MicroInteractionReduceMotionGuard.approvedNoMotion`（它里面**没有**任何
    /// `motionCalls` 变换——揭示与把手位置都由布局宽度给出）。
    /// 那条豁免只有在「本文件不自建第二套位移」时才站得住 ⇒ 由本判据钉住。
    @Test("揭示与把手位置只走布局宽度，不用 offset / position 这类变换")
    func sliderPositionsByLayoutNotByTransform() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("BeforeAfterSlider.swift"))
        for call in MicroInteractionReduceMotionGuard.motionCalls {
            #expect(!code.contains(call), """
            BeforeAfterSlider.swift 里出现了 `\(call)` —— 它在 approvedNoMotion 名单上，
            那条豁免的前提正是「本文件没有任何 motionCalls 变换」。
            要么改回布局定位，要么把它从名单里挪出来并按逐调用门控处理。
            """)
        }
        #expect(code.contains("BeforeAfterSweep.revealWidth("),
                "揭示宽度不再走共享几何函数 —— 判据与生产代码会各自漂移")
    }

    @Test("揭示宽度随 fraction 单调，端点恰为 0 与满宽")
    func revealWidthIsMonotonic() {
        #expect(BeforeAfterSweep.revealWidth(fraction: 0, width: 200) == 0)
        #expect(BeforeAfterSweep.revealWidth(fraction: 1, width: 200) == 200)
        #expect(BeforeAfterSweep.revealWidth(fraction: 0.25, width: 200)
                < BeforeAfterSweep.revealWidth(fraction: 0.75, width: 200))
    }

    /// fraction 真的接到渲染上——否则"拖拽照常"是一句无覆盖的话。
    @Test("fraction 真的接到渲染：两个位置的位图不同")
    func fractionReachesRendering() {
        let quarter = Self.pixels(Self.slider(fraction: 0.25))
        let threeQuarters = Self.pixels(Self.slider(fraction: 0.75))
        #expect(quarter != nil && threeQuarters != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(quarter?.contains(where: { $0 != 0 }) == true, "位图全 0")
        #expect(quarter != threeQuarters, "换 fraction 位图不变 —— 揭示宽度没有接到渲染上")
    }

    /// AC：`showLabels: Bool` 换成语义枚举，且三档在渲染上真的不同。
    @Test("标签取值域是枚举三档，且三档渲染互不相同")
    func labelDomainIsAnEnumWithThreeDistinctRenderings() {
        let hidden = Self.pixels(Self.slider(labels: .hidden))
        let standard = Self.pixels(Self.slider(labels: .standard))
        let custom = Self.pixels(Self.slider(labels: .shown(before: "Draft", after: "Final")))
        #expect(hidden != nil && standard != nil && custom != nil, "渲染失败")
        #expect(hidden != standard, "`.hidden` 与 `.standard` 渲染相同 —— 标签根本没画出来")
        #expect(standard != custom, "自定义文案与默认文案渲染相同 —— 调用方传入的文案没生效")
    }

    /// AC：默认 "Before" / "After" 是 `LocalizedStringResource`（公约 §4 A 类），
    /// 且**真的经本 target 自己的 `Bundle.module` 查表**——否则它永远只能落到宿主 App。
    @Test("默认文案走本 target 的 Bundle.module（哨兵键证明查表命中，而非静默回退）")
    func defaultLabelsResolveThroughModuleBundle() {
        // ⚠️ 哨兵的译文与 key **有意不同**：查表 miss 时 Foundation 原样返回 key，
        // 只有译文 != key 时才能区分「命中」与「静默回退」（同 `CoreDesignCharts` 的成法）。
        #expect(String(localized: .effectsChrome("__localization_probe__")) == "resource-bundle-resolved",
                "本 target 的 Bundle.module 查表没有命中 —— chrome 文案永远无法由本包提供翻译")
        #expect(String(localized: BeforeAfterSliderLabels.defaultBefore) == "Before")
        #expect(String(localized: BeforeAfterSliderLabels.defaultAfter) == "After")
    }

    /// AC：触控目标测试**在本 target 内同形态实现**，不进 `CoreDesignTests.TouchTargetTests`。
    /// 平台无关的那一半：把手的命中尺寸常量本身。
    @Test("把手命中尺寸常量 ≥ 44pt")
    func handleHitSizeConstantMeetsMinimum() {
        #expect(BeforeAfterSweep.handleHitSize >= 44,
                "把手命中尺寸 \(BeforeAfterSweep.handleHitSize)pt < 44pt —— 触控目标不达标")
    }
}

// ⚠️ **与 `CoreDesignTests.TouchTargetTests` 同形态**：`ImageRenderer` 量的是 SwiftUI
// **布局 frame**，它等于命中区的前提是 `contentShape` 挂在最外层、盖住完整 frame
// ——`BeforeAfterSliderHandle` 满足这个前提（`frame(width:height:)` 之后才施加
// `contentShape`）。整个 suite `#if os(iOS)`，只在 xcodebuild iOS Simulator 腿上执行；
// 平台无关的那一半在 `BeforeAfterSliderTests.handleHitSizeConstantMeetsMinimum`。
#if os(iOS)
@Suite("BeforeAfterSlider 触控目标 ≥ 44pt")
@MainActor
struct BeforeAfterSliderTouchTargetTests {

    private func renderedSize(_ view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage?.size ?? .zero
    }

    @Test("拖拽把手实测命中区两个方向都 ≥ 44pt")
    func handleMeetsMinimumTouchTarget() {
        let size = self.renderedSize(BeforeAfterSliderHandle().frame(height: 140))
        #expect(size.width >= 44, "把手实测命中宽度 \(size.width)pt < 44pt")
        #expect(size.height >= 44, "把手实测命中高度 \(size.height)pt < 44pt")
    }
}
#endif

// MARK: - ParticleTransition

@Suite("ParticleTransition 的相位、取色与降级契约")
@MainActor
struct ParticleTransitionTests {

    static func source(_ fileName: String) throws -> String {
        try TypewriterTextTests.source(fileName)
    }

    /// ⚠️ 粒子走 `Canvas`，与 `ConfettiTests.canvasWarmUp` 同一条首帧伪影，先跑热。
    private static let canvasWarmUp: Bool = {
        let probe = ParticleBurstLayer(progress: 0.4, count: 24, colors: [])
            .frame(width: 160, height: 160)
            .background(Color.surfaceRaised)
        for _ in 0..<8 { _ = MicroInteractionAPITests.stablePixels(probe) }
        return true
    }()

    static func pixels(_ view: some View) -> Data? {
        _ = Self.canvasWarmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    static func burst(progress: Double, colors: [Color] = []) -> some View {
        ParticleBurstLayer(progress: progress, count: 24, colors: colors)
            .frame(width: 160, height: 160)
            .background(Color.surfaceRaised)
    }

    @Test("相位映射：identity ⇒ 进度 0（不画粒子），进出两侧都在动")
    func progressMapping() {
        #expect(ParticleBurst.progress(phase: .identity) == 0)
        #expect(ParticleBurst.progress(phase: .willAppear) > 0)
        #expect(ParticleBurst.progress(phase: .didDisappear) > 0)
        // 内容自身：identity 必须完全不透明、不缩放，否则常驻态就被转场改了样子。
        #expect(ParticleBurst.contentOpacity(phase: .identity) == 1)
        #expect(ParticleBurst.contentScale(phase: .identity) == 1)
        #expect(ParticleBurst.contentOpacity(phase: .willAppear) < 1)
        #expect(ParticleBurst.contentScale(phase: .willAppear) != 1)
    }

    /// 终帧（identity）一颗粒子都不剩——否则转场结束后画面上永久挂着粒子。
    @Test("identity 相位一颗粒子都不画")
    func identityFrameDrawsNothing() {
        let empty = Self.pixels(Color.clear.frame(width: 160, height: 160).background(Color.surfaceRaised))
        #expect(empty != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(empty?.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 相等断言恒真")
        #expect(Self.pixels(Self.burst(progress: ParticleBurst.progress(phase: .identity))) == empty,
                "identity 相位还有粒子 —— 转场结束后会永久残留")
        // ⚠️ **互锁**：中途必须画得出粒子，否则上一条是恒真的。
        #expect(Self.pixels(Self.burst(progress: 0.4)) != empty,
                "progress = 0.4 都画不出粒子 —— 上一条相等断言是恒真的")
    }

    /// AC / FR-8：空色板 ⇒ 取调用方 `.tint`，不自带色板。
    @Test("空色板 ⇒ 粒子色跟随调用方 .tint；给了色板则不跟随")
    func particlesFollowCallerTint() {
        let red = Self.pixels(Self.burst(progress: 0.4).tint(.red))
        let blue = Self.pixels(Self.burst(progress: 0.4).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败")
        #expect(red != blue, "空色板下换 .tint 位图不变 —— 取色没有走 .tint")

        let palette: [Color] = [.surfaceRaised, .contentPrimary]
        #expect(Self.pixels(Self.burst(progress: 0.4, colors: palette).tint(.red))
                == Self.pixels(Self.burst(progress: 0.4, colors: palette).tint(.blue)),
                "给了色板还跟着 .tint 变 —— 调用方参数没有生效")
    }

    /// ⚠️⚠️ **Reduce Motion 降级不是 no-op**（#250 第 1 轮因此被打回）：
    /// 早退分支必须仍然让内容淡入淡出，只是不放粒子、不缩放。
    @Test("Reduce Motion 分支保留淡入淡出，且不建粒子层")
    func reduceMotionKeepsTheFade() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("ParticleTransition.swift"))
        // ⚠️ **配对括号取分支体**，不用"找下一个 `}`"——后者会在第一个嵌套闭包处截断。
        // 复用 `ConfettiTests` 已有的那份实现，不另抄一遍。
        guard let branch = ConfettiTests.bracedRegion(after: "guard !isReduced else", in: code) else {
            Issue.record("ParticleTransition 里找不到 Reduce Motion 早退 —— 降级没有落地")
            return
        }
        #expect(branch.contains("ParticleBurst.contentOpacity("),
                "Reduce Motion 分支没有保留淡入淡出 —— 那就是 no-op")
        #expect(!branch.contains("ParticleBurstLayer("),
                "Reduce Motion 分支还建了粒子层 —— 降级没有落地")
        #expect(!branch.contains("contentScale("),
                "Reduce Motion 分支还在缩放 —— 缩放同样属于 FR-11 的运动")
    }

    /// `.transition(.particle)` 点语法与含参重载都在，且可用于真实视图。
    @Test("Transition 静态成员存在，两种写法都可用")
    func staticTransitionMembersExist() {
        let plain = Text("x").transition(.particle)
        let configured = Text("x").transition(.particle(count: 8, colors: [.surfaceRaised]))
        #expect(MicroInteractionAPITests.stablePixels(plain) != nil)
        #expect(MicroInteractionAPITests.stablePixels(configured) != nil)
        #expect(ParticleTransition().count > 0, "默认粒子数为 0 —— 这个转场什么都不放")
    }
}
