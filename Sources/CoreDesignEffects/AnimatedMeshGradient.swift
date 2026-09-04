//
//  AnimatedMeshGradient.swift
//  CoreDesignEffects
//
//  常驻的网格渐变背景 / A continuously drifting mesh gradient surface.
//

import CoreDesign
import SwiftUI

// MARK: - 驱动层（读环境、定策略、决定建不建 TimelineView）

/// 一块**持续漂移**的 3 × 3 网格渐变，用作背景面。典型用途：引导页、空态、
/// 品牌区块的柔和底色。
///
/// ```swift
/// ZStack {
///     AnimatedMeshGradient()          // 空色板 ⇒ 全部取调用方的 .tint
///     content
/// }
/// .tint(.indigo)
/// ```
///
/// ## 取色：**不自带调色板**（FR-8 / AC 逐字）
///
/// 上游 ShipSwift 的默认 indigo / blue / cyan 是**硬编码色相**，在暗色模式与高对比度下
/// 不会跟着变，本仓 `EffectsColorLiteralGuard` 对这一族直接判红。⇒ 9 个色位 × 两组
/// **全部**由调用方传入，或者一个都不传：
///
/// - `colors` **非空** ⇒ 按 9 个色位循环补齐 / 截断后直接进 `MeshGradient`；
/// - `colors` **为空** ⇒ 回落到调用方的 **`.tint`**（与 `.spray` / `.confetti` 同一纪律）。
///   ⚠️ 这一档下网格里跑的是**透明度**而不是色相：`Rectangle().fill(.tint)` 被一张
///   由 `Color.primary.opacity(…)` 组成的网格**遮罩**——`mask` 吃的是 alpha 通道，
///   `.primary` 恒不透明，与写死白色等效但它是语义色（`ProcessingSweep.glowRing` 用的
///   是同一个手法）。⇒ 没有色板时本组件**不凭空造色相**，只把调用方那一个色相
///   铺成有层次的面。
/// - `alternateColors` **非空** ⇒ 两组色板之间来回混合（`Color.mix(with:by:)`），
///   这就是 AC 里「9 色 × 2 组」的第二组。为空 ⇒ 只有网格点在漂，颜色不变。
///
/// ⚠️ **为什么不给一个"好看的默认色板"**：那是品牌决定，不是设计系统该替调用方做的。
/// `.spray` / `.confetti` 已经就同一件事立过规矩。
///
/// ## Reduce Motion
///
/// **冻结在某一帧**（AC 逐字）：网格点钉死在 `MeshDrift.restingPhase`，
/// 整层仍然照常绘制。**不是 no-op**——这是一块背景面，抹掉它等于把界面的底色拿走。
/// 走**降级形态 2**（保留"长什么样"、只去掉运动、不叠透明度脉冲）。
///
/// ## 后台 / 低电量（NFR-7）
///
/// 本组件**是常驻渲染件**（`TimelineView` 持续驱相位），与 `ScanningOverlay` /
/// `Confetti` 同类 ⇒ 接能耗闸：
///
/// | 键 | 类型 | 默认 | 行为 |
/// |---|---|---|---|
/// | `\.scenePhaseOverride` | `ScenePhase?` | `nil` ⇒ 读系统 `\.scenePhase` | `.inactive` / `.background` ⇒ **整层不建** |
/// | `\.lowPowerModeOverride` | `Bool?` | `nil` ⇒ 读 `ProcessInfo.isLowPowerModeEnabled` | `true` ⇒ 降到 15 fps，并去掉柔化用的离屏模糊 |
///
/// ⚠️⚠️ **顺序是承重的：先 NFR-7 的能耗闸，再 Reduce Motion 闸**。
/// 这个顺序不由本文件实现——它在 `EffectsEnergyState.presentation(reduceMotion:)` 里，
/// 与 `ConfettiCore` / `ProcessingSweepDriver` **共用同一份**。
/// 此前两处各写一遍时 `Confetti` 就把顺序写反了，而当时全套测试是绿的
///（#252 PR #269 第 1 轮终审 I-1 / I-2）。
///
/// ## ⚠️ 已知限度：`.inactive` 下这块面会从 App 切换器的快照里消失
///
/// 「`.inactive` / `.background` ⇒ 一个像素都不画」是本仓既有的、有机器判据守着的
/// 停摆语义（`EffectsRenderPolicy.drawsAnything` 的文档逐字：「调用方应当**整层不建**」）。
/// 对 `ScanningOverlay` 那类**盖在内容上的小装饰**它无副作用；而本组件是一整块**背景面**
/// ⇒ App 切换器里那张快照（`.inactive`）会缺掉底色。
///
/// **本轮按既有语义落地、不为一个组件另开一档**：理由是「两处各写一遍必然漂移」正是
/// 本仓反复在堵的形态，而 `EffectsPresentation` 的存在本身就是那次漂移的产物。
/// ⇒ 这条**登记为已知限度**，处置属 epic 级裁决（要么给 `EffectsRenderPolicy` 增设
/// 「停摆但保留静止帧」一档并同时改三个调用点，要么接受快照缺底色）。
/// 需要立刻规避的宿主 App 可以自己注入 `\.scenePhaseOverride = .active`。
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
        let state = EffectsEnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: EffectsPowerMode.lifted(from: self.lowPowerModeOverride)
        )
        // ⚠️ 两道闸的顺序在这个纯函数里，不在这里——见类型文档。
        let presentation = state.presentation(reduceMotion: self.reduceMotion)

        // ⚠️ **单出口、分支只发生在这个 `switch` 内部**：本类型没有被修饰的调用方内容，
        // 但形状上仍与 `ConfettiCore` 保持一致（`#252` PR #269 第 2 轮终审 C-1 的教训：
        // 随 `scenePhase` 翻转的多出口会让子树反复换身份）。
        switch presentation {
        case .none:
            // NFR-7 停摆：一个像素都不画。已知限度见类型文档。
            EmptyView()
        case .resting:
            // Reduce Motion：**冻结在某一帧**——照常绘制，只把相位钉死。
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

/// 唯一建 `TimelineView` 的地方。**只有 `.animated` 档才会被构造。**
///
/// ⚠️ 抽成独立类型不是风格问题：`ProcessingSweepDriver` 用 `guard` 早退把
/// `TimelineView` 关在一个分支里，本类型用的是 `switch`——两种写法都要求
/// 「停摆 / 静止两档下这个调度器**根本不存在**」，而不是"建了但 paused"
///（后者仍是一个活着的视图节点）。判据在
/// `AnimatedMeshGradientTests.timelineOnlyExistsInTheAnimatedBranch`。
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

/// 给定相位画出一帧网格。**不读时间、不调度**——因此可以被单测钉在任意相位上渲染。
///
/// ⚠️ 它**自己**读能耗环境取"要不要柔化"，而不是由驱动层传进来：这样单测可以对
/// **同一个相位**注入不同的 `\.lowPowerModeOverride` 比较两张位图——低电量的行为差异
/// 才是确定性可观测的（同 `ProcessingSweepBody` 的理由，那里逐字记着：若靠驱动层传参，
/// 测试就只能走 `TimelineView`，两次渲染落在不同相位上，比不出来）。
///
/// ⚠️ **每帧重解析的已知限度同样适用**：本类型在 `TimelineView` 闭包内部被构造
/// ⇒ 那次 `EffectsEnergyState.resolve(...)` 每帧都跑一次。完整登记在
/// `ProcessingSweepBody` 的类型文档里，本轮不改结构。
struct AnimatedMeshBody: View {

    let phase: CGFloat
    let colors: [Color]
    let alternateColors: [Color]

    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    var body: some View {
        let policy = EffectsEnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: EffectsPowerMode.lifted(from: self.lowPowerModeOverride)
        ).policy
        // ⚠️ 复用 `usesGlow` 这个既有旋钮而不是另开一个：它的语义就是
        //「要不要走离屏模糊这类昂贵通道」，柔化正是同一件事。
        // ⚠️ 它同时是低电量在**静态位图**上唯一可观测的差异（降帧拍不进一帧），
        // 因此也是 NFR-7 低电量方向判据的落点。
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
                // 空色板 ⇒ 调用方的 `.tint` + 一张 alpha 网格遮罩。见类型文档「取色」。
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
        // ⚠️ 背景面是**纯装饰**（FR-13）：它不承载任何语义，语义由它背后 / 上面的内容提供。
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - 网格几何与取色（纯函数，生产代码与判据共用同一份）

/// 网格渐变的**相位、点位与取色契约**。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `ConfettiBurst` / `ProcessingSweep` / `ShineBand`
/// 同一条纪律）：判据要能对**这条真轨道**求值，而不是在测试里重抄一遍常量。
/// ⚠️ **不要把字面量写回绘制层**——那会让钉帧判据重新变成"测试自说自话"。
nonisolated enum MeshDrift {

    /// 网格尺寸。`MeshGradient` 要求 `colors.count == width * height`，
    /// 三者必须一起改。
    static let gridWidth: Int = 3
    static let gridHeight: Int = 3
    static var colorSlots: Int { Self.gridWidth * Self.gridHeight }

    /// 一个完整漂移周期（秒）。取得比"处理中"那三个长得多——背景面要慢到不抢注意力。
    static let period: Double = 12

    /// Reduce Motion / 静止形态所用的相位。
    ///
    /// 取 `0.125` 而不是 `0`：`0` 上所有内点恰好回到规则网格，那一帧看起来像一张
    /// **没有做任何事**的普通渐变；`0.125` 是漂移幅度接近峰值的那一帧
    /// ——静止形态落在"最像这个效果"的一帧上（同 `ProcessingSweep.restingPhase` 的理由）。
    static let restingPhase: CGFloat = 0.125

    /// 两组色板混合最深（系数 = 1）的相位。判据要在这一相位上比"第二组有没有生效"。
    static let blendPeakPhase: CGFloat = 0.5

    /// 柔化用的离屏模糊半径（低电量下降为 0）。
    static let softenRadius: CGFloat = 18

    /// 内点的漂移幅度（归一化坐标）。**必须 < 0.25**，否则内点会越过外圈、网格自交。
    static let drift: CGFloat = 0.16

    /// `.tint` 形态下 alpha 的取值范围。下限不取 0——取 0 会让网格边缘出现完全透明的
    /// 硬边，看起来像一块被抠掉的洞。
    static let minimumAlpha: Double = 0.18
    static let maximumAlpha: Double = 0.95

    /// 由时间取相位，落在 `[0, 1)`。
    ///
    /// ⚠️ 用 `timeIntervalSinceReferenceDate` 取模而不是"起始时刻到现在"：
    /// 背景面没有起点（它是常驻呈现，不是一次性动作），无状态的取模让任意时刻
    /// 进入 / 退出都不会跳帧（同 `ProcessingSweep.phase(at:)`）。
    static func phase(at date: Date, period: Double = MeshDrift.period) -> CGFloat {
        guard period > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return CGFloat((t < 0 ? t + period : t) / period)
    }

    /// 3 × 3 网格的点位。**四角钉死**（否则整块面会缩边、露出底色），
    /// 边中点与中心按两条不同频率的正弦漂移。
    static func points(phase: CGFloat) -> [SIMD2<Float>] {
        let a = Double(phase) * 2 * .pi
        func wobble(_ multiplier: Double, _ offset: Double) -> CGFloat {
            Self.drift * CGFloat(sin(a * multiplier + offset))
        }
        // 行 0 / 1 / 2 的固定 y，列 0 / 1 / 2 的固定 x。
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

    /// `.tint` 形态下每个色位的 alpha 遮罩色。
    ///
    /// ⚠️ 用 `Color.primary` 而不是白色：`mask` 吃的是 alpha 通道，`.primary` 恒为不透明
    /// ⇒ 与写死 `.white` 等效，但它是语义色、不触碰 `EffectsColorLiteralGuard` 的色相清单
    ///（`ProcessingSweep.glowRing` 记着同一条）。
    static func tintAlphaMask(phase: CGFloat) -> [Color] {
        let a = Double(phase) * 2 * .pi
        return (0..<Self.colorSlots).map { index in
            // 每个色位一个固定的相位偏移 ⇒ 亮暗区在网格上缓慢流动，而不是整块一起呼吸。
            let offset = Double(index) * (2 * .pi / Double(Self.colorSlots))
            let unit = 0.5 + 0.5 * sin(a + offset)
            let alpha = Self.minimumAlpha + (Self.maximumAlpha - Self.minimumAlpha) * unit
            return Color.primary.opacity(alpha)
        }
    }

    /// 把任意长度的色板规整到恰好 `colorSlots` 个：不足按下标循环补齐、超出截断。
    /// **空色板原样返回空**——那是"没有显式色，用 `.tint`"的信号（同
    /// `[Color].particleColor(at:)` 的约定）。
    static func normalised(_ colors: [Color]) -> [Color] {
        guard !colors.isEmpty else { return [] }
        return (0..<Self.colorSlots).map { colors[$0 % colors.count] }
    }

    /// 两组色板按相位混合后的 9 个色位；**两组都空 ⇒ `nil`**，表示回落到 `.tint` 形态。
    ///
    /// ⚠️ 混合系数走**往复**（`pingPong`）而不是线性回绕：后者在回绕那一帧会瞬跳，
    /// 而这是一块常驻背景，跳一下非常显眼。
    static func blended(base: [Color], alternate: [Color], phase: CGFloat) -> [Color]? {
        let first = Self.normalised(base)
        let second = Self.normalised(alternate)
        guard !first.isEmpty || !second.isEmpty else { return nil }
        guard !first.isEmpty else { return second }
        guard !second.isEmpty else { return first }
        let t = Self.pingPong(phase)
        return zip(first, second).map { $0.mix(with: $1, by: t) }
    }

    /// 相位 → 往复进度，落在 `[0, 1]`，两端平滑回折（同 `ProcessingSweep.pingPong`）。
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
