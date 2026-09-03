//
//  ProcessingSweep.swift
//  CoreDesignEffects
//
//  三个"处理中"常驻动效的共用驱动与绘制 / Shared driver & drawing for the three
//  continuous "processing" effects（`ScanningOverlay` / `GlowSweep` / `LightSweep`）。
//

import CoreDesign
import SwiftUI

// MARK: - 为什么三个效果共用一个驱动

// `ScanningOverlay` / `GlowSweep` / `LightSweep` 三者的**外观**不同，但
// 「读能耗环境 → 决定停摆 / 降帧 / 满帧 → Reduce Motion 降级 → 用 `TimelineView` 驱相位」
// 这条链**逐字相同**。三份实现必然漂移（本仓 `reduceMotionFallback` 的文档已经为同一件事
// 立过规矩：「各效果**不要**各自实现降级路径——那样必然漂移」）。
// ⇒ 驱动与绘制都在本文件，三个公开容器（各自一个文件）是薄封装。
//
// ⚠️ **薄封装不是自觉，是有判据的**：`ProcessingSweepTests.containersDelegateToDriver`
// 逐个断言三个容器文件里既出现 `ProcessingSweepDriver(`、又**不出现**任何自建动画/绘制调用。
// 否则容器可以绕过本文件自建一套，而 `MicroInteractionReduceMotionGuard` 对它全绿
// （容器文件不含运动关键字 ⇒ 根本不进它的射程）——这正是 `Shine` 容器形态当初被钉死的同一个洞。

// MARK: - 效果种类

/// 三个"处理中"效果的外观分支。
enum ProcessingSweepKind: CaseIterable {
    /// 一道横向光束在内容上下往复扫描。
    case scanning
    /// 一段辉光沿内容边框转圈。
    case glow
    /// 一道斜向光带在内容表面左右扫过。
    case light
}

// MARK: - 驱动层（读环境、定策略、决定建不建 TimelineView）

/// 三个容器共用的驱动层：**它是本 target 里唯一决定"要不要调度"的地方**。
///
/// ⚠️ 顺序是承重的：**先 NFR-7 的能耗闸，再 Reduce Motion 闸**。
/// 后台 / 非活跃时连静态层都不画（一个像素都不画才叫"停摆"）；
/// 而 Reduce Motion 是 a11y 偏好，前台时仍要留下"这里正在处理"的静态呈现。
struct ProcessingSweepDriver: View {

    let kind: ProcessingSweepKind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.effectsPowerMode) private var injectedPowerMode
    @Environment(\.effectsScenePhase) private var injectedScenePhase
    @Environment(\.scenePhase) private var systemScenePhase

    var body: some View {
        let policy = EffectsEnergyState.resolve(
            injectedScenePhase: self.injectedScenePhase,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: self.injectedPowerMode
        ).policy

        // ⚠️ **NFR-7 停摆：整层不建**。不是 `paused: true` 的 `TimelineView`，
        // 是根本没有 `TimelineView`——后者仍是一个活着的视图节点。
        guard policy.drawsAnything else { return AnyView(EmptyView()) }

        let isReduced = self.reduceMotion
        // ⚠️ **Reduce Motion 降级形态 2**（见 `View.reduceMotionFallback` 的文档）：
        // 保留这个效果**长什么样**，只把相位钉死在静止值上，**不叠透明度脉冲**
        // ——脉冲是给 trigger 驱动的一次性微交互用的反馈，而这三个是常驻状态呈现，
        // 反复脉冲本身就是运动。
        guard !isReduced else {
            return AnyView(ProcessingSweepBody(kind: self.kind, phase: ProcessingSweep.restingPhase))
        }

        return AnyView(
            TimelineView(.animation(minimumInterval: policy.minimumInterval)) { context in
                ProcessingSweepBody(
                    kind: self.kind,
                    phase: ProcessingSweep.phase(at: context.date)
                )
            }
        )
    }
}

// MARK: - 绘制层（纯相位函数，不含任何调度）

/// 给定相位画出一帧。**不读时间、不调度**——因此可以被单测钉在任意相位上渲染。
///
/// ⚠️ 它**自己**读能耗环境取 `usesGlow`，而不是由驱动层传进来：
/// 这样单测可以 `ProcessingSweepBody(kind:phase:).environment(\.effectsPowerMode, .lowPower)`
/// ——**同一个相位**下比较两张位图，低电量的行为差异才是确定性可观测的
/// （若靠驱动层传参，测试就只能走 `TimelineView`，两次渲染落在不同相位上，比不出来）。
struct ProcessingSweepBody: View {

    let kind: ProcessingSweepKind
    let phase: CGFloat

    @Environment(\.effectsPowerMode) private var injectedPowerMode
    @Environment(\.effectsScenePhase) private var injectedScenePhase
    @Environment(\.scenePhase) private var systemScenePhase

    var body: some View {
        let policy = EffectsEnergyState.resolve(
            injectedScenePhase: self.injectedScenePhase,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: self.injectedPowerMode
        ).policy
        let glow = policy.usesGlow

        Group {
            switch self.kind {
            case .scanning: self.scanBeam(glow: glow)
            case .glow: self.glowRing(glow: glow)
            case .light: self.lightBand(glow: glow)
            }
        }
        // ⚠️ 三层都是**纯装饰**（FR-13）：「正在处理」这个状态语义由调用方通告
        //（`docs/components/*.md` 各自写明了这条分工）。
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// 横向光束，上下往复。
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

    /// 边框辉光，沿框转圈。
    @ViewBuilder
    private func glowRing(glow: Bool) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(
                cornerRadius: ProcessingSweep.ringRadius(for: proxy.size),
                style: .continuous
            )
            .strokeBorder(.tint, lineWidth: ProcessingSweep.ringLineWidth)
            // ⚠️ 遮罩里用 `.primary` 而不是白色：`mask` 吃的是 alpha 通道，
            // `.primary` 恒为不透明 ⇒ 与写死 `.white` 等效，但它是语义色、
            // 不触碰 `EffectsColorLiteralGuard` 的色相清单。
            .mask {
                AngularGradient(
                    gradient: Gradient(colors: [.clear, .clear, .primary, .clear]),
                    center: .center
                )
                .rotationEffect(ProcessingSweep.ringAngle(phase: self.phase))
            }
            .blur(radius: glow ? ProcessingSweep.ringBlur : 0)
        }
    }

    /// 斜向光带，左右往复。
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
                        gradient: Gradient(colors: [.clear, .primary, .clear]),
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
        // ⚠️ **裁到内容的外接矩形，而不是 `.mask(content)`**：后者会把被包裹的内容
        // **实例化两次**（`.shine(trigger:)` 的已知限度，那里逐字写着"不要把带副作用的
        // modifier 放进去"）。容器形态天生就是"包住别人的东西"，把那个陷阱继承进来
        // 是不可接受的 ⇒ 本效果只裁矩形，代价是不贴合内容的圆角/异形轮廓。
        .clipped()
    }
}

// MARK: - 相位与几何（纯函数，生产代码与判据共用同一份）

/// 三个效果的**相位与几何契约**。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `ShineBand` 同一条纪律）：判据要能对
/// **这条真轨道**求值，而不是在测试里重抄一遍常量。
/// ⚠️ **不要把字面量写回绘制层**——那会让钉帧判据重新变成"测试自说自话"。
nonisolated enum ProcessingSweep {

    /// 一个来回的周期（秒）。
    static let period: Double = 1.8

    /// Reduce Motion / 静止形态所用的相位。
    ///
    /// 取 `0.25` 是因为 `pingPong(0.25) == 0.5` ⇒ 光束正好停在内容中央、
    /// 光带正好停在内容中线——静止形态落在"最像这个效果"的那一帧上，而不是端点。
    static let restingPhase: CGFloat = 0.25

    /// 由时间取相位，落在 `[0, 1)`。
    ///
    /// ⚠️ 用 `timeIntervalSinceReferenceDate` 取模而不是"起始时刻到现在"：
    /// 这三个效果没有起点（它们是常驻状态呈现，不是一次性动作），
    /// 无状态的取模让任意时刻进入 / 退出都不会跳帧。
    static func phase(at date: Date, period: Double = ProcessingSweep.period) -> CGFloat {
        guard period > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return CGFloat((t < 0 ? t + period : t) / period)
    }

    /// 相位 → 往复进度，落在 `[0, 1]`，两端平滑回折。
    ///
    /// ⚠️ **往复而不是"扫出去再从另一头进来"**：后者在回绕的那一帧上会瞬移，
    /// 而且**存在整段看不见任何东西的相位区间**——那会让"注入伪值断言渲染行为"
    /// 这条 AC 的判据变成时序抽奖（渲染恰好落在空档就判绿）。
    /// 往复形态在**任何**相位上都有可见像素，判据因此是确定性的。
    static func pingPong(_ phase: CGFloat) -> CGFloat {
        0.5 - 0.5 * cos(2 * .pi * phase)
    }

    // MARK: 扫描光束

    static let beamThickness: CGFloat = 3
    static let beamBlur: CGFloat = 8
    static let beamOpacity: Double = 0.85

    /// 光束中心的纵坐标。
    static func beamCenterY(phase: CGFloat, height: CGFloat) -> CGFloat {
        Self.pingPong(phase) * height
    }

    // MARK: 边框辉光

    static let ringLineWidth: CGFloat = CoreBorderWidth.thick
    static let ringBlur: CGFloat = 5

    /// 辉光弧的转角：整圈匀速。
    static func ringAngle(phase: CGFloat) -> Angle {
        .degrees(Double(phase) * 360)
    }

    /// 边框圆角：跟随 `CoreRadius.large`，但不超过短边的一半（否则小尺寸内容上会画歪）。
    static func ringRadius(for size: CGSize) -> CGFloat {
        min(CoreRadius.large, max(0, min(size.width, size.height) / 2))
    }

    // MARK: 表面光带

    static let bandWidthRatio: CGFloat = 0.32
    static let bandTilt: Angle = .degrees(20)
    static let bandOpacity: Double = 0.55
    static let bandBlur: CGFloat = 6

    /// 光带中心的横坐标。**恒落在 `[0, width]` 内** ⇒ 任何相位都有可见像素。
    static func bandCenterX(phase: CGFloat, width: CGFloat) -> CGFloat {
        Self.pingPong(phase) * width
    }
}
