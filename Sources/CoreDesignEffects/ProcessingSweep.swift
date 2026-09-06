import CoreDesign
import SwiftUI

// MARK: - 效果种类

enum ProcessingSweepKind: CaseIterable {
    case scanning
    case glow
    case light
}

// MARK: - 驱动层（读环境、定策略、决定建不建 TimelineView）

struct ProcessingSweepDriver: View {
    let kind: ProcessingSweepKind

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

        guard presentation != .hidden else { return AnyView(EmptyView()) }

        let isReduced = presentation == .resting
        guard !isReduced else {
            return AnyView(ProcessingSweepBody(kind: self.kind, phase: ProcessingSweep.restingPhase))
        }

        return AnyView(
            TimelineView(.animation(minimumInterval: state.policy.minimumInterval)) { context in
                ProcessingSweepBody(
                    kind: self.kind,
                    phase: ProcessingSweep.phase(at: context.date)
                )
            }
        )
    }
}

// MARK: - 绘制层（纯相位函数，不含任何调度）

struct ProcessingSweepBody: View {
    let kind: ProcessingSweepKind
    let phase: CGFloat

    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    var body: some View {
        let policy = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        ).policy
        let glow = policy.usesGlow

        Group {
            switch self.kind {
            case .scanning: self.scanBeam(glow: glow)
            case .glow: self.glowRing(glow: glow)
            case .light: self.lightBand(glow: glow)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func scanBeam(glow: Bool) -> some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.tint)
                .frame(height: ProcessingSweep.beamThickness)
                .blur(radius: glow ? ProcessingSweep.beamBlur : 0)
                .opacity(ProcessingSweep.beamOpacity)
                .offset(
                    y: ProcessingSweep.beamCenterY(phase: self.phase, height: proxy.size.height)
                        - ProcessingSweep.beamThickness / 2
                )
        }
        .clipped()
    }

    @ViewBuilder
    private func glowRing(glow: Bool) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(
                cornerRadius: ProcessingSweep.ringRadius(for: proxy.size),
                style: .continuous
            )
            .strokeBorder(.tint, lineWidth: ProcessingSweep.ringLineWidth)
            .mask {
                AngularGradient(
                    gradient: Gradient(colors: ProcessingSweep.ringMaskStops),
                    center: .center
                )
                .rotationEffect(ProcessingSweep.ringAngle(phase: self.phase))
            }
            .blur(radius: glow ? ProcessingSweep.ringBlur : 0)
        }
    }

    @ViewBuilder
    private func lightBand(glow: Bool) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let travel = size.width + size.height
            Rectangle()
                .fill(.tint)
                .frame(width: travel * ProcessingSweep.bandWidthRatio, height: travel)
                .mask {
                    LinearGradient(
                        gradient: Gradient(colors: ProcessingSweep.bandMaskStops),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .rotationEffect(ProcessingSweep.bandTilt)
                .opacity(ProcessingSweep.bandOpacity)
                .blur(radius: glow ? ProcessingSweep.bandBlur : 0)
                .offset(
                    x: ProcessingSweep.bandCenterX(phase: self.phase, width: size.width)
                        - travel * ProcessingSweep.bandWidthRatio / 2,
                    y: (size.height - travel) / 2
                )
        }
        .clipped()
    }
}

// MARK: - 相位与几何（纯函数，生产代码与判据共用同一份）

nonisolated enum ProcessingSweep {
    static let period: Double = 1.8

    static let restingPhase: CGFloat = 0.25

    static func phase(at date: Date, period: Double = ProcessingSweep.period) -> CGFloat {
        guard period > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return CGFloat((t < 0 ? t + period : t) / period)
    }

    static func pingPong(_ phase: CGFloat) -> CGFloat {
        0.5 - 0.5 * cos(2 * .pi * phase)
    }

    // MARK: 扫描光束

    static let beamThickness: CGFloat = 3
    static let beamBlur: CGFloat = 8
    static let beamOpacity: Double = 0.85

    static func beamCenterY(phase: CGFloat, height: CGFloat) -> CGFloat {
        Self.pingPong(phase) * height
    }

    // MARK: 边框辉光

    static let ringLineWidth: CGFloat = CoreBorderWidth.thick
    static let ringBlur: CGFloat = 5

    static let ringMaskStops: [Color] = [.clear, .clear, .maskOpaque, .clear]

    static func ringAngle(phase: CGFloat) -> Angle {
        .degrees(Double(phase) * 360)
    }

    static func ringRadius(for size: CGSize) -> CGFloat {
        min(CoreRadius.large, max(0, min(size.width, size.height) / 2))
    }

    // MARK: 表面光带

    static let bandWidthRatio: CGFloat = 0.32
    static let bandTilt: Angle = .degrees(20)
    static let bandOpacity: Double = 0.55
    static let bandBlur: CGFloat = 6

    static let bandMaskStops: [Color] = [.clear, .maskOpaque, .clear]

    static func bandCenterX(phase: CGFloat, width: CGFloat) -> CGFloat {
        Self.pingPong(phase) * width
    }
}
