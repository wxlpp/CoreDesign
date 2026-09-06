import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #266：滤镜类转场（blur / filmExposure / snapshot / flicker）

@Suite("#266 滤镜类转场的相位、安全档位与降级契约", .serialized)
@MainActor
struct FilterTransitionTests {
    // MARK: - 公共 harness

    static let clusterFiles: Set<String> = [
        "FilterTransitionSupport.swift", "BlurTransition.swift",
        "FilmExposureTransition.swift", "SnapshotTransition.swift", "FlickerTransition.swift",
    ]

    static let exposureGatedFiles: Set<String> = [
        "FilmExposureTransition.swift", "SnapshotTransition.swift",
    ]

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

    static func pixels(_ view: some View) -> Data? {
        _ = Self.warmUp
        return MicroInteractionAPITests.stablePixels(view.frame(width: 200, height: 160))
    }

    static func framesMatch(_ lhs: Data?, _ rhs: Data?) -> Bool { lhs == rhs }

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

    static let appearingProgress = FilterTransitionPhase.progress(phase: .willAppear)
    static let identityProgress = FilterTransitionPhase.progress(phase: .identity)

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
        #expect(BlurFilm.radius(progress: p, maximum: 12) == 0)
        #expect(BlurFilm.contentOpacity(progress: p) == 1)
        #expect(FilmExposure.brightness(progress: p, peak: 0.55) == 0)
        #expect(FilmExposure.saturation(progress: p) == 1)
        #expect(FilmExposure.contrast(progress: p) == 1)
        #expect(FilmExposure.contentOpacity(progress: p) == 1)
        #expect(SnapshotDevelop.brightness(progress: p, peak: 0.7) == 0)
        #expect(SnapshotDevelop.saturation(progress: p) == 1)
        #expect(SnapshotDevelop.contrast(progress: p) == 1)
        #expect(SnapshotDevelop.contentOpacity(progress: p) == 1)
        #expect(FlickerWave.opacity(progress: p, cycles: FlickerTransition.defaultCycles) == 1)

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
        for cycles in [0, -1, Int.min] {
            let out = FlickerWave.opacity(progress: 0.4, cycles: cycles)
            #expect(out.isFinite)
            #expect(abs(out - 0.6) < 1e-12, "非法 cycles 应退化为单调淡出 1 - p，实测 \(out)")
        }
    }

    // MARK: - B. blur：仿射 ⇒ 豁免 `Animatable`

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
        #expect(SnapshotDevelop.brightness(
            progress: SnapshotDevelop.shutterCenter - SnapshotDevelop.shutterWidth, peak: peak) == 0)
        #expect(SnapshotDevelop.brightness(
            progress: SnapshotDevelop.shutterCenter + SnapshotDevelop.shutterWidth, peak: peak) == 0)
        #expect(SnapshotDevelop.brightness(
            progress: SnapshotDevelop.shutterCenter - SnapshotDevelop.shutterWidth / 2, peak: peak) > 0)
    }

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
        let calmedCycles = FilterTransitionSafety.calmed
            .oscillationCycles(FlickerTransition.defaultCycles)
        #expect(!Self.hasRise { FlickerWave.opacity(progress: $0, cycles: calmedCycles) },
                "压制档下仍有上升段 —— 往复没有被真正去掉（闸给出的 cycles 是 \(calmedCycles)）")
        for i in 0...20 {
            let p = Double(i) / 20
            #expect(abs(FlickerWave.opacity(progress: p, cycles: calmedCycles) - (1 - p)) < 1e-12)
        }
    }

    // MARK: - D. 安全档位（两道闸）

    @Test("曝光闸：只看减弱闪烁灯光，且把峰值压到策略上限以下但不为 0")
    func exposureGateClampsPeakToThePolicyCeiling() {
        #expect(FilterTransitionSafety.exposure(dimFlashingLights: false) == .full)
        #expect(FilterTransitionSafety.exposure(dimFlashingLights: true) == .calmed)

        let requested = 1.0
        let full = FilterTransitionSafety.full.exposurePeak(requested)
        let calmed = FilterTransitionSafety.calmed.exposurePeak(requested)
        #expect(full == 1)
        #expect(calmed <= FilterTransitionSafety.calmedBrightnessCeiling)
        #expect(calmed < full, "压制档与完整档给出同一个峰值 —— 这道闸没有效果")
        #expect(calmed > 0, "压制档把曝光抹成 0 —— 那不是降级，是删掉这条转场的全部内容")
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
        #expect(!midMatchesIdentity, "插值出来的中间帧与恒等帧逐字节相同 —— 转场什么都没做")
        #expect(!midMatchesAppearing, "插值出来的中间帧与端点帧逐字节相同 —— 转场什么都没做")

        #expect(FilmExposure.brightness(progress: 0.5, peak: peak) > 0,
                "中点没有过曝 —— 上面两条位图断言没有可判的东西")
        #expect(FilmExposure.brightness(progress: Self.identityProgress, peak: peak) == 0)
        #expect(FilmExposure.brightness(progress: Self.appearingProgress, peak: peak) == 0)
        let midOpacity = FilmExposure.contentOpacity(progress: 0.5)
        #expect(midOpacity != FilmExposure.contentOpacity(progress: Self.identityProgress))
        #expect(midOpacity != FilmExposure.contentOpacity(progress: Self.appearingProgress))

        let direct = try #require(
            Self.pixels(Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: peak))), "渲染失败"
        )
        let matchesDirect = Self.framesMatch(midFlight, direct)
        #expect(matchesDirect, "`animatableData` 没有绑在 `progress` 上，插值改不动绘制")
    }

    @Test("快门白场真的画得出来：插到窗口中心，位图必须与两端都不同")
    func snapshotDrawsTheShutterMidFlight() throws {
        let peak = SnapshotTransition.defaultIntensity
        let start = SnapshotFilm(progress: Self.appearingProgress, peak: peak)
        let end = SnapshotFilm(progress: Self.identityProgress, peak: peak)
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
        #expect(!shutterMatchesIdentity, "白场帧与恒等帧逐字节相同 —— 快门什么都没做")
        #expect(!shutterMatchesAppearing, "白场帧与端点帧逐字节相同 —— 快门什么都没做")

        #expect(SnapshotDevelop.brightness(progress: SnapshotDevelop.shutterCenter, peak: peak) > 0,
                "窗口中心没有白场 —— 上面两条位图断言没有可判的东西")
        #expect(SnapshotDevelop.brightness(progress: Self.identityProgress, peak: peak) == 0)
        #expect(SnapshotDevelop.brightness(progress: Self.appearingProgress, peak: peak) == 0)
        let shutterOpacity = SnapshotDevelop.contentOpacity(progress: SnapshotDevelop.shutterCenter)
        #expect(shutterOpacity != SnapshotDevelop.contentOpacity(progress: Self.identityProgress))
        #expect(shutterOpacity != SnapshotDevelop.contentOpacity(progress: Self.appearingProgress))

        let direct = try #require(
            Self.pixels(Self.probeContent.modifier(
                SnapshotFilm(progress: SnapshotDevelop.shutterCenter, peak: peak))), "渲染失败"
        )
        let matchesDirect = Self.framesMatch(atShutter, direct)
        #expect(matchesDirect, "`animatableData` 没有绑在 `progress` 上")
    }

    @Test("闪烁真的在明暗往复：曲线上升段的两帧，后一帧必须比前一帧更实")
    func flickerDrawsDifferentFramesMidFlight() throws {
        let cycles = FlickerTransition.defaultCycles
        let start = FlickerFilm(progress: Self.appearingProgress, cycles: cycles)
        let end = FlickerFilm(progress: Self.identityProgress, cycles: cycles)

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
        let fullPeak = FilterTransitionSafety.full.exposurePeak(FilmExposureTransition.defaultIntensity)
        let calmPeak = FilterTransitionSafety.calmed.exposurePeak(FilmExposureTransition.defaultIntensity)
        let full = try #require(
            Self.pixels(Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: fullPeak))), "渲染失败")
        let calmed = try #require(
            Self.pixels(Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: calmPeak))), "渲染失败")
        let exposureCalmMatchesFull = Self.framesMatch(full, calmed)
        #expect(!exposureCalmMatchesFull, "「减弱闪烁灯光」下的过曝帧与完整帧逐字节相同 —— 这道闸没有效果")

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

        let noExposure = try #require(
            Self.pixels(Self.probeContent.modifier(FilmExposureFilm(progress: 0.5, peak: 0))), "渲染失败")
        let calmedMatchesNoExposure = Self.framesMatch(calmed, noExposure)
        #expect(!calmedMatchesNoExposure, "压制档把曝光抹成了 0 —— 那是删掉，不是降级")
    }

    @Test("四种 chrome 在三个真实相位上都渲染得出来")
    func everyChromeRendersAtEveryRealPhase() {
        for (name, make) in Self.chromeCases {
            for phase in [TransitionPhase.willAppear, .identity, .didDisappear] {
                #expect(Self.pixels(make(phase)) != nil, "\(name) 在相位 \(phase) 上渲染失败")
            }
        }
    }

    @Test("两个端点相位上内容不透明度恰为 0（四种）")
    func endpointsFadeContentToZero() {
        for phase in [TransitionPhase.willAppear, TransitionPhase.didDisappear] {
            let p = FilterTransitionPhase.progress(phase: phase)
            #expect(BlurFilm.contentOpacity(progress: p) == 0)
            #expect(FilmExposure.contentOpacity(progress: p) == 0)
            #expect(SnapshotDevelop.contentOpacity(progress: p) == 0)
            #expect(FlickerWave.opacity(progress: p, cycles: FlickerTransition.defaultCycles) == 0)
        }
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

        #expect(MicroInteractionReduceMotionGuard.motionCalls.count > 8,
                "运动关键字表只有 \(MicroInteractionReduceMotionGuard.motionCalls.count) 条 —— 疑似被削过")
        for name in Self.clusterFiles {
            #expect(MicroInteractionReduceMotionGuard.approvedNoMotion.contains(name),
                    "\(name) 不在 approvedNoMotion 名单里 —— 分类漂了")
            #expect((try? Self.source(name))?.isEmpty == false, "读不到 \(name)")
        }
    }

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

    @Test("blur 不读任何 a11y 信号（这条裁决写在源码上，改它必须回来改判据）")
    func blurConsumesNoAccessibilitySignal() throws {
        let code = try Self.strippedSource("BlurTransition.swift")
        #expect(!code.contains("accessibilityReduceMotion"), """
        `BlurTransition.swift` 读了 Reduce Motion —— 那与它的类型文档直接打架
        （「不读任何 a11y 信号」是那份文档给出的**结论**，不是遗漏）。
        要改这条裁决，先改 `FilterTransitionSupport.swift` 的判据表与
        `docs/components/blur-transition.md`，再改本判据。
        """)
        #expect(!code.contains("accessibilityDimFlashingLights"),
                "`BlurTransition.swift` 读了「减弱闪烁灯光」")
        #expect(try Self.strippedSource("FlickerTransition.swift").contains("accessibilityReduceMotion"))
        #expect(try Self.strippedSource("FilmExposureTransition.swift")
            .contains("accessibilityDimFlashingLights"))
    }

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
                    let cycles = safety.oscillationCycles(self.cycles)
                    return content
                        .modifier(FlickerFilm(
                            progress: FilterTransitionPhase.progress(phase: self.phase),
                            cycles: cycles
                        ))
                        .animation(.easeInOut(duration: FlickerPace.duration(cycles: cycles)), value: self.phase)
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

    @Test("四个 Transition 类型体与四个入口点 extension 逐字钉死（整层被绕过也判红）")
    func transitionBodiesAndEntryPointsArePinnedVerbatim() throws {
        let expected: [(file: String, marker: String, body: String)] = [
            ("BlurTransition.swift", "public struct BlurTransition: Transition", #"""
            {
                public let radius: CGFloat
                public nonisolated static let defaultRadius: CGFloat = 12
                public nonisolated static let properties = TransitionProperties(hasMotion: false)
                public init(radius: CGFloat = BlurTransition.defaultRadius) {
                    self.radius = radius
                }
                public func body(content: Content, phase: TransitionPhase) -> some View {
                    content.modifier(BlurTransitionChrome(phase: phase, radius: self.radius))
                }
            }
            """#),
            ("BlurTransition.swift", "public extension Transition where Self == BlurTransition", #"""
            {
                static var blur: BlurTransition { BlurTransition() }
                static func blur(radius: CGFloat = BlurTransition.defaultRadius) -> BlurTransition {
                    BlurTransition(radius: radius)
                }
            }
            """#),
            ("FilmExposureTransition.swift", "public struct FilmExposureTransition: Transition", #"""
            {
                public let intensity: Double
                public nonisolated static let defaultIntensity: Double = 0.55
                public nonisolated static let properties = TransitionProperties(hasMotion: false)
                public init(intensity: Double = FilmExposureTransition.defaultIntensity) {
                    self.intensity = intensity
                }
                public func body(content: Content, phase: TransitionPhase) -> some View {
                    content.modifier(FilmExposureChrome(phase: phase, intensity: self.intensity))
                }
            }
            """#),
            ("FilmExposureTransition.swift",
             "public extension Transition where Self == FilmExposureTransition", #"""
            {
                static var filmExposure: FilmExposureTransition { FilmExposureTransition() }
                static func filmExposure(
                    intensity: Double = FilmExposureTransition.defaultIntensity
                ) -> FilmExposureTransition {
                    FilmExposureTransition(intensity: intensity)
                }
            }
            """#),
            ("SnapshotTransition.swift", "public struct SnapshotTransition: Transition", #"""
            {
                public let intensity: Double
                public nonisolated static let defaultIntensity: Double = 0.7
                public nonisolated static let properties = TransitionProperties(hasMotion: false)
                public init(intensity: Double = SnapshotTransition.defaultIntensity) {
                    self.intensity = intensity
                }
                public func body(content: Content, phase: TransitionPhase) -> some View {
                    content.modifier(SnapshotChrome(phase: phase, intensity: self.intensity))
                }
            }
            """#),
            ("SnapshotTransition.swift",
             "public extension Transition where Self == SnapshotTransition", #"""
            {
                static var snapshot: SnapshotTransition { SnapshotTransition() }
                static func snapshot(
                    intensity: Double = SnapshotTransition.defaultIntensity
                ) -> SnapshotTransition {
                    SnapshotTransition(intensity: intensity)
                }
            }
            """#),
            ("FlickerTransition.swift", "public struct FlickerTransition: Transition", #"""
            {
                public let cycles: Int
                public nonisolated static let defaultCycles: Int = 3
                public nonisolated static let properties = TransitionProperties(hasMotion: false)
                public init(cycles: Int = FlickerTransition.defaultCycles) {
                    self.cycles = cycles
                }
                public func body(content: Content, phase: TransitionPhase) -> some View {
                    content.modifier(FlickerChrome(phase: phase, cycles: self.cycles))
                }
            }
            """#),
            ("FlickerTransition.swift",
             "public extension Transition where Self == FlickerTransition", #"""
            {
                static var flicker: FlickerTransition { FlickerTransition() }
                static func flicker(cycles: Int = FlickerTransition.defaultCycles) -> FlickerTransition {
                    FlickerTransition(cycles: cycles)
                }
            }
            """#),
        ]

        for (file, marker, body) in expected {
            let code = try Self.strippedSource(file)
            #expect(ConfettiTests.occurrences(of: marker, in: code) == 1,
                    "`\(marker)` 不是恰好出现一次 —— 下面取到的可能不是被测的那个")
            guard let actual = ConfettiTests.bracedRegion(after: marker, in: code) else {
                Issue.record("找不到 `\(marker)` 的区间 —— 下面的断言无从谈起")
                continue
            }
            #expect(Self.squeezed(actual) == Self.squeezed(body), """
            `\(marker)` 与期望形态逐字不符。

            实测：\(Self.squeezed(actual))

            期望：\(Self.squeezed(body))
            """)
        }
        #expect(expected.count == 8, "期望表只剩 \(expected.count) 条 —— 第 1 层有区间没被钉住")
    }

    @Test("两个 a11y 环境属性只许出现在被逐字钉住的四个 chrome 类型体内")
    func accessibilityKeyPathsLiveOnlyInsideThePinnedChromes() throws {
        let dimKeyPath = "accessibilityDimFlashingLights"
        let motionKeyPath = "accessibilityReduceMotion"
        let pinnedChromes = [
            "struct BlurTransitionChrome", "struct FilmExposureChrome",
            "struct SnapshotChrome", "struct FlickerChrome",
        ]
        var totalDim = 0, totalMotion = 0
        var strayDim: [String] = [], strayMotion: [String] = []

        for name in Self.clusterFiles.sorted() {
            let code = try Self.strippedSource(name)
            totalDim += ConfettiTests.occurrences(of: dimKeyPath, in: code)
            totalMotion += ConfettiTests.occurrences(of: motionKeyPath, in: code)

            var outside = code
            for type in pinnedChromes { outside = ConfettiTests.removingRegion(after: type, in: outside) }
            let dimOutside = ConfettiTests.occurrences(of: dimKeyPath, in: outside)
            let motionOutside = ConfettiTests.occurrences(of: motionKeyPath, in: outside)
            if dimOutside > 0 { strayDim.append("\(name): \(dimOutside) 处") }
            if motionOutside > 0 { strayMotion.append("\(name): \(motionOutside) 处") }
        }

        #expect(strayDim.isEmpty, """
        这些地方在被逐字钉住的四个 chrome **之外**读了 `\(dimKeyPath)`：\(strayDim)
        —— 绘制层（或任何相邻类型）自己再读一遍原始信号，就能把共享闸的结论反过来，
        而按变量名计数的 `safetySignalsAreOnlyConsumedByTheSharedGate` 对此**零可见性**
        （改个变量名两侧计数都归 0）。
        """)
        #expect(strayMotion.isEmpty, "这些地方在四个 chrome 之外读了 `\(motionKeyPath)`：\(strayMotion)")

        #expect(totalDim == 3, """
        全簇 `\(dimKeyPath)` 实测 \(totalDim) 处，裁决表说 3 处
        （`FilmExposureChrome` / `SnapshotChrome` / `FlickerChrome` 各一）。
        多出来的那些没有被任何逐字判据钉住；少了的那几个说明某条转场不再读这个信号
        —— 两种都要回 `FilterTransitionSupport.swift` 的裁决表重判。
        """)
        #expect(totalMotion == 1, """
        全簇 `\(motionKeyPath)` 实测 \(totalMotion) 处，裁决表说 1 处（只有 `FlickerChrome`）。
        """)
    }

    private struct DefaultPropertiesProbe: Transition {
        func body(content: Content, phase: TransitionPhase) -> some View { content }
    }

    @Test("四种转场都显式退出框架的 Reduce Motion 替换（hasMotion == false）")
    func everyTransitionOptsOutOfTheFrameworkMotionSubstitution() {
        let note = """
        —— `Transition.properties` 默认 `hasMotion == true`，其语义是「Reduce Motion 开启时
        把这条转场整个替换成 opacity」。不显式声明 `false` 的话，四种转场的裁决表、
        类型文档与 `docs/components/*.md` 在运行时**全部是假的**。
        """
        #expect(BlurTransition.properties.hasMotion == false, "`blur` 没有退出框架替换 \(note)")
        #expect(FilmExposureTransition.properties.hasMotion == false, "`filmExposure` 没有退出框架替换 \(note)")
        #expect(SnapshotTransition.properties.hasMotion == false, "`snapshot` 没有退出框架替换 \(note)")
        #expect(FlickerTransition.properties.hasMotion == false, """
        `flicker` 没有退出框架替换 \(note)
        ⚠️ 它取 `false` 是一次**显式裁决**（留 `true` 会让那道手写闸在 Reduce Motion 路径上
        变成死代码），两条路的权衡逐字写在 `FilterTransitionSupport.swift` 的
        《`TransitionProperties.hasMotion`》一节。要改这一位，先改那一节。
        """)

        #expect(Self.DefaultPropertiesProbe.properties.hasMotion, """
        `Transition.properties` 的协议默认值不再是 `hasMotion == true`
        —— 上面四条 `== false` 于是不再证明任何事（"显式声明"与"什么都没写"不可分辨）。
        """)
    }

    @Test("flicker 自己钉死时长：任何 cycles 下的感知频率都在 WCAG 的 3 次/秒线下")
    func flickerPaceStaysUnderTheFlashRateLimit() {
        #expect(FlickerPace.maximumFlashesPerSecond < 3,
                "本簇给自己定的速率上界 \(FlickerPace.maximumFlashesPerSecond) 没有落在 WCAG 2.3.1 的 3 次/秒线下")
        for cycles in [1, 2, 3, 4, 8, 20, 100] {
            let duration = FlickerPace.duration(cycles: cycles)
            #expect(duration > 0)
            let rate = Double(cycles) / duration
            #expect(rate <= FlickerPace.maximumFlashesPerSecond + 1e-12,
                    "cycles = \(cycles) 时感知频率 \(rate) 次/秒，超过上界 \(FlickerPace.maximumFlashesPerSecond)")
        }
        #expect(abs(FlickerPace.duration(cycles: FlickerTransition.defaultCycles) - 1.2) < 1e-12,
                "默认往复次数下的时长变了 —— 默认路径的速率账要重算")
        #expect(FlickerPace.duration(cycles: 0) == FlickerPace.calmedDuration)
        #expect(FlickerPace.calmedDuration > 0, "压制档时长为 0 —— 那不是淡出，是硬跳变")
        #expect(FlickerPace.duration(cycles: -5) == FlickerPace.calmedDuration)
        #expect(FlickerPace.duration(cycles: Int.min).isFinite)
        #expect(FlickerPace.duration(cycles: 20) > FlickerPace.duration(cycles: 3))
        #expect(FlickerPace.duration(cycles: 1000) == 400,
                "`duration(cycles: 1000)` 不再是 400 秒 —— 要么加了钳位，要么速率上界变了，两种都要回 `FlickerPace` 重判")
    }

    @Test("本文件的位图取样只许经本地 harness，不许直调底层 stablePixels")
    func bitmapAssertionsAllGoThroughTheLocalHarness() throws {
        let code = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
        let stripped = MicroInteractionReduceMotionGuard.stripComments(code)
        let bareCall = ".stablePixels" + "("
        let warmUpMarker = "private static let " + "warmUp"
        let pixelsMarker = "static func " + "pixels(_ view:"

        #expect(ConfettiTests.occurrences(of: bareCall, in: stripped) == 2, """
        本文件里直调底层取样的地方实测 \(ConfettiTests.occurrences(of: bareCall, in: stripped)) 处，
        应当恰好 2 处（形态级暖机 1 处 + `pixels(_:)` 这道漏斗 1 处）。
        """)
        var outside = stripped
        outside = ConfettiTests.removingRegion(after: warmUpMarker, in: outside)
        outside = ConfettiTests.removingRegion(after: pixelsMarker, in: outside)
        #expect(!outside.contains(bareCall), """
        暖机与 `pixels(_:)` 之外还有地方直调底层取样 —— 那条判据静默丢掉了形态级暖机。
        """)
        #expect(stripped.contains(bareCall), "读不到本文件源码 —— 上面那条是恒真的")
        #expect(stripped.contains(warmUpMarker) && stripped.contains(pixelsMarker),
                "两个 marker 里有已经改名的 —— `removingRegion` 会原样返回，判据形同虚设")
    }

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
        let blurChrome: Any = BlurTransitionChrome(phase: .identity, radius: 12)
        #expect(!(blurChrome is any Animatable), """
        `BlurTransitionChrome` 变成了 `Animatable` —— 要么曲线不再仿射（那该判红的是
        `blurCurvesAreAffine`），要么是无谓地多了一层。两种情况都要回来重新裁决。
        """)
    }

    @Test("本文件不得把 Data 直接塞进 #expect（否则一次失败产出几百 KB 输出）")
    func noRawBitmapComparisonsInThisFile() throws {
        let code = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
        let stripped = MicroInteractionReduceMotionGuard.stripComments(code)
        let needle = "#expect(" + "Self.framesMatch("
        let violates = stripped.contains(needle)
        #expect(!violates, """
        有人把 `Self.framesMatch(...)` 直接写进了 `#expect(...)`：Swift Testing 会把实参
        展开进失败信息，而实参是 128 000 字节的位图 ⇒ 一次失败产出几百 KB 输出、
        真正的失败原因读不出来（本轮实测过一次，450 KB）。先 `let` 成 `Bool` 再断言。
        """)
        #expect(stripped.contains("framesMatch"), "读不到本文件源码 —— 上面那条是恒真的")
    }

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
