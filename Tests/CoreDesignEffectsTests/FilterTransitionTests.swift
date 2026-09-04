import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #266：滤镜类转场（blur / filmExposure / snapshot / flicker）
//
// ⚠️⚠️ **本文件每一组判据都有一条"承重"断言，其余是它的非退化前置（互锁）。**
// 写下每条断言之前先问的是同一个问题：**这条断言在功能整个不工作时会不会照样绿？**
// 本仓已经三次栽在"绿而东西不工作"上（粒子从未在任何真实相位出现、滑块左右画反、
// 能耗闸把调用方内容整个吃掉），三次**都没有**被"测试是绿的"抓到。
//
// 本簇最可能重演的就是第一种：`TransitionPhase` 是 **3 case frozen enum**
//（`willAppear` / `identity` / `didDisappear`，`value` = `-1` / `0` / `1`）
// ⇒ `body(content:phase:)` 的可达进度只有 `{0, 1}`，而
// **过曝峰值 / 快门白场 / 每一次闪烁全部落在这两个值之外**。
// 若绘制层不 `Animatable`，SwiftUI 只插值滤镜的**输出**（0 → 0 / 1 → 0）
// ⇒ 三种效果一次都不会发生，而"纯函数返回值对不对"这一路判据**照样全绿**。
// ⇒ 承重的是 `*DrawsTheBlowOutMidFlight` / `*DrawsTheShutterMidFlight` /
// `flickerDrawsDifferentFramesMidFlight` 三条：它们把 SwiftUI 的插值步骤原样跑一遍，
// 再用位图证明那一帧确实与两个端点都不同。
//
// ⚠️ 两个 a11y 环境键（`\.accessibilityDimFlashingLights` /
// `\.accessibilityReduceMotion`）**都不可注入**（`.environment(...)` 对它们编译红，
// 实测两者皆然）⇒ 「档位真的被消费」只能走**纯函数 + 调用点源码判据**两条链，
// 形态照抄 `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`。

// ⚠️⚠️ **`.serialized` 不是装饰**（本轮实测）：本 suite 里多条判据靠
// `ImageRenderer` 的**逐字节相等**说话，而 `MicroInteractionAPITests.stablePixels`
// 的稳定性依赖"进程级暖机之后没有别的渲染插进两次取样之间"。
// 并行跑的时候实测出现过**同一条判据一次绿一次红**（`midFlight == direct` 在
// 单跑时绿、与其余 15 条并行时红），且整个 suite 耗时从 ~2 s 涨到 111 s
// ——两者同源：多个 `@MainActor` 测试在 `await` 点交错，彼此把对方的渲染栈状态改了。
// 这正是 `MicroInteractionAPITests.processWarmUp` 文档里记的那条
// 「Swift Testing 不保证测试顺序 ⇒ 绿不绿取决于当次调度」，只是换了个触发面。
@Suite("#266 滤镜类转场的相位、安全档位与降级契约", .serialized)
@MainActor
struct FilterTransitionTests {

    // MARK: - 公共 harness

    /// 本簇的五个源文件。**顺序即分类顺序**，下面多条判据对它做双向差集。
    static let clusterFiles: Set<String> = [
        "FilterTransitionSupport.swift", "BlurTransition.swift",
        "FilmExposureTransition.swift", "SnapshotTransition.swift", "FlickerTransition.swift",
    ]

    /// 走**曝光闸**（只读「减弱闪烁灯光」）的文件。
    static let exposureGatedFiles: Set<String> = [
        "FilmExposureTransition.swift", "SnapshotTransition.swift",
    ]

    /// 走**往复闸**（两个信号取「或」）的文件。
    static let oscillationGatedFiles: Set<String> = ["FlickerTransition.swift"]

    static func source(_ fileName: String) throws -> String {
        try TypewriterTextTests.source(fileName)
    }

    static func strippedSource(_ fileName: String) throws -> String {
        MicroInteractionReduceMotionGuard.stripComments(try Self.source(fileName))
    }

    static func squeezed(_ text: String) -> String {
        ParticleTransitionTests.squeezed(text)
    }

    /// 被测内容：一块有形状、有文字、有颜色的东西——纯色块在 `.saturation` /
    /// `.contrast` 下可能逐字节不变，那会让下面的"不等"断言恒真。
    static var probeContent: some View {
        VStack(spacing: CoreSpacing.xs) {
            Text("Roll")
            Image(systemName: "camera.aperture")
        }
        .padding(CoreSpacing.md)
        .frame(width: 160, height: 120)
        .background(Color.accent)
        .foregroundStyle(Color.contentOnAccent)
    }

    /// 四个 chrome 的统一构造入口（相位 → 一帧）。多条判据共用同一份。
    static let chromeCases: [(name: String, make: (TransitionPhase) -> AnyView)] = [
        ("blur", { AnyView(FilterTransitionTests.probeContent.modifier(
            BlurTransitionChrome(phase: $0, radius: BlurTransition.defaultRadius))) }),
        ("filmExposure", { AnyView(FilterTransitionTests.probeContent.modifier(
            FilmExposureChrome(phase: $0, intensity: FilmExposureTransition.defaultIntensity))) }),
        ("snapshot", { AnyView(FilterTransitionTests.probeContent.modifier(
            SnapshotChrome(phase: $0, intensity: SnapshotTransition.defaultIntensity))) }),
        ("flicker", { AnyView(FilterTransitionTests.probeContent.modifier(
            FlickerChrome(phase: $0, cycles: FlickerTransition.defaultCycles))) }),
    ]

    private static let warmUp: Bool = {
        for _ in 0..<8 {
            _ = MicroInteractionAPITests.stablePixels(
                Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: 0.55))
            )
        }
        return true
    }()

    /// ⚠️⚠️ **本 suite 的位图判据一律「同一条 `#Test` 内、同构视图、相邻取样」**，
    /// 这不是风格偏好，是本轮实测出来的**射程**：
    ///
    /// 实测（单跑 vs 与本 suite 其余判据同跑，两种都复现）——
    /// · `Self.pixels(Color.clear)` 单跑时是**全 0**，跟在别的判据后面跑时**不是全 0**；
    /// · `chrome(.willAppear)` 与 `chrome(.didDisappear)`（**同一个视图、同一批实参值**）
    ///   单跑时逐字节相同，跟在别的判据后面跑时不同。
    /// ⇒ `ImageRenderer` 在本进程里带着**跨调用的状态**，而 `stablePixels` 的
    /// 「渲一次丢掉、再渲一次取用」只覆盖到"同一个视图刚出现"那一档，
    /// 覆盖不到"前面渲过一大堆别的东西"。加长暖机（丢掉前三帧）实测**更糟**，不是解法。
    ///
    /// ⇒ 本 suite 的纪律：
    /// · **可以**比「同一个 Film 类型、只有实参不同」的两帧（相邻两次取样，实测稳定）；
    /// · **不可以**比「chrome vs film」「有滤镜 vs 无滤镜」「跨 `#Test` 复用的基线」
    ///   ——这三类的契约改由**源码判据**承担（`chromeBodiesArePinnedVerbatim`
    ///   逐字钉住每个 chrome 把什么喂给绘制层）与**纯函数判据**承担
    ///   （`identityIsNeutralForEveryFilter` / `endpointsFadeContentToZero`）。
    static func pixels(_ view: some View) -> Data? {
        _ = Self.warmUp
        return MicroInteractionAPITests.stablePixels(view.frame(width: 200, height: 160))
    }

    /// ⚠️⚠️ **位图的相等判断必须先算成 `Bool` 再进 `#expect`**（本轮实测的代价）。
    ///
    /// Swift Testing 会把 `#expect(a == b)` 里两个操作数**展开**进失败信息，而 `Data`
    /// 是 `Collection` ⇒ 它会逐元素算差异并整段打印。这里的操作数是 128 000 字节的位图
    /// ——实测一次失败产出 **450 KB** 输出，整轮 `swift test` 被拖到几分钟不结束、
    /// 失败原因（`\(name)` 是哪一种转场）被淹没在字节流里读不出来。
    /// ⇒ 本 suite 里**不允许**出现 `#expect(<Data> == <Data>)` 的写法，
    /// 一律先 `let same = Self.framesMatch(...)` 再 `#expect(same, "…")`。
    /// 判据：`noRawBitmapComparisonsInThisFile`（本文件源码自检）。
    static func framesMatch(_ lhs: Data?, _ rhs: Data?) -> Bool { lhs == rhs }

    /// SwiftUI 在一次动画事务里对 `Animatable` 做的**正是这三步**：
    /// 取两端的 `animatableData`、按 `amount` 插值、写回。本函数逐字复刻它。
    ///
    /// ⚠️ **走存在类型而不是具体类型**：去掉某个 Film 的 `Animatable` 一致性时，
    /// 判据是**运行时判红**（`as?` 返回 nil ⇒ `#require` 抛出），
    /// 而不是"整个测试 target 编译不过"——后者在变异实证里读不出是哪一条判据在咬。
    static func interpolatedFrame(from: Any, to: Any, amount: Double) -> AnyView? {
        guard let start = from as? (any ViewModifier & Animatable),
              let end = to as? (any Animatable) else { return nil }
        return Self.blend(start, towards: end, amount: amount)
    }

    private static func blend<M: ViewModifier & Animatable>(
        _ start: M, towards end: any Animatable, amount: Double
    ) -> AnyView? {
        guard let target = end.animatableData as? M.AnimatableData else { return nil }
        var out = start
        var data = out.animatableData
        data.interpolate(towards: target, amount: amount)
        out.animatableData = data
        return AnyView(Self.probeContent.modifier(out))
    }

    /// 两个**可达相位**给出的进度端点，判据一律取它们而不是随手写的字面量。
    static let appearingProgress = FilterTransitionPhase.progress(phase: .willAppear)   // 1
    static let identityProgress = FilterTransitionPhase.progress(phase: .identity)      // 0

    // MARK: - A. 相位契约与纯函数

    @Test("可达相位只有两个端点：identity ⇒ 0，进出两侧 ⇒ 1")
    func reachablePhasesAreOnlyTheEndpoints() {
        #expect(FilterTransitionPhase.progress(phase: .identity) == 0)
        #expect(FilterTransitionPhase.progress(phase: .willAppear) == 1)
        #expect(FilterTransitionPhase.progress(phase: .didDisappear) == 1)
    }

    @Test("identity 相位上四种转场的每一条滤镜都取中性值（常驻态不被转场改样子）")
    func identityIsNeutralForEveryFilter() {
        let p = Self.identityProgress
        // blur
        #expect(BlurFilm.radius(progress: p, maximum: 12) == 0)
        #expect(BlurFilm.contentOpacity(progress: p) == 1)
        // filmExposure
        #expect(FilmExposure.brightness(progress: p, peak: 0.55) == 0)
        #expect(FilmExposure.saturation(progress: p) == 1)
        #expect(FilmExposure.contrast(progress: p) == 1)
        #expect(FilmExposure.contentOpacity(progress: p) == 1)
        // snapshot
        #expect(SnapshotDevelop.brightness(progress: p, peak: 0.7) == 0)
        #expect(SnapshotDevelop.saturation(progress: p) == 1)
        #expect(SnapshotDevelop.contrast(progress: p) == 1)
        #expect(SnapshotDevelop.contentOpacity(progress: p) == 1)
        // flicker
        #expect(FlickerWave.opacity(progress: p, cycles: FlickerTransition.defaultCycles) == 1)

        // ⚠️⚠️ **互锁**：若这些函数**恒**返回中性值（例如有人把曲线整条注释掉），
        // 上面 11 条会全绿而四种转场什么都不做。中途必须有非中性值。
        #expect(BlurFilm.radius(progress: 0.5, maximum: 12) > 0, "blur 的半径恒为 0 —— 上面那条是恒真的")
        #expect(FilmExposure.brightness(progress: 0.5, peak: 0.55) > 0, "过曝恒为 0 —— 上面那条是恒真的")
        #expect(SnapshotDevelop.brightness(progress: SnapshotDevelop.shutterCenter, peak: 0.7) > 0,
                "白场恒为 0 —— 上面那条是恒真的")
        #expect(FlickerWave.opacity(progress: 1.0 / 6, cycles: 3) < 0.5, "闪烁恒不熄 —— 上面那条是恒真的")
    }

    @Test("退化输入（NaN / ∞ / 负数）不产生 NaN，也不越界")
    func degenerateInputsStayFinite() {
        let bad = [Double.nan, .infinity, -.infinity, -1, 2]
        for value in bad {
            #expect(FilterTransitionPhase.clamped01(value).isFinite)
            #expect((0...1).contains(FilterTransitionPhase.clamped01(value)))

            #expect(BlurFilm.radius(progress: value, maximum: 12).isFinite)
            #expect(BlurFilm.radius(progress: 0.5, maximum: CGFloat(value)).isFinite)
            #expect(BlurFilm.radius(progress: 0.5, maximum: CGFloat(value)) >= 0)
            #expect(BlurFilm.contentOpacity(progress: value).isFinite)

            #expect(FilmExposure.brightness(progress: value, peak: value).isFinite)
            #expect(FilmExposure.saturation(progress: value).isFinite)
            #expect(FilmExposure.contrast(progress: value).isFinite)
            #expect(FilmExposure.contentOpacity(progress: value).isFinite)

            #expect(SnapshotDevelop.brightness(progress: value, peak: value).isFinite)
            #expect(SnapshotDevelop.saturation(progress: value).isFinite)
            #expect(SnapshotDevelop.contrast(progress: value).isFinite)
            #expect(SnapshotDevelop.contentOpacity(progress: value).isFinite)

            #expect(FlickerWave.opacity(progress: value, cycles: 3).isFinite)
        }
        // 非法往复次数按 0 处理 ⇒ 退化为单调淡出，而不是 crash / NaN。
        for cycles in [0, -1, Int.min] {
            let out = FlickerWave.opacity(progress: 0.4, cycles: cycles)
            #expect(out.isFinite)
            #expect(abs(out - 0.6) < 1e-12, "非法 cycles 应退化为单调淡出 1 - p，实测 \(out)")
        }
    }

    // MARK: - B. blur：仿射 ⇒ 豁免 `Animatable`

    /// ⚠️⚠️ **这条判据守的是一张豁免**：`BlurTransitionChrome` 是全簇唯一不套
    /// `Animatable` 绘制层的，而那张豁免**只有在两条曲线仿射时才成立**
    ///（仿射 `f` 满足「插值输出 == 先插值再求值」）。
    /// 谁把 blur 的曲线改成非仿射（给模糊加个 ease-out 之类），本条当场判红
    /// ——那正是"必须补上 `Animatable`"的信号。
    @Test("blur 的两条曲线在进度上是仿射的（这是它豁免 Animatable 的前提）")
    func blurCurvesAreAffine() {
        func isAffine(_ f: (Double) -> Double) -> Bool {
            stride(from: 0.0, through: 0.8, by: 0.1).allSatisfy { a in
                let b = a + 0.2
                return abs(f((a + b) / 2) - (f(a) + f(b)) / 2) < 1e-12
            }
        }
        #expect(isAffine { Double(BlurFilm.radius(progress: $0, maximum: 12)) })
        #expect(isAffine { BlurFilm.contentOpacity(progress: $0) })

        // ⚠️ **互锁**：`isAffine` 必须真的能判假，否则上面两条毫无意义。
        // 另外三种曲线全部非仿射——这也正是它们必须 `Animatable` 的理由。
        #expect(!isAffine { FilmExposure.brightness(progress: $0, peak: 0.55) },
                "过曝曲线被判成仿射 —— isAffine 判不了假，上面两条是恒真的")
        #expect(!isAffine { SnapshotDevelop.brightness(progress: $0, peak: 0.7) })
        #expect(!isAffine { FlickerWave.opacity(progress: $0, cycles: 3) })
        #expect(!isAffine { FilmExposure.contentOpacity(progress: $0) })
    }

    // MARK: - C. 非单调曲线：峰值全部落在可达相位之外

    @Test("过曝峰值只出现在两个可达相位之间（不 Animatable 就一次都不会发生）")
    func filmExposureOnlyBlowsOutMidFlight() {
        let peak = FilmExposureTransition.defaultIntensity
        for phase in [TransitionPhase.willAppear, .identity, .didDisappear] {
            let p = FilterTransitionPhase.progress(phase: phase)
            #expect(FilmExposure.brightness(progress: p, peak: peak) == 0,
                    "相位 \(phase) 上就有过曝 —— 那一帧是端点，亮冲留在那里是一次 pop")
        }
        #expect(abs(FilmExposure.brightness(progress: 0.5, peak: peak) - peak) < 1e-12,
                "中点没有拿到满峰值 —— 过曝曲线不是它声称的那条")
    }

    @Test("快门白场只出现在窗口内，且两个可达相位上恒为 0")
    func snapshotOnlyFlashesInsideTheShutterWindow() {
        let peak = SnapshotTransition.defaultIntensity
        for phase in [TransitionPhase.willAppear, .identity, .didDisappear] {
            let p = FilterTransitionPhase.progress(phase: phase)
            #expect(SnapshotDevelop.brightness(progress: p, peak: peak) == 0)
        }
        #expect(abs(SnapshotDevelop.brightness(progress: SnapshotDevelop.shutterCenter, peak: peak) - peak) < 1e-12)
        // 窗外恒为 0（两侧各取一个点）。
        #expect(SnapshotDevelop.brightness(
            progress: SnapshotDevelop.shutterCenter - SnapshotDevelop.shutterWidth, peak: peak) == 0)
        #expect(SnapshotDevelop.brightness(
            progress: SnapshotDevelop.shutterCenter + SnapshotDevelop.shutterWidth, peak: peak) == 0)
        // 窗内非零（否则上面几条是恒真的）。
        #expect(SnapshotDevelop.brightness(
            progress: SnapshotDevelop.shutterCenter - SnapshotDevelop.shutterWidth / 2, peak: peak) > 0)
    }

    /// 密集采样：**存在一次上升**才叫往复。一条单调淡出永远不会出现上升。
    static func hasRise(_ f: (Double) -> Double, samples: Int = 400) -> Bool {
        var previous = f(0)
        for i in 1...samples {
            let value = f(Double(i) / Double(samples))
            if value > previous + 1e-9 { return true }
            previous = value
        }
        return false
    }

    @Test("flicker 真的在往复（曲线上存在上升段），压制后退化为单调淡出")
    func flickerActuallyOscillates() {
        #expect(Self.hasRise { FlickerWave.opacity(progress: $0, cycles: FlickerTransition.defaultCycles) },
                """
                默认参数下 flicker 的不透明度曲线**单调**——那就是一次普通淡出，
                「忽明忽暗」从未发生。
                """)
        // ⚠️⚠️ **往复次数必须经那道闸取，不能在这里写字面量 `0`**（本轮变异实证）。
        // 上一版这里写的是 `cycles: 0`——它只证明「喂 0 进去就不闪」，
        // 而**闸有没有真的给出 0** 是另一件事。实测：把
        // `FilterTransitionSafety.oscillationCycles(_:)` 的 `.calmed` 分支改成
        // `Swift.max(0, requested)`（压制档形同虚设、闪烁照旧），本条**照样绿**。
        // ⇒ 改从闸里取，两件事才连成一条链。
        let calmedCycles = FilterTransitionSafety.calmed
            .oscillationCycles(FlickerTransition.defaultCycles)
        #expect(!Self.hasRise { FlickerWave.opacity(progress: $0, cycles: calmedCycles) },
                "压制档下仍有上升段 —— 往复没有被真正去掉（闸给出的 cycles 是 \(calmedCycles)）")
        // 压制档就是单调淡出 `1 - p` 本身（逐点核对，不只是"没有上升"）。
        for i in 0...20 {
            let p = Double(i) / 20
            #expect(abs(FlickerWave.opacity(progress: p, cycles: calmedCycles) - (1 - p)) < 1e-12)
        }
    }

    // MARK: - D. 安全档位（两道闸）

    @Test("曝光闸：只看减弱闪烁灯光，且把峰值压到 WCAG 阈值以下但不为 0")
    func exposureGateClampsPeakBelowTheFlashThreshold() {
        #expect(FilterTransitionSafety.exposure(dimFlashingLights: false) == .full)
        #expect(FilterTransitionSafety.exposure(dimFlashingLights: true) == .calmed)

        let requested = 1.0
        let full = FilterTransitionSafety.full.exposurePeak(requested)
        let calmed = FilterTransitionSafety.calmed.exposurePeak(requested)
        #expect(full == 1)
        #expect(calmed <= FilterTransitionSafety.calmedBrightnessCeiling)
        #expect(FilterTransitionSafety.calmedBrightnessCeiling < 0.1,
                "上限没有落在 WCAG 2.3.1 通用闪光阈值（相对亮度变化 0.1）以下")
        #expect(calmed < full, "压制档与完整档给出同一个峰值 —— 这道闸没有效果")
        // ⚠️ **不是 no-op**：压制档仍保留一点曝光，抹到 0 会让这条转场只剩淡出。
        #expect(calmed > 0, "压制档把曝光抹成 0 —— 那不是降级，是删掉这条转场的全部内容")
        // 调用方**调不高**上限。
        #expect(FilterTransitionSafety.calmed.exposurePeak(10) <= FilterTransitionSafety.calmedBrightnessCeiling)
    }

    @Test("往复闸：两个信号任一开启即压制（四种组合逐个钉）")
    func oscillationGateTakesEitherSignal() {
        #expect(FilterTransitionSafety.oscillation(dimFlashingLights: false, reduceMotion: false) == .full)
        #expect(FilterTransitionSafety.oscillation(dimFlashingLights: true, reduceMotion: false) == .calmed,
                "只开「减弱闪烁灯光」的用户拿不到保护 —— 那正是 WCAG 2.3.1 点名的那批人")
        #expect(FilterTransitionSafety.oscillation(dimFlashingLights: false, reduceMotion: true) == .calmed,
                "只开「减弱动态效果」的用户拿不到保护")
        #expect(FilterTransitionSafety.oscillation(dimFlashingLights: true, reduceMotion: true) == .calmed)

        #expect(FilterTransitionSafety.full.oscillationCycles(3) == 3)
        #expect(FilterTransitionSafety.calmed.oscillationCycles(3) == 0)
        #expect(FilterTransitionSafety.calmed.oscillationCycles(99) == 0, "调用方能绕过这道闸")
        #expect(FilterTransitionSafety.full.oscillationCycles(-5) == 0)
    }

    // MARK: - E. 承重判据：中间帧真的画得出来

    /// ⚠️⚠️⚠️ **承重判据。** 上面 D 组全部只证「纯函数返回什么」——那一路在
    /// 「绘制层不 `Animatable` ⇒ 过曝一次都不会发生」这枚缺陷下**照样全绿**
    ///（`#253` 的 `ParticleTransition` 就是这么带着"绿"合进来的）。
    /// 本条把 SwiftUI 在动画事务里做的三步原样跑一遍，再用位图证明那一帧
    /// 与**两个可达端点都不同**。
    @Test("过曝真的画得出来：把两个可达相位插到中点，位图必须与两端都不同")
    func filmExposureDrawsTheBlowOutMidFlight() throws {
        let peak = FilmExposureTransition.defaultIntensity
        let start = FilmExposureFilm(progress: Self.appearingProgress, peak: peak)
        let end = FilmExposureFilm(progress: Self.identityProgress, peak: peak)

        let interpolated = try #require(
            Self.interpolatedFrame(from: start, to: end, amount: 0.5),
            """
            `FilmExposureFilm` 不是 `Animatable`（或它的 `animatableData` 不是 `Double`）——
            SwiftUI 于是只在两个可达相位上求值它，而那两个值上过曝**恒为 0**
            ⇒ 「胶片过曝」在用户面前永远不会发生。
            """
        )
        let midFlight = try #require(Self.pixels(interpolated), "渲染失败")
        let atIdentity = try #require(Self.pixels(Self.probeContent.modifier(end)), "渲染失败")
        let atAppearing = try #require(Self.pixels(Self.probeContent.modifier(start)), "渲染失败")

        let midMatchesIdentity = Self.framesMatch(midFlight, atIdentity)
        let midMatchesAppearing = Self.framesMatch(midFlight, atAppearing)
        let endpointsMatch = Self.framesMatch(atIdentity, atAppearing)
        #expect(!midMatchesIdentity, "插值出来的中间帧与恒等帧逐字节相同 —— 转场什么都没做")
        #expect(!midMatchesAppearing, "插值出来的中间帧与端点帧逐字节相同 —— 转场什么都没做")
        #expect(!endpointsMatch, "两个端点自己就一样 —— 上面两条是恒真的")

        // `animatableData` 必须**真的绑在 `progress` 上**：插出来的那一帧必须与
        // 「直接用中间进度构造」的那一帧逐字节相同，否则它绑在了某个不参与绘制的字段上。
        let direct = try #require(
            Self.pixels(Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: peak))), "渲染失败"
        )
        let matchesDirect = Self.framesMatch(midFlight, direct)
        #expect(matchesDirect, "`animatableData` 没有绑在 `progress` 上，插值改不动绘制")
    }

    /// 与上一条同形态，钉的是快门白场（峰值在 `shutterCenter = 0.75`）。
    @Test("快门白场真的画得出来：插到窗口中心，位图必须与两端都不同")
    func snapshotDrawsTheShutterMidFlight() throws {
        let peak = SnapshotTransition.defaultIntensity
        let start = SnapshotFilm(progress: Self.appearingProgress, peak: peak)
        let end = SnapshotFilm(progress: Self.identityProgress, peak: peak)
        // 端点 1 → 0，取 amount = 1 - shutterCenter ⇒ 中间进度恰为 shutterCenter。
        let amount = 1 - SnapshotDevelop.shutterCenter

        let interpolated = try #require(
            Self.interpolatedFrame(from: start, to: end, amount: amount),
            "`SnapshotFilm` 不是 `Animatable` —— 快门白场在用户面前永远不会发生"
        )
        let atShutter = try #require(Self.pixels(interpolated), "渲染失败")
        let atIdentity = try #require(Self.pixels(Self.probeContent.modifier(end)), "渲染失败")
        let atAppearing = try #require(Self.pixels(Self.probeContent.modifier(start)), "渲染失败")

        let shutterMatchesIdentity = Self.framesMatch(atShutter, atIdentity)
        let shutterMatchesAppearing = Self.framesMatch(atShutter, atAppearing)
        let endpointsMatch = Self.framesMatch(atIdentity, atAppearing)
        #expect(!shutterMatchesIdentity, "白场帧与恒等帧逐字节相同 —— 快门什么都没做")
        #expect(!shutterMatchesAppearing, "白场帧与端点帧逐字节相同 —— 快门什么都没做")
        #expect(!endpointsMatch, "两个端点自己就一样 —— 上面两条是恒真的")

        let direct = try #require(
            Self.pixels(Self.probeContent.modifier(
                SnapshotFilm(progress: SnapshotDevelop.shutterCenter, peak: peak))), "渲染失败"
        )
        let matchesDirect = Self.framesMatch(atShutter, direct)
        #expect(matchesDirect, "`animatableData` 没有绑在 `progress` 上")
    }

    /// ⚠️⚠️ **闪烁这条比另外两条更难判**：它的每一帧都只是"内容 + 某个不透明度"，
    /// 而**一次普通淡出的中间帧也长这样**。⇒ 光证"中间帧与端点不同"不够
    ///（那对单调淡出同样成立）。本条钉的是**往复**本身：
    /// 取相邻的两个中间进度，其中后一个的不透明度**更高**（曲线在那里上升），
    /// 于是"后一帧比前一帧更实"这件事只有真的在往复时才成立。
    @Test("闪烁真的在明暗往复：曲线上升段的两帧，后一帧必须比前一帧更实")
    func flickerDrawsDifferentFramesMidFlight() throws {
        let cycles = FlickerTransition.defaultCycles
        let start = FlickerFilm(progress: Self.appearingProgress, cycles: cycles)
        let end = FlickerFilm(progress: Self.identityProgress, cycles: cycles)

        // 曲线上真实存在的一段上升：默认 3 次往复下，1/6 是谷、1/3 是峰。
        let trough = 1.0 / 6
        let crest = 1.0 / 3
        #expect(FlickerWave.opacity(progress: trough, cycles: cycles)
                < FlickerWave.opacity(progress: crest, cycles: cycles),
                "选定的两点不在上升段上 —— 曲线换了，本判据的前提没了")

        let atTrough = try #require(
            Self.interpolatedFrame(from: start, to: end, amount: 1 - trough).flatMap(Self.pixels),
            "`FlickerFilm` 不是 `Animatable` —— 闪烁在用户面前永远不会发生，只剩一次普通淡出"
        )
        let atCrest = try #require(
            Self.interpolatedFrame(from: start, to: end, amount: 1 - crest).flatMap(Self.pixels),
            "渲染失败"
        )
        let troughMatchesCrest = Self.framesMatch(atTrough, atCrest)
        #expect(!troughMatchesCrest, "谷与峰画出同一帧 —— 往复没有发生")

        // ⚠️ 承重的一半：**同一条链在压制档下必须不再往复**。
        // 压制档（cycles = 0）是单调淡出 ⇒ 进度更大的那一帧一定更淡，
        // 而完整档在这两点上恰恰相反（进度更大的 crest 反而更实）。
        let calmedStart = FlickerFilm(progress: Self.appearingProgress, cycles: 0)
        let calmedEnd = FlickerFilm(progress: Self.identityProgress, cycles: 0)
        let calmedAtTrough = try #require(
            Self.interpolatedFrame(from: calmedStart, to: calmedEnd, amount: 1 - trough).flatMap(Self.pixels),
            "渲染失败"
        )
        let calmedMatchesFull = Self.framesMatch(calmedAtTrough, atTrough)
        #expect(!calmedMatchesFull, """
        压制档与完整档在同一进度上画出同一帧 —— `oscillationCycles(_:)` 的结论
        没有走到绘制层，那道 a11y 闸是摆设。
        """)
    }

    @Test("压制档真的改变了画出来的东西（曝光类两种）")
    func calmedExposureFramesDifferFromFullFrames() throws {
        // filmExposure：峰值进度 0.5。
        let fullPeak = FilterTransitionSafety.full.exposurePeak(FilmExposureTransition.defaultIntensity)
        let calmPeak = FilterTransitionSafety.calmed.exposurePeak(FilmExposureTransition.defaultIntensity)
        let full = try #require(
            Self.pixels(Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: fullPeak))), "渲染失败")
        let calmed = try #require(
            Self.pixels(Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: calmPeak))), "渲染失败")
        let exposureCalmMatchesFull = Self.framesMatch(full, calmed)
        #expect(!exposureCalmMatchesFull, "「减弱闪烁灯光」下的过曝帧与完整帧逐字节相同 —— 这道闸没有效果")

        // snapshot：峰值进度 shutterCenter。
        let sFull = FilterTransitionSafety.full.exposurePeak(SnapshotTransition.defaultIntensity)
        let sCalm = FilterTransitionSafety.calmed.exposurePeak(SnapshotTransition.defaultIntensity)
        let shutterFull = try #require(
            Self.pixels(Self.probeContent.modifier(
                SnapshotFilm(progress: SnapshotDevelop.shutterCenter, peak: sFull))), "渲染失败")
        let shutterCalm = try #require(
            Self.pixels(Self.probeContent.modifier(
                SnapshotFilm(progress: SnapshotDevelop.shutterCenter, peak: sCalm))), "渲染失败")
        let shutterCalmMatchesFull = Self.framesMatch(shutterFull, shutterCalm)
        #expect(!shutterCalmMatchesFull, "「减弱闪烁灯光」下的快门帧与完整帧逐字节相同")

        // ⚠️ **不是 no-op**：压制帧仍然与"完全没有曝光"那一帧不同。
        let noExposure = try #require(
            Self.pixels(Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: 0))), "渲染失败")
        let calmedMatchesNoExposure = Self.framesMatch(calmed, noExposure)
        #expect(!calmedMatchesNoExposure, "压制档把曝光抹成了 0 —— 那是删掉，不是降级")
    }

    /// 四种 chrome 在三个真实相位上都渲染得出来（非空）。
    ///
    /// ⚠️ **本条有意只判"渲得出来"，不判逐字节相等**——射程理由见 `pixels(_:)` 的文档。
    /// 「chrome 把什么喂给绘制层」由 `chromeBodiesArePinnedVerbatim` 逐字钉；
    /// 「两端淡到 0、identity 中性」由 `endpointsFadeContentToZero` /
    /// `identityIsNeutralForEveryFilter` 两条纯函数判据钉。
    @Test("四种 chrome 在三个真实相位上都渲染得出来")
    func everyChromeRendersAtEveryRealPhase() {
        for (name, make) in Self.chromeCases {
            for phase in [TransitionPhase.willAppear, .identity, .didDisappear] {
                #expect(Self.pixels(make(phase)) != nil, "\(name) 在相位 \(phase) 上渲染失败")
            }
        }
    }

    /// 四种转场在**两个可达端点**上内容不透明度必须恰为 0。
    ///
    /// ⚠️ 这是"转场结束不留半透明残影"的契约，也是 `identityIsNeutralForEveryFilter`
    /// 的另一端：一端完全可见、另一端完全消失，中间的形状才是这条转场自己的东西。
    @Test("两个端点相位上内容不透明度恰为 0（四种）")
    func endpointsFadeContentToZero() {
        for phase in [TransitionPhase.willAppear, TransitionPhase.didDisappear] {
            let p = FilterTransitionPhase.progress(phase: phase)
            #expect(BlurFilm.contentOpacity(progress: p) == 0)
            #expect(FilmExposure.contentOpacity(progress: p) == 0)
            #expect(SnapshotDevelop.contentOpacity(progress: p) == 0)
            #expect(FlickerWave.opacity(progress: p, cycles: FlickerTransition.defaultCycles) == 0)
        }
        // ⚠️ **互锁**：中途必须**不是** 0，否则上面四条对"整条转场恒为 0"同样成立。
        #expect(BlurFilm.contentOpacity(progress: 0.5) > 0)
        #expect(FilmExposure.contentOpacity(progress: 0.5) > 0)
        #expect(SnapshotDevelop.contentOpacity(progress: 0.5) > 0)
        #expect(FlickerWave.opacity(progress: 0.5, cycles: 2) > 0)
    }

    @Test("四个入口点都存在、可用点语法、可与内容组合")
    func allFourEntryPointsCompose() {
        let composed = VStack {
            Text("a").transition(.blur)
            Text("b").transition(.blur(radius: 4))
            Text("c").transition(.filmExposure)
            Text("d").transition(.filmExposure(intensity: 0.3))
            Text("e").transition(.snapshot)
            Text("f").transition(.snapshot(intensity: 0.4))
            Text("g").transition(.flicker)
            Text("h").transition(.flicker(cycles: 5))
        }
        #expect(Self.pixels(composed) != nil, "八个静态成员组合后渲染失败")
    }

    // MARK: - F. 源码判据（位图路证不到的那几条）

    /// 本簇的分类前提：**只改成像、不改几何**。
    ///
    /// ⚠️⚠️ **这条不是可有可无的自白**：五个文件因为「一个运动关键字都不出现」
    /// 而进了 `MicroInteractionReduceMotionGuard.approvedNoMotion` 名单
    /// ——那份名单的三条 RM 判据于是**整个跳过**它们。
    /// 「文件里没有运动关键字」在这里必须**不是逃逸位**：哪天有人往里加一处
    /// `offset(` / `scaleEffect(` / `Canvas(`，本条当场判红，逼人回到
    /// `FilterTransitionSupport.swift` 那张表重新裁决这条转场的 Reduce Motion 判据。
    /// 形态同 `BeforeAfterSliderTests.sliderPositionsByLayoutNotByTransform` /
    /// `CrossPlatformRenderTests.spheresDelegateToSharedSurface`。
    @Test("滤镜类五个文件只改成像、不改几何（一个运动关键字都不出现）")
    func filterClusterChangesImagingNotGeometry() throws {
        var offenders: [String] = []
        for name in Self.clusterFiles.sorted() {
            let code = try Self.strippedSource(name)
            for call in MicroInteractionReduceMotionGuard.motionCalls where code.contains(call) {
                offenders.append("\(name): \(call)")
            }
        }
        #expect(offenders.isEmpty, """
        滤镜类转场里出现了运动变换：\(offenders)
        —— 本簇「不改几何」的前提没了，`approvedNoMotion` 那张豁免随之失效。
        处置：回 `FilterTransitionSupport.swift` 的判据表重新裁决这条转场的
        Reduce Motion 形态，并把文件从 `approvedNoMotion` 挪进运动文件那一档。
        """)

        // ⚠️ **非空前置**：关键字表若为空，上面的循环一次都不执行 ⇒ 恒绿。
        #expect(MicroInteractionReduceMotionGuard.motionCalls.count > 8,
                "运动关键字表只有 \(MicroInteractionReduceMotionGuard.motionCalls.count) 条 —— 疑似被削过")
        // ⚠️ **双向差集**：本簇文件名单必须与 `approvedNoMotion` 里本簇那几条一致，
        // 且五个文件都真的在磁盘上（漏一个的话上面的循环少跑一轮、静默放行）。
        for name in Self.clusterFiles {
            #expect(MicroInteractionReduceMotionGuard.approvedNoMotion.contains(name),
                    "\(name) 不在 approvedNoMotion 名单里 —— 分类漂了")
            #expect((try? Self.source(name))?.isEmpty == false, "读不到 \(name)")
        }
    }

    /// ⚠️⚠️ **调用点判据**，形态照抄
    /// `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`。
    ///
    /// 纯函数判据（D 组）钉的是「给定两个 Bool，`FilterTransitionSafety` 返回什么」。
    /// **调用点是否真的用这个结论**是另一条链，而它在位图路上**零可见性**：
    /// 两个 a11y 环境键都不可注入 ⇒ 测试里恒为 `false` ⇒
    /// 「读 `safety`」与「调用点自己再判一遍」渲染出的像素**逐字节相同**。
    /// ⇒ 由本条接管：每个文件里那两个信号的每一次出现，都必须正好是喂给
    /// 共享裁决点的那一次；且不许**裸写**（去掉 `self.` 就能绕过按字面子串的计数）。
    @Test("两个 a11y 信号只许喂给共享裁决点，且名单与实际双向差集")
    func safetySignalsAreOnlyConsumedByTheSharedGate() throws {
        var actualExposure: Set<String> = []
        var actualOscillation: Set<String> = []
        var actualUngated: Set<String> = []

        for name in Self.clusterFiles.sorted() {
            let code = try Self.strippedSource(name)
            let squeezedCode = code.filter { !$0.isWhitespace }
            let usesExposure = squeezedCode.contains("FilterTransitionSafety.exposure(")
            let usesOscillation = squeezedCode.contains("FilterTransitionSafety.oscillation(")
            // ⚠️ `FilterTransitionSupport.swift` 是**定义**这两个函数的地方，
            // 它当然含有这两个名字，但它不是调用点 ⇒ 单独排除，且下面双向差集会守住它。
            if name == "FilterTransitionSupport.swift" { continue }
            if usesExposure { actualExposure.insert(name) }
            if usesOscillation { actualOscillation.insert(name) }
            if !usesExposure, !usesOscillation { actualUngated.insert(name) }

            let dimReads = ConfettiTests.occurrences(of: "self.dimFlashingLights", in: code)
            let motionReads = ConfettiTests.occurrences(of: "self.reduceMotion", in: code)
            let dimFed = ConfettiTests.occurrences(
                of: "dimFlashingLights: self.dimFlashingLights", in: code)
            let motionFed = ConfettiTests.occurrences(
                of: "reduceMotion: self.reduceMotion", in: code)

            #expect(dimReads == dimFed, """
            \(name) 里 `self.dimFlashingLights` 出现 \(dimReads) 次，只有 \(dimFed) 次是喂给
            `FilterTransitionSafety` 的 —— 多出来的那些是调用点自己又判了一遍，
            共享裁决点会被绕过（这正是 `#252` I-1 在能耗闸上的原形态）。
            """)
            #expect(motionReads == motionFed, """
            \(name) 里 `self.reduceMotion` 出现 \(motionReads) 次，只有 \(motionFed) 次是喂给
            `FilterTransitionSafety.oscillation(dimFlashingLights:reduceMotion:)` 的。
            """)

            // 裸写检查：`reduceMotion` 复用既有实现，`dimFlashingLights` 同形态一份。
            let strayMotion = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: code)
            #expect(strayMotion.isEmpty, "\(name) 里有裸写的 `reduceMotion`：\n\(strayMotion.joined(separator: "\n"))")
            let strayDim = Self.bareOccurrences(of: "dimFlashingLights", in: code)
            #expect(strayDim.isEmpty, """
            \(name) 里这些 `dimFlashingLights` 既不是声明、也不是实参标签、更不是
            `self.dimFlashingLights`：\n\(strayDim.joined(separator: "\n"))
            —— 去掉 `self.` 就能绕过上面按字面子串的计数。
            """)
        }

        #expect(actualExposure == Self.exposureGatedFiles,
                "曝光闸名单 \(Self.exposureGatedFiles.sorted()) 与实际 \(actualExposure.sorted()) 不一致")
        #expect(actualOscillation == Self.oscillationGatedFiles,
                "往复闸名单 \(Self.oscillationGatedFiles.sorted()) 与实际 \(actualOscillation.sorted()) 不一致")
        #expect(actualUngated == ["BlurTransition.swift"], """
        不走任何 a11y 闸的文件实际是 \(actualUngated.sorted())，与裁决不符。
        ⚠️ 全簇**只有 `blur`** 是「判过、结论是不降级」——理由逐字写在
        `BlurTransition` 的类型文档里（无光流、无亮度往复、降级等于删掉这条转场）。
        新增一个不读任何信号的滤镜转场必须先改那份裁决表，再改本名单。
        """)
    }

    /// `blur` 的「两个信号都不读」这条裁决，正面钉一遍。
    @Test("blur 不读任何 a11y 信号（这条裁决写在源码上，改它必须回来改判据）")
    func blurConsumesNoAccessibilitySignal() throws {
        let code = try Self.strippedSource("BlurTransition.swift")
        #expect(!code.contains("reduceMotion"), """
        `BlurTransition.swift` 读了 Reduce Motion —— 那与它的类型文档直接打架
        （「不读任何 a11y 信号」是那份文档给出的**结论**，不是遗漏）。
        要改这条裁决，先改 `FilterTransitionSupport.swift` 的判据表与
        `docs/components/blur-transition.md`，再改本判据。
        """)
        #expect(!code.contains("dimFlashingLights"), "`BlurTransition.swift` 读了「减弱闪烁灯光」")
        // ⚠️ **互锁**：另外三个文件必须真的读得到这两个名字，否则上面两条对
        // 「整个 target 都没这两个符号」同样成立。
        #expect(try Self.strippedSource("FlickerTransition.swift").contains("reduceMotion"))
        #expect(try Self.strippedSource("FilmExposureTransition.swift").contains("dimFlashingLights"))
    }

    /// ⚠️⚠️ **四个 chrome 的类型体逐字钉死。**
    ///
    /// 它替代的是位图路做不到的那一半（射程见 `pixels(_:)` 的文档）：
    /// 「chrome 到底把什么喂给绘制层」——进度是不是从相位算的、
    /// 安全档位的结论有没有真的传下去、有没有在这里偷偷加一个相位门控。
    /// `#253` 的 `ParticleTransition` 用一整轮终审证明了：只钉**片段**（某个 `let`
    /// 的字面形状、某个子串在不在）会被等价形态绕过，必须取**整个类型**当断言面。
    ///
    /// ⚠️ **代价照录**：本条是逐字的 ⇒ 给这四个类型换行、加一个绑定、调整缩进
    /// 都会判红，必须连同期望串一起改。这是有意的——这四个 `body` 是两道 a11y 闸
    /// 的唯一落点，宁可让它们的每一次改动都回到评审桌上。
    @Test("四个 chrome 的类型体逐字钉死（任何相位门控 / 绕闸都判红）")
    func chromeBodiesArePinnedVerbatim() throws {
        let expected: [(file: String, type: String, body: String)] = [
            ("BlurTransition.swift", "struct BlurTransitionChrome", #"""
            {
                let phase: TransitionPhase
                let radius: CGFloat

                func body(content: Content) -> some View {
                    let progress = FilterTransitionPhase.progress(phase: self.phase)
                    return content
                        .blur(radius: BlurFilm.radius(progress: progress, maximum: self.radius))
                        .opacity(BlurFilm.contentOpacity(progress: progress))
                }
            }
            """#),
            ("FilmExposureTransition.swift", "struct FilmExposureChrome", #"""
            {
                let phase: TransitionPhase
                let intensity: Double

                @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights

                func body(content: Content) -> some View {
                    let safety = FilterTransitionSafety.exposure(dimFlashingLights: self.dimFlashingLights)
                    return content.modifier(FilmExposureFilm(
                        progress: FilterTransitionPhase.progress(phase: self.phase),
                        peak: safety.exposurePeak(self.intensity)
                    ))
                }
            }
            """#),
            ("SnapshotTransition.swift", "struct SnapshotChrome", #"""
            {
                let phase: TransitionPhase
                let intensity: Double

                @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights

                func body(content: Content) -> some View {
                    let safety = FilterTransitionSafety.exposure(dimFlashingLights: self.dimFlashingLights)
                    return content.modifier(SnapshotFilm(
                        progress: FilterTransitionPhase.progress(phase: self.phase),
                        peak: safety.exposurePeak(self.intensity)
                    ))
                }
            }
            """#),
            ("FlickerTransition.swift", "struct FlickerChrome", #"""
            {
                let phase: TransitionPhase
                let cycles: Int

                @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights
                @Environment(\.accessibilityReduceMotion) private var reduceMotion

                func body(content: Content) -> some View {
                    let safety = FilterTransitionSafety.oscillation(
                        dimFlashingLights: self.dimFlashingLights,
                        reduceMotion: self.reduceMotion
                    )
                    return content.modifier(FlickerFilm(
                        progress: FilterTransitionPhase.progress(phase: self.phase),
                        cycles: safety.oscillationCycles(self.cycles)
                    ))
                }
            }
            """#),
        ]

        for (file, type, body) in expected {
            let code = try Self.strippedSource(file)
            #expect(ConfettiTests.occurrences(of: type, in: code) == 1,
                    "`\(type)` 不是恰好声明一次 —— 下面取到的可能不是被测的那个")
            guard let actual = ConfettiTests.bracedRegion(after: type, in: code) else {
                Issue.record("找不到 `\(type)` 的类型体 —— 下面的断言无从谈起")
                continue
            }
            #expect(Self.squeezed(actual) == Self.squeezed(body), """
            `\(type)` 与期望形态逐字不符。

            实测：\(Self.squeezed(actual))

            期望：\(Self.squeezed(body))
            """)
        }
    }

    /// 三个非单调曲线的绘制层必须真的 `Animatable`；`blur` 那一层**有意不是**。
    ///
    /// ⚠️ 走**运行时**判定（`as?`）而不是编译期约束：拿掉某个 `Animatable` 一致性时，
    /// 判据是这一条判红，而不是整个测试 target 编译不过——后者在变异实证里
    /// 读不出是哪一条判据在咬。
    @Test("三个 Film 是 Animatable，blur 的 chrome 有意不是")
    func animatableConformanceMatchesTheDecision() {
        let animatables: [(String, Any)] = [
            ("FilmExposureFilm", FilmExposureFilm(progress: 0.5, peak: 0.5)),
            ("SnapshotFilm", SnapshotFilm(progress: 0.5, peak: 0.5)),
            ("FlickerFilm", FlickerFilm(progress: 0.5, cycles: 3)),
        ]
        for (name, value) in animatables {
            #expect(value is any Animatable, """
            `\(name)` 不是 `Animatable` —— 它那条曲线是**非单调**的，
            SwiftUI 于是只在两个可达相位上求值它，而那两个值上效果恒为中性
            ⇒ 这条转场的主体在用户面前永远不会发生（`#253` `ParticleTransition` 的原形态）。
            """)
        }
        // `blur` 走仿射豁免（见 `blurCurvesAreAffine`）⇒ 不该有 `Animatable` 绘制层。
        let blurChrome: Any = BlurTransitionChrome(phase: .identity, radius: 12)
        #expect(!(blurChrome is any Animatable), """
        `BlurTransitionChrome` 变成了 `Animatable` —— 要么曲线不再仿射（那该判红的是
        `blurCurvesAreAffine`），要么是无谓地多了一层。两种情况都要回来重新裁决。
        """)
    }

    /// 本文件自己的纪律：位图比对必须先算成 `Bool`（理由见 `framesMatch(_:_:)` 的文档）。
    @Test("本文件不得把 Data 直接塞进 #expect（否则一次失败产出几百 KB 输出）")
    func noRawBitmapComparisonsInThisFile() throws {
        let code = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
        let stripped = MicroInteractionReduceMotionGuard.stripComments(code)
        // ⚠️ **needle 必须拼出来，不能写成一个字面量**：本判据读的是**本文件自己**，
        // 一个完整的字面量会命中它自己 ⇒ 恒红（实测过一次）。
        let needle = "#expect(" + "Self.framesMatch("
        let violates = stripped.contains(needle)
        #expect(!violates, """
        有人把 `Self.framesMatch(...)` 直接写进了 `#expect(...)`：Swift Testing 会把实参
        展开进失败信息，而实参是 128 000 字节的位图 ⇒ 一次失败产出几百 KB 输出、
        真正的失败原因读不出来（本轮实测过一次，450 KB）。先 `let` 成 `Bool` 再断言。
        """)
        // ⚠️ 非空前置：文件读不到时上面恒真。
        #expect(stripped.contains("framesMatch"), "读不到本文件源码 —— 上面那条是恒真的")
    }

    /// 词边界意义上**裸写**的某个标识符（返回 `行号: 该行源码`，1-based）。
    ///
    /// ⚠️ 与 `MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences` 同一形态，
    /// 只是把 needle 参数化——那份是硬编码 `reduceMotion` 的，本簇还要守
    /// `dimFlashingLights`。只接受三种形态：`var X` 声明、`X:` 实参标签、`self.X` 读取。
    static func bareOccurrences(of needle: String, in code: String) -> [String] {
        func isIdentifierChar(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        var out: [String] = []
        for (index, rawLine) in code.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = String(rawLine)
            var searchStart = line.startIndex
            while let r = line.range(of: needle, range: searchStart..<line.endIndex) {
                searchStart = r.upperBound
                if r.lowerBound > line.startIndex,
                   isIdentifierChar(line[line.index(before: r.lowerBound)]) { continue }
                if r.upperBound < line.endIndex, isIdentifierChar(line[r.upperBound]) { continue }
                let prefix = line[line.startIndex..<r.lowerBound]
                if prefix.hasSuffix("var ") { continue }
                if r.upperBound < line.endIndex, line[r.upperBound] == ":" { continue }
                if prefix.hasSuffix("self.") { continue }
                out.append("\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        return out
    }
}
