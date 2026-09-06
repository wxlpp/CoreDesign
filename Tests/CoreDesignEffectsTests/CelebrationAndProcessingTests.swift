import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #252：庆祝与处理中动效 + NFR-7 可注入能耗 environment

// MARK: - 纯函数层：能耗状态 → 渲染策略

@Suite("NFR-7 的 effects 专用旋钮（#271 下沉后只剩这一半）")
struct EffectsEnergyKnobTests {
    @Test("effects 旋钮：低电量去光晕、粒子减半，停摆一个不放")
    func effectsKnobs() {
        #expect(RenderPolicy.full.usesGlow)
        #expect(RenderPolicy.reduced.usesGlow == false, "低电量没有去掉光晕 —— 那是唯一能拍进静态位图的差异")
        #expect(RenderPolicy.paused.usesGlow == false)
        #expect(RenderPolicy.full.particleScale == 1)
        #expect(RenderPolicy.reduced.particleScale == 0.5)
        #expect(RenderPolicy.paused.particleScale == 0)
    }
}

// MARK: - 渲染层：注入伪值 ⇒ 位图断言

@Suite("NFR-7 注入伪值断言渲染行为")
@MainActor
struct EffectsEnergyRenderTests {
    static func sampleContent() -> some View {
        RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 180, height: 120)
    }

    private static let layerWarmUp: Bool = {
        for kind in ProcessingSweepKind.allCases {
            let probe = ProcessingSweepBody(kind: kind, phase: ProcessingSweep.restingPhase)
                .frame(width: 180, height: 120)
                .background(Color.surfaceRaised)
                .environment(\.scenePhaseOverride, .active)
            for _ in 0..<4 { _ = MicroInteractionAPITests.stablePixels(probe) }
        }
        return true
    }()

    static func pixels(_ view: some View) -> Data? {
        _ = Self.layerWarmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    static func wrapped(_ kind: ProcessingSweepKind, phase: ScenePhase) -> Data? {
        let content = Self.sampleContent()
        let view: AnyView = switch kind {
        case .scanning: AnyView(ScanningOverlay { content })
        case .glow: AnyView(GlowSweep { content })
        case .light: AnyView(LightSweep { content })
        }
        return Self.pixels(view.environment(\.scenePhaseOverride, phase))
    }

    @Test("注入 .background / .inactive ⇒ 三个容器整层不画（与空 overlay 逐字节相同）")
    func backgroundedContainersDrawNothing() {
        let baseline = Self.pixels(Self.sampleContent().overlay { EmptyView() })
        #expect(baseline != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(baseline?.contains(where: { $0 != 0 }) == true,
                "基线位图全 0 —— 相等断言会恒真")

        for kind in ProcessingSweepKind.allCases {
            for phase in [ScenePhase.background, .inactive] {
                expectBitmapsEqual(Self.wrapped(kind, phase: phase), baseline,
                        "\(kind) 在 \(phase) 下仍然画了东西 —— NFR-7 的停摆没有落地")
            }
            expectBitmapsDiffer(Self.wrapped(kind, phase: .active), baseline,
                    "\(kind) 在 .active 下也什么都没画 —— 上面的停摆断言是恒真的")
        }
    }

    @Test("注入 .lowPower ⇒ 同一相位下位图与满电不同（光晕那层被去掉）")
    func lowPowerChangesRenderingAtSamePhase() {
        func pixels(_ kind: ProcessingSweepKind, lowPower: Bool) -> Data? {
            Self.pixels(
                ProcessingSweepBody(kind: kind, phase: ProcessingSweep.restingPhase)
                    .frame(width: 180, height: 120)
                    .background(Color.surfaceRaised)
                    .environment(\.scenePhaseOverride, .active)
                    .environment(\.lowPowerModeOverride, lowPower)
            )
        }
        for kind in ProcessingSweepKind.allCases {
            let full = pixels(kind, lowPower: false)
            let low = pixels(kind, lowPower: true)
            #expect(full != nil && low != nil, "\(kind) 渲染失败，下面的不等断言会静默变绿")
            #expect(full?.contains(where: { $0 != 0 }) == true, "\(kind) 位图全 0")
            expectBitmapsDiffer(full, low,
                    "\(kind) 在低电量下与满电渲染完全一致 —— 注入的 \\.lowPowerModeOverride 没有影响渲染")
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
        #expect(abs(ProcessingSweep.pingPong(ProcessingSweep.restingPhase) - 0.5) < 0.0001)
        #expect(ProcessingSweep.phase(at: .now, period: 0) == 0)
        #expect(!ProcessingSweep.ringRadius(for: .zero).isNaN)
        #expect(ProcessingSweep.ringRadius(for: .zero) == 0)
    }

    @Test("任何相位都画得出东西（往复形态的承重前提）")
    func everyPhaseDrawsSomething() {
        let baseline = EffectsEnergyRenderTests.pixels(
            Color.surfaceRaised.frame(width: 180, height: 120)
        )
        #expect(baseline != nil, "基线渲染失败，下面的不等断言会静默变绿")
        #expect(baseline?.contains(where: { $0 != 0 }) == true, "基线位图全 0")
        for kind in ProcessingSweepKind.allCases {
            for step in 0..<8 {
                let phase = CGFloat(step) / 8
                let drawn = EffectsEnergyRenderTests.pixels(
                    ProcessingSweepBody(kind: kind, phase: phase)
                        .frame(width: 180, height: 120)
                        .background(Color.surfaceRaised)
                        .environment(\.scenePhaseOverride, .active)
                )
                #expect(drawn != nil, "\(kind) 在相位 \(phase) 上渲染失败")
                expectBitmapsDiffer(drawn, baseline, "\(kind) 在相位 \(phase) 上什么都没画")
            }
        }
    }

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

    @Test("遮罩色标：峰值 α 必须是 1，两端必须是 0（明暗两端各验一次）")
    func maskStopsAreFullyOpaqueAtTheirPeak() {
        let stops: [(name: String, colors: [Color])] = [
            ("ringMaskStops", ProcessingSweep.ringMaskStops),
            ("bandMaskStops", ProcessingSweep.bandMaskStops),
        ]
        for (schemeName, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            for (name, colors) in stops {
                #expect(colors.count >= 3, "\(name) 只有 \(colors.count) 个色标 —— 下面的断言会失去意义")
                let alphas = colors.map { Double($0.resolve(in: env).opacity) }
                let peak = alphas.max() ?? -1
                #expect(peak == 1, """
                \(schemeName)：`ProcessingSweep.\(name)` 的峰值 α = \(peak)，不是 1
                （逐个色标：\(alphas)）。`mask` 吃的正是 alpha ⇒ 这一层能达到的最大
                不透明度被基色打了折，整条扫光比它的 opacity 常量声称的更淡（Issue #276）。
                基色必须走 `Color.maskOpaque`（契约 α = 1），不得换成任何 `label` 族语义色。
                """)
                #expect(alphas.first == 0 && alphas.last == 0, """
                \(schemeName)：`ProcessingSweep.\(name)` 的两端不是全透明（\(alphas)）
                —— 扫光会在边界上出现硬边。
                """)
            }
        }
    }

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

    @Test("终帧（progress = 1）一片彩纸都不画")
    func terminalFrameDrawsNothing() {
        let empty = Self.emptyBaseline
        #expect(empty != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(empty?.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 相等断言恒真")

        expectBitmapsEqual(Self.pixels(Self.canvas(progress: 1)), empty,
                "progress = 1 时还有彩纸 —— burst 结束后会永久残留")
        expectBitmapsDiffer(Self.pixels(Self.canvas(progress: 0.25)), empty,
                "progress = 0.25 都画不出彩纸 —— 上一条相等断言是恒真的")
        expectBitmapsDiffer(Self.pixels(Self.canvas(progress: ConfettiBurst.restingProgress)), empty,
                "Reduce Motion 静态庆祝层是空的 —— 那就是 no-op")
    }

    @Test("默认（空色板）彩纸色跟随调用方 .tint；给了色板则不跟随")
    func confettiParticlesFollowCallerTint() {
        let red = Self.pixels(Self.canvas(progress: 0.3).tint(.red))
        let blue = Self.pixels(Self.canvas(progress: 0.3).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的不等断言会静默变绿")
        expectBitmapsDiffer(red, blue,
                "空色板时彩纸色没有跟随 .tint —— Canvas 里的 .style(.tint) 没被解析")

        let explicitRedTint = Self.pixels(Self.canvas(progress: 0.3, colors: [.green]).tint(.red))
        let explicitBlueTint = Self.pixels(Self.canvas(progress: 0.3, colors: [.green]).tint(.blue))
        #expect(explicitRedTint != nil && explicitBlueTint != nil,
                "显式色板渲染失败，下面两条断言会静默变绿")
        expectBitmapsEqual(explicitRedTint, explicitBlueTint,
                "给了显式色板还跟着 .tint 变 —— 调用方参数没有优先，取色多半绕过了 colors")
        expectBitmapsDiffer(explicitRedTint, red, "显式色板与回落 .tint 画出的东西一样 —— colors 参数没进渲染")

        #expect([Color]().particleColor(at: 0) == nil, "空色板必须回落到 .tint，而不是取某个具体色")
        #expect([Color.red, .blue].particleColor(at: 2) == .red, "非空色板必须按下标轮转")
    }

    // MARK: - 实际渲染路径（不是更里面的 ConfettiCanvas）

    static var pinnedBurstStart: Date { .now.addingTimeInterval(3600) }

    @Test("ConfettiLayer：progress 真的接到画布，终帧不留残留，色板与 .tint 都接得上")
    func confettiLayerRendersTheRealPath() {
        let empty = Self.emptyBaseline
        #expect(empty != nil, "基线渲染失败，下面的断言会静默变绿")
        #expect(empty?.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 相等断言恒真")

        func layer(_ start: Date, colors: [Color] = []) -> some View {
            Self.framed(
                ConfettiLayer(burstStart: start, count: 36, colors: colors, minimumInterval: nil)
            )
        }

        let mid = Self.pixels(layer(.now.addingTimeInterval(-0.5)))
        #expect(mid != nil, "ConfettiLayer 渲染失败")
        expectBitmapsDiffer(mid, empty, "burst 中途 ConfettiLayer 什么都没画 —— progress 没有接到画布")

        let terminal = Self.pixels(layer(.now.addingTimeInterval(-10)))
        #expect(terminal != nil, "ConfettiLayer 终帧渲染失败")
        expectBitmapsEqual(terminal, empty, "burst 结束后 ConfettiLayer 仍有残留")

        let pinned = Self.pinnedBurstStart
        let red = Self.pixels(layer(pinned).tint(.red))
        let blue = Self.pixels(layer(pinned).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的不等断言会静默变绿")
        expectBitmapsDiffer(red, blue, "ConfettiLayer 的空色板没有跟随 .tint")

        let green = Self.pixels(layer(pinned, colors: [.green]).tint(.red))
        let greenAgain = Self.pixels(layer(pinned, colors: [.green]).tint(.blue))
        #expect(green != nil && greenAgain != nil, "渲染失败，下面两条断言会静默变绿")
        expectBitmapsEqual(green, greenAgain, "给了显式色板还跟着 .tint 变 —— 取色绕过了 colors")
        expectBitmapsDiffer(green, red, "显式色板与回落 .tint 画出的东西一样 —— colors 没进渲染")
    }

    @Test("ConfettiCore：能耗闸生效、burst 门控生效、colors 接得到画布")
    func confettiCoreRendersTheRealPath() {
        func core(
            _ start: Date?, colors: [Color] = [], phase: ScenePhase = .active
        ) -> some View {
            Self.framed(
                Color.clear
                    .modifier(ConfettiCore(
                        fire: 0, strength: .regular, colors: colors, initialBurstStart: start
                    ))
                    .environment(\.scenePhaseOverride, phase)
            )
        }

        let pinned = Self.pinnedBurstStart
        let resting = Self.pixels(core(nil))
        let bursting = Self.pixels(core(pinned))
        #expect(resting != nil && bursting != nil, "渲染失败，下面的断言会静默变绿")
        expectBitmapsDiffer(bursting, resting,
                "burst 进行中与静息态逐字节相同 —— .confetti 的渲染路径整条没接上")

        for phase in [ScenePhase.background, .inactive] {
            let gated = Self.pixels(core(pinned, phase: phase))
            #expect(gated != nil, "\(phase) 下渲染失败")
            expectBitmapsEqual(gated, resting, "\(phase) 下彩纸层仍在画 —— NFR-7 的停摆没有落地")
        }

        let tintRed = Self.pixels(core(pinned).tint(.red))
        let greenOnRed = Self.pixels(core(pinned, colors: [.green]).tint(.red))
        let greenOnBlue = Self.pixels(core(pinned, colors: [.green]).tint(.blue))
        #expect(tintRed != nil && greenOnRed != nil && greenOnBlue != nil,
                "渲染失败，下面两条断言会静默变绿")
        expectBitmapsEqual(greenOnRed, greenOnBlue, "给了显式色板还跟着 .tint 变")
        expectBitmapsDiffer(greenOnRed, tintRed,
                "colors 参数没有从 ConfettiCore 传到画布 —— 公开的 colors: 是死参数")
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

    @Test("TimelineView 只在 burst 进行中存在")
    func timelineOnlyExistsDuringBurst() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(
            try ProcessingSweepTests.source("Confetti.swift")
        )
        let occurrences = code.components(separatedBy: "TimelineView(").count - 1
        #expect(occurrences == 1, "Confetti.swift 里有 \(occurrences) 处 TimelineView —— 移除判据只覆盖得了一处")
        guard let layerRange = code.range(of: "struct ConfettiLayer: View {") else {
            Issue.record("找不到 ConfettiLayer 声明")
            return
        }
        guard let timelineRange = code.range(of: "TimelineView(") else {
            Issue.record("Confetti.swift 里找不到 TimelineView( —— 上一条计数判据应当已经判红")
            return
        }
        #expect(timelineRange.lowerBound > layerRange.lowerBound,
                "TimelineView 不在 ConfettiLayer 里")
        guard let animatedCase = code.range(of: "case .animated:") else {
            Issue.record("找不到 switch presentation 的 .animated 分支")
            return
        }
        let firstStatement = code[animatedCase.upperBound...]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        #expect(firstStatement == "if let start = self.burstStart {",
                "`.animated` 分支的第一句不是对 burstStart 的 `if let`（实为 `\(firstStatement)`）—— 双重门控被拆掉了一半")
        #expect(code.contains("switch presentation {"),
                "两道闸的结论不再由 switch presentation 单点裁决")
        #expect(code.contains("try await Task.sleep(for: .seconds(ConfettiBurst.duration))"))
        #expect(code.contains("self.burstStart = nil"), "没有任何地方把 burstStart 清空 —— 层永不移除")
    }

    static func bracedRegion(after marker: String, in code: String) -> String? {
        guard let r = code.range(of: marker) else { return nil }
        let chars = Array(code)
        var k = code.distance(from: code.startIndex, to: r.lowerBound)
        while k < chars.count, chars[k] != "{" { k += 1 }
        guard k < chars.count else { return nil }
        let start = k
        var depth = 0
        while k < chars.count {
            if chars[k] == "{" { depth += 1 }
            else if chars[k] == "}" {
                depth -= 1
                if depth == 0 { return String(chars[start...k]) }
            }
            k += 1
        }
        return nil
    }

    static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    static func removingRegion(after marker: String, in code: String) -> String {
        var out = code
        while let markerRange = out.range(of: marker),
              let region = Self.bracedRegion(after: marker, in: out),
              let regionRange = out.range(of: region, range: markerRange.lowerBound..<out.endIndex) {
            out.removeSubrange(markerRange.lowerBound..<regionRange.upperBound)
        }
        return out
    }

    @Test("ConfettiCore.body 只有一种形状（content 与 .task 恒在，分支只在 overlay 内部）")
    func confettiKeepsOneShapeAcrossScenePhase() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(
            try ProcessingSweepTests.source("Confetti.swift")
        )
        guard let body = Self.bracedRegion(
            after: "func body(content: Content) -> some View {", in: code
        ) else {
            Issue.record("找不到 ConfettiCore.body —— 判据无法工作，这不是「零违规」")
            return
        }

        #expect(Self.occurrences(of: "content", in: body) == 1,
                "ConfettiCore.body 里 `content` 出现了 \(Self.occurrences(of: "content", in: body)) 次 —— 多于一次意味着 body 有多条出口，调用方内容子树会随 scenePhase 换身份")
        #expect(Self.occurrences(of: ".task(", in: body) == 1,
                ".task( 不是恰好一处 —— burst 状态机必须恒在，否则某条路径上它会被整个摘掉")
        #expect(Self.occurrences(of: "AnyView", in: body) == 0,
                "ConfettiCore.body 又用上了 AnyView —— 类型擦除的顶层分支正是 C-1 的成因")
        #expect(Self.occurrences(of: "return ", in: body) == 1,
                "ConfettiCore.body 的 return 不是恰好一处 —— 0 处意味着走了 @ViewBuilder 的隐式分支")
        #expect(Self.occurrences(of: ".id(", in: body) == 0,
                "ConfettiCore.body 里出现了 `.id(` —— presentation 随 scenePhase 翻转，显式换 id 就是每次后台往返都重建整棵被修饰子树，与 C-1 等价")
        #expect(body.contains("switch presentation {"),
                "两道闸的结论不再由单个 switch 裁决")

        guard let staticDecl = Self.bracedRegion(
            after: "struct ConfettiStaticCelebration: View {", in: code
        ) else {
            Issue.record("找不到 ConfettiStaticCelebration 声明")
            return
        }
        #expect(staticDecl.contains("let active: Bool"),
                "静态庆祝层不再由外部传入的 active 驱动")
        #expect(!staticDecl.contains("@State"),
                "静态庆祝层又自带 @State —— 它会随 scenePhase 的分支翻转被重建并复位")
        let outsideCore = Self.removingRegion(
            after: "#Preview",
            in: Self.removingRegion(after: "struct ConfettiCore: ViewModifier {", in: code)
        )
        #expect(!outsideCore.contains("@State"),
                "Confetti.swift 里 ConfettiCore 之外还有 @State —— 状态只许长在挂着恒在 .task(id:) 的 ConfettiCore 上，别处的 @State 会随 scenePhase 分支重建复位（C-1 的成因）")
        #expect(!staticDecl.contains(".task("),
                "静态庆祝层又自带 .task —— 后台往返把它移除再插回就会重放一次庆祝")
        #expect(!staticDecl.contains("fire"),
                "静态庆祝层又直接吃 trigger —— 触发源必须是 ConfettiCore 的 burstStart")
    }

    @Test("静态庆祝层是 active 的纯函数（active: false ⇒ 一个像素都不画）")
    func staticCelebrationIsDrivenByItsActiveParameter() {
        func layer(active: Bool, policy: RenderPolicy) -> Data? {
            Self.pixels(Self.framed(ConfettiStaticCelebration(
                active: active, strength: .regular, colors: [], policy: policy
            )))
        }
        let on = layer(active: true, policy: .full)
        let off = layer(active: false, policy: .full)
        let empty = layer(active: true, policy: .paused)
        #expect(on != nil && off != nil && empty != nil, "渲染失败，下面的断言会静默变绿")
        expectBitmapsDiffer(on, off,
                "静态庆祝层没有跟着 active 变 —— 它的触发源不是 ConfettiCore 的 burstStart")
        expectBitmapsDiffer(on, empty, "active: true 也什么都没画 —— 上一条是恒真的")
        expectBitmapsEqual(off, empty, "active: false 时静态层仍在画东西")
    }

    @Test("Reduce Motion 分支渲染的是静态庆祝层，不是 no-op")
    func reduceMotionFallsBackToStaticCelebration() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(
            try ProcessingSweepTests.source("Confetti.swift")
        )
        guard let restingCase = code.range(of: "case .resting:"),
              let end = code.range(of: "case .animated:", range: restingCase.upperBound..<code.endIndex)
        else {
            Issue.record("找不到 Reduce Motion 的 .resting 分支")
            return
        }
        let branch = String(code[restingCase.upperBound..<end.lowerBound])
        #expect(branch.contains("ConfettiStaticCelebration("),
                "Reduce Motion 分支没有渲染静态庆祝层 —— 降级成了 no-op")
        #expect(branch.contains("active: self.burstStart != nil"),
                "静态庆祝层不是由 ConfettiCore 的 burstStart 驱动 —— 后台往返会重放")
        #expect(ConfettiBurst.restingProgress > 0 && ConfettiBurst.restingProgress < 1,
                "静态庆祝层的相位落在了终帧或起帧上 —— 那一帧要么空要么全挤在中心")
        #expect(!code.contains("reduceMotionFallback("),
                "Confetti 走的是降级形态 2，不该再叠 reduceMotionFallback 的脉冲")
    }
}
