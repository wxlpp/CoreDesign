import OhMyDesign
import SwiftUI

// MARK: - 标记形态 / Mark kind

enum SphereMark: Equatable {
    case dots(diameter: Double)

    case glyphs([String], fontSize: Double)

    var cullsFarSide: Bool {
        switch self {
        case .dots: false
        case .glyphs: true
        }
    }

    var countLimit: Int {
        switch self {
        case .dots: 3000
        case .glyphs: 1000
        }
    }
}

// MARK: - 驱动层（读环境、定策略、决定建不建 TimelineView）

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
        let state = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        )
        let presentation = state.presentation(reduceMotion: self.reduceMotion)
            .frozenIfPeriodIsDegenerate(self.rotationPeriod)

        switch presentation {
        case .hidden:
            EmptyView()
        case .resting:
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
        let policy = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        ).policy
        let total = SphereField.clamped(
            count: Int((Double(self.count) * policy.particleScale).rounded()),
            limit: self.mark.countLimit
        )

        self.canvas(total: total)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private func canvas(total: Int) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let worldRadius = min(size.width, size.height) / 2 * SphereField.radiusRatio
            guard total > 0, worldRadius > 0 else { return }

            let tintShading = context.resolve(.style(.tint))
            for index in 0..<total {
                let unit = SphereField.unitPoint(index: index, count: total)
                let spun = SphereField.spun(unit, byTurns: self.turns)
                if self.mark.cullsFarSide, SphereField.isFarSide(spun) { continue }

                let projected = SphereField.project(spun, worldRadius: worldRadius, center: center)
                let progress = SphereField.waveProgress(
                    elevation: SphereField.elevation(of: unit),
                    timeInCycle: self.wave.timeInCycle
                )
                let alpha = SphereField.alpha(depth: projected.depth)
                let tone = SphereField.tone(palette: self.colors, wave: self.wave, progress: progress)

                switch self.mark {
                case let .dots(diameter):
                    let d = max(1, diameter * projected.depth)
                    let box = CGRect(x: projected.x - d / 2, y: projected.y - d / 2, width: d, height: d)
                    if let tone {
                        context.opacity = 1
                        context.fill(Path(ellipseIn: box), with: .color(tone.opacity(alpha)))
                    } else {
                        context.opacity = alpha
                        context.fill(Path(ellipseIn: box), with: tintShading)
                    }
                case let .glyphs(glyphs, fontSize):
                    guard !glyphs.isEmpty else { continue }
                    let glyph = glyphs[SphereField.glyphSlot(index: index, glyphCount: glyphs.count)]
                    let paint = tone.map { AnyShapeStyle($0.opacity(alpha)) }
                        ?? AnyShapeStyle(.tint.opacity(alpha))
                    let resolved = Text(glyph)
                        .font(.system(size: max(4, fontSize * projected.depth),
                                      weight: .semibold, design: .rounded))
                        .foregroundStyle(paint)
                    context.opacity = 1
                    context.draw(resolved, at: CGPoint(x: projected.x, y: projected.y))
                }
            }
        }
    }
}
