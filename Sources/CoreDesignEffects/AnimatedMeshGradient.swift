import CoreDesign
import SwiftUI

// MARK: - 驱动层（读环境、定策略、决定建不建 TimelineView）

/// 一块**持续漂移**的 3 × 3 网格渐变，用作背景面。典型用途：引导页、空态、
/// 品牌区块的柔和底色。
public struct AnimatedMeshGradient: View {
    private let colors: [Color]
    private let alternateColors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    /// - Parameters:
    ///   - colors: 9 个色位的色板，不足循环补齐、超出截断。**默认为空 ⇒ 取调用方的 `.tint`**。
    ///   - alternateColors: 第二组色板，网格在两组之间来回混合。**默认为空 ⇒ 颜色不变，只有点在漂**。
    public init(colors: [Color] = [], alternateColors: [Color] = []) {
        self.colors = colors
        self.alternateColors = alternateColors
    }

    public var body: some View {
        let state = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        )
        let presentation = state.presentation(reduceMotion: self.reduceMotion)

        switch presentation {
        case .hidden:
            EmptyView()
        case .resting:
            AnimatedMeshBody(
                phase: MeshDrift.restingPhase,
                colors: self.colors,
                alternateColors: self.alternateColors
            )
        case .animated:
            AnimatedMeshTimeline(
                minimumInterval: state.policy.minimumInterval,
                colors: self.colors,
                alternateColors: self.alternateColors
            )
        }
    }
}

// MARK: - 调度层

struct AnimatedMeshTimeline: View {
    let minimumInterval: Double?
    let colors: [Color]
    let alternateColors: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: self.minimumInterval)) { context in
            AnimatedMeshBody(
                phase: MeshDrift.phase(at: context.date),
                colors: self.colors,
                alternateColors: self.alternateColors
            )
        }
    }
}

// MARK: - 绘制层（纯相位函数，不含任何调度）

struct AnimatedMeshBody: View {
    let phase: CGFloat
    let colors: [Color]
    let alternateColors: [Color]

    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    var body: some View {
        let policy = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        ).policy
        let softens = policy.usesGlow
        let points = MeshDrift.points(phase: self.phase)

        Group {
            if let palette = MeshDrift.blended(
                base: self.colors, alternate: self.alternateColors, phase: self.phase
            ) {
                MeshGradient(
                    width: MeshDrift.gridWidth,
                    height: MeshDrift.gridHeight,
                    points: points,
                    colors: palette
                )
            } else {
                Rectangle()
                    .fill(.tint)
                    .mask {
                        MeshGradient(
                            width: MeshDrift.gridWidth,
                            height: MeshDrift.gridHeight,
                            points: points,
                            colors: MeshDrift.tintAlphaMask(phase: self.phase)
                        )
                    }
            }
        }
        .blur(radius: softens ? MeshDrift.softenRadius : 0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - 网格几何与取色（纯函数，生产代码与判据共用同一份）

nonisolated enum MeshDrift {
    static let gridWidth: Int = 3
    static let gridHeight: Int = 3
    static var colorSlots: Int { Self.gridWidth * Self.gridHeight }

    static let period: Double = 12

    static let restingPhase: CGFloat = 0.125

    static let blendPeakPhase: CGFloat = 0.5

    static let softenRadius: CGFloat = 18

    static let drift: CGFloat = 0.16

    static let minimumAlpha: Double = 0.18
    static let maximumAlpha: Double = 0.95

    static func phase(at date: Date, period: Double = MeshDrift.period) -> CGFloat {
        guard period > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return CGFloat((t < 0 ? t + period : t) / period)
    }

    static func points(phase: CGFloat) -> [SIMD2<Float>] {
        let a = Double(phase) * 2 * .pi
        func wobble(_ multiplier: Double, _ offset: Double) -> CGFloat {
            Self.drift * CGFloat(sin(a * multiplier + offset))
        }
        let midX = 0.5 + wobble(1, 0)
        let midY = 0.5 + wobble(1, .pi / 2)
        let topMid = 0.5 + wobble(2, 0.6)
        let bottomMid = 0.5 + wobble(2, 2.1)
        let leftMid = 0.5 + wobble(2, 1.3)
        let rightMid = 0.5 + wobble(2, 3.4)

        let raw: [(CGFloat, CGFloat)] = [
            (0, 0), (topMid, 0), (1, 0),
            (0, leftMid), (midX, midY), (1, rightMid),
            (0, 1), (bottomMid, 1), (1, 1),
        ]
        return raw.map { SIMD2<Float>(Float(Self.clamp01($0.0)), Float(Self.clamp01($0.1))) }
    }

    static func tintAlphaMask(phase: CGFloat) -> [Color] {
        let a = Double(phase) * 2 * .pi
        return (0..<Self.colorSlots).map { index in
            let offset = Double(index) * (2 * .pi / Double(Self.colorSlots))
            let unit = 0.5 + 0.5 * sin(a + offset)
            let alpha = Self.minimumAlpha + (Self.maximumAlpha - Self.minimumAlpha) * unit
            return Color.maskOpaque.opacity(alpha)
        }
    }

    static func normalised(_ colors: [Color]) -> [Color] {
        guard !colors.isEmpty else { return [] }
        return (0..<Self.colorSlots).map { colors[$0 % colors.count] }
    }

    static func blended(base: [Color], alternate: [Color], phase: CGFloat) -> [Color]? {
        let first = Self.normalised(base)
        let second = Self.normalised(alternate)
        guard !first.isEmpty || !second.isEmpty else { return nil }
        guard !first.isEmpty else { return second }
        guard !second.isEmpty else { return first }
        let t = Self.pingPong(phase)
        return zip(first, second).map { $0.mix(with: $1, by: t) }
    }

    static func pingPong(_ phase: CGFloat) -> Double {
        0.5 - 0.5 * cos(2 * .pi * Double(phase))
    }

    static func clamp01(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
}

#Preview("AnimatedMeshGradient — 取 .tint") {
    ZStack {
        AnimatedMeshGradient()
        Text("Welcome")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.contentOnAccent)
    }
    .frame(width: 320, height: 220)
    .clipShape(CoreShape.rounded(CoreRadius.xLarge))
    .tint(.accent)
    .padding(CoreSpacing.xxl)
}

#Preview("AnimatedMeshGradient — 两组色板") {
    AnimatedMeshGradient(
        colors: [.surfaceRaised, .surfaceInteractive, .tertiaryFill],
        alternateColors: [.secondaryFill, .surfaceRaised, .quaternaryFill]
    )
    .frame(width: 320, height: 220)
    .clipShape(CoreShape.rounded(CoreRadius.xLarge))
    .padding(CoreSpacing.xxl)
}
