//
//  SphereSurface.swift
//  CoreDesignEffects
//
//  两个球面件共用的驱动与绘制 / The shared driver and canvas behind the two spheres.
//

import CoreDesign
import SwiftUI

// MARK: - 标记形态 / Mark kind

/// 球面上每个点画成什么。
///
/// ⚠️ **不是 Bool**（J-1 / AD-C）：`DotSphere` 与 `CharSphere` 的差别不是"要不要字形"，
/// 而是**画哪一种标记**——两档各自带载荷（点带直径、字形带字号与字表）。
enum SphereMark: Equatable {

    /// 实心圆点，`diameter` 是正对观察者那一层的直径（会被景深缩放）。
    case dots(diameter: Double)

    /// 字形，`glyphs` 按确定性散列分配到各点上，`fontSize` 同样被景深缩放。
    case glyphs([String], fontSize: Double)

    /// 是否剔除背面。
    ///
    /// 字形**必须**剔除：背面的字与正面的字叠在一起会糊成一团（上游的
    /// `hidesBackFaces` 默认 `true` 就是这条）；圆点**不剔除**：它们本来就靠
    /// 景深不透明度分层，剔掉背面会让球看起来像半个壳。
    /// ⚠️ 这条被固化成形态自带的属性，而不是一个 `Bool` 参数——见类型文档。
    var cullsFarSide: Bool {
        switch self {
        case .dots: false
        case .glyphs: true
        }
    }

    /// 本形态的点数上限。字形比圆点贵得多，上限也低得多（上游：3000 / 1000）。
    var countLimit: Int {
        switch self {
        case .dots: 3000
        case .glyphs: 1000
        }
    }
}

// MARK: - 驱动层（读环境、定策略、决定建不建 TimelineView）

/// 两个球面件共用的驱动。**唯一裁决"画不画、动不动"的地方。**
///
/// ⚠️ **类型名刻意不叫 `SphereCanvas`**：`MicroInteractionReduceMotionGuard.motionCalls`
/// 是**子串匹配**（`"Canvas("`），任何以 `Canvas` 结尾的类型名会让**每一个构造它的
/// 文件**都被判成"含运动"——两个薄封装因此会被要求各自读一遍
/// `accessibilityReduceMotion`，而那正是本类型存在的意义要禁止的事。
/// 实测过这枚误判（`DotSphere.swift:86 Canvas(… [无门控]`）。
///
/// ⚠️ **两个公开件都只是本类型的薄封装**（同 `ScanningOverlay` / `GlowSweep` /
/// `LightSweep` 对 `ProcessingSweepDriver` 的关系）：降级路径与能耗闸只有一份，
/// 不给两个球各写一遍——那样必然漂移，本仓已经在 `Confetti` 上吃过一次
///（#252 PR #269 终审 I-1：两处各写一遍，其中一处把两道闸的顺序写反了，全套测试还是绿的）。
struct SphereSurface: View {

    let mark: SphereMark
    let count: Int
    let colors: [Color]
    let rotationPeriod: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    var body: some View {
        let state = EffectsEnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: EffectsPowerMode.lifted(from: self.lowPowerModeOverride)
        )
        // ⚠️ 两道闸的顺序在这个纯函数里，不在这里（先 NFR-7 能耗闸、再 Reduce Motion 闸）。
        // ⚠️ 第三道闸是"自转周期非法"：`rotationPeriod <= 0` 的调用方要的就是**静止**，
        // 建一个每帧产出同一张图的 `TimelineView` 纯属白烧电（PR #274 终审 I-4）。
        let presentation = state.presentation(reduceMotion: self.reduceMotion)
            .frozenIfPeriodIsDegenerate(self.rotationPeriod)

        // ⚠️ **单出口**：分支只发生在这个 `switch` 内部（同 `AnimatedMeshGradient`）。
        switch presentation {
        case .none:
            // NFR-7 停摆：一个像素都不画。
            EmptyView()
        case .resting:
            // Reduce Motion：**冻结在某一帧**——球照常画，只把自转相位与色波钉死。
            // 降级形态 2（保留"长什么样"、只去掉运动、不叠透明度脉冲）。
            SphereSurfaceBody(
                mark: self.mark,
                count: self.count,
                colors: self.colors,
                turns: SphereField.restingPhase,
                wave: SphereField.restingWave(paletteCount: self.colors.count)
            )
        case .animated:
            SphereSurfaceTimeline(
                minimumInterval: state.policy.minimumInterval,
                mark: self.mark,
                count: self.count,
                colors: self.colors,
                rotationPeriod: self.rotationPeriod
            )
        }
    }
}

// MARK: - 调度层

/// 唯一建 `TimelineView` 的地方。**只有 `.animated` 档才会被构造**
/// ——停摆 / 静止两档下这个调度器根本不存在，而不是"建了但 paused"。
struct SphereSurfaceTimeline: View {

    let minimumInterval: Double?
    let mark: SphereMark
    let count: Int
    let colors: [Color]
    let rotationPeriod: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: self.minimumInterval)) { context in
            SphereSurfaceBody(
                mark: self.mark,
                count: self.count,
                colors: self.colors,
                turns: SphereField.phase(at: context.date, period: self.rotationPeriod),
                wave: SphereField.wave(at: context.date, paletteCount: self.colors.count)
            )
        }
    }
}

// MARK: - 绘制层（纯相位函数，不含任何调度）

/// 给定自转相位与色波画出一帧。**不读时间、不调度**——因此可以被单测钉在任意相位上渲染。
///
/// ⚠️ 用一个 `Canvas` 画 N 个点，而不是 N 个 `Circle` 视图：默认 800 个点、
/// 逐个建视图会让每一帧都重走布局（NFR-1）。`Confetti` 已就同一件事立过规矩。
///
/// ⚠️ 它**自己**读能耗环境取密度，而不是由驱动层传进来（同 `AnimatedMeshBody` 的理由）：
/// 这样单测可以对**同一个相位**注入不同的 `\.lowPowerModeOverride` 比较两张位图
/// ——降帧拍不进静态帧，密度才是低电量在位图上唯一可观测的差异。
struct SphereSurfaceBody: View {

    let mark: SphereMark
    let count: Int
    let colors: [Color]
    let turns: Double
    let wave: SphereField.Wave

    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    var body: some View {
        let policy = EffectsEnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: EffectsPowerMode.lifted(from: self.lowPowerModeOverride)
        ).policy
        // ⚠️ 复用 `particleScale` 这个既有旋钮而不是另开一个：它的语义就是
        //「这一档下画多少个粒子」，球面上的点是同一件事。
        let total = SphereField.clamped(
            count: Int((Double(self.count) * policy.particleScale).rounded()),
            limit: self.mark.countLimit
        )

        // ⚠️⚠️ **不再走 `Rectangle().fill(.tint).mask { … }`**（PR #274 终审 C-2）：
        // 那一版用 `Color.primary` 当遮罩色，注释宣称"`.primary` 恒不透明、与写死白色等效"
        // ——**实测为假**：`Color.primary.resolve(in:)` 在明暗两端都给 `a = 0.8471`
        //（它映射到 `label` / `labelColor`）。`mask` 吃 alpha ⇒ `.tint` 那条路上
        // 每个点的实际不透明度是 `0.8471 × alpha(depth:)`，近侧的点**从来不是**
        // `maximumAlpha` 那个常量选来的"实"，而且与显式色板那条路差了 15%
        //（后者走 `tone.opacity(alpha)`，满量程）。位图判据全是 `a != b` ⇒ 抓不到。
        // ⇒ 直接用 `.tint` 给 `Canvas` 上色（`Color.white` 被 `EffectsColorLiteralGuard` 禁），
        // 顺带去掉一层离屏合成。判据：`CrossPlatformRenderTests.tintPathMatchesSinglePalette`。
        self.canvas(total: total)
            // 球面点云是**纯装饰**（FR-13）：它不承载任何语义，语义由它背后 / 上面的内容提供。
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private func canvas(total: Int) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let worldRadius = min(size.width, size.height) / 2 * SphereField.radiusRatio
            guard total > 0, worldRadius > 0 else { return }

            for index in 0..<total {
                let unit = SphereField.unitPoint(index: index, count: total)
                let spun = SphereField.spun(unit, byTurns: self.turns)
                if self.mark.cullsFarSide, SphereField.isFarSide(spun) { continue }

                let projected = SphereField.project(spun, worldRadius: worldRadius, center: center)
                let progress = SphereField.waveProgress(
                    elevation: SphereField.elevation(of: unit),
                    timeInCycle: self.wave.timeInCycle
                )
                // ⚠️ 空色板 ⇒ 直接拿调用方的 `.tint` 上色（**不凭空造色相**，
                // 只把调用方那一个色相铺成有景深的点云）；非空色板 ⇒ 用色板里那一档。
                // 两条路都只叠**一次** `alpha(depth:)`，量程逐字相同。
                let alpha = SphereField.alpha(depth: projected.depth)
                let tone = SphereField.tone(palette: self.colors, wave: self.wave, progress: progress)
                let paint = tone.map { AnyShapeStyle($0.opacity(alpha)) } ?? AnyShapeStyle(.tint.opacity(alpha))

                switch self.mark {
                case let .dots(diameter):
                    let d = max(1, diameter * projected.depth)
                    let box = CGRect(x: projected.x - d / 2, y: projected.y - d / 2, width: d, height: d)
                    context.fill(Path(ellipseIn: box), with: .style(paint))
                case let .glyphs(glyphs, fontSize):
                    guard !glyphs.isEmpty else { continue }
                    let glyph = glyphs[SphereField.glyphSlot(index: index, glyphCount: glyphs.count)]
                    let resolved = Text(glyph)
                        .font(.system(size: max(4, fontSize * projected.depth),
                                      weight: .semibold, design: .rounded))
                        .foregroundStyle(paint)
                    context.draw(resolved, at: CGPoint(x: projected.x, y: projected.y))
                }
            }
        }
    }
}
