import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #254：跨平台改造（OrbitingLogos / DotSphere / CharSphere / FullScreenButton）

// MARK: - 球面几何（DotSphere / CharSphere 共用）

@Suite("球面投影的纯几何契约")
struct SphereFieldTests {
    @Test("Vogel 螺旋点全部落在单位球面上")
    func unitPointsLieOnTheUnitSphere() {
        for count in [1, 2, 7, 240, 800] {
            for index in 0..<count {
                let p = SphereField.unitPoint(index: index, count: count)
                let length = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
                #expect(abs(length - 1) < 1e-9,
                        "count=\(count) index=\(index) 的点不在单位球面上：|p|=\(length)")
            }
        }
    }

    @Test("y 从 +1 单调降到 −1（球面被均匀铺满，不是全挤在一层）")
    func elevationsAreMonotonic() {
        let count = 64
        let ys = (0..<count).map { SphereField.unitPoint(index: $0, count: count).y }
        #expect(abs(ys.first! - 1) < 1e-9)
        #expect(abs(ys.last! + 1) < 1e-9)
        for (a, b) in zip(ys, ys.dropFirst()) { #expect(a > b, "y 不单调：\(a) → \(b)") }
    }

    @Test("退化输入：单点落在赤道、不产生 NaN")
    func singlePointDoesNotDivideByZero() {
        let p = SphereField.unitPoint(index: 0, count: 1)
        #expect(!p.x.isNaN && !p.y.isNaN && !p.z.isNaN)
        #expect(p.y == 0)
        let over = SphereField.unitPoint(index: 99, count: 1)
        #expect(!over.x.isNaN && !over.y.isNaN && !over.z.isNaN)
    }

    @Test("点数被钳在 0...limit（负数与超限都不越界）")
    func countIsClamped() {
        #expect(SphereField.clamped(count: -5, limit: 100) == 0)
        #expect(SphereField.clamped(count: 0, limit: 100) == 0)
        #expect(SphereField.clamped(count: 37, limit: 100) == 37)
        #expect(SphereField.clamped(count: 10_000, limit: 100) == 100)
    }

    @Test("绕 Y 轴旋转保长、半圈把 z 翻到对面")
    func spinPreservesLength() {
        let p = SIMD3<Double>(0.3, 0.5, 0.8)
        for turns in [0.0, 0.125, 0.5, 0.75, 1.0] {
            let q = SphereField.spun(p, byTurns: turns)
            let lp = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
            let lq = (q.x * q.x + q.y * q.y + q.z * q.z).squareRoot()
            #expect(abs(lp - lq) < 1e-9, "turns=\(turns) 旋转改变了长度")
            #expect(abs(q.y - p.y) < 1e-9, "绕 Y 轴旋转不该动 y")
        }
        let half = SphereField.spun(p, byTurns: 0.5)
        #expect(abs(half.z + p.z) < 1e-9, "半圈之后 z 应当翻到对面")
        let full = SphereField.spun(p, byTurns: 1)
        #expect(abs(full.z - p.z) < 1e-9, "整圈之后应当回到原处")
    }

    @Test("相位由时刻取模得到，落在 [0, 1) 且周期非法时不发散")
    func phaseIsPeriodic() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        #expect(SphereField.phase(at: base, period: 8) == 0)
        #expect(abs(SphereField.phase(at: base.addingTimeInterval(2), period: 8) - 0.25) < 1e-12)
        #expect(abs(SphereField.phase(at: base.addingTimeInterval(10), period: 8) - 0.25) < 1e-12)
        for period in [0.0, -3.0] {
            let p = SphereField.phase(at: base.addingTimeInterval(3), period: period)
            #expect(p == 0, "period=\(period) 应当退化为静止而不是 NaN")
        }
        let p = SphereField.phase(at: base.addingTimeInterval(-2), period: 8)
        #expect(p >= 0 && p < 1)
    }

    @Test("透视：近的点放大、远的点缩小，且不会除零")
    func perspectiveScalesWithDepth() {
        let near = SphereField.project(SIMD3(0, 0, -1), worldRadius: 100, center: .zero)
        let far = SphereField.project(SIMD3(0, 0, 1), worldRadius: 100, center: .zero)
        #expect(near.depth > 1, "近侧应当放大")
        #expect(far.depth < 1, "远侧应当缩小")
        #expect(near.depth > far.depth)
        let degenerate = SphereField.project(SIMD3(0, 0, 1), worldRadius: 0, center: .zero)
        #expect(degenerate.depth.isFinite && degenerate.x.isFinite && degenerate.y.isFinite)
    }

    @Test("背面判定：z > 0 是远侧")
    func farSideIsDetected() {
        #expect(SphereField.isFarSide(SIMD3(0, 0, 1)))
        #expect(!SphereField.isFarSide(SIMD3(0, 0, -1)))
        #expect(!SphereField.isFarSide(SIMD3(0, 0, 0)), "赤道边缘不算远侧")
    }

    @Test("不透明度随景深递增，且始终留在 (0, 1]")
    func alphaFollowsDepth() {
        let near = SphereField.alpha(depth: SphereField.project(SIMD3(0, 0, -1), worldRadius: 100, center: .zero).depth)
        let far = SphereField.alpha(depth: SphereField.project(SIMD3(0, 0, 1), worldRadius: 100, center: .zero).depth)
        #expect(near > far, "近的点应当更实")
        for a in [near, far] { #expect(a > 0 && a <= 1) }
    }

    @Test("色波：色板索引按周期轮转，逐点延迟让浪从下往上洗")
    func colorWaveRollsUpward() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let wave = SphereField.wave(at: base, paletteCount: 3)
        #expect(wave.base == 0)
        #expect(wave.next == 1)
        let later = SphereField.wave(at: base.addingTimeInterval(SphereField.waveCycle), paletteCount: 3)
        #expect(later.base == 1 && later.next == 2)
        let single = SphereField.wave(at: base.addingTimeInterval(99), paletteCount: 1)
        #expect(single.base == 0 && single.next == 0)
        let none = SphereField.wave(at: base.addingTimeInterval(99), paletteCount: 0)
        #expect(none.base == 0 && none.next == 0)

        let low = SphereField.waveProgress(elevation: 0, timeInCycle: 2)
        let high = SphereField.waveProgress(elevation: 1, timeInCycle: 2)
        #expect(low > high, "低处应当先换色")
        for p in [low, high] { #expect(p >= 0 && p <= 1) }
    }

    @Test("取色：空色板返回 nil（⇒ 交给调用方的 .tint），非空才自己给色")
    func emptyPaletteYieldsNoColor() {
        let wave = SphereField.wave(at: Date(timeIntervalSinceReferenceDate: 0), paletteCount: 0)
        #expect(SphereField.tone(palette: [], wave: wave, progress: 0.5) == nil)
        let painted = SphereField.tone(
            palette: [.surfaceRaised, .contentPrimary],
            wave: SphereField.wave(at: Date(timeIntervalSinceReferenceDate: 0), paletteCount: 2),
            progress: 0
        )
        #expect(painted != nil)
    }

    @Test("字形分配：确定性、在界内，且**不**等价于 index % count")
    func glyphSlotIsScrambledNotModulo() {
        for index in 0..<50 {
            #expect(SphereField.glyphSlot(index: index, glyphCount: 7)
                    == SphereField.glyphSlot(index: index, glyphCount: 7))
        }
        for count in [1, 2, 5, 59] {
            for index in 0..<200 {
                let slot = SphereField.glyphSlot(index: index, glyphCount: count)
                #expect(slot >= 0 && slot < count, "count=\(count) index=\(index) 越界：\(slot)")
            }
        }
        #expect(SphereField.glyphSlot(index: 3, glyphCount: 0) == 0, "空字表不许除零")
        #expect(SphereField.glyphSlot(index: -4, glyphCount: 5) >= 0, "负索引不许给出负下标")

        for count in [3, 5, 8] {
            let naive = (0..<40).map { $0 % count }
            let actual = (0..<40).map { SphereField.glyphSlot(index: $0, glyphCount: count) }
            #expect(actual != naive, """
            count=\(count) 时 glyphSlot 与 `index % count` 逐项相同 —— 字表会沿着 Vogel 螺旋
            整齐重复，肉眼能看出一圈圈的规律（本轮渲图实测到的正是这个）。
            """)
        }
        let spread = Set((0..<40).map { SphereField.glyphSlot(index: $0, glyphCount: 5) })
        #expect(spread.count == 5, "40 个点位只用到了 \(spread.count) 个字 —— 分配退化了")

        for count in [3, 5, 8] {
            for period in 1...(2 * count) {
                let repeatsWithPeriod = (0..<200).allSatisfy {
                    SphereField.glyphSlot(index: $0, glyphCount: count)
                        == SphereField.glyphSlot(index: $0 + period, glyphCount: count)
                }
                #expect(!repeatsWithPeriod, """
                count=\(count) 时 glyphSlot 有周期 \(period) 的整齐重复 —— 字表会沿着
                Vogel 螺旋一圈圈复现，肉眼能看出规律（本轮渲图实测到的正是这个）。
                ⚠️ 「不等于 index % count」不足以排除它：`(index &* 3) % 5` 就同时逃过
                上面 ③ 与 ④ 两条。
                """)
            }
        }
    }

    @Test("插值走 perceptual，且色彩空间是显式写出来的（不吃 SwiftUI 的默认值）")
    func toneMixesInPerceptualSpace() throws {
        let env = EnvironmentValues()
        let wave = SphereField.Wave(base: 0, next: 1, timeInCycle: 0)
        let palette: [Color] = [.accent, .contentSecondary]
        let tone = try #require(SphereField.tone(palette: palette, wave: wave, progress: 0.5))

        let perceptual = palette[0].mix(with: palette[1], by: 0.5, in: .perceptual).resolve(in: env)
        let device = palette[0].mix(with: palette[1], by: 0.5, in: .device).resolve(in: env)
        #expect(perceptual != device, """
        这两个色彩空间在本色板上给出了同一个结果 —— 判据挑不出差别，请换一对色重钉。
        """)
        #expect(tone.resolve(in: env) == perceptual, """
        `SphereField.tone` 没有走 perceptual —— 与本仓记下的裁决不符。
        """)

        let code = MicroInteractionReduceMotionGuard.stripComments(try String(
            contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                .appendingPathComponent("SphereField.swift"),
            encoding: .utf8
        ))
        #expect(code.contains("in: .perceptual"), """
        `SphereField.swift` 没有显式写出插值的色彩空间 —— 它在吃 SwiftUI 的隐式默认。
        """)
    }

    @Test("静止相位不是 0（0 那一帧看起来像没做任何事）")
    func restingPhaseIsCharacteristic() {
        #expect(SphereField.restingPhase > 0 && SphereField.restingPhase < 1)
    }
}

// MARK: - 轨道环几何（OrbitingLogos）

@Suite("轨道环的纯几何契约")
struct OrbitRingTests {
    @Test("同一环上的点等角分布，整圈闭合")
    func dotsAreEvenlySpaced() {
        let count = OrbitRing.dotsPerRing
        let angles = (0..<count).map { OrbitRing.angle(index: $0, of: count, turns: 0, ring: 0) }
        let step = angles[1] - angles[0]
        for (a, b) in zip(angles, angles.dropFirst()) {
            #expect(abs((b - a) - step) < 1e-9, "角度步长不均匀")
        }
        #expect(abs(step * Double(count) - 2 * .pi) < 1e-9, "整圈应当恰好 2π")
    }

    @Test("退化输入：环上零个点不产生除零")
    func zeroDotsDoNotDivideByZero() {
        let a = OrbitRing.angle(index: 0, of: 0, turns: 0.25, ring: 1)
        #expect(a.isFinite)
    }

    @Test("外环半径最大，逐环向内收")
    func radiiShrinkInward() {
        let radii = (0..<OrbitRing.ringCount).map { OrbitRing.ringRadius(ring: $0, size: 300) }
        for (outer, inner) in zip(radii, radii.dropFirst()) {
            #expect(outer > inner, "环半径没有向内收：\(radii)")
        }
        #expect(radii.first! <= 150, "最外环不得超出容器半径")
        #expect(radii.last! > 0)
    }

    @Test("logo 均匀落在外环的 slot 上，且数量退化时不越界")
    func logoSlotsAreDistributed() {
        let slots = (0..<4).map { OrbitRing.slot(of: $0, logoCount: 4) }
        #expect(Set(slots).count == 4, "四个 logo 落在了同一个 slot 上：\(slots)")
        for s in slots { #expect(s >= 0 && s < OrbitRing.dotsPerRing) }
        #expect(OrbitRing.slot(of: 0, logoCount: 0) == 0)
        #expect(OrbitRing.slot(of: 0, logoCount: 1) == 0)
        #expect(OrbitRing.slot(of: 99, logoCount: 99) < OrbitRing.dotsPerRing)
        #expect(OrbitRing.slot(of: 3, logoCount: 4, dotsPerRing: 0) == 0)

        for logoCount in 1...OrbitRing.dotsPerRing {
            let all = (0..<logoCount).map { OrbitRing.slot(of: $0, logoCount: logoCount) }
            #expect(Set(all).count == logoCount,
                    "logoCount=\(logoCount) 时有 logo 共用同一个 slot：\(all)")
        }
    }

    @Test("logo 的角度：坐在真实画出来的环点上，且任何数量下都不重叠")
    func logoAnglesSitOnRealSeatsAndNeverCollide() {
        for seats in [OrbitRing.dotsPerRing, 12, 1] {
            let ringAngles = (0..<seats).map { OrbitRing.angle(index: $0, of: seats, turns: 0.3, ring: 0) }
            for index in 0..<min(4, seats) {
                let a = OrbitRing.logoAngle(logoIndex: index, logoCount: min(4, seats),
                                            dotsPerRing: seats, turns: 0.3)
                #expect(ringAngles.contains { abs($0 - a) < 1e-9 }, """
                seats=\(seats) 时第 \(index) 个 logo 的角度 \(a) 不在实际画出来的环点上
                —— 低电量下环变稀，logo 会悬在点与点之间。
                """)
            }
        }

        for logoCount in [1, 4, 8, 22, 23, 24, 40, 99] {
            let angles = (0..<logoCount).map {
                OrbitRing.logoAngle(logoIndex: $0, logoCount: logoCount,
                                    dotsPerRing: OrbitRing.dotsPerRing, turns: 0)
            }
            for (i, a) in angles.enumerated() {
                for (j, b) in angles.enumerated() where j > i {
                    #expect(abs(a - b) > 1e-9, """
                    logoCount=\(logoCount) 时第 \(i) 与第 \(j) 个 logo 落在同一个角度上
                    —— 它们在屏幕上完全重叠。
                    """)
                }
            }
        }

        #expect(OrbitRing.logoAngle(logoIndex: 0, logoCount: 0, dotsPerRing: 23, turns: 0.5) == 0)
        #expect(OrbitRing.logoAngle(logoIndex: 2, logoCount: 4, dotsPerRing: 0, turns: 0.5).isFinite)

        let seats = OrbitRing.dotsPerRing
        let ringShift = OrbitRing.angle(index: 0, of: seats, turns: 0.25, ring: 0)
            - OrbitRing.angle(index: 0, of: seats, turns: 0, ring: 0)
        #expect(abs(ringShift + .pi / 2) < 1e-9, "环自己的 1/4 圈位移不再是 -π/2 —— 下面的判据失去参照")
        for logoCount in [seats + 1, 40, 99] {
            for index in [0, 1, logoCount - 1] {
                let at0 = OrbitRing.logoAngle(logoIndex: index, logoCount: logoCount,
                                              dotsPerRing: seats, turns: 0)
                let atQuarter = OrbitRing.logoAngle(logoIndex: index, logoCount: logoCount,
                                                    dotsPerRing: seats, turns: 0.25)
                #expect(abs((atQuarter - at0) - ringShift) < 1e-9, """
                logoCount=\(logoCount)（> \(seats) 个座位）时第 \(index) 个 logo 的角度不吃 `turns`
                —— 它与环的自转脱钩了，整圈 logo 原地冻住而只有环在转。
                """)
            }
        }
    }

    @Test("轮播：每个 logo 轮流被点名，进度落在 [0, 1)")
    func featureCyclesThroughLogos() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let first = OrbitRing.feature(at: base, logoCount: 3)
        #expect(first.index == 0)
        #expect(first.progress >= 0 && first.progress < 1)
        let second = OrbitRing.feature(at: base.addingTimeInterval(OrbitRing.featureSeconds), logoCount: 3)
        #expect(second.index == 1)
        let wrapped = OrbitRing.feature(at: base.addingTimeInterval(OrbitRing.featureSeconds * 3), logoCount: 3)
        #expect(wrapped.index == 0, "走满一轮应当回到第一个")
        let none = OrbitRing.feature(at: base.addingTimeInterval(5), logoCount: 0)
        #expect(none.index == 0 && none.progress.isFinite)
    }

    @Test("pop 曲线两端归 1、中段放大，且不越过上限")
    func popScaleReturnsToRest() {
        #expect(OrbitRing.popScale(progress: 0) == 1)
        #expect(abs(OrbitRing.popScale(progress: 1) - 1) < 1e-9)
        let peak = OrbitRing.popScale(progress: 0.5)
        #expect(peak > 1, "中段没有放大 —— pop 效果不存在")
        #expect(peak <= OrbitRing.popPeak)
        for step in stride(from: 0.0, through: 1.0, by: 0.05) {
            let s = OrbitRing.popScale(progress: step)
            #expect(s >= 1 && s <= OrbitRing.popPeak, "progress=\(step) 的缩放越界：\(s)")
        }
    }

    @Test("挤压：半径内的点被推远、半径外原样、强度为 0 时不动")
    func pushDisplacesOnlyNearbyDots() {
        let source = CGPoint(x: 100, y: 100)
        let near = CGPoint(x: 110, y: 100)
        let far = CGPoint(x: 400, y: 100)
        let pushedNear = OrbitRing.pushed(near, awayFrom: source, radius: 60, strength: 20)
        #expect(pushedNear.x > near.x, "半径内的点没有被推开")
        let pushedFar = OrbitRing.pushed(far, awayFrom: source, radius: 60, strength: 20)
        #expect(pushedFar == far, "半径外的点不该动")
        let unpushed = OrbitRing.pushed(near, awayFrom: source, radius: 60, strength: 0)
        #expect(unpushed == near, "强度为 0 时不该动")
        let coincident = OrbitRing.pushed(source, awayFrom: source, radius: 60, strength: 20)
        #expect(coincident.x.isFinite && coincident.y.isFinite)
        let zeroRadius = OrbitRing.pushed(near, awayFrom: source, radius: 0, strength: 20)
        #expect(zeroRadius == near)
    }

    @Test("角向明暗波留在 (0, 1]，整圈连续（首尾相接不跳变）")
    func angularAlphaIsContinuous() {
        for step in stride(from: 0.0, to: 1.0, by: 0.05) {
            let a = OrbitRing.alpha(angle: step * 2 * .pi)
            #expect(a > 0 && a <= 1, "angle=\(step) 的 alpha 越界：\(a)")
        }
        #expect(abs(OrbitRing.alpha(angle: 0) - OrbitRing.alpha(angle: 2 * .pi)) < 1e-9,
                "0 与 2π 的取值不同 ⇒ 整圈会有一条缝")
    }
}

// MARK: - 常驻自转件的第三道闸（周期非法）

@Suite("周期非法时的呈现降级")
struct DegeneratePeriodTests {
    @Test("非法周期（含 nan / inf）把 .animated 降到 .resting，其余两档原样穿过")
    func degeneratePeriodFreezesAnimated() {
        for period in [0.0, -3.0, -0.001, .nan, .infinity, -.infinity] {
            #expect(MotionPresentation.animated.frozenIfPeriodIsDegenerate(period) == .resting,
                    "period=\(period) 时仍在建调度器")
            #expect(MotionPresentation.resting.frozenIfPeriodIsDegenerate(period) == .resting)
            #expect(MotionPresentation.hidden.frozenIfPeriodIsDegenerate(period) == .hidden,
                    "period=\(period) 把停摆档抬回了 .resting —— 能耗闸被这道闸绕过了")
        }
        for period in [0.001, 10.0, 24.0] {
            #expect(MotionPresentation.animated.frozenIfPeriodIsDegenerate(period) == .animated,
                    "period=\(period) 是合法周期，不该被冻结")
            #expect(MotionPresentation.hidden.frozenIfPeriodIsDegenerate(period) == .hidden)
            #expect(MotionPresentation.resting.frozenIfPeriodIsDegenerate(period) == .resting)
        }
    }
}

// MARK: - FullScreenButton 的转场裁决

@Suite("FullScreenButton 的转场裁决")
struct FullScreenTransitionPlanTests {
    @Test("只有「支持 zoom 的平台 × 未开启 Reduce Motion」才走 zoom")
    func zoomRequiresBothPlatformAndMotion() {
        #expect(FullScreenTransitionPlan.resolve(reduceMotion: false, platformSupportsZoom: true) == .zoom)
        #expect(FullScreenTransitionPlan.resolve(reduceMotion: true, platformSupportsZoom: true) == .plain)
        #expect(FullScreenTransitionPlan.resolve(reduceMotion: false, platformSupportsZoom: false) == .plain)
        #expect(FullScreenTransitionPlan.resolve(reduceMotion: true, platformSupportsZoom: false) == .plain)
    }

    @Test("平台常量与当前编译目标一致")
    func platformConstantMatchesTarget() {
        #if os(iOS)
        #expect(FullScreenTransitionPlan.platformSupportsZoom)
        #else
        #expect(!FullScreenTransitionPlan.platformSupportsZoom,
                "macOS 上报了「支持 zoom」—— 那个 API 在 macOS 上标了 unavailable")
        #endif
    }
}

// MARK: - 渲染层：位图判据

@Suite("跨平台四件的渲染契约")
@MainActor
struct CrossPlatformRenderTests {
    static let side: CGFloat = 220

    static func framed(_ view: some View) -> some View {
        view.frame(width: Self.side, height: Self.side).background(Color.surfaceRaised)
    }

    static func staged(
        _ view: some View, phase: ScenePhase = .active, lowPower: Bool = false
    ) -> some View {
        Self.framed(
            view
                .environment(\.scenePhaseOverride, phase)
                .environment(\.lowPowerModeOverride, lowPower)
        )
    }

    static var blank: Data? { Self.pixels(Self.framed(Color.clear)) }

    static func sphereBody(
        mark: SphereMark, count: Int = 240, colors: [Color] = [],
        turns: Double = SphereField.restingPhase
    ) -> SphereSurfaceBody {
        SphereSurfaceBody(
            mark: mark, count: count, colors: colors, turns: turns,
            wave: SphereField.restingWave(paletteCount: colors.count)
        )
    }

    static func orbitBody(
        colors: [Color] = [], turns: Double = OrbitRing.restingPhase,
        feature: (index: Int, progress: Double) = OrbitRing.restingFeature,
        layers: OrbitLayers = .full
    ) -> some View {
        OrbitingLogosBody(
            items: OrbitingLogosPreviewItem.samples, colors: colors, turns: turns, feature: feature,
            layers: layers,
            logo: { item in Self.orbitLogo(item) },
            center: Self.orbitCenter
        )
    }

    static func orbitLogo(_ item: OrbitingLogosPreviewItem) -> some View {
        Circle().fill(Color.contentPrimary).frame(width: 12, height: 12)
            .accessibilityHidden(true)
            .id(item.id)
    }

    static var orbitCenter: some View {
        Circle().fill(Color.accent).frame(width: 40, height: 40)
    }

    private static let branchWarmUp: Bool = {
        let probes: [AnyView] = [
            AnyView(Self.staged(Self.sphereBody(mark: .dots(diameter: 3)))),
            AnyView(Self.staged(Self.sphereBody(mark: .dots(diameter: 3), colors: [.accent]))),
            AnyView(Self.staged(Self.sphereBody(mark: .glyphs(["道"], fontSize: 11)))),
            AnyView(Self.staged(Self.sphereBody(mark: .glyphs(["道"], fontSize: 11), colors: [.accent]))),
            AnyView(Self.staged(Self.orbitBody())),
            AnyView(Self.staged(Self.orbitBody(colors: [.accent]))),
            AnyView(Self.staged(Self.orbitBody(layers: .contentOnly))),
        ]
        for probe in probes {
            for _ in 0..<8 { _ = MicroInteractionAPITests.stablePixels(probe) }
        }
        return true
    }()

    static func pixels(_ view: some View) -> Data? {
        _ = Self.branchWarmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    // MARK: 取色（FR-8）

    @Test("空色板：换 .tint 位图必须变；给了色板则必须不变")
    func spheresFollowTheCallerTint() {
        for mark in [SphereMark.dots(diameter: 4), .glyphs(["道", "德"], fontSize: 14)] {
            let a = Self.pixels(Self.staged(Self.sphereBody(mark: mark).tint(Color.accent)))
            let b = Self.pixels(Self.staged(Self.sphereBody(mark: mark).tint(Color.contentSecondary)))
            #expect(a != nil && b != nil, "渲染失败，下面的相等断言会恒真")
            expectBitmapsDiffer(a, b, "\(mark) 空色板下换 .tint 位图没变 —— 取色没走调用方")
            expectBitmapsDiffer(a, Self.blank, "空色板下什么都没画")

            let palette = [Color.borderSubtle]
            let c = Self.pixels(Self.staged(Self.sphereBody(mark: mark, colors: palette).tint(Color.accent)))
            let d = Self.pixels(Self.staged(Self.sphereBody(mark: mark, colors: palette).tint(Color.contentSecondary)))
            #expect(c != nil, "渲染失败 —— 不得当作通过")
            expectBitmapsDiffer(c, Self.blank)
            expectBitmapsEqual(c, d, "\(mark) 给了色板还跟着 .tint 变 —— 调用方的色板被忽略了")
        }
    }

    @Test("轨道环：空色板取 .tint，给了色板则不跟着变")
    func orbitFollowsTheCallerTint() {
        let a = Self.pixels(Self.staged(Self.orbitBody().tint(Color.accent)))
        let b = Self.pixels(Self.staged(Self.orbitBody().tint(Color.contentSecondary)))
        #expect(a != nil && b != nil)
        expectBitmapsDiffer(a, b, "空色板下换 .tint 位图没变 —— 环上的点没走调用方取色")
        let c = Self.pixels(Self.staged(Self.orbitBody(colors: [.borderSubtle]).tint(Color.accent)))
        let d = Self.pixels(Self.staged(Self.orbitBody(colors: [.borderSubtle]).tint(Color.contentSecondary)))
        #expect(c != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(c, Self.blank)
        expectBitmapsEqual(c, d, "给了色板还跟着 .tint 变")
    }

    @Test("空色板 + .tint(X) 必须与 colors: [X] 渲成同一张图（遮罩不许再吃一层 alpha）")
    func tintPathMatchesSinglePalette() {
        let tone = Color.accent
        for mark in [SphereMark.dots(diameter: 4), .glyphs(["道", "德"], fontSize: 14)] {
            let tinted = Self.pixels(Self.staged(Self.sphereBody(mark: mark).tint(tone)))
            let explicit = Self.pixels(Self.staged(Self.sphereBody(mark: mark, colors: [tone]).tint(tone)))
            #expect(tinted != nil, "渲染失败 —— 不得当作通过")
            expectBitmapsDiffer(tinted, Self.blank, "\(mark) 什么都没画 —— 下面的相等断言会恒真")
            expectBitmapsEqual(tinted, explicit, """
            \(mark)：空色板走 `.tint` 与显式单色色板渲出了**不同**的图。
            两条路的量程本该逐字相同 —— 差异来自 `.tint` 那条路上多吃的一层 alpha
            （`Rectangle().fill(.tint).mask { … }` + `Color.primary` 哨兵，`.primary`
            **macOS 实测 a=0.8471、iOS 实测 a=1.0** ⇒ 本条只会在 macOS 腿上因此判红）。
            """)
        }
        let tintedOrbit = Self.pixels(Self.staged(Self.orbitBody().tint(tone)))
        let explicitOrbit = Self.pixels(Self.staged(Self.orbitBody(colors: [tone]).tint(tone)))
        #expect(tintedOrbit != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(tintedOrbit, Self.blank)
        expectBitmapsEqual(tintedOrbit, explicitOrbit, """
        轨道环：空色板走 `.tint` 与显式单色色板渲出了不同的图 —— 同一枚遮罩偏差。
        """)
    }

    // MARK: 公开包装器的参数管线（终审 I-2）

    @Test("公开包装器：调用方的 colors 真的交到了绘制层")
    func publicWrappersForwardTheirPalette() {
        let tint = Color.borderSubtle
        let dotA = Self.pixels(Self.staged(DotSphere(count: 240, colors: [.accent], rotationPeriod: 0).tint(tint)))
        let dotB = Self.pixels(Self.staged(DotSphere(count: 240, colors: [.contentSecondary], rotationPeriod: 0).tint(tint)))
        #expect(dotA != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(dotA, Self.blank, "DotSphere 什么都没画 —— 下面的不等断言会失去意义")
        expectBitmapsDiffer(dotA, dotB, "DotSphere 换色板位图没变 —— `colors: self.colors` 没交到 SphereSurface")
        let dotAgain = Self.pixels(Self.staged(DotSphere(count: 240, colors: [.accent], rotationPeriod: 0).tint(tint)))
        expectBitmapsEqual(dotA, dotAgain, "同一份输入渲出两张不同的图 —— 判据与挂钟有关，不可信")

        let charA = Self.pixels(Self.staged(CharSphere(["道", "德"], count: 160, colors: [.accent], rotationPeriod: 0).tint(tint)))
        let charB = Self.pixels(Self.staged(CharSphere(["道", "德"], count: 160, colors: [.contentSecondary], rotationPeriod: 0).tint(tint)))
        #expect(charA != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(charA, Self.blank)
        expectBitmapsDiffer(charA, charB, "CharSphere 换色板位图没变 —— `colors: self.colors` 没交到 SphereSurface")

        let orbitA = Self.pixels(Self.staged(Self.orbitContainer(colors: [.accent], rotationPeriod: 0).tint(tint)))
        let orbitB = Self.pixels(Self.staged(Self.orbitContainer(colors: [.contentSecondary], rotationPeriod: 0).tint(tint)))
        #expect(orbitA != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(orbitA, Self.blank)
        expectBitmapsDiffer(orbitA, orbitB, "OrbitingLogos 换色板位图没变 —— `colors: self.colors` 没交到绘制层")
    }

    @Test("rotationPeriod <= 0：公开包装器渲出的正是那张钉死的静止帧")
    func degeneratePeriodRendersTheRestingFrame() {
        let tint = Color.accent
        let dot = Self.pixels(Self.staged(DotSphere(count: 240, rotationPeriod: 0).tint(tint)))
        let dotReference = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 3), count: 240).tint(tint)))
        #expect(dot != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(dot, Self.blank, "周期为 0 渲成了空白 —— 那是停摆不是静止")
        expectBitmapsEqual(dot, dotReference, """
        `DotSphere(rotationPeriod: 0)` 渲出的不是钉死的静止帧。
        要么它还在走 `.animated`（`TimelineView` 照建、每帧同一张图，白付 NFR-1/NFR-7），
        要么 `count` / `mark` / `rotationPeriod` 里有一条没交到 `SphereSurface`。
        """)

        let char = Self.pixels(Self.staged(CharSphere(["道", "德"], count: 160, rotationPeriod: 0).tint(tint)))
        let charReference = Self.pixels(Self.staged(
            Self.sphereBody(mark: .glyphs(["道", "德"], fontSize: 11), count: 160).tint(tint)
        ))
        #expect(char != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(char, Self.blank)
        expectBitmapsEqual(char, charReference, "`CharSphere(rotationPeriod: 0)` 渲出的不是钉死的静止帧")

        let orbit = Self.pixels(Self.staged(Self.orbitContainer(rotationPeriod: 0).tint(tint)))
        let orbitReference = Self.pixels(Self.staged(Self.orbitBody().tint(tint)))
        #expect(orbit != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(orbit, Self.blank)
        expectBitmapsEqual(orbit, orbitReference, "`OrbitingLogos(rotationPeriod: 0)` 渲出的不是钉死的静止帧")
    }

    @Test("低电量：logo 跟着变稀的环挪位（不许悬在环点之间）")
    func logoSeatsFollowTheThinnedRing() {
        let full = Self.pixels(Self.staged(Self.orbitBody(colors: [.clear])))
        let low = Self.pixels(Self.staged(Self.orbitBody(colors: [.clear]), lowPower: true))
        #expect(full != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(full, Self.blank, "环画成 .clear 之后连 logo 都没了 —— 判据在比两张空白图")
        expectBitmapsDiffer(full, low, """
        低电量下 logo 的位置一点没变 —— 座位数还钉在标称的 23，而这一档每环只画 12 个点
        ⇒ logo 会悬在环点之间。
        """)
    }

    // MARK: NFR-7 能耗闸

    @Test("后台与非活跃：两个球面件一个像素都不画")
    func pausedDrawsNothing() {
        for phase in [ScenePhase.background, .inactive] {
            let dot = Self.pixels(Self.staged(DotSphere(), phase: phase))
            let char = Self.pixels(Self.staged(CharSphere(["道"]), phase: phase))
            expectBitmapsEqual(dot, Self.blank, "DotSphere 在 \(phase) 下还在画")
            expectBitmapsEqual(char, Self.blank, "CharSphere 在 \(phase) 下还在画")
        }
        let active = Self.pixels(Self.staged(DotSphere()))
        #expect(active != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(active, Self.blank, "活跃态下什么都没画 —— 上面的停摆判据是空真")
    }

    @Test("后台与非活跃：OrbitingLogos 摘掉装饰，但调用方的内容必须留下")
    func pausedKeepsCallerContentInOrbitingLogos() {
        let contentOnly = Self.pixels(Self.staged(Self.orbitBody(layers: .contentOnly)))
        #expect(contentOnly != nil, "内容层渲染失败 —— 下面的相等断言会恒真")
        expectBitmapsDiffer(contentOnly, Self.blank,
                            "内容层自己就画不出东西 —— 下面的相等断言会恒真")
        for phase in [ScenePhase.background, .inactive] {
            let orbit = Self.pixels(Self.staged(Self.orbitContainer(), phase: phase))
            expectBitmapsDiffer(orbit, Self.blank, """
            OrbitingLogos 在 \(phase) 下变成了空白 —— 调用方的 logo 与中心视图被能耗闸
            一起删掉了。`.inactive` 在 macOS 上就是"窗口没聚焦"，窗口完全可见。
            """)
            expectBitmapsEqual(orbit, contentOnly, """
            OrbitingLogos 在 \(phase) 下渲出的不是"只有内容"那一帧
            —— 要么装饰层还在建，要么内容层被改了。
            """)
        }
    }

    static func orbitContainer(
        colors: [Color] = [], rotationPeriod: Double = OrbitRing.rotationPeriod
    ) -> some View {
        OrbitingLogos(
            OrbitingLogosPreviewItem.samples, colors: colors, rotationPeriod: rotationPeriod
        ) { item in
            Self.orbitLogo(item)
        } center: {
            Self.orbitCenter
        }
    }

    @Test("低电量：点数减半 ⇒ 同一相位的位图必须不同")
    func lowPowerThinsTheField() {
        let full = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 4), count: 400)))
        let low = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 4), count: 400), lowPower: true))
        #expect(full != nil && low != nil)
        expectBitmapsDiffer(full, low, "低电量下点数没变 —— particleScale 这个旋钮没接上")
        expectBitmapsDiffer(low, Self.blank, "低电量下一个点都不画 —— 那是停摆不是降级")

        let fullOrbit = Self.pixels(Self.staged(Self.orbitBody()))
        let lowOrbit = Self.pixels(Self.staged(Self.orbitBody(), lowPower: true))
        expectBitmapsDiffer(fullOrbit, lowOrbit, "低电量下环上点数没变")
        expectBitmapsDiffer(lowOrbit, Self.blank)
    }

    // MARK: Reduce Motion 的静止形态

    @Test("静止相位画得出球，且与别的相位不是同一张图")
    func restingPhaseStillDraws() {
        let resting = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 4))))
        let moved = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 4), turns: 0.37)))
        #expect(resting != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(resting, Self.blank, "静止形态是空白 —— 那是 no-op 不是降级")
        expectBitmapsDiffer(resting, moved, "两个不同相位渲成了同一张图 —— 自转根本没接上")
    }

    @Test("轮播：被点名的 logo 在中段确实放大了")
    func featuredLogoPopsOut() {
        let rest = Self.pixels(Self.staged(Self.orbitBody(feature: (index: 0, progress: 0))))
        let peak = Self.pixels(Self.staged(Self.orbitBody(feature: (index: 0, progress: 0.5))))
        #expect(rest != nil && peak != nil)
        expectBitmapsDiffer(rest, peak, "pop 峰值与静止渲成了同一张图 —— 放大与挤压都没发生")
    }

    // MARK: 退化输入

    @Test("退化输入：点数为 0 / 负 / 超限、字表为空、条目为空都不崩")
    func degenerateInputsDoNotCrash() {
        expectBitmapsEqual(Self.pixels(Self.staged(DotSphere(count: 0))), Self.blank, "0 个点却画了东西")
        expectBitmapsEqual(Self.pixels(Self.staged(DotSphere(count: -12))), Self.blank)
        #expect(Self.pixels(Self.staged(DotSphere(count: 99_999))) != nil, "超限点数应当截断而不是崩")
        expectBitmapsDiffer(Self.pixels(Self.staged(DotSphere(rotationPeriod: 0))), Self.blank, "周期为 0 应当静止而不是空白")
        expectBitmapsEqual(Self.pixels(Self.staged(CharSphere([]))), Self.blank, "空字表却画了东西")
        expectBitmapsEqual(Self.pixels(Self.staged(CharSphere(["道"], count: 0))), Self.blank)
        let empty = OrbitingLogos([OrbitingLogosPreviewItem]()) { _ in
            Circle().frame(width: 8, height: 8)
        } center: {
            EmptyView()
        }
        expectBitmapsDiffer(Self.pixels(Self.staged(empty)), Self.blank, "没有 logo 时环也该照画")
    }

    // MARK: FullScreenButton

    @Test("FullScreenButton 在当前平台上渲染得出内容（macOS 上同样可用）")
    func fullScreenButtonRenders() {
        let view = NavigationStack {
            FullScreenButton {
                Color.surfaceRaised
            } label: {
                Text(verbatim: "Card")
                    .padding(CoreSpacing.lg)
                    .background(Color.surfaceRaised)
            }
        }
        let rendered = Self.pixels(Self.staged(view))
        #expect(rendered != nil, "渲染失败")
        expectBitmapsDiffer(rendered, Self.blank, "什么都没画 —— macOS 上这一件应当照常可用")
    }

    // MARK: 三档呈现的接线（位图路结构上到不了的那一半）

    @Test("三档呈现的接线：停摆不建任何东西、静止钉在 restingPhase、只有 animated 建时间线")
    func presentationBranchesAreWiredCorrectly() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try String(
            contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                .appendingPathComponent("SphereSurface.swift"),
            encoding: .utf8
        ))
        guard let switchRange = code.range(of: "switch presentation {") else {
            Issue.record("找不到共享裁决点 `switch presentation {` —— 两道闸的顺序无人守")
            return
        }
        let afterSwitch = String(code[switchRange.upperBound...])
        let switchBody = afterSwitch.components(separatedBy: "struct SphereSurfaceTimeline").first ?? afterSwitch

        let hiddenBranch = switchBody.components(separatedBy: "case .resting:").first ?? ""
        #expect(hiddenBranch.contains("EmptyView()"), """
        `.hidden` 分支不是 `EmptyView()` —— NFR-7 的"一个像素都不画"变成了"画了但画不出来"。
        ⚠️ 这枚变异在位图判据上是绿的——位图判据看不出"画了但完全透明"与"没画"的差别。
        """)
        #expect(!hiddenBranch.contains("SphereSurfaceBody("), "`.hidden` 分支还在建绘制层")
        #expect(!hiddenBranch.contains("SphereSurfaceTimeline("), "`.hidden` 分支还在建调度器")

        let restingBranch = (switchBody.components(separatedBy: "case .resting:").last ?? "")
            .components(separatedBy: "case .animated:").first ?? ""
        #expect(restingBranch.contains("SphereField.restingPhase"), """
        `.resting` 分支没有把相位钉在 `SphereField.restingPhase` 上
        —— Reduce Motion 下的"冻结"会冻在一个随手写的相位上。
        """)
        #expect(restingBranch.contains("SphereField.restingWave("), "`.resting` 分支的色波没有钉死")
        #expect(!restingBranch.contains("TimelineView("), "`.resting` 分支建了调度器")
        #expect(!restingBranch.contains("SphereSurfaceTimeline("), "`.resting` 分支建了调度器")

        #expect(!switchBody.contains("TimelineView("),
                "驱动层的 switch 体里直接建了 TimelineView —— 停摆 / 静止两档会跟着建出调度器")
        let animatedBranch = switchBody.components(separatedBy: "case .animated:").last ?? ""
        #expect(animatedBranch.contains("SphereSurfaceTimeline("), "`.animated` 分支没有建调度器")
        #expect(code.contains("TimelineView("), "整份文件都没有 TimelineView —— 这个效果根本没在动")

        let beforeSwitch = String(code[..<switchRange.lowerBound])
        #expect(beforeSwitch.contains("frozenIfPeriodIsDegenerate(self.rotationPeriod)"), """
        驱动层没有接"周期非法"这道闸 —— `rotationPeriod <= 0` 会照常建
        `TimelineView(.animation)`，永远产出同一张图，白付 NFR-1 / NFR-7 的代价。
        """)
    }

    @Test("轨道环的三档呈现同样接对了")
    func orbitPresentationBranchesAreWiredCorrectly() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try String(
            contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                .appendingPathComponent("OrbitingLogos.swift"),
            encoding: .utf8
        ))
        guard let switchRange = code.range(of: "switch presentation {") else {
            Issue.record("找不到共享裁决点 `switch presentation {`")
            return
        }
        let afterSwitch = String(code[switchRange.upperBound...])
        let switchBody = afterSwitch.components(separatedBy: "struct OrbitingLogosTimeline").first ?? afterSwitch

        let hiddenBranch = switchBody.components(separatedBy: "case .resting:").first ?? ""
        #expect(!hiddenBranch.contains("EmptyView()"), """
        `.hidden` 分支又回到了 `EmptyView()` —— 那会把**调用方的** logo 与中心视图一起删掉。
        能耗闸的"一个像素都不画"只适用于装饰层；画内容的件把内容藏掉不是停摆、是 bug。
        （⚠️ 别拿这条去判断下一个件：`BeforeAfterSlider` / `ParticleTransition` 不进
        `energyGatedFiles` 用的是**另一条**理由——它们没有可停的常驻装饰层。终审 I-E。）
        """)
        #expect(hiddenBranch.contains("layers: .contentOnly"), """
        `.hidden` 分支没有把绘制层钉在 `.contentOnly` 上 —— 装饰层（环 + Canvas）会跟着建出来。
        """)
        #expect(!hiddenBranch.contains("OrbitingLogosTimeline("), "`.hidden` 分支还在建调度器")
        #expect(!hiddenBranch.contains("TimelineView("), "`.hidden` 分支还在建调度器")

        let restingBranch = (switchBody.components(separatedBy: "case .resting:").last ?? "")
            .components(separatedBy: "case .animated:").first ?? ""
        #expect(restingBranch.contains("OrbitRing.restingPhase"), "`.resting` 分支没有钉住自转相位")
        #expect(restingBranch.contains("OrbitRing.restingFeature"),
                "`.resting` 分支没有钉住轮播 —— Reduce Motion 下仍会有 logo 弹出放大")
        #expect(restingBranch.contains("layers: .full"),
                "`.resting` 分支没有画整件 —— 降级形态 2 是「冻结」，不是「摘掉环」")
        #expect(!restingBranch.contains("TimelineView("), "`.resting` 分支建了调度器")
        #expect(!restingBranch.contains("OrbitingLogosTimeline("), "`.resting` 分支建了调度器")

        #expect(!switchBody.contains("TimelineView("), "驱动层的 switch 体里直接建了 TimelineView")
        let animatedBranch = switchBody.components(separatedBy: "case .animated:").last ?? ""
        #expect(animatedBranch.contains("OrbitingLogosTimeline("), """
        `.animated` 分支没有建调度器 —— 本件不再动了，而位图判据全都直接构造
        `OrbitingLogosBody`、绕过 driver ⇒ 没有任何别的判据看得见这件事。
        """)
        #expect(code.contains("TimelineView("), """
        整份文件都没有 TimelineView —— 这个效果根本没在动。
        （非平凡性互锁：没有这条，上面每一条 `!contains("TimelineView(")` 在
        "把 TimelineView 整个删掉"这枚变异下全部恒真。）
        """)

        let beforeSwitch = String(code[..<switchRange.lowerBound])
        #expect(beforeSwitch.contains("frozenIfPeriodIsDegenerate(self.rotationPeriod)"), """
        驱动层没有接"周期非法"这道闸 —— `rotationPeriod <= 0` 会照常建
        `TimelineView(.animation)`，display link 满帧跑只为产出同一张图。
        """)
    }

    @Test("a11y 隐藏只贴在装饰层上，不许套住整件")
    func accessibilityHiddenStaysOnTheDecorationLayer() throws {
        let hosts = [
            ("OrbitingLogos.swift", "self.ringMarks("),
            ("SphereSurface.swift", "self.canvas("),
        ]
        let marker = ".accessibilityHidden(true)"
        for (file, host) in hosts {
            let code = MicroInteractionReduceMotionGuard.stripComments(try String(
                contentsOf: MicroInteractionReduceMotionGuard.sourceRoot.appendingPathComponent(file),
                encoding: .utf8
            ))
            let count = code.components(separatedBy: marker).count - 1
            #expect(count == 1, """
            \(file) 里 `\(marker)` 出现了 \(count) 次（应当恰好 1 次）。
            多出来的那一句多半套在整件上 —— 那会让**调用方的**内容一并对 VoiceOver 消失，
            正是 C-1 的规则收窄要防的后果；少一句则装饰层重新进了 a11y 树。
            """)
            guard let range = code.range(of: marker) else { continue }
            let window = String(code[..<range.lowerBound].suffix(240))
            #expect(window.contains(host), """
            \(file) 的 `\(marker)` 没有贴在 `\(host)` 这条**装饰层**链上。
            它一旦上移到 `ZStack` / `body` 这一层，藏掉的就不只是装饰。
            """)
        }
    }

    @Test("座位数只吃能耗档位、不吃 scenePhase")
    func seatCountFollowsPowerModeNotScenePhase() {
        #expect(OrbitRing.seats(particleScale: 1) == OrbitRing.dotsPerRing)
        #expect(OrbitRing.seats(particleScale: 0.5) == 12)
        #expect(OrbitRing.seats(particleScale: 0) == 1, "座位数为 0 会让全部 logo 叠到角度 0")
        #expect(OrbitRing.seats(particleScale: .nan) == 1)
        #expect(OrbitRing.seats(particleScale: -1) == 1)

        let normal = Self.pixels(Self.staged(Self.orbitBody(layers: .contentOnly)))
        let low = Self.pixels(Self.staged(Self.orbitBody(layers: .contentOnly), lowPower: true))
        #expect(normal != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(normal, Self.blank, "内容层什么都没画 —— 下面的不等断言会失去意义")
        expectBitmapsDiffer(normal, low, """
        `.contentOnly` 档下换低电量位图没变 —— 座位数又回落到标称的 23 了。
        后果：低电量下窗口一失焦（`.active` ⇒ `.inactive`，窗口**完全可见**），
        调用方的 logo 会整体挪位（实测最大 11.7°，320pt 容器上约 28pt）。
        """)
    }

    @Test("非等比容器里本件仍是正方形（信箱边）")
    func orbitBodyStaysSquareInNonSquareContainer() {
        let width: CGFloat = 320, height: CGFloat = 200
        let view = Self.orbitBody()
            .environment(\.scenePhaseOverride, ScenePhase.active)
            .environment(\.lowPowerModeOverride, false)
            .background(Color.accent)
            .frame(width: width, height: height)
        guard let bounds = Self.inkColumns(view, width: Int(width), height: Int(height)) else {
            Issue.record("渲染失败，取不到墨迹边界")
            return
        }
        #expect(bounds.width == Int(height), """
        本件在 \(Int(width))×\(Int(height)) 容器里的布局宽度是 \(bounds.width)pt，
        不是正方形的 \(Int(height))pt —— `aspectRatio(1, contentMode: .fit)` 没了，
        环会被拉成椭圆。
        """)
        #expect(bounds.first == (Int(width) - Int(height)) / 2, "内容没有居中：左边界 \(bounds.first)")
    }

    static func inkColumns(_ view: some View, width: Int, height: Int) -> (first: Int, width: Int)? {
        guard let data = Self.pixels(view), data.count == width * height * 4 else { return nil }
        var first = width, last = -1
        for y in 0..<height {
            for x in 0..<width where data[(y * width + x) * 4 + 3] > 0 {
                first = min(first, x)
                last = max(last, x)
            }
        }
        guard last >= first else { return nil }
        return (first, last - first + 1)
    }

    // MARK: 薄封装的互锁

    @Test("薄封装：两个球面件只转发给 SphereSurface，不自建动画 / 绘制 / 能耗闸")
    func spheresDelegateToSharedSurface() throws {
        for name in ["DotSphere.swift", "CharSphere.swift"] {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try String(contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                    .appendingPathComponent(name), encoding: .utf8)
            )
            #expect(code.contains("SphereSurface("), "\(name) 没有转发给共享驱动")
            for forwarded in ["count: self.count", "colors: self.colors", "rotationPeriod: self.rotationPeriod"] {
                #expect(code.contains(forwarded), """
                \(name) 没有把 `\(forwarded)` 交给 `SphereSurface` —— 调用方传的这个参数被静默忽略。
                """)
            }
            for keyword in MicroInteractionReduceMotionGuard.motionCalls {
                #expect(!code.contains(keyword), "\(name) 自己写了运动调用 `\(keyword)` —— 它不再是薄封装")
            }
            for keyword in ["EnergyState", "accessibilityReduceMotion", "TimelineView", "phaseAnimator", "keyframeAnimator"] {
                #expect(!code.contains(keyword),
                        "\(name) 自己接了 `\(keyword)` —— 降级 / 能耗闸会与共享驱动漂移")
            }
        }
    }
}

// MARK: - 平台支持守卫（AD-E 的机器判据）

@Suite("跨平台四件的平台支持守卫")
struct PlatformSupportGuard {
    static var repoRoot: URL {
        MicroInteractionReduceMotionGuard.sourceRoot
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func effectsSources() throws -> [(name: String, code: String)] {
        try MicroInteractionReduceMotionGuard.swiftFiles().map {
            ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8))
        }
    }

    // MARK: ① 不许把平台专有框架 import 进来

    @Test("Effects 里不许出现平台专有框架的 import")
    func noPlatformOnlyImports() throws {
        let banned = ["UIKit", "AppKit", "SpriteKit", "SceneKit"]
        var offenders: [String] = []
        for (name, code) in try Self.effectsSources() {
            let stripped = MicroInteractionReduceMotionGuard.stripComments(code)
            for (index, rawLine) in stripped.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix("import ") || line.hasPrefix("@_exported import ") else { continue }
                let words = line.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
                    .map(String.init)
                for framework in banned where words.contains(framework) {
                    offenders.append("\(name):\(index + 1) \(line)")
                }
            }
        }
        #expect(offenders.isEmpty, """
        这些 import 会把 CoreDesignEffects 钉死在单一平台上（AD-E 的正面违反）：
        \(offenders.joined(separator: "\n"))
        """)
    }

    @Test("import 探测器真的会开火（合成源码逐条变红）")
    func importDetectorFires() {
        func offenders(in code: String) -> [String] {
            var found: [String] = []
            let banned = ["UIKit", "AppKit", "SpriteKit", "SceneKit"]
            for rawLine in MicroInteractionReduceMotionGuard.stripComments(code)
                .split(separator: "\n", omittingEmptySubsequences: false) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix("import ") || line.hasPrefix("@_exported import ") else { continue }
                let words = line.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }).map(String.init)
                for framework in banned where words.contains(framework) { found.append(line) }
            }
            return found
        }
        #expect(!offenders(in: "import UIKit").isEmpty)
        #expect(!offenders(in: "import SpriteKit").isEmpty, "上游 OrbitingLogos 的那一行")
        #expect(!offenders(in: "import class UIKit.UIColor").isEmpty)
        #expect(!offenders(in: "  import AppKit").isEmpty, "缩进后的 import 同样要抓")
        #expect(offenders(in: "// 上游这里写的是 import UIKit").isEmpty)
        #expect(offenders(in: "import SwiftUI").isEmpty)
        #expect(offenders(in: "import CoreDesign").isEmpty)
    }

    // MARK: ② 平台围栏必须两端都有代码

    struct Fence {
        let file: String
        let line: Int
        let condition: String
        var hasElse: Bool
    }

    static func fences(in code: String, file: String) -> [Fence] {
        var stack: [Int] = []
        var result: [Fence] = []
        for (index, rawLine) in code.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                let condition = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let isPlatform = ["os(", "canImport(", "targetEnvironment("]
                    .contains { condition.contains($0) }
                if isPlatform {
                    result.append(Fence(file: file, line: index + 1, condition: condition, hasElse: false))
                    stack.append(result.count - 1)
                } else {
                    stack.append(-1)
                }
            } else if line.hasPrefix("#else") || line.hasPrefix("#elseif") {
                if let top = stack.last, top >= 0 { result[top].hasElse = true }
            } else if line.hasPrefix("#endif") {
                if !stack.isEmpty { stack.removeLast() }
            }
        }
        return result
    }

    @Test("每一道平台围栏都必须有 #else（macOS 上不许留空）")
    func everyPlatformFenceHasAnElse() throws {
        var offenders: [String] = []
        for (name, code) in try Self.effectsSources() {
            for fence in Self.fences(in: code, file: name) where !fence.hasElse {
                offenders.append("\(fence.file):\(fence.line) `#if \(fence.condition)` 没有 #else")
            }
        }
        #expect(offenders.isEmpty, """
        这些平台围栏在另一端什么都不给（macOS 上少一块行为，而编译照常通过）：
        \(offenders.joined(separator: "\n"))
        """)
    }

    @Test("围栏扫描器真的会开火，且嵌套层级不串")
    func fenceScannerFires() {
        let bare = "#if os(iOS)\nlet a = 1\n#endif"
        #expect(Self.fences(in: bare, file: "x").first?.hasElse == false)
        let paired = "#if os(iOS)\nlet a = 1\n#else\nlet a = 2\n#endif"
        #expect(Self.fences(in: paired, file: "x").first?.hasElse == true)
        #expect(Self.fences(in: "#if DEBUG\nlet a = 1\n#endif", file: "x").isEmpty)
        let nested = "#if os(iOS)\n#if DEBUG\nlet a = 1\n#else\nlet a = 2\n#endif\n#endif"
        #expect(Self.fences(in: nested, file: "x").first?.hasElse == false,
                "内层 #else 被算给了外层 —— 一个 `#if DEBUG` 就能让平台围栏蒙混过关")
        #expect(Self.fences(in: "#if canImport(UIKit)\nlet a = 1\n#endif", file: "x").count == 1)
    }

    // MARK: ③ Package.swift 的 platforms 不许被动

    @Test("Package.swift 仍然声明 macOS 支持")
    func packageStillSupportsMacOS() throws {
        let url = Self.repoRoot.appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: url, encoding: .utf8)
        #expect(manifest.contains("platforms:"), "Package.swift 里找不到 platforms 声明 —— 判据无法工作")
        #expect(manifest.contains(".macOS(.v26)"), """
        Package.swift 不再声明 .macOS(.v26) —— AD-E 的第一条 AC 就是"不得降低 macOS 支持"。
        跨平台改造的正解是让代码在两端都能跑，不是把 macOS 从 platforms 里删掉。
        """)
        #expect(manifest.contains(".iOS(.v26)"))
    }

    // MARK: ④ 平台限制必须写进 docs/components/*.md

    static let documentedPieces: [(slug: String, source: String)] = [
        ("dot-sphere", "DotSphere.swift"),
        ("char-sphere", "CharSphere.swift"),
        ("orbiting-logos", "OrbitingLogos.swift"),
        ("full-screen-button", "FullScreenButton.swift"),
    ]

    static func section(named title: String, in text: String) -> String? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        func isHeading(_ line: String, level: Int) -> Bool {
            let hashes = String(repeating: "#", count: level)
            return line.hasPrefix(hashes + " ")
        }
        guard let start = lines.firstIndex(where: { isHeading($0, level: 2) && $0.contains(title) })
        else { return nil }
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { isHeading($0, level: 2) } ?? rest.endIndex
        return rest[..<end].joined(separator: "\n")
    }

    static let behaviourWords = [
        "可用", "不可用", "编译", "退化", "降级", "推入", "放大", "一致", "相同",
        "同一份", "支持", "不支持", "转场", "完整", "空转", "冻结",
    ]

    static let differenceClaims = ["不可用", "编译不过", "差别", "差异", "只包住", "只有 iOS", "仅 iOS"]

    static let parityClaims = ["同一份代码", "完全一致", "没有任何条件编译", "没有平台分支", "没有条件编译"]

    static func platformSectionOffenders(
        slug: String, section: String, hasPlatformFence: Bool
    ) -> [String] {
        var out: [String] = []
        let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
        if !section.contains("macOS") { out.append("\(slug)：平台支持一节没提 macOS") }
        if !section.contains("iOS") { out.append("\(slug)：平台支持一节没提 iOS") }
        if trimmed.count < 80 { out.append("\(slug)：平台支持一节只有 \(trimmed.count) 字符，像占位") }

        let platformRows = section.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("|") && ($0.contains("iOS") || $0.contains("macOS")) }
        if platformRows.count < 2 {
            out.append("\(slug)：平台支持一节里少于两行平台表格行（iOS / macOS 各一行）")
        }
        for row in platformRows where !Self.behaviourWords.contains(where: row.contains) {
            out.append("\(slug)：平台行没说清行为（一个行为动词都没有）→ \(row)")
        }

        let claimsDifference = Self.differenceClaims.contains(where: section.contains)
        let claimsParity = Self.parityClaims.contains(where: section.contains)
        if hasPlatformFence, !claimsDifference {
            out.append("\(slug)：源码里真有平台围栏，文档却没说两端有差异")
        }
        if !hasPlatformFence, !claimsParity {
            out.append("\(slug)：源码里一道平台围栏都没有，文档却没说两端是同一份代码")
        }
        return out
    }

    @Test("四件的平台限制都写进了 docs/components/*.md，且与源码里的围栏一致")
    func platformLimitsAreDocumented() throws {
        var offenders: [String] = []
        for piece in Self.documentedPieces {
            let url = Self.repoRoot.appendingPathComponent("docs/components/\(piece.slug).md")
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                Issue.record("docs/components/\(piece.slug).md 不存在 —— AD-E 的硬 AC 没有落地")
                continue
            }
            guard let section = Self.section(named: "平台支持", in: text) else {
                Issue.record("docs/components/\(piece.slug).md 没有「## 平台支持」二级标题")
                continue
            }
            let code = try String(
                contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                    .appendingPathComponent(piece.source),
                encoding: .utf8
            )
            let hasFence = !Self.fences(in: code, file: piece.source).isEmpty
            offenders += Self.platformSectionOffenders(
                slug: piece.slug, section: section, hasPlatformFence: hasFence
            )
        }
        #expect(offenders.isEmpty, """
        平台支持一节写得不合格（AD-E 的硬 AC）：
        \(offenders.joined(separator: "\n"))
        """)
        let fullScreen = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/components/full-screen-button.md"),
            encoding: .utf8
        )
        #expect(fullScreen.contains("zoom"),
                "full-screen-button.md 没点名 .zoom —— 调用方无从知道 macOS 上少的是哪一层")
    }

    @Test("文档检查器真的会开火（含终审构造的那段占位）")
    func platformDocDetectorFires() {
        let padded = """
        | 平台 | 行为 |
        |---|---|
        | iOS 26+ | ✅ |
        | macOS 26+ | ✅ |

        两端都跑得起来，细节见源码。两端都跑得起来，细节见源码。两端都跑得起来。
        """
        #expect(padded.trimmingCharacters(in: .whitespacesAndNewlines).count >= 80,
                "这段占位本来就该过字数门槛 —— 否则下面证不到「字数不够用」这件事")
        let paddedOffenders = Self.platformSectionOffenders(
            slug: "x", section: padded, hasPlatformFence: false
        )
        #expect(paddedOffenders.contains { $0.contains("行为动词") },
                "只写一个勾的平台行没被抓住：\(paddedOffenders)")

        let liar = """
        | 平台 | 行为 |
        |---|---|
        | iOS 26+ | 完整可用 |
        | macOS 26+ | 完整可用，与 iOS 逐行同一份代码 |

        本件没有任何条件编译，两端完全一致，同一份代码同样跑得起来，观感逐字相同。
        """
        #expect(Self.platformSectionOffenders(slug: "x", section: liar, hasPlatformFence: true)
            .contains { $0.contains("真有平台围栏") }, "说反了的平台说明没被抓住")

        let good = """
        | 平台 | 转场 |
        |---|---|
        | iOS 26+ | `.zoom(sourceID:in:)` 几何匹配放大 |
        | macOS 26+ | 系统默认推入转场（`.zoom` 在 macOS 上不可用） |

        `.zoom` 在 macOS 上编译不过，`#if os(iOS)` 只包住那一行，其余两端完全一致。
        """
        #expect(Self.platformSectionOffenders(slug: "x", section: good, hasPlatformFence: true).isEmpty,
                "合格的说明被误伤了：\(Self.platformSectionOffenders(slug: "x", section: good, hasPlatformFence: true))")

        let subheading = "# T\n\n### 平台支持\n\n只是个子节。\n"
        #expect(Self.section(named: "平台支持", in: subheading) == nil,
                "三级子标题被当成了 `## 平台支持` —— 取到的节根本不是那一节")
        let nested = "## 平台支持\n\n一行。\n\n### 细节\n\n二行。\n\n## 下一节\n\n三行。\n"
        let picked = Self.section(named: "平台支持", in: nested) ?? ""
        #expect(picked.contains("二行。"), "`###` 子节被错误地当成了本节的终止符")
        #expect(!picked.contains("三行。"), "本节越过了下一个二级标题")
    }

    // MARK: ⑤ FullScreenButton 的隔离与降级

    @Test("`.zoom(` 只出现在 #if os(iOS) 里，且整个类型没有被围栏吞掉")
    func zoomIsFencedToIOS() throws {
        let code = try String(
            contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                .appendingPathComponent("FullScreenButton.swift"),
            encoding: .utf8
        )
        let stripped = MicroInteractionReduceMotionGuard.stripComments(code)
        let lines = stripped.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var depth = 0
        var iOSBranchDepths: Set<Int> = []
        var offenders: [String] = []
        var publicTypeDepth: Int?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if") {
                depth += 1
                if trimmed.contains("os(iOS)") { iOSBranchDepths.insert(depth) }
            } else if trimmed.hasPrefix("#else") || trimmed.hasPrefix("#elseif") {
                iOSBranchDepths.remove(depth)
            } else if trimmed.hasPrefix("#endif") {
                iOSBranchDepths.remove(depth)
                depth -= 1
            } else {
                if trimmed.contains(".zoom("), iOSBranchDepths.isEmpty {
                    offenders.append("\(index + 1): \(trimmed)")
                }
                if trimmed.hasPrefix("public struct FullScreenButton"), depth > 0 {
                    publicTypeDepth = index + 1
                }
            }
        }
        #expect(offenders.isEmpty, """
        `.zoom(` 出现在 #if os(iOS) 之外 —— 那在 macOS 上是编译错误：
        \(offenders.joined(separator: "\n"))
        """)
        #expect(stripped.contains(".zoom("), "文件里根本没有 .zoom —— 判据在空输入上恒真")
        #expect(publicTypeDepth == nil, """
        `public struct FullScreenButton` 被包在条件编译里（第 \(publicTypeDepth ?? 0) 行）
        —— 那不是"隔离一行不可跨平台的 API"，是让整个公开类型在 macOS 上消失。
        """)
    }

    @Test("调用点：FullScreenButton.swift 里 reduceMotion 只喂给 FullScreenTransitionPlan.resolve")
    func reduceMotionIsOnlyConsumedByTheTransitionPlan() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try String(
            contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                .appendingPathComponent("FullScreenButton.swift"),
            encoding: .utf8
        ))
        #expect(code.contains("accessibilityReduceMotion"),
                "FullScreenButton 没有读 Reduce Motion —— 降级无从谈起")
        let reads = code.components(separatedBy: "self.reduceMotion").count - 1
        let fed = code.components(separatedBy: "reduceMotion: self.reduceMotion").count - 1
        #expect(fed >= 1, "没有把 reduceMotion 喂给 FullScreenTransitionPlan.resolve")
        #expect(reads == fed, """
        `self.reduceMotion` 出现 \(reads) 次，只有 \(fed) 次喂给裁决函数
        —— 多出来的那些是调用点自己又判了一遍，两处必然漂移。
        """)
        let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: code)
        #expect(strays.isEmpty, """
        这些 `reduceMotion` 既不是声明、也不是实参标签、更不是 `self.reduceMotion`：
        \(strays.joined(separator: "\n"))
        """)
    }

    @Test("sourceID 单一来源：不许跨泛型特化去取静态成员")
    func sourceIDHasASingleSource() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try String(
            contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                .appendingPathComponent("FullScreenButton.swift"),
            encoding: .utf8
        ))
        #expect(!code.contains(">.sourceID"), """
        出现了跨泛型特化的 `sourceID` 静态访问（形如 `FullScreenButton<A, B>.sourceID`）。
        Swift 的泛型静态成员按具体特化分开 ⇒ label 与 destination 可能拿到两个不同的 id，
        zoom 静默退化成普通 push 且无编译错误、无测试失败。
        """)
        #expect(code.contains("matchedTransitionSource(id: Self.sourceID"),
                "label 侧不再用 `Self.sourceID` —— 单一来源这条断了")
        #expect(code.contains("sourceID: Self.sourceID"),
                "目的地没有从 `FullScreenButton` 拿到 sourceID —— 它又在自己取了")
        #expect(code.contains(".zoom(sourceID: self.sourceID"),
                "`.zoom` 用的不是传进来的那个 sourceID")
    }

    @Test("四件各自带 #Preview")
    func everyPieceHasAPreview() throws {
        for name in ["DotSphere.swift", "CharSphere.swift", "OrbitingLogos.swift", "FullScreenButton.swift"] {
            let code = try String(
                contentsOf: MicroInteractionReduceMotionGuard.sourceRoot.appendingPathComponent(name),
                encoding: .utf8
            )
            #expect(code.contains("#Preview"), "\(name) 没有 #Preview")
        }
    }
}
