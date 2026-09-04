import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #254：跨平台改造（OrbitingLogos / DotSphere / CharSphere / FullScreenButton）
//
// 本 task 与前四个性质不同：不是"新写效果"，而是让上游**四个非纯 SwiftUI 件**
// 在 macOS 上活下来，且**不降低 package 的 macOS 支持**。
//
// | 件 | 上游依赖 | 本仓处置 |
// |---|---|---|
// | `DotSphere` | `import UIKit`（只为 `UIColor(color).getRed`） | **重写为跨平台**：取色改走 `Color.mix`/`.tint`，一行平台分支都不留 |
// | `CharSphere` | 同上 | **重写为跨平台** |
// | `OrbitingLogos` | `import SpriteKit`（SKScene + 物理体） | **重写为跨平台**：环 + 点用 `Canvas` 画，物理挤压换成解析位移场 |
// | `FullScreenButton` | `navigationTransition(.zoom)`，macOS 上**编译不过** | **隔离 + 文档标注**：`#if os(iOS)` 只包住 `.zoom`，macOS 走系统默认转场 |
//
// ⚠️ 只有第四件走了"隔离"，前三件都是真重写。四件的平台限制**必须**同时写进
// `docs/components/*.md`（AD-E 第 2 轮评审 S-2 的硬 AC），本文件的
// `PlatformSupportGuard` 用机器判据钉住这一条——否则它就只是一句人话。

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

    /// 退化输入：`count == 1` 时上游的 `(count − 1)` 会除零。
    @Test("退化输入：单点落在赤道、不产生 NaN")
    func singlePointDoesNotDivideByZero() {
        let p = SphereField.unitPoint(index: 0, count: 1)
        #expect(!p.x.isNaN && !p.y.isNaN && !p.z.isNaN)
        #expect(p.y == 0)
        // 越界索引同样不许炸。
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
        // 参考时刻之前（负时间）同样落在 [0, 1)。
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
        // 半径为 0（尺寸为 0 的容器）不许产生 NaN / inf。
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
        // 走完一个完整周期后换到下一对。
        let later = SphereField.wave(at: base.addingTimeInterval(SphereField.waveCycle), paletteCount: 3)
        #expect(later.base == 1 && later.next == 2)
        // 单色色板：两端同一索引，不越界。
        let single = SphereField.wave(at: base.addingTimeInterval(99), paletteCount: 1)
        #expect(single.base == 0 && single.next == 0)
        // 空色板：不许除零。
        let none = SphereField.wave(at: base.addingTimeInterval(99), paletteCount: 0)
        #expect(none.base == 0 && none.next == 0)

        // 高处的点延迟更久 ⇒ 同一时刻进度更小（浪从下往上）。
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

    /// ⚠️⚠️ **本条是"看图"逼出来的**（本轮实测，照录成因）：
    /// 我给 `glyphSlot` 写的注释宣称它"用 Knuth 乘法散列打散、不是 `index % count`"，
    /// 而渲染出来的字球上肉眼可见一圈圈整齐重复的 道/德/经。
    ///
    /// 算一下就知道注释是假的：`(index &* 2654435761) % 5`
    /// = `(index * (2654435761 % 5)) % 5` = `(index * 1) % 5` = **`index % 5`**
    /// ——乘法散列的高位熵在"直接取模一个小数"时**全部被丢掉**，它退化成恒等映射。
    /// ⇒ 判据必须直接钉"与朴素取模不同"，而不是信注释里的那个词。
    @Test("字形分配：确定性、在界内，且**不**等价于 index % count")
    func glyphSlotIsScrambledNotModulo() {
        // ① 确定性（同一输入两次调用必须相同——不许是 Int.random）。
        for index in 0..<50 {
            #expect(SphereField.glyphSlot(index: index, glyphCount: 7)
                    == SphereField.glyphSlot(index: index, glyphCount: 7))
        }
        // ② 界内 + 退化输入。
        for count in [1, 2, 5, 59] {
            for index in 0..<200 {
                let slot = SphereField.glyphSlot(index: index, glyphCount: count)
                #expect(slot >= 0 && slot < count, "count=\(count) index=\(index) 越界：\(slot)")
            }
        }
        #expect(SphereField.glyphSlot(index: 3, glyphCount: 0) == 0, "空字表不许除零")
        #expect(SphereField.glyphSlot(index: -4, glyphCount: 5) >= 0, "负索引不许给出负下标")

        // ③ ⚠️ **承重**：与 `index % count` 必须**不同**。
        for count in [3, 5, 8] {
            let naive = (0..<40).map { $0 % count }
            let actual = (0..<40).map { SphereField.glyphSlot(index: $0, glyphCount: count) }
            #expect(actual != naive, """
            count=\(count) 时 glyphSlot 与 `index % count` 逐项相同 —— 字表会沿着 Vogel 螺旋
            整齐重复，肉眼能看出一圈圈的规律（本轮渲图实测到的正是这个）。
            """)
        }
        // ④ 互锁：也不许退化成"永远同一个字"。
        let spread = Set((0..<40).map { SphereField.glyphSlot(index: $0, glyphCount: 5) })
        #expect(spread.count == 5, "40 个点位只用到了 \(spread.count) 个字 —— 分配退化了")
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
        // 零个 / 一个 logo 都不许除零。
        #expect(OrbitRing.slot(of: 0, logoCount: 0) == 0)
        #expect(OrbitRing.slot(of: 0, logoCount: 1) == 0)
        // logo 比 slot 还多时按 slot 取模，仍在合法区间。
        #expect(OrbitRing.slot(of: 99, logoCount: 99) < OrbitRing.dotsPerRing)
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
        // 退化输入：零个 logo。
        let none = OrbitRing.feature(at: base.addingTimeInterval(5), logoCount: 0)
        #expect(none.index == 0 && none.progress.isFinite)
    }

    /// ⚠️ **承重**：pop 的两端必须回到 1，否则 logo 会永远停在放大状态。
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

    /// 上游用 SpriteKit 物理体让被放大的点把邻居挤开；这里换成**解析位移场**。
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
        // 退化输入：点与源重合（方向无定义）不许产生 NaN。
        let coincident = OrbitRing.pushed(source, awayFrom: source, radius: 60, strength: 20)
        #expect(coincident.x.isFinite && coincident.y.isFinite)
        // 半径为 0 同样不许除零。
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

// MARK: - FullScreenButton 的转场裁决

@Suite("FullScreenButton 的转场裁决")
struct FullScreenTransitionPlanTests {

    /// ⚠️⚠️ **承重**：四种输入组合的真值表。
    /// `.zoom` 在 macOS 上**编译不过**（实测 `'zoom(sourceID:in:)' is unavailable in macOS`），
    /// 而 Reduce Motion 下即使在 iOS 上也不该做几何放大 ⇒ 两条闸都必须落到 `.plain`。
    @Test("只有「支持 zoom 的平台 × 未开启 Reduce Motion」才走 zoom")
    func zoomRequiresBothPlatformAndMotion() {
        #expect(FullScreenTransitionPlan.resolve(reduceMotion: false, platformSupportsZoom: true) == .zoom)
        #expect(FullScreenTransitionPlan.resolve(reduceMotion: true, platformSupportsZoom: true) == .plain)
        #expect(FullScreenTransitionPlan.resolve(reduceMotion: false, platformSupportsZoom: false) == .plain)
        #expect(FullScreenTransitionPlan.resolve(reduceMotion: true, platformSupportsZoom: false) == .plain)
    }

    /// 平台常量本身也要判——写反了（macOS 报 true）会让 `#if` 与裁决脱节。
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

/// ⚠️⚠️ **每条渲染分支各自暖机**（`#253` PR #273 的教训逐字：只暖了一条分支
/// 导致另一条分支的判据实际上在比首帧伪影）。本 suite 有**四条**互不相同的绘制路径：
/// 圆点 / 字形 × 「直接上色」/「`.tint` + alpha 遮罩」，加上轨道环那一条。
@Suite("跨平台四件的渲染契约")
@MainActor
struct CrossPlatformRenderTests {

    static let side: CGFloat = 220

    static func framed(_ view: some View) -> some View {
        view.frame(width: Self.side, height: Self.side).background(Color.surfaceRaised)
    }

    /// ⚠️⚠️ **两个能耗信号必须显式注入，一个都不能省**（本轮实测踩到）：
    ///
    /// · `\.scenePhase` 在 `ImageRenderer` 这种**没有 `Scene` 的**求值环境里不是
    ///   `.active` ⇒ 不注入的话能耗闸判 `.paused`、`particleScale == 0`
    ///   ⇒ **每一张位图都是空白**，而"空白 == 空白"会让一整批相等断言恒真。
    ///   第一版就是这样：9 条判据里 6 条在比两张空白图。
    /// · `\.lowPowerModeOverride` 不注入则回落到 `ProcessInfo.isLowPowerModeEnabled`
    ///   ⇒ **判据的绿不绿取决于跑测试那台机器当时插没插电**。
    ///
    /// ⇒ 本 suite 的每一次取像素都经过这里。要测停摆的那条判据显式传 `phase:`。
    static func staged(
        _ view: some View, phase: ScenePhase = .active, lowPower: Bool = false
    ) -> some View {
        Self.framed(
            view
                .environment(\.scenePhaseOverride, phase)
                .environment(\.lowPowerModeOverride, lowPower)
        )
    }

    /// 空白基线：只有底色，什么都没画。
    static var blank: Data? { Self.pixels(Self.framed(Color.clear)) }

    /// 固定相位的球面绘制层。**不走 `TimelineView`** ⇒ 与挂钟无关，可比。
    static func sphereBody(
        mark: SphereMark, count: Int = 240, colors: [Color] = [],
        turns: Double = SphereField.restingPhase
    ) -> SphereSurfaceBody {
        SphereSurfaceBody(
            mark: mark, count: count, colors: colors, turns: turns,
            wave: SphereField.restingWave(paletteCount: colors.count)
        )
    }

    /// 固定相位的轨道环绘制层。
    static func orbitBody(
        colors: [Color] = [], turns: Double = OrbitRing.restingPhase,
        feature: (index: Int, progress: Double) = OrbitRing.restingFeature
    ) -> some View {
        OrbitingLogosBody(
            items: OrbitingLogosPreviewItem.samples, colors: colors, turns: turns, feature: feature,
            logo: { item in
                Circle().fill(Color.contentPrimary).frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                    .id(item.id)
            },
            center: Circle().fill(Color.accent).frame(width: 40, height: 40)
        )
    }

    /// ⚠️⚠️ **本 suite 只用系统语义色做位图判据，不用资源色阶（本轮实测的坑）**：
    /// `swift test` 进程里 `Color("brand-…", bundle: .module)` 一族**解析成完全透明**
    /// （实测 `Color.secondaryAccent.resolve(in:)` 给出 `a = 0.0`，
    /// 在 `CoreDesignTests` 与 `CoreDesignEffectsTests` 两个 target 上都一样
    /// ⇒ 是本仓既有条件，不是本 target 的私事，与 `CLAUDE.md`《验证边界与常见坑》
    /// 记的"资源缺失是静默失败"同源）。
    /// ⚠️ 后果不是理论上的：用它当"另一种 tint"会让 `a != b` 这类判据**因为其中一张
    /// 是空白而通过** —— 判到的是"这个色根本没画出来"，不是"取色跟着调用方走"。
    /// ⇒ 本文件用到的每个颜色都实测过非透明：`accent` / `contentPrimary` /
    /// `contentSecondary` / `borderSubtle`。
    ///
    /// ⚠️ **逐分支暖机**：六条路径各跑 8 次。
    private static let branchWarmUp: Bool = {
        let probes: [AnyView] = [
            AnyView(Self.staged(Self.sphereBody(mark: .dots(diameter: 3)))),
            AnyView(Self.staged(Self.sphereBody(mark: .dots(diameter: 3), colors: [.accent]))),
            AnyView(Self.staged(Self.sphereBody(mark: .glyphs(["道"], fontSize: 11)))),
            AnyView(Self.staged(Self.sphereBody(mark: .glyphs(["道"], fontSize: 11), colors: [.accent]))),
            AnyView(Self.staged(Self.orbitBody())),
            AnyView(Self.staged(Self.orbitBody(colors: [.accent]))),
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

    /// ⚠️⚠️ **承重**：空色板 ⇒ 全部取调用方的 `.tint`。
    @Test("空色板：换 .tint 位图必须变；给了色板则必须不变")
    func spheresFollowTheCallerTint() {
        for mark in [SphereMark.dots(diameter: 4), .glyphs(["道", "德"], fontSize: 14)] {
            let a = Self.pixels(Self.staged(Self.sphereBody(mark: mark).tint(Color.accent)))
            let b = Self.pixels(Self.staged(Self.sphereBody(mark: mark).tint(Color.contentSecondary)))
            #expect(a != nil && b != nil, "渲染失败，下面的相等断言会恒真")
            #expect(a != b, "\(mark) 空色板下换 .tint 位图没变 —— 取色没走调用方")
            #expect(a != Self.blank, "空色板下什么都没画")

            let palette = [Color.borderSubtle]
            let c = Self.pixels(Self.staged(Self.sphereBody(mark: mark, colors: palette).tint(Color.accent)))
            let d = Self.pixels(Self.staged(Self.sphereBody(mark: mark, colors: palette).tint(Color.contentSecondary)))
            #expect(c != nil && c != Self.blank)
            #expect(c == d, "\(mark) 给了色板还跟着 .tint 变 —— 调用方的色板被忽略了")
        }
    }

    @Test("轨道环：空色板取 .tint，给了色板则不跟着变")
    func orbitFollowsTheCallerTint() {
        let a = Self.pixels(Self.staged(Self.orbitBody().tint(Color.accent)))
        let b = Self.pixels(Self.staged(Self.orbitBody().tint(Color.contentSecondary)))
        #expect(a != nil && b != nil)
        #expect(a != b, "空色板下换 .tint 位图没变 —— 环上的点没走调用方取色")
        let c = Self.pixels(Self.staged(Self.orbitBody(colors: [.borderSubtle]).tint(Color.accent)))
        let d = Self.pixels(Self.staged(Self.orbitBody(colors: [.borderSubtle]).tint(Color.contentSecondary)))
        #expect(c != nil && c != Self.blank)
        #expect(c == d, "给了色板还跟着 .tint 变")
    }

    // MARK: NFR-7 能耗闸

    /// ⚠️⚠️ **承重**：`.background` / `.inactive` ⇒ 一个像素都不画。
    ///
    /// ⚠️ **它证不到"整层不建"那一半**（本轮变异实测）：`SphereSurfaceBody` 自己也读
    /// 能耗环境，停摆时 `particleScale == 0` ⇒ 「`.none` 分支返回 `EmptyView()`」与
    /// 「`.none` 分支照常建绘制层」渲出来**逐字节相同**。那一半由
    /// `presentationBranchesAreWiredCorrectly`（源码链）接管。
    @Test("后台与非活跃：四件里的三个常驻件一个像素都不画")
    func pausedDrawsNothing() {
        for phase in [ScenePhase.background, .inactive] {
            let dot = Self.pixels(Self.staged(DotSphere(), phase: phase))
            let char = Self.pixels(Self.staged(CharSphere(["道"]), phase: phase))
            let orbit = Self.pixels(Self.staged(Self.orbitContainer(), phase: phase))
            #expect(dot == Self.blank, "DotSphere 在 \(phase) 下还在画")
            #expect(char == Self.blank, "CharSphere 在 \(phase) 下还在画")
            #expect(orbit == Self.blank, "OrbitingLogos 在 \(phase) 下还在画")
        }
        // ⚠️ **互锁**：`.active` 下必须画得出东西，否则上面三条对"永远不画"的实现也恒真。
        let active = Self.pixels(Self.staged(DotSphere()))
        #expect(active != nil && active != Self.blank, "活跃态下什么都没画 —— 上面的停摆判据是空真")
    }

    static func orbitContainer() -> some View {
        OrbitingLogos(OrbitingLogosPreviewItem.samples) { _ in
            Circle().fill(Color.contentPrimary).frame(width: 12, height: 12)
        } center: {
            Circle().fill(Color.accent).frame(width: 40, height: 40)
        }
    }

    /// 低电量在**静态帧**上唯一可观测的差异是密度（降帧拍不进一帧）。
    @Test("低电量：点数减半 ⇒ 同一相位的位图必须不同")
    func lowPowerThinsTheField() {
        let full = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 4), count: 400)))
        let low = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 4), count: 400), lowPower: true))
        #expect(full != nil && low != nil)
        #expect(full != low, "低电量下点数没变 —— particleScale 这个旋钮没接上")
        #expect(low != Self.blank, "低电量下一个点都不画 —— 那是停摆不是降级")

        let fullOrbit = Self.pixels(Self.staged(Self.orbitBody()))
        let lowOrbit = Self.pixels(Self.staged(Self.orbitBody(), lowPower: true))
        #expect(fullOrbit != lowOrbit, "低电量下环上点数没变")
        #expect(lowOrbit != Self.blank)
    }

    // MARK: Reduce Motion 的静止形态

    /// ⚠️ `\.accessibilityReduceMotion` 不可注入 ⇒ RM 方向只能落在纯函数与源码两条链上。
    /// 位图这条只证一件事：**静止相位画得出东西**（"冻结"不是"变空白"）。
    @Test("静止相位画得出球，且与别的相位不是同一张图")
    func restingPhaseStillDraws() {
        let resting = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 4))))
        let moved = Self.pixels(Self.staged(Self.sphereBody(mark: .dots(diameter: 4), turns: 0.37)))
        #expect(resting != nil && resting != Self.blank, "静止形态是空白 —— 那是 no-op 不是降级")
        #expect(resting != moved, "两个不同相位渲成了同一张图 —— 自转根本没接上")
    }

    /// pop 的两端归 1、中段放大，位图层面也要看得见。
    @Test("轮播：被点名的 logo 在中段确实放大了")
    func featuredLogoPopsOut() {
        let rest = Self.pixels(Self.staged(Self.orbitBody(feature: (index: 0, progress: 0))))
        let peak = Self.pixels(Self.staged(Self.orbitBody(feature: (index: 0, progress: 0.5))))
        #expect(rest != nil && peak != nil)
        #expect(rest != peak, "pop 峰值与静止渲成了同一张图 —— 放大与挤压都没发生")
    }

    // MARK: 退化输入

    @Test("退化输入：点数为 0 / 负 / 超限、字表为空、条目为空都不崩")
    func degenerateInputsDoNotCrash() {
        #expect(Self.pixels(Self.staged(DotSphere(count: 0))) == Self.blank, "0 个点却画了东西")
        #expect(Self.pixels(Self.staged(DotSphere(count: -12))) == Self.blank)
        #expect(Self.pixels(Self.staged(DotSphere(count: 99_999))) != nil, "超限点数应当截断而不是崩")
        #expect(Self.pixels(Self.staged(DotSphere(rotationPeriod: 0))) != Self.blank, "周期为 0 应当静止而不是空白")
        #expect(Self.pixels(Self.staged(CharSphere([]))) == Self.blank, "空字表却画了东西")
        #expect(Self.pixels(Self.staged(CharSphere(["道"], count: 0))) == Self.blank)
        let empty = OrbitingLogos([OrbitingLogosPreviewItem]()) { _ in
            Circle().frame(width: 8, height: 8)
        } center: {
            EmptyView()
        }
        #expect(Self.pixels(Self.staged(empty)) != Self.blank, "没有 logo 时环也该照画")
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
        #expect(rendered != Self.blank, "什么都没画 —— macOS 上这一件应当照常可用")
    }

    // MARK: 三档呈现的接线（位图路结构上到不了的那一半）

    /// ⚠️⚠️ **本条是两枚逃逸出位图判据的变异逼出来的**（本轮实测，逐条照录）：
    ///
    /// | 变异 | `pausedDrawsNothing` / `restingPhaseStillDraws` | 成因 |
    /// |---|---|---|
    /// | 把 `.none` 分支换成"照常画一帧静止球" | **绿** | `SphereSurfaceBody` **自己**也读能耗环境，停摆时 `particleScale == 0` ⇒ 两条路都渲成空白，位图上不可分辨 |
    /// | 把 `.resting` 分支的相位从 `SphereField.restingPhase` 改成 `0.37` | **绿** | `\.accessibilityReduceMotion` 不可注入 ⇒ 那条分支在测试里**根本到不了**；位图判据构造的是 `SphereSurfaceBody`，绕过了驱动层 |
    ///
    /// ⇒ 三档呈现"接得对不对"只能落在**源码**这条链上（同
    /// `AnimatedMeshGradientTests.timelineOnlyExistsInTheAnimatedBranch` 的处置）。
    ///
    /// ⚠️ **已知限度**：本条钉的是"分支里写了什么"，不是"运行起来是什么"。
    /// 一个把 `SphereField.restingPhase` 改成 `0.37` 的**常量定义**（而不是调用点）
    /// 仍然会绿——那条由 `SphereFieldTests.restingPhaseIsCharacteristic` 从另一侧管。
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
        // `switch` 体 = 到下一个类型声明为止（驱动层之后就是调度层）。
        let switchBody = afterSwitch.components(separatedBy: "struct SphereSurfaceTimeline").first ?? afterSwitch

        // ① 停摆档**什么都不建**。
        let noneBranch = switchBody.components(separatedBy: "case .resting:").first ?? ""
        #expect(noneBranch.contains("EmptyView()"), """
        `.none` 分支不是 `EmptyView()` —— NFR-7 的"一个像素都不画"变成了"画了但画不出来"。
        ⚠️ 这枚变异在位图判据上是绿的（见本条的类型文档）。
        """)
        #expect(!noneBranch.contains("SphereSurfaceBody("), "`.none` 分支还在建绘制层")
        #expect(!noneBranch.contains("SphereSurfaceTimeline("), "`.none` 分支还在建调度器")

        // ② 静止档钉在 restingPhase / restingWave 上，且**不建调度器**。
        let restingBranch = (switchBody.components(separatedBy: "case .resting:").last ?? "")
            .components(separatedBy: "case .animated:").first ?? ""
        #expect(restingBranch.contains("SphereField.restingPhase"), """
        `.resting` 分支没有把相位钉在 `SphereField.restingPhase` 上
        —— Reduce Motion 下的"冻结"会冻在一个随手写的相位上。
        """)
        #expect(restingBranch.contains("SphereField.restingWave("), "`.resting` 分支的色波没有钉死")
        #expect(!restingBranch.contains("TimelineView("), "`.resting` 分支建了调度器")
        #expect(!restingBranch.contains("SphereSurfaceTimeline("), "`.resting` 分支建了调度器")

        // ③ 只有 animated 档建调度器，而且 `TimelineView` 本身关在独立类型里。
        #expect(!switchBody.contains("TimelineView("),
                "驱动层的 switch 体里直接建了 TimelineView —— 停摆 / 静止两档会跟着建出调度器")
        let animatedBranch = switchBody.components(separatedBy: "case .animated:").last ?? ""
        #expect(animatedBranch.contains("SphereSurfaceTimeline("), "`.animated` 分支没有建调度器")
        #expect(code.contains("TimelineView("), "整份文件都没有 TimelineView —— 这个效果根本没在动")
    }

    /// `OrbitingLogos` 的同一条链（它有自己的 `switch`，不与球面件共用驱动）。
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
        let noneBranch = switchBody.components(separatedBy: "case .resting:").first ?? ""
        #expect(noneBranch.contains("EmptyView()"), "`.none` 分支不是 EmptyView()")
        #expect(!noneBranch.contains("OrbitingLogosBody("), "`.none` 分支还在建绘制层")
        let restingBranch = (switchBody.components(separatedBy: "case .resting:").last ?? "")
            .components(separatedBy: "case .animated:").first ?? ""
        #expect(restingBranch.contains("OrbitRing.restingPhase"), "`.resting` 分支没有钉住自转相位")
        #expect(restingBranch.contains("OrbitRing.restingFeature"),
                "`.resting` 分支没有钉住轮播 —— Reduce Motion 下仍会有 logo 弹出放大")
        #expect(!switchBody.contains("TimelineView("), "驱动层的 switch 体里直接建了 TimelineView")
    }

    // MARK: 薄封装的互锁

    /// ⚠️ 两个球面件在 `approvedNoMotion` 名单上，前提是它们**真的**只做转发。
    /// 本条把那个前提自己钉住（形态同 `ProcessingSweepTests.containersDelegateToDriver`）。
    @Test("薄封装：两个球面件只转发给 SphereSurface，不自建动画 / 绘制 / 能耗闸")
    func spheresDelegateToSharedSurface() throws {
        for name in ["DotSphere.swift", "CharSphere.swift"] {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try String(contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                    .appendingPathComponent(name), encoding: .utf8)
            )
            #expect(code.contains("SphereSurface("), "\(name) 没有转发给共享驱动")
            for keyword in MicroInteractionReduceMotionGuard.motionCalls {
                #expect(!code.contains(keyword), "\(name) 自己写了运动调用 `\(keyword)` —— 它不再是薄封装")
            }
            for keyword in ["EffectsEnergyState", "accessibilityReduceMotion", "TimelineView", "phaseAnimator", "keyframeAnimator"] {
                #expect(!code.contains(keyword),
                        "\(name) 自己接了 `\(keyword)` —— 降级 / 能耗闸会与共享驱动漂移")
            }
        }
    }
}

// MARK: - 平台支持守卫（AD-E 的机器判据）

/// ⚠️⚠️ **本 suite 是 `#254` 的 AC 里唯一"人话变机器判据"的那一半。**
///
/// AD-E 的三条硬 AC——「不得降低 macOS 支持」「平台限制必须写进
/// `docs/components/*.md`」「隔离只许包住真正不可跨平台的那一行」——如果只写在
/// 任务书与代码注释里，下一个人加一句 `import UIKit` 时**没有任何东西会红**。
///
/// ## **已知口子**（写在明处，不是漏了）
///
/// 1. **判据只覆盖 `Sources/CoreDesignEffects`**（`sourceRoot`）。同一枚违规
///    落在 `Sources/CoreDesign` 或 `Sources/CoreDesignCharts` 里本 suite 一概看不见
///    ——那两个根有各自的守卫，而"平台围栏"这条**目前只有本 target 有人查**。
///    扩根是一次独立裁决（会顶动 `CoreDesign` 现存的 `#if canImport(UIKit)` 桥接层，
///    那一层的 `#else` 形态与本条判据不同）。
/// 2. **文档判据查的是"写了没有"，不是"写得对不对"**：一份说反了的平台说明
///    照样绿。真值靠人工评审。本条只堵"根本没写"这个方向。
/// 3. **`#else` 判据不看分支内容**：`#if os(iOS) … #else … #endif` 里 `#else` 分支
///    只写一句 `EmptyView()` 也算数。它堵的是"macOS 上那半段代码根本不存在"，
///    不是"macOS 上的行为等价"。
@Suite("跨平台四件的平台支持守卫")
struct PlatformSupportGuard {

    /// ⚠️ 复用 `MicroInteractionReduceMotionGuard.sourceRoot` 推导仓库根，
    /// 不重抄一遍 `deletingLastPathComponent`（同 `TypewriterTextTests.source(_:)` 的理由：
    /// 两处各自演化时，挪目录只有一处会跟着改）。
    static var repoRoot: URL {
        MicroInteractionReduceMotionGuard.sourceRoot
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // 仓库根
    }

    static func effectsSources() throws -> [(name: String, code: String)] {
        try MicroInteractionReduceMotionGuard.swiftFiles().map {
            ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8))
        }
    }

    // MARK: ① 不许把平台专有框架 import 进来

    /// ⚠️⚠️ **承重**：上游四件里三件的问题就是这一行
    /// （`import UIKit` × 2、`import SpriteKit` × 1）。
    ///
    /// 判据形态是**逐行**而不是整篇 `contains`：`contains("import UIKit")` 会漏掉
    /// `import class UIKit.UIColor`（细粒度 import，Swift 完全合法），也会被
    /// 文档注释里提到的"上游 `import UIKit`"误伤——本文件的类型文档里就有好几处。
    @Test("Effects 里不许出现平台专有框架的 import")
    func noPlatformOnlyImports() throws {
        let banned = ["UIKit", "AppKit", "SpriteKit", "SceneKit"]
        var offenders: [String] = []
        for (name, code) in try Self.effectsSources() {
            let stripped = MicroInteractionReduceMotionGuard.stripComments(code)
            for (index, rawLine) in stripped.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix("import ") || line.hasPrefix("@_exported import ") else { continue }
                // `import class UIKit.UIColor` / `import UIKit` 两种形态都要抓：
                // 取 import 之后的整段，按非标识符字符切成词再比。
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

    /// **非真空自证**：探测器对一段合成源码必须开火。
    /// 没有这条，「零违规」与「判据写错了、什么都不匹配」不可分辨。
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
        // ⚠️ 细粒度 import ——「整篇 contains("import UIKit")」会放过它。
        #expect(!offenders(in: "import class UIKit.UIColor").isEmpty)
        #expect(!offenders(in: "  import AppKit").isEmpty, "缩进后的 import 同样要抓")
        // 反向：注释里提到与正常 import 不许误伤。
        #expect(offenders(in: "// 上游这里写的是 import UIKit").isEmpty)
        #expect(offenders(in: "import SwiftUI").isEmpty)
        #expect(offenders(in: "import CoreDesign").isEmpty)
    }

    // MARK: ② 平台围栏必须两端都有代码

    /// 一段条件编译块的记录。
    struct Fence {
        let file: String
        let line: Int
        let condition: String
        var hasElse: Bool
    }

    /// 扫出所有**平台相关**的 `#if`，标出它有没有 `#else`。
    static func fences(in code: String, file: String) -> [Fence] {
        var stack: [Int] = []          // 每层在 result 里的下标；非平台条件存 -1
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

    /// ⚠️⚠️ **承重**：`#if os(iOS)` 少一个 `#else` = macOS 上那段代码**根本不存在**。
    /// 这正是"降低 macOS 支持"最常见、也最不容易被 `swift build` 抓到的形态
    /// ——库照样编译得过，只是 macOS 上少了一块行为。
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
        // 非平台条件不进结果（`#if DEBUG` 不该被要求补 `#else`）。
        #expect(Self.fences(in: "#if DEBUG\nlet a = 1\n#endif", file: "x").isEmpty)
        // ⚠️ **嵌套**：内层 `#if DEBUG` 的 `#else` 不许被算给外层平台围栏。
        let nested = "#if os(iOS)\n#if DEBUG\nlet a = 1\n#else\nlet a = 2\n#endif\n#endif"
        #expect(Self.fences(in: nested, file: "x").first?.hasElse == false,
                "内层 #else 被算给了外层 —— 一个 `#if DEBUG` 就能让平台围栏蒙混过关")
        #expect(Self.fences(in: "#if canImport(UIKit)\nlet a = 1\n#endif", file: "x").count == 1)
    }

    // MARK: ③ Package.swift 的 platforms 不许被动

    /// ⚠️ **fail-closed**：读不到文件、或读到的文件里没有 `platforms:` 声明，
    /// 都判红——不能"找不到 ⇒ 没有违规 ⇒ 绿"。
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

    /// AD-E 第 2 轮评审 S-2 逐字：**平台限制不能只活在代码的 `#if` 里，调用方看不见**。
    /// ⇒ 四件各自的文档必须有一节写明它在两端各是什么行为。
    @Test("四件的平台限制都写进了 docs/components/*.md")
    func platformLimitsAreDocumented() throws {
        let docs = ["dot-sphere", "char-sphere", "orbiting-logos", "full-screen-button"]
        for slug in docs {
            let url = Self.repoRoot
                .appendingPathComponent("docs/components/\(slug).md")
            // fail-closed：文档不存在直接判红。
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                Issue.record("docs/components/\(slug).md 不存在 —— AD-E 的硬 AC 没有落地")
                continue
            }
            guard let range = text.range(of: "## 平台支持") else {
                Issue.record("docs/components/\(slug).md 没有「## 平台支持」一节")
                continue
            }
            // 取到下一个二级标题为止。
            let rest = text[range.upperBound...]
            let section = rest.range(of: "\n## ").map { String(rest[..<$0.lowerBound]) } ?? String(rest)
            #expect(section.contains("macOS"), "\(slug).md 的平台支持一节没提 macOS")
            #expect(section.contains("iOS"), "\(slug).md 的平台支持一节没提 iOS")
            #expect(section.trimmingCharacters(in: .whitespacesAndNewlines).count >= 80,
                    "\(slug).md 的平台支持一节只有 \(section.count) 字符，像占位")
        }
        // ⚠️ `FullScreenButton` 是四件里唯一真有平台差异的一件，文档必须点名那个 API。
        let fullScreen = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/components/full-screen-button.md"),
            encoding: .utf8
        )
        #expect(fullScreen.contains("zoom"),
                "full-screen-button.md 没点名 .zoom —— 调用方无从知道 macOS 上少的是哪一层")
    }

    // MARK: ⑤ FullScreenButton 的隔离与降级

    /// ⚠️⚠️ **承重**：`.zoom(` **只许**出现在 `#if os(iOS)` 里面。
    ///
    /// 它在 macOS 上标了 `unavailable`（不是"没效果"，是编译错误）⇒ 漏在围栏外面
    /// **会当场编译红**。那么这条判据的价值在哪？——在于**围栏的形态**：
    /// 有人为了"让 macOS 也编译"而把整个 `FullScreenButton` 塞进 `#if os(iOS)`，
    /// **`swift build` 照样全绿**，而 macOS 上这个公开类型整个消失。
    ///
    /// ⚠️⚠️ **照录变异实证的真实结果，不要把功劳记在本条上**（本轮实测）：
    /// 把整份 `FullScreenButton.swift`（类型 + `#Preview`）一起塞进 `#if os(iOS)` 之后，
    /// · `swift build` —— **绿**（这正是这枚变异可怕的地方）；
    /// · `swift test` —— **红**，但红在
    ///   `CrossPlatformTests.swift: cannot find 'FullScreenButton' in scope`
    ///   ——**测试 target 自己用到了它**，编译就断了，下面那条 `publicTypeDepth`
    ///   断言压根没机会执行；
    /// · `scripts/downstream-probe` —— 同样编译红（`consumeCrossPlatformEffects`）。
    ///
    /// ⇒ 真正挡住这枚变异的是**"macOS 侧有人用它"**这件事（测试 + probe 两处调用点），
    /// 不是本条断言。本条留着的价值是：万一有人连 macOS 侧的调用点一起删掉
    /// （那时前两道都变绿），它还能指名道姓地说出问题是什么。**这是第三道，不是第一道。**
    @Test("`.zoom(` 只出现在 #if os(iOS) 里，且整个类型没有被围栏吞掉")
    func zoomIsFencedToIOS() throws {
        let code = try String(
            contentsOf: MicroInteractionReduceMotionGuard.sourceRoot
                .appendingPathComponent("FullScreenButton.swift"),
            encoding: .utf8
        )
        let stripped = MicroInteractionReduceMotionGuard.stripComments(code)
        let lines = stripped.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // 逐行跟踪：当前是否在一个 `os(iOS)` 围栏的**真分支**里。
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

    /// 与 `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`
    /// **同一形态**：纯函数只钉"给定这个布尔值返回什么"，**调用点是否真的用这个结论**
    /// 是另一条链。`\.accessibilityReduceMotion` 不可注入 ⇒ 位图路结构上不可达。
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
        // ⚠️ **堵掉"去掉 `self.` 就逃逸"**（同那份守卫的 ③，评审有变异实证）：
        // `reads` 数的是字面子串，写成 `let x = reduceMotion` 两个计数都不变。
        let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: code)
        #expect(strays.isEmpty, """
        这些 `reduceMotion` 既不是声明、也不是实参标签、更不是 `self.reduceMotion`：
        \(strays.joined(separator: "\n"))
        """)
        // ⚠️ **已知口子，登记不堵**（与 `TypewriterTextTests` 同一条存量形态）：
        // `fed` 是前缀匹配 ⇒ `reduceMotion: self.reduceMotion && false` 同时命中两边，
        // `reads == fed` 照样成立而喂进闸的恒为 `false`。堵它要上语法树，
        // 属那条存量判据的统一改造，不在本 task 射程内。
    }

    /// 四件都必须有 `#Preview`（AC 逐字）。
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
