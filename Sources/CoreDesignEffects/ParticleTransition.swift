//
//  ParticleTransition.swift
//  CoreDesignEffects
//
//  粒子消散 / 汇聚转场 / A particle dispersal transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时，内容轻微缩放淡出，同时一圈粒子向外飞散（进入时反向汇聚）。
///
/// ```swift
/// if showsBadge {
///     Badge("PRO").transition(.particle)
/// }
/// ```
///
/// ## ⚠️ 形态判定：它是 `Transition`，不是容器视图、也不是 modifier
///
/// 四个 API 单位里只有这一个以 `Transition` 结尾。本仓（与 `#251` 的 16 个转场）
/// 对这一形态的约定是：**`Transition` 协议实现 + `extension Transition where Self == …`
/// 的静态成员**，支持 `.transition(.particle)` 点语法。
/// ⇒ 静态成员 `Transition.particle` 是一个**公开入口点**，它不是类型、
/// `ComponentRegistryGuard` 的组件条目结构上覆盖不到它
/// ⇒ 必须登记进 `docs/component-registry.json` 的 `entryPoints` 数组，
/// 由 `ExtensionEntryPointGuard` 做双向差集（漏登记与幽灵条目两个方向都判红）。
///
/// ## 取色（FR-8）
///
/// 粒子取色池默认**为空 ⇒ 全部取调用方的 `.tint`**，与 `.spray` / `.confetti` 共用
/// 同一个取色函数（`[Color].particleStyle(at:)`）。**不给彩虹默认色板**——那是品牌决定。
///
/// ## Reduce Motion
///
/// **不放粒子、不缩放，只留内容自身的淡入淡出**（与 `#251` 给整个转场簇定的
/// 「位移 / 旋转类降级为淡入淡出」一致）。⚠️ **不是 no-op**：转场承载的是
/// "这块内容出现 / 消失了"这个信息，抹掉它会让开启该偏好的用户看到界面瞬间跳变。
/// 走**降级形态 2**（保留呈现、去掉运动、不叠透明度脉冲）。
///
/// ## a11y 分工（FR-13）
///
/// 粒子层是**纯装饰**，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`。
public struct ParticleTransition: Transition {

    /// 一次转场放多少颗粒子。
    public let count: Int

    /// 粒子取色池，按下标轮转。**空 ⇒ 全部取调用方的 `.tint`**。
    public let colors: [Color]

    /// 默认粒子数。
    ///
    /// ⚠️ **`public` 且住在本类型上，不在 `ParticleBurst` 里**：它被两处 `public`
    /// 签名当默认实参用，而 Swift 不允许默认实参引用 internal 符号
    ///（实测 `error: … is internal and cannot be referenced from a default argument value`）。
    /// `ParticleBurst` 是**几何契约**，一个 API 默认值本来也不该长在那里。
    public static let defaultCount: Int = 18

    public init(count: Int = ParticleTransition.defaultCount, colors: [Color] = []) {
        self.count = count
        self.colors = colors
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        // ⚠️ **走 `ViewModifier` 而不是就地写**：`Transition.body(content:phase:)` 拿不到
        // `@Environment`（它不是 `View`），而 Reduce Motion 必须从环境里读。
        // ⚠️ 且那个 modifier **非泛型**——与 `TriggerRelay` 同一条纪律：
        // 泛型进动画路径会带出 `capture of non-Sendable type 'T.Type'` 一族问题。
        content.modifier(
            ParticleTransitionChrome(phase: phase, count: self.count, colors: self.colors)
        )
    }
}

/// 转场的实际绘制。**非泛型**（只吃 `TransitionPhase` + 两个值类型参数）。
struct ParticleTransitionChrome: ViewModifier {

    let phase: TransitionPhase
    let count: Int
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let phase = self.phase

        // ⚠️ **Reduce Motion：整段换一套呈现——只留淡入淡出**（降级形态 2）。
        // 不是 no-op：内容仍然淡入淡出，用户仍然知道"这块东西出现/消失了"。
        // ⚠️ 与 `.ping` / `.spray` / `.shine` 同一个早退形态（它们同在
        // `MicroInteractionReduceMotionGuard.approvedEarlyExit` 名单上）。
        // ⚠️ 这里的两个 `AnyView` 出口**不受 `#252` C-1 那条约束**：那条针对的是
        // 随 `scenePhase` **反复翻转**的出口（每次后台往返都让调用方子树换身份）；
        // `\.accessibilityReduceMotion` 是用户在系统设置里手动切换的偏好，
        // 且转场本身就是瞬态视图，不存在"反复重建"这个后果。
        guard !isReduced else {
            return AnyView(content.opacity(ParticleBurst.contentOpacity(phase: phase)))
        }

        // ⚠️⚠️ **这个条件里绝不能再出现 `progress`**（#253 PR #273 终审 C-A / I-B）。
        //
        // 上一版写的是 `progress > 0 && self.count > 0`（PR #273 Copilot inline 的
        // 「恒等相位跳过整层」）。它当时"无害"的**唯一**原因是粒子本来就画不出来：
        // `TransitionPhase` 是 3 case frozen enum ⇒ `progress` 的可达取值只有 `{0, 1}`，
        // 而两端的粒子 alpha 都恒为 0 ⇒ 整个粒子层是死代码（终审逐字节实证：三个相位
        // 下与「无粒子层版本」完全相同）。
        //
        // 修好之后（`ParticleBurstLayer` 现在是 `Animatable`，见下），中间进度由
        // **SwiftUI 插值** `animatableData` 得到——而插值的前提是**这个视图在整段动画里
        // 一直在树上**。一旦条件里带上 `progress > 0`，恒等那一端会把整层摘掉：
        // 进场（progress 1 → 0）的收尾、出场（0 → 1）的起手都被截断，
        // 且 `if` 翻转本身会给子树套上默认 `.opacity` 转场、把粒子的峰值再乘一遍。
        // ⇒ 只留「粒子数为 0 就别建层」这半——它与相位无关，翻不动动画。
        // 判据：`ParticleTransitionTests.particleLayerSurvivesTheWholeTransition`
        //（源码逐字钉住这个条件）+ `chromeDrawsParticlesMidFlight`（插值中间值真的画得出）。
        // ⚠️ **代价照录**：恒等相位（转场停住后**长期**停留的那一帧）现在仍会留一个
        // `Canvas`，它每次绘制空跑 `count` 次循环、逐颗 `alpha == 0` 早退。
        // 这是让 SwiftUI 有东西可插值的必要开销，不是遗漏。
        let progress = ParticleBurst.progress(phase: phase)
        let drawsParticles = self.count > 0
        let count = self.count
        let colors = self.colors

        return AnyView(content
            .scaleEffect(ParticleBurst.contentScale(phase: phase))
            .opacity(ParticleBurst.contentOpacity(phase: phase))
            .overlay {
                if drawsParticles {
                    ParticleBurstLayer(progress: progress, count: count, colors: colors)
                }
            })
    }
}

// MARK: - 绘制层

/// 给定进度画出一帧粒子。**不读时间、不读相位**——因此可以被单测钉在任意进度上渲染。
///
/// ⚠️ 用 `Canvas` 而不是 `ZStack` + N 个 `Circle`：默认 18 颗、逐颗建视图会让每一帧
/// 都重走布局（NFR-1）。`Confetti` 已就同一件事立过规矩。
///
/// ## ⚠️⚠️ 为什么必须 `Animatable`（#253 PR #273 终审 C-A）
///
/// **上一版在任何真实相位上都画不出一颗粒子**，四步实证：
///
/// 1. `TransitionPhase` 是 **3 case frozen enum**（`willAppear` / `identity` /
///    `didDisappear`，`value` 分别是 `-1` / `0` / `1`）⇒ `body(content:phase:)`
///    只可能拿到这三个值；
/// 2. ⇒ `ParticleBurst.progress` 的**可达取值只有 `{0.0, 1.0}`**；
/// 3. 这两个值上所有粒子 alpha **恒为 0**（`progress == 0` 被 `guard progress > 0` 挡；
///    `progress == 1` 被 `guard progress < particle.lifetime` 挡——`lifetime` 上界
///    `0.75 + 0.99 × 0.25 = 0.9975 < 1`）；
/// 4. ⇒ 三个相位下直接渲 `ParticleTransitionChrome`，与「无粒子层版本」**逐字节相同**。
///
/// **`ParticleBurstLayer` 是普通 `View`、不 conform `Animatable`、也没有 `TimelineView`**
/// ⇒ 没有任何中间相位来救场：SwiftUI 只插值**可动画属性**，不插值 `Canvas` 的绘制内容。
/// 用户实际只看到内容自身的 `scaleEffect` + `opacity`，「一圈粒子飞散」从未发生。
///
/// ⇒ 现在把 `progress` 声明为 `animatableData`：SwiftUI 在一次动画事务里会把它从
/// 端点 A 插值到端点 B 并**逐帧重求 `body`**，`Canvas` 于是每帧拿到一个新的中间进度。
///
/// ⚠️ **为什么不用 `TimelineView`（`Confetti` 的成法）**：`Confetti` 有一个明确的
/// `burstStart: Date` 可以锚定一段自驱窗口，而 `Transition` **拿不到任何时间源**——
/// 它只被喂三个离散相位，既不知道调用方的 `withAnimation` 用了多长、什么曲线，
/// 也没有"何时开始"这个事实。自建一条时间线会与 SwiftUI 自己的转场时钟**两套时序**
/// （时长 / 曲线 / 打断行为全部对不上），且它在恒等相位会留一个常驻 display link。
/// ⚠️ **也不用 `.keyframeAnimator`**：同一条理由——它要自己声明时长，而转场的时长
/// 在调用方的 `withAnimation` 里。`animatableData` 是唯一"跟着 SwiftUI 的时钟走"的选项。
///
/// ⚠️ **端点画不出粒子是正确的、不是残留缺陷**：`progress == 0` 是恒等相位（转场停住后
/// 长期停留的那一帧，画一颗都是永久残留）；`progress == 1` 是"完全进入前 / 完全离开后"
/// 那一帧，内容不透明度也恰为 0——那一端还留着可见粒子就是一次 pop。
/// ⇒ 判据不能写成「某个真实相位必须画出粒子」（那对任何正确实现都判红），
/// 只能钉**插值中间值**，见 `ParticleTransitionTests.chromeDrawsParticlesMidFlight`。
struct ParticleBurstLayer: View, Animatable {

    var progress: Double
    let count: Int
    let colors: [Color]

    /// ⚠️⚠️ **本转场唯一能让粒子真的动起来的东西**（终审 C-A）。
    /// SwiftUI 在动画事务里做的正是：取两端的 `animatableData`、按 t 插值、写回视图。
    /// 判据 `ParticleTransitionTests.chromeDrawsParticlesMidFlight` 逐字复刻这一步。
    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }

    var body: some View {
        // ⚠️ **先取成局部 `let` 再进闭包**：本包开了 `.defaultIsolation(MainActor.self)`，
        // 在绘制闭包里直接读 `self.x` 会撞上 `MicroInteractionSupport.swift`
        //《写微交互前必读：隔离约束》里记的那一族问题。
        let count = self.count
        let colors = self.colors
        let progress = self.progress

        Canvas { context, size in
            for index in 0..<max(0, count) {
                let particle = ParticleBurst.particle(at: index, count: count)
                let alpha = ParticleBurst.opacity(of: particle, progress: progress)
                guard alpha > 0 else { continue }
                let point = ParticleBurst.location(of: particle, progress: progress, in: size)

                var layer = context
                layer.opacity = alpha
                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - particle.radius,
                        y: point.y - particle.radius,
                        width: particle.radius * 2,
                        height: particle.radius * 2
                    )),
                    // ⚠️ **空色板 ⇒ `.tint`，不是 `Color.accent`**：后者不跟随逐视图
                    // `.tint(_:)`（`Spray.swift` / `Confetti.swift` 都记着这条裁决）。
                    with: .style(colors.particleStyle(at: index))
                )
            }
        }
        // 粒子是**纯装饰**（FR-13）；"这块内容出现了"由调用方通告。
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - 几何与相位（纯函数，生产代码与判据共用同一份）

/// 一颗粒子的确定性初始状态。
///
/// ⚠️ **确定性伪随机：全部由 `index` 派生，不用 `random`**——否则每次重绘粒子都会跳，
/// 且测试无法复现（`Spray` / `Confetti` 已就同一件事立过规矩）。
nonisolated struct ParticleBurstDot: Equatable {
    /// 发射角（度）。
    let angle: Double
    /// 飞散距离，`0...1` 的归一化量。
    let spread: Double
    /// 半径（pt）。
    let radius: CGFloat
    /// 存活到的进度值，`0...1`。
    let lifetime: Double
}

/// 粒子转场的**相位与几何契约**。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `ConfettiBurst` / `ProcessingSweep` / `ShineBand`
/// 同一条纪律）：判据要能对**这条真曲线**求值，而不是在测试里重抄一遍常量。
/// ⚠️ **不要把字面量写回绘制层**——那会让钉帧判据重新变成"测试自说自话"。
nonisolated enum ParticleBurst {

    /// 内容在完全进入 / 完全离开时的缩放量。
    static let scaleDelta: CGFloat = 0.12

    /// 粒子飞散半径相对内容短边的比例，并给小内容一个下限。
    static let reachRatio: CGFloat = 0.75
    static let minimumReach: CGFloat = 60

    /// 相位 → 转场进度，落在 `0...1`。
    ///
    /// ⚠️ **`.identity` 必须恒为 0**：那是转场结束后停住的那一帧，也是用户实际长期
    /// 看到的那一帧（`ShineBand.terminalProgress` / `ConfettiBurst.opacity` 都记着
    /// 同一条教训）。它为 0 ⇒ 所有粒子的不透明度为 0 ⇒ 一颗都不画。
    ///
    /// ⚠️⚠️ **本函数的可达取值只有 `{0, 1}`**：`TransitionPhase` 是 3 case frozen enum，
    /// `value` 只可能是 `-1` / `0` / `1`。中间进度**全部来自 SwiftUI 对
    /// `ParticleBurstLayer.animatableData` 的插值**——不是本函数给的（终审 C-A）。
    /// ⇒ 任何"喂一个 0.4 进去"的判据都**走不到真实相位上**，只能算在插值那条链上。
    static func progress(phase: TransitionPhase) -> Double {
        abs(phase.value)
    }

    /// 内容自身的不透明度。`.identity` ⇒ 1。
    static func contentOpacity(phase: TransitionPhase) -> Double {
        max(0, 1 - Self.progress(phase: phase))
    }

    /// 内容自身的缩放。`.identity` ⇒ 1（恒等，转场不改变常驻态的样子）。
    ///
    /// ⚠️ 进入时从**小**放大、离开时向**大**散开，两侧方向相反 ⇒ 用带符号的 `phase.value`
    /// 而不是 `progress`。
    static func contentScale(phase: TransitionPhase) -> CGFloat {
        1 + CGFloat(phase.value) * Self.scaleDelta
    }

    /// 第 `index` 颗粒子的初始状态。
    static func particle(at index: Int, count: Int) -> ParticleBurstDot {
        let span = Double(max(count - 1, 1))
        let t = Double(index) / span
        let jitterA = Double((index &* 41) % 100) / 100
        let jitterB = Double((index &* 67) % 100) / 100
        return ParticleBurstDot(
            // 整圈均分 + 确定性抖动，避免看出等分。
            angle: t * 360 + (jitterA - 0.5) * 28,
            spread: 0.5 + jitterA * 0.5,
            radius: 1.5 + CGFloat(jitterB) * 2.5,
            lifetime: 0.75 + jitterB * 0.25
        )
    }

    /// 第 `index` 颗粒子在 `progress` 时刻的位置。
    ///
    /// ⚠️ 命名是 `location(...)` 而不是 `position(...)`：后者是
    /// `MicroInteractionReduceMotionGuard.motionCalls` 里的关键字，一个**纯几何函数**
    /// 不该把整份文件卷进运动判据的窗口里（`ConfettiBurst.location` 记着同一条）。
    static func location(of particle: ParticleBurstDot, progress: Double, in size: CGSize) -> CGPoint {
        let reach = Self.reach(in: size)
        let radians = particle.angle * .pi / 180
        let travel = reach * particle.spread * progress
        return CGPoint(
            x: size.width / 2 + cos(radians) * travel,
            y: size.height / 2 + sin(radians) * travel
        )
    }

    /// 第 `index` 颗粒子在 `progress` 时刻的不透明度。
    ///
    /// ⚠️ **`progress == 0` 时必须恒为 0**：那是 `.identity`，转场停住的那一帧。
    /// ⚠️ **`progress == 1` 时同样恒为 0**（`lifetime` 上界 `0.9975 < 1`）：那是
    /// "完全进入前 / 完全离开后"，内容不透明度也恰为 0 ⇒ 那一端留着可见粒子就是一次 pop。
    /// ⇒ **两端都不画是这条曲线的正确形态**，画得出粒子的只有中间进度（终审 C-A）。
    static func opacity(of particle: ParticleBurstDot, progress: Double) -> Double {
        guard progress > 0, progress < particle.lifetime else { return 0 }
        let fadeStart = particle.lifetime * 0.35
        guard progress > fadeStart else { return progress / max(fadeStart, 0.0001) }
        return max(0, 1 - (progress - fadeStart) / (particle.lifetime - fadeStart))
    }

    /// 飞散半径：跟随内容尺寸，并给小内容一个下限（否则在一个图标上完全看不见）。
    static func reach(in size: CGSize) -> CGFloat {
        max(Self.minimumReach, min(size.width, size.height) * Self.reachRatio)
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == ParticleTransition {

    /// 粒子消散 / 汇聚转场。
    ///
    /// ```swift
    /// Badge("PRO").transition(.particle)
    /// ```
    static var particle: ParticleTransition { ParticleTransition() }

    /// 粒子消散 / 汇聚转场，可指定粒子数与取色池。
    ///
    /// - Parameter colors: 取色池，按下标轮转。**默认为空 ⇒ 全部取调用方的 `.tint`**。
    ///   ⚠️ 不给彩虹默认色板：那是品牌决定，不是设计系统该替调用方做的（FR-8）。
    static func particle(count: Int = ParticleTransition.defaultCount, colors: [Color] = []) -> ParticleTransition {
        ParticleTransition(count: count, colors: colors)
    }
}

#Preview("ParticleTransition") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("PRO")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, CoreSpacing.xxl)
                    .padding(.vertical, CoreSpacing.md)
                    .background(Color.accent, in: Capsule())
                    .foregroundStyle(Color.contentOnAccent)
                    .transition(.particle)
            }
        }
        .frame(height: 120)

        Button("切换") { withAnimation(.easeInOut(duration: 0.6)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
