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
// · `\.scenePhaseOverride = .background` ⇒ 三个常驻效果**一个像素都不画**（与裸内容逐字节相同）；
// · `\.lowPowerModeOverride = true` ⇒ **同一相位**下位图与满电时不同（光晕那一层被去掉）。
//
// ⚠️ **低电量那条必须钉相位**：降帧本身拍不进静态帧（`ImageRenderer` 拍的是一帧），
// 而若走 `TimelineView` 的活相位，两次渲染落在不同时刻上，位图必然不同 ⇒ 断言恒真。
// ⇒ 判据吃的是 `ProcessingSweepBody(kind:phase:)`——同一个 `phase`、只换注入值。
//
// ⚠️ **本 target 的一条覆盖限度（#252 PR #269 第 4 轮终审 S2-5）**：
// `docs/components/` 下 `confetti` / `glow-sweep` / `light-sweep` / `scanning-overlay`
// 四份文档的示例代码**零机器覆盖**——`import` 漏写、API 改名、参数标签变更都不会让
// 任何一条腿变红，只能人工发现（第 4 轮修的正是两份文档缺 `import`）。
// 不便机器化的理由与记账方式写在 `docs/components/confetti.md` 的「使用示例」小节；
// `.build/` 里那个 `__DocExampleCompileCheck.swift.o` 是一次尝试的**陈旧产物**，
// 树里没有对应源文件，别把它当成"其实有覆盖"。

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

    /// ⚠️ **`CoreDesign` 的 `Bool?` 键 → 本 target 的语义档位，这一步是承重的**
    ///（#252 PR #269 终审 S-2 的下沉处置）：三个调用点都靠
    /// `EffectsPowerMode.lifted(from:)` 抬升，抬错就等于两个能耗键在动效层上失效。
    ///
    /// ⚠️ **`nil` 必须原样传下去**，不能就地折成 `.standard`：`nil` 的语义是
    /// "没有人注入 ⇒ 去读 `ProcessInfo`"，折成 `.standard` 会把"默认从系统读"
    /// 整条抹掉（`defaultPowerModeReadsSystem` 断的正是那条），
    /// 而这两种写法在 `.policy` 上**只在真机开着低电量时**才可分辨——
    /// 靠上面那个测试抓不到，必须在这里单独钉死。
    @Test("lowPowerModeOverride（Bool?）抬成 EffectsPowerMode?：true ⇒ .lowPower，nil ⇒ nil")
    func liftsGenericLowPowerKeyIntoPowerMode() {
        #expect(EffectsPowerMode.lifted(from: true) == .lowPower)
        #expect(EffectsPowerMode.lifted(from: false) == .standard)
        #expect(EffectsPowerMode.lifted(from: nil) == nil, "nil 被折成了档位 —— 「默认从系统读」整条失效")
    }

    /// ⚠️⚠️ **I-1 的机器判据**（#252 PR #269 第 1 轮终审 I-1 / I-2）。
    ///
    /// 「顺序是承重的：先 NFR-7 的能耗闸，再 Reduce Motion 闸」这句话此前**只是注释**：
    /// 终审把 `ProcessingSweepDriver` 的两道闸对调，**42/42 全绿**；而 `Confetti`
    /// 当时就是反的（RM 闸在前 ⇒ `policy` 根本不被求值 ⇒ 两个能耗键对它完全无效）。
    ///
    /// ⇒ 裁决抽成纯函数 `EffectsEnergyState.presentation(reduceMotion:)`，两个调用点
    /// 共用同一份，顺序由本条钉死：**只要不在 `.active`，无论 Reduce Motion 与能耗档位
    /// 取什么值，结果都必须是 `.none`**。
    ///
    /// ⚠️ 为什么不走位图：`\.accessibilityReduceMotion` **不可注入**（写它编译红），
    /// "RM 开启 × 后台"这个组合在 `ImageRenderer` 下构造不出来。纯函数是唯一可行路径。
    @Test("两道闸的顺序：能耗闸压过 Reduce Motion 闸")
    func energyGateOutranksReduceMotion() {
        for phase in [ScenePhase.background, .inactive] {
            for mode in EffectsPowerMode.allCases {
                for reduceMotion in [true, false] {
                    let state = EffectsEnergyState(scenePhase: phase, powerMode: mode)
                    #expect(state.presentation(reduceMotion: reduceMotion) == .none,
                            "\(phase) / \(mode) / reduceMotion=\(reduceMotion) 下没有停摆 —— 两道闸的顺序反了：Reduce Motion 闸不得先于 NFR-7 的能耗闸")
                }
            }
        }
        // 前台：这时才轮到 Reduce Motion 决定"动还是静止"。
        for mode in EffectsPowerMode.allCases {
            let state = EffectsEnergyState(scenePhase: .active, powerMode: mode)
            #expect(state.presentation(reduceMotion: true) == .resting,
                    "\(mode) 下 Reduce Motion 没有降级为静止呈现 —— 降级不是 no-op")
            #expect(state.presentation(reduceMotion: false) == .animated,
                    "\(mode) 下前台不动了 —— 上面那两条会退化成恒真")
        }
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
                .environment(\.scenePhaseOverride, .active)
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
        return Self.pixels(view.environment(\.scenePhaseOverride, phase))
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
                expectBitmapsEqual(Self.wrapped(kind, phase: phase), baseline,
                        "\(kind) 在 \(phase) 下仍然画了东西 —— NFR-7 的停摆没有落地")
            }
            // ⚠️ **互锁**：`.active` 必须画得出东西，否则上面那条相等断言是恒真的
            //（"什么都不画"与"这个效果压根没实现"在位图上不可分辨）。
            expectBitmapsDiffer(Self.wrapped(kind, phase: .active), baseline,
                    "\(kind) 在 .active 下也什么都没画 —— 上面的停摆断言是恒真的")
        }
    }

    /// 低电量方向的渲染判据。**必须钉相位**——理由见文件头。
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
        // ⚠️ **非空断言先行**（本文件自己的纪律）：基线为 `nil` 时下面的不等断言恒真。
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
                // ⚠️ 少了这条，整体渲染失败（`drawn == nil`）会让下一条静默判绿
                //（`nil != baseline` 恒真）——#252 PR #269 第 1 轮终审 S-3。
                #expect(drawn != nil, "\(kind) 在相位 \(phase) 上渲染失败")
                expectBitmapsDiffer(drawn, baseline, "\(kind) 在相位 \(phase) 上什么都没画")
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

    /// ⚠️⚠️ **承重（Issue #276）：遮罩色标的峰值必须是满不透明。**
    ///
    /// `glowRing` / `lightBand` 都是「`Rectangle().fill(.tint)` + 一条 alpha 渐变遮罩」。
    /// `mask` 吃的是 alpha ⇒ 色标的峰值就是这一层能达到的**最大**不透明度。
    ///
    /// 上一版两条色标写的都是 `.primary`，注释宣称「`.primary` 恒为不透明 ⇒ 与写死
    /// `.white` 等效，但它是语义色」。**实测为假**：`.primary` 映射到 `label` /
    /// `labelColor`，**macOS 26** 明暗两端 α = 0.8471
    /// （⚠️ **iOS 26 上实测 α = 1.0** ⇒ 偏差只在 macOS 腿上，见
    /// `MaskOpaqueTokenTests.primaryAlphaIsPlatformDependent`）⇒
    /// · `glowRing` 没有自己的 opacity 常量、本该是满的，实际峰值一直是 `0.847 × .tint`；
    /// · `lightBand` 的实际峰值是 `0.847 × bandOpacity` = 0.466 而不是常量声称的 0.55。
    ///
    /// ⚠️ **#276 正文只点了 `AnimatedMeshGradient` 与 `BeforeAfterSlider` 两处，
    /// 漏了本处**——而那两处的注释都援引「`ProcessingSweep.glowRing` 用的是同一个手法」
    /// 当先例，本处才是抄来抄去的源头。
    ///
    /// ⚠️ 判据钉的是**性质**（"峰值 α == 1、两端 α == 0"），不是"写没写 `.primary`"：
    /// 换成 `.contentPrimary`（同样是 `label`、同样 0.8471）照样判红。
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

        expectBitmapsEqual(Self.pixels(Self.canvas(progress: 1)), empty,
                "progress = 1 时还有彩纸 —— burst 结束后会永久残留")
        // ⚠️ **互锁**：中途必须画得出彩纸，否则上一条是恒真的。
        expectBitmapsDiffer(Self.pixels(Self.canvas(progress: 0.25)), empty,
                "progress = 0.25 都画不出彩纸 —— 上一条相等断言是恒真的")
        // Reduce Motion 静态层用的那一帧同样必须**看得见**（降级不是 no-op）。
        expectBitmapsDiffer(Self.pixels(Self.canvas(progress: ConfettiBurst.restingProgress)), empty,
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
        expectBitmapsDiffer(red, blue,
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
        // ⚠️ **非空断言先行**：两者同时为 `nil` 时 `==` 恒真、`!=` 也恒真，
        // 下面两条会一起变哑（上面 `red`/`blue` 有这条，这两个漏了）
        //——#252 PR #269 第 1 轮终审 S-3。
        #expect(explicitRedTint != nil && explicitBlueTint != nil,
                "显式色板渲染失败，下面两条断言会静默变绿")
        expectBitmapsEqual(explicitRedTint, explicitBlueTint,
                "给了显式色板还跟着 .tint 变 —— 调用方参数没有优先，取色多半绕过了 colors")
        // 且显式色板与"回落 .tint"必须真的画出不同的东西（否则上一条可以恒真）。
        expectBitmapsDiffer(explicitRedTint, red, "显式色板与回落 .tint 画出的东西一样 —— colors 参数没进渲染")

        // 取色函数层（与 `.spray` 共用同一实现）的契约同样钉住。
        #expect([Color]().particleColor(at: 0) == nil, "空色板必须回落到 .tint，而不是取某个具体色")
        #expect([Color.red, .blue].particleColor(at: 2) == .red, "非空色板必须按下标轮转")
    }

    // MARK: - 实际渲染路径（不是更里面的 ConfettiCanvas）

    /// ⚠️ **钉住的 burst 起帧**：`burstStart` 取**未来**时刻 ⇒ `ConfettiBurst.progress`
    /// 恒被钳到 0 ⇒ 无论什么时候渲染都是同一帧（所有彩纸叠在中心、不透明、未自转）。
    ///
    /// ⚠️ 这条是**相等断言**能成立的前提：`ConfettiLayer` 里的 `TimelineView` 读的是
    /// **真实当前时刻**，用 `.now - 0.5` 这类活相位时两次渲染必然落在不同进度上
    /// ⇒ 相等断言恒假、不等断言恒真（本文件头为 `lowPowerChangesRenderingAtSamePhase`
    /// 记的是同一条教训）。
    static var pinnedBurstStart: Date { .now.addingTimeInterval(3600) }

    /// ⚠️⚠️ **本条补的是 `.confetti(trigger:)` 的实际渲染路径**
    ///（#252 PR #269 第 1 轮终审 I-3）。
    ///
    /// 此前所有位图判据吃的都是更里面的 `ConfettiCanvas`，从 `ConfettiCore` 到
    /// `ConfettiLayer` 再到 `ConfettiCanvas` 的**接线**只由三条 `code.contains(...)`
    /// 字符串检查守着，而那三条既不覆盖 `progress:` 也不覆盖 `colors:`。
    /// 终审同时施加两枚变异（`ConfettiLayer.body` 的 `progress:` 写死成 `1`
    /// ⇒ 用户永远看不到彩纸；`colors:` 改成 `colors: []` ⇒ 公开参数变死参数），
    /// **42/42 仍然全绿**。
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

        // ① burst 进行中必须画得出彩纸。`progress:` 写死成 1 ⇒ 本条判红。
        let mid = Self.pixels(layer(.now.addingTimeInterval(-0.5)))
        #expect(mid != nil, "ConfettiLayer 渲染失败")
        expectBitmapsDiffer(mid, empty, "burst 中途 ConfettiLayer 什么都没画 —— progress 没有接到画布")

        // ② 终帧（burst 早已结束）必须一片不剩。这是**端到端**的，不是纯函数层。
        let terminal = Self.pixels(layer(.now.addingTimeInterval(-10)))
        #expect(terminal != nil, "ConfettiLayer 终帧渲染失败")
        expectBitmapsEqual(terminal, empty, "burst 结束后 ConfettiLayer 仍有残留")

        // ③ 空色板回落 `.tint`：同一层换 tint 必须画出不同的东西。
        let pinned = Self.pinnedBurstStart
        let red = Self.pixels(layer(pinned).tint(.red))
        let blue = Self.pixels(layer(pinned).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的不等断言会静默变绿")
        expectBitmapsDiffer(red, blue, "ConfettiLayer 的空色板没有跟随 .tint")

        // ④ 显式色板必须真的进渲染（`colors:` 不是死参数），且不再跟随 `.tint`。
        let green = Self.pixels(layer(pinned, colors: [.green]).tint(.red))
        let greenAgain = Self.pixels(layer(pinned, colors: [.green]).tint(.blue))
        #expect(green != nil && greenAgain != nil, "渲染失败，下面两条断言会静默变绿")
        expectBitmapsEqual(green, greenAgain, "给了显式色板还跟着 .tint 变 —— 取色绕过了 colors")
        expectBitmapsDiffer(green, red, "显式色板与回落 .tint 画出的东西一样 —— colors 没进渲染")
    }

    /// ⚠️⚠️ **`ConfettiCore` 本身**（`.confetti(trigger:)` 真正装上去的那个 modifier）
    /// 的渲染判据。上一条只覆盖 `ConfettiLayer`，从 `ConfettiCore.body` 到它的那段接线
    /// （`colors: self.colors` / `count:` / `presentation == .animated` 门控）仍然在射程外。
    ///
    /// ⚠️ 能渲染是因为 `ConfettiCore` 开了 `initialBurstStart` 这道**判据用的渲染缝**：
    /// `ImageRenderer` 下 `.task` 不跑 ⇒ `burstStart` 恒为 `nil` ⇒ 整条路径渲不出一个像素。
    /// 生产路径永远不传它（`.confetti(trigger:)` 不暴露这个参数）。
    ///
    /// ⚠️ **`\.scenePhaseOverride` 必须显式注入 `.active`**：单测里没有 `Scene`，
    /// 系统 `\.scenePhase` 的默认值不保证是 `.active`。
    @Test("ConfettiCore：能耗闸生效、burst 门控生效、colors 接得到画布")
    func confettiCoreRendersTheRealPath() {
        // ⚠️⚠️ **`fire: 0` 是承重的，不是随手写的**（本轮 iOS 腿判红后逐形态排查得到）。
        //
        // `.task(id:)` 在 **iOS Simulator 的 `ImageRenderer` 下是会跑的**（macOS 上不跑）
        // ⇒ `fire > 0` 时 `runBurst()` 会把 `burstStart` 改成 `.now`，
        // 于是同一个视图连渲 8 次得到 8 张**互不相同**的位图（实测差 4–22 字节，
        // `fire: 0` 时稳定为 0）。那会让下面所有相等断言在 iOS 腿上随机判红。
        // `fire == 0` 是 `TriggerRelay` 的初始态，`runBurst()` 见它即早退
        // ⇒ `burstStart` 永远保持 `initialBurstStart` ⇒ 整条渲染路径确定性可比。
        //
        // ⚠️ 这条差异**只有 iOS 腿看得见**——`CLAUDE.md`「`swift test` 全绿不等于
        // 验证过了，必须看 CI 的 xcodebuild iOS Simulator 腿」那条的又一个实例。
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
        // ⚠️ 基线取"同一个 modifier、只是没有 burst"——两侧包装层数逐字相同
        //（`eachEffectRestsClean` 的文档记着：层数不一致会全体等量偏差）。
        let resting = Self.pixels(core(nil))
        let bursting = Self.pixels(core(pinned))
        #expect(resting != nil && bursting != nil, "渲染失败，下面的断言会静默变绿")
        expectBitmapsDiffer(bursting, resting,
                "burst 进行中与静息态逐字节相同 —— .confetti 的渲染路径整条没接上")

        // ① NFR-7：注入 .background / .inactive ⇒ 与"没有 burst"逐字节相同（一个像素都不画）。
        for phase in [ScenePhase.background, .inactive] {
            let gated = Self.pixels(core(pinned, phase: phase))
            #expect(gated != nil, "\(phase) 下渲染失败")
            expectBitmapsEqual(gated, resting, "\(phase) 下彩纸层仍在画 —— NFR-7 的停摆没有落地")
        }

        // ② 公开的 `colors:` 一路接到画布：显式色板不跟 `.tint` 变，且与回落 `.tint` 不同。
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
    /// ⚠️ **本条如实登记覆盖限度**：`ImageRenderer` 拍的是静态帧，
    /// "两秒后那个节点真的消失了"这件事**没有**端到端的机器判据
    ///（`.task` 在 macOS 的 `ImageRenderer` 下不跑；iOS Simulator 下虽会被调度，
    /// 但落点不确定 ⇒ 拿它当判据只会得到一条随机判红的测试，
    /// 实测见 `confettiCoreRendersTheRealPath` 里 `fire: 0` 那段注释）。
    /// 能钉住的是三段结构、一条"没有 burst 时逐字节等于裸视图"的渲染判据（见下一条），
    /// 外加 `confettiLayerRendersTheRealPath` 的终帧判据
    ///（burst 早已结束 ⇒ 与空基线逐字节相同，这条是端到端的）。
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
        // ⚠️ **不强解包**：`TimelineView(` 若被整个删掉，`!` 会**崩掉测试进程**
        // 而不是干净判红（#252 PR #269 第 1 轮终审 S-3；上面 `layerRange` 已是这个写法）。
        guard let timelineRange = code.range(of: "TimelineView(") else {
            Issue.record("Confetti.swift 里找不到 TimelineView( —— 上一条计数判据应当已经判红")
            return
        }
        #expect(timelineRange.lowerBound > layerRange.lowerBound,
                "TimelineView 不在 ConfettiLayer 里")
        // ② `ConfettiLayer` 只在 `burstStart` 非空、且两道闸裁出 `.animated` 时被构造。
        // ⚠️ 门控形态在第 2 轮终审 C-1 后从 `if let …, presentation == .animated` 改成
        // `switch presentation` 的 `.animated` 分支里的 `if let`（单出口，理由见
        // `confettiKeepsOneShapeAcrossScenePhase`）——两个条件一条不少，只是位置换了。
        guard let animatedCase = code.range(of: "case .animated:") else {
            Issue.record("找不到 switch presentation 的 .animated 分支")
            return
        }
        // `.animated:` 之后的**第一行有效代码**必须就是那句 `if let`——中间不许插别的，
        // 否则"只在 burst 进行中才建 TimelineView"就多了一条没被看住的路径。
        let firstStatement = code[animatedCase.upperBound...]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        #expect(firstStatement == "if let start = self.burstStart {",
                "`.animated` 分支的第一句不是对 burstStart 的 `if let`（实为 `\(firstStatement)`）—— 双重门控被拆掉了一半")
        #expect(code.contains("switch presentation {"),
                "两道闸的结论不再由 switch presentation 单点裁决")
        // ③ 状态机等的是 `ConfettiBurst.duration`，并在其后清空。
        #expect(code.contains("try await Task.sleep(for: .seconds(ConfettiBurst.duration))"))
        #expect(code.contains("self.burstStart = nil"), "没有任何地方把 burstStart 清空 —— 层永不移除")
    }

    /// 从 `marker` 起，配对它之后第一个 `{` 到其闭合 `}`（含两端）的源码文本。
    ///
    /// ⚠️ **必须配对括号而不是"找下一个 `}`"**：后者会在第一个嵌套闭包处就截断，
    /// 而本文件要看的正是整段 `body` / 整个类型声明。
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

    /// 删掉 `marker` 及其后配对花括号区间（**所有**出现处），返回剩下的源码。
    ///
    /// ⚠️ 判据要问的是"**某个区间之外**还有没有 X"，而这类问题只能靠"把区间挖掉再看"
    /// 来回答——直接数出现次数会把区间内外混在一起。
    /// ⚠️ 找不到 `marker`（或它后面没有 `{`）时**原样返回**：这是有意的 fail-closed
    /// ——区间没被挖掉，区间内的东西会留在结果里、被调用方的断言抓住。
    static func removingRegion(after marker: String, in code: String) -> String {
        var out = code
        while let markerRange = out.range(of: marker),
              let region = Self.bracedRegion(after: marker, in: out),
              let regionRange = out.range(of: region, range: markerRange.lowerBound..<out.endIndex) {
            out.removeSubrange(markerRange.lowerBound..<regionRange.upperBound)
        }
        return out
    }

    /// ⚠️⚠️⚠️ **C-1 的判据**（#252 PR #269 第 2 轮终审）：钉住「后台往返不重放」
    /// 与「调用方内容子树不换身份」。
    ///
    /// ## 缺陷形态（第 1 批新引入的）
    ///
    /// `isReduced` 改成由 `presentation` 派生之后，它就**依赖 `scenePhase`** 了。
    /// 对开启 Reduce Motion 的用户：`.active` ⇒ `.resting` ⇒ 走 `guard !isReduced` 的
    /// 早退出口（静态庆祝层，**没有 `.task`**）；`.inactive` / `.background` ⇒ `.none`
    /// ⇒ 走主出口（`.task(id:)` + 空 overlay）。**每次后台往返 `content` 被包进底层类型
    /// 不同的两个 `AnyView`**，两条后果：庆祝重放（静态层是新插入实例，`@State` 复位、
    /// `.task(id: fire)` 重跑，而 `fire` 触发过就永远 `> 0`）、调用方整棵被修饰子树的
    /// `@State` / 动画 / `.task` 全部重置。
    ///
    /// ## 为什么是**源码结构**判据，以及它凭什么真能咬住
    ///
    /// ⚠️ **位图路走不通，不是偷懒**：`\.accessibilityReduceMotion` 不可注入（写它编译红），
    /// 缺陷只在 RM 开启时才出现；而且要观测的是**视图身份在一次状态变化前后是否保持**，
    /// `ImageRenderer` 拍的是**一帧静态图**，身份这件事它根本不成像。
    /// ⇒ 只能钉**形状**：把 `body` 的**顶层分支**封死（与下面第 4 条同一措辞——
    /// **顶层分支无路可走**）。
    ///
    /// ⚠️ **不是「`body` 只有一种形状，缺陷就无处可长」**（#252 PR #269 第 4 轮终审 S2-1）：
    /// 上一版这里逐字写着那句话，而它是过头话——分支挪进 `overlay` 闭包内部、
    /// 或挪进同文件的**兄弟类型**仍然写得出来，链尾追加 `.id(presentation)` 也写得出来。
    /// 那两条路分别由下面第 5 条（`.id(` × 0）与文件级的「除 `ConfettiCore` 外
    /// 不得声明 `@State`」接管。**本条的射程只到顶层分支，不多说一句。**
    ///
    /// 五条一起才封得住，缺一条都有逃逸位（逐条对应一枚真实变异）：
    /// · `content` × 1 —— 两个出口（`guard … else { return AnyView(content…) }`）
    ///   或 `@ViewBuilder` 的 `if/else` 都必须把 `content` 写两遍 ⇒ 判红；
    /// · `.task(` × 1 —— 堵"只把 `.task` 挂在其中一条路径上"（RM 路径此前正是**没有**它）；
    /// · `AnyView` × 0 —— 堵"用类型擦除在 `body` 顶层分支"这一整类写法；
    /// · `return` × 1 —— 堵上一条的漏网之鱼：`@ViewBuilder` 的隐式 `if/else` 不需要
    ///   `AnyView`，但它**没有** `return`（写了 `return` 就关掉 builder 变换、又需要
    ///   两侧类型一致 ⇒ 回到需要 `AnyView`）。两条合起来，顶层分支无路可走；
    /// · `.id(` × 0 —— 堵**显式身份覆盖**（第 4 轮终审 S2-1 的变异 A）：`presentation`
    ///   依赖 `scenePhase`，在链尾写 `.id(presentation)` 就是每次后台往返主动换掉
    ///   整棵被修饰子树的身份——**与 C-1 等价，且比它更彻底**（C-1 至少只换 `AnyView`
    ///   的底层类型，`.id` 是直接下令重建）。前四条对这枚变异**全绿**，实测过。
    ///
    /// 静态层那一半由后三条钉：它不得自带 `@State` / `.task(` / `fire`，
    /// 且必须由 `active` 参数驱动 —— 触发源回到 `.task(id: fire)` 是**编译失败**
    /// （初始化器签名变了，下面 `staticCelebrationIsDrivenByItsActiveParameter` 用的是
    /// `active:`），而"既留 `active:` 又偷偷加一个 `.task`"由这里的结构判据接住。
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
        // ⚠️ 第 5 条：**显式身份覆盖等价于 C-1**（理由见上面文档的第 5 条）。
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
        // ⚠️⚠️ **射程从「`ConfettiStaticCelebration` 声明内」扩到「除 `ConfettiCore` 外
        // 整个文件」**（#252 PR #269 第 4 轮终审 S2-1 的变异 B，评审有实证）：
        // 上面三条禁止只扫 `struct ConfettiStaticCelebration: View {` 的括号区间
        // ⇒ 把随 `presentation` 翻转的分支挪进同文件的**兄弟类型**
        //（如新写一个 `ConfettiOverlay: ViewModifier`，`@State` 与真正的身份翻转都在它里面），
        // 同时 `ConfettiCore.body` 里保留 `switch presentation {` 与 `.task(` 撑住上面五条
        // ⇒ 全绿，新类型完全不在射程内。
        // ⇒ 状态只许长在 `ConfettiCore` 上：它是本文件唯一挂着**恒在** `.task(id:)` 的类型，
        // 别处的 `@State` 必然随分支出现/消失而重建复位，正是 C-1 的成因。
        // ⚠️ `#Preview` 区间排除：`@Previewable @State` 是预览宿主的局部状态，不是视图成员。
        // ⚠️ **fail-closed**：`ConfettiCore` 声明找不到时区间删不掉，`burstStart` 那句
        // `@State` 会留在 `outsideCore` 里 ⇒ 判红，而不是静默变绿。
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

    /// C-1 的**渲染侧**一半：静态庆祝层画什么完全由传进来的 `active` 决定。
    ///
    /// ⚠️ 这条与上一条是互补的，不是重复：上一条钉"没有自带状态机"，本条钉
    /// "**确实**由参数驱动"——否则 `active` 可以是个死参数，结构判据看不出来。
    /// ⚠️ 且它让"把触发源改回 `.task(id: fire)`"变成**编译失败**（初始化器签名变了），
    /// 这是本仓能拿到的最硬的一种红。
    @Test("静态庆祝层是 active 的纯函数（active: false ⇒ 一个像素都不画）")
    func staticCelebrationIsDrivenByItsActiveParameter() {
        func layer(active: Bool, policy: EffectsRenderPolicy) -> Data? {
            Self.pixels(Self.framed(ConfettiStaticCelebration(
                active: active, strength: .regular, colors: [], policy: policy
            )))
        }
        let on = layer(active: true, policy: .full)
        let off = layer(active: false, policy: .full)
        // ⚠️ **互锁基线**：包装层数与上面两者**逐字相同**，只把粒子数打成 0
        //（`eachEffectRestsClean` 的文档：层数不一致会全体等量偏差）。
        let empty = layer(active: true, policy: .paused)
        #expect(on != nil && off != nil && empty != nil, "渲染失败，下面的断言会静默变绿")
        expectBitmapsDiffer(on, off,
                "静态庆祝层没有跟着 active 变 —— 它的触发源不是 ConfettiCore 的 burstStart")
        expectBitmapsDiffer(on, empty, "active: true 也什么都没画 —— 上一条是恒真的")
        expectBitmapsEqual(off, empty, "active: false 时静态层仍在画东西")
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
        // ⚠️ 第 2 轮终审 C-1 之后 RM 分支不再是 `guard !isReduced else { return AnyView(…) }`
        // 而是 `switch presentation` 的 `.resting` case（单出口，理由见
        // `confettiKeepsOneShapeAcrossScenePhase`）。
        guard let restingCase = code.range(of: "case .resting:"),
              let end = code.range(of: "case .animated:", range: restingCase.upperBound..<code.endIndex)
        else {
            Issue.record("找不到 Reduce Motion 的 .resting 分支")
            return
        }
        let branch = String(code[restingCase.upperBound..<end.lowerBound])
        #expect(branch.contains("ConfettiStaticCelebration("),
                "Reduce Motion 分支没有渲染静态庆祝层 —— 降级成了 no-op")
        // ⚠️ 静态层的触发源必须是 `burstStart`（C-1）：它自带 `.task(id: fire)` 时，
        // 后台往返把这一层移除再插回就等于重放一次已经结束的庆祝。
        #expect(branch.contains("active: self.burstStart != nil"),
                "静态庆祝层不是由 ConfettiCore 的 burstStart 驱动 —— 后台往返会重放")
        // 静态层用的那一帧真的画得出东西 —— 在 `terminalFrameDrawsNothing` 里已断言。
        #expect(ConfettiBurst.restingProgress > 0 && ConfettiBurst.restingProgress < 1,
                "静态庆祝层的相位落在了终帧或起帧上 —— 那一帧要么空要么全挤在中心")
        // 静态层不叠透明度脉冲（降级形态 2：两次反馈是错的）。
        #expect(!code.contains("reduceMotionFallback("),
                "Confetti 走的是降级形态 2，不该再叠 reduceMotionFallback 的脉冲")
    }
}
