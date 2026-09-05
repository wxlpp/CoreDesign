//
//  MaskRevealTransitions.swift
//  CoreDesignEffects
//
//  六种 mask reveal 转场的公开入口 / The six mask-reveal transitions.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// `iris` / `wipe` / `blinds` / `clock` / `glare` / `dissolve` 六种「揭示型」转场。
///
/// ```swift
/// if showsBadge {
///     Badge("PRO").transition(.iris)
/// }
/// ```
///
/// ## ⚠️ 六种共用**一个**类型，这是有意的
///
/// 六者的差别只在几何族（`MaskRevealKind`），降级、恒等余量、插值机制、a11y 分工
/// 全部逐字相同。拆成六个 `Transition` 类型只会把同一份 `body` 抄六遍——而
/// `#251` 的计数单位是「**一种 transition**」、登记表按 `Host.member` 去重，
/// 计数与登记看的都是 `extension Transition` 上那六个名字，不是类型个数。
/// ⇒ 六个静态成员 = 六条 `entryPoints` 登记，与本类型是不是一个类型无关。
///
/// ## ⚠️ 没有 public init
///
/// 调用方只应经由下面六个静态成员拿到实例——`init` 一旦公开，`MaskRevealKind`
/// 也得跟着公开，而那是一个纯实现细节（它随几何实现变，不该冻进 API）。
/// 本仓「public 类型必须有 public init」的惯例针对的是**组件**（调用方要构造它），
/// 转场不属于那一类。
///
/// ## 形态判定
///
/// 它是 `Transition`，不是容器视图、也不是 modifier ⇒ 静态成员
/// `Transition.iris` … 是**公开入口点**，不是类型，`ComponentRegistryGuard` 的
/// 组件条目结构上覆盖不到它 ⇒ 六个名字必须登记进 `docs/component-registry.json`
/// 的 `entryPoints` 数组，由 `ExtensionEntryPointGuard` 做双向差集
/// （漏登记与幽灵条目两个方向都判红）。
///
/// ## Reduce Motion —— ⚠️⚠️ **两道闸，框架那道在前**
///
/// 结论形态：**遮罩全开、内容不透明度跟着进度走**，退化成一次纯淡入淡出
/// （`#251` 给整簇定的「位移 / 旋转类降级为淡入淡出」）。⚠️ **不是 no-op**：
/// 转场承载的是"这块内容出现 / 消失了"这个信息，抹掉它会让开启该偏好的用户
/// 看到界面瞬间跳变。
///
/// ⚠️⚠️ **上一版这里写「裁决点是 `MaskReveal.plan(…)` 这一个纯函数」——
/// 那句话在运行时是假的，照录更正**（终审 I-5）：
///
/// | 闸 | 谁 | 何时生效 |
/// |---|---|---|
/// | **第一道（真正生效的那道）** | SwiftUI，看 `properties.hasMotion` | 本类型声明 `hasMotion == true` ⇒ **RM 打开时框架直接把整条转场换成 `.opacity`**，本类型的 `body` 根本不被调用 |
/// | 第二道（兜底） | `MaskReveal.plan(kind:progress:isReduced:)` | 只在框架**没有**替换时才轮得到 |
///
/// ⇒ 经 `.transition(.iris)` 这条正常路径，`plan` **永远看不到 `isReduced == true`**。
///
/// ## ⚠️ 内层 RM 路径：**显式裁定为保留**，理由与代价照录
///
/// `MaskReveal.plan` 的 `guard !isReduced`、`MaskRevealChrome` 的
/// `@Environment(\.accessibilityReduceMotion)` 读取、以及守着它们的两条判据
/// （`reduceMotionOpensTheMaskAndCrossFadesInstead` /
/// `reducedPlanRendersAsPlainFade`）**保留**，理由：
/// · `hasMotion` 是一个**一行就能改**的开关（`#292` 正在统一跟踪本仓的声明面）——
///   哪天它被改成 `false`，内层这道闸当场从"兜底"变成"唯一保护"，而删掉它之后
///   那次改动会**静默**让 RM 用户看到完整运动；
/// · 框架替换的**时机与范围**没有文档承诺（`AnyTransition` 包装、别的平台 / 版本），
///   内层闸让本簇在任何一种情况下的结论都一样。
/// **代价照录**：这四处今天守的是**不可达路径**，别把「RM 降级有判据」读成
/// 「RM 在生产里由我们处置」——生产里处置它的是 SwiftUI。
///
/// `MaskRevealSourceGuard.reduceMotionIsOnlyConsumedByThePlan` 钉的仍然是
/// **内层这道闸不被绕过**（本簇代码里 `reduceMotion` 只喂给 `plan` 一处），
/// 这一条与上面的更正不冲突：它守的是第二道闸的完整性，不是"它是唯一的闸"。
///
/// ## a11y 分工
///
/// 裁剪不改变 accessibility tree——被裁掉的内容仍在树上（这与 `.opacity(0)` 相同，
/// 是 SwiftUI 的既有语义，本簇不另作处理）；"这块内容出现了"由调用方通告。
/// `glare` 的柔光带是**纯装饰**，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`。
public struct MaskRevealTransition: Transition {

    let kind: MaskRevealKind

    init(_ kind: MaskRevealKind) {
        self.kind = kind
    }

    /// 默认百叶条数。
    ///
    /// ⚠️ **`public` 且住在本类型上，不在 `MaskReveal` 里**：它被下面的 `public`
    /// 签名当默认实参用，而 Swift 不允许默认实参引用 internal 符号
    /// （实测 `error: … is internal and cannot be referenced from a default argument value`；
    /// `ParticleTransition.defaultCount` 记着同一条）。
    ///
    /// ⚠️⚠️ **四个默认值常量都必须 `nonisolated`，这是下游 probe 实测换来的**
    /// （终审 I-3）：本 target 开了 `.defaultIsolation(MainActor.self)` ⇒ 不写
    /// `nonisolated` 时它们是 MainActor 隔离的静态属性，下游从 `nonisolated`
    /// 上下文（在自己的模型 / 配置层读一个默认值）引用会拿到
    /// `warning: main actor-isolated static property '…' can not be referenced
    /// from a nonisolated context`。这只有 `scripts/downstream-probe` 看得见，
    /// 库自身的 `swift build` / `swift test` 全跑在被隔离的 target **内部**。
    /// 判据：`readMaskRevealTransitionDefaults()`（那个包的
    /// `EffectsNonisolatedUsage.swift`，`nonisolated func`）。
    public nonisolated static let defaultBlindCount: Int = 8

    /// 默认格边长（pt）。同上，`public` 是默认实参的要求、`nonisolated` 是下游的要求。
    public nonisolated static let defaultCellSize: CGFloat = 24

    /// `wipe` 的默认方向：左 → 右。
    public nonisolated static let defaultWipeAngle: Angle = .degrees(0)

    /// `glare` 的默认方向：左上 → 右下的斜掠。
    ///
    /// ⚠️ 与 `wipe` 的默认值**有意不同**——两者共用同一条半平面数学，
    /// 若默认角度也相同，调用方在默认参数下就分不出 `.glare` 与 `.wipe`
    /// （差别只剩那条柔光带）。
    public nonisolated static let defaultGlareAngle: Angle = .degrees(35)

    /// ## ⚠️⚠️ `hasMotion` 取 `true`，这是一次**有代价**的定案，代价照录
    ///
    /// Apple 文档逐字：「*Whether the transition includes motion. When this behavior
    /// is included in a transition, that transition **will be replaced by opacity**
    /// when Reduce Motion is enabled.*」（`TransitionProperties.hasMotion`，默认 `true`）
    /// ⇒ 声明 `true` 意味着 **Reduce Motion 打开时 SwiftUI 直接把本转场换成
    /// `.opacity`，本类型的 `body` 根本不会被调用**。
    ///
    /// **为什么仍然取 `true`**：
    /// 1. **它是事实。** `properties` 是 `static`，拿不到环境 ⇒ 它描述的只能是
    ///    **未降级形态**的本转场，而那个形态确实有一条边扫过内容。
    ///    取 `false` 是对系统撒谎，且 `TransitionProperties` 的文档明写这些属性
    ///    「决定转场如何与**包括辅助功能在内**的系统特性交互」——今天只有 RM 一项，
    ///    骗过这一项等于把将来所有基于它的适配一并关掉。
    /// 2. **降级结论一致，用户看不出差别。** 系统的替换是纯 opacity；本簇自己的降级
    ///    （`MaskReveal.plan(…isReduced: true)`：遮罩全开 + 内容不透明度跟着进度走）
    ///    **就是**一次纯淡入淡出。两条路径同一个观感 ⇒ 交给系统不损失任何东西。
    /// 3. 取 `false` 则**唯一**的保护是手写闸；一旦有人把 `isReduced` 那条分支重构掉，
    ///    RM 用户当场看到完整运动，且没有任何系统兜底。
    ///
    /// ⚠️⚠️ **代价（别把它读成"两道保险"）**：`true` ⇒ 本类型自己那套 RM 降级在
    /// **生产路径上不可达**。保留它的裁定与理由写在本类型的文档注释里
    /// （「## ⚠️ 内层 RM 路径：**显式裁定为保留**」那一节）。
    ///
    /// ⚠️ **显式写出来的意义**：`true` 与 SDK 默认值相同 ⇒ 这一行不改变任何行为，
    /// 它换来的是**下一个人能在代码里看见框架那道闸**——上一版没有这行，于是
    /// 整份文档把 `plan(…)` 说成"唯一裁决点"，而那在运行时是假的。
    /// 判据：`MaskRevealTransitionBodyTests.transitionDeclaresItHasMotion`
    /// （运行时取值 + 源码钉住这是**显式声明**而不是继承 SDK 默认）。
    ///
    /// ⚠️ 追踪：`#292` 已收口本仓 `Transition` 的 `properties` 声明面——12 条实现全部
    /// 显式声明（最后一条 `ParticleTransition` 在 `#292` 补上），
    /// 由 `TransitionPropertiesGuard`（`CoreDesignTests`，SwiftSyntax 结构判定）
    /// 与 `TransitionPropertiesRoster`（12 条运行时取值）两条守卫接管。
    /// ⚠️ `#292` **有意不统一**三簇的声明形态（理由见那条守卫的文件头），
    /// 故下面这一行与本簇原样保留。
    public static let properties: TransitionProperties = TransitionProperties(hasMotion: true)

    /// ⚠️⚠️ **本函数是六个公开静态成员通向 `MaskRevealChrome` 的唯一路径，
    /// 而它曾经完全没有判据**（终审 C-1，变异 M-A 实证）：把本函数整段改成
    /// 「丢弃调用方的相位与几何族、恒定交出 `progress: 1` 与 `.iris`」——即六种转场
    /// 全部退化成「内容凭空出现」——本簇 31 条判据与全量 761 条**零红**。
    /// 成因：`entryPoints` 取的是静态成员的存储属性 `kind`、渲染判据直接构造
    /// `MaskRevealChrome`、逐字钉只钉 `MaskRevealChrome` 的类型体，
    /// 三条都绕开了本函数。
    /// ⇒ 现由 `MaskRevealTransitionBodyTests` 的两条判据合起来钉住：
    /// · `bodyHandsChromeThePhaseAndTheKind` —— 对本函数**直接求值**（`Transition.Content`
    ///   是零尺寸类型，可以从 `()` 位转换出来），逐相位 × 逐入口点断言 `MaskRevealChrome`
    ///   拿到的 `(progress, kind)` 恰是 `(MaskReveal.progress(phase:), self.kind)`,
    ///   12 个入口点 × 3 个相位；
    /// · `appliedTransitionRendersThroughBody` —— 经**公开的**
    ///   `Transition.apply(content:phase:)` 渲染，端到端把 SwiftUI 自己那段接线也走一遍。
    /// 上面那枚变异下两条合计判红 **69** 次（`37 tests … failed … with 69 issues`）。
    public func body(content: Content, phase: TransitionPhase) -> some View {
        // ⚠️ **走 `ViewModifier` 而不是就地写**：`Transition.body(content:phase:)`
        // 拿不到 `@Environment`（它不是 `View`），而 Reduce Motion 必须从环境里读。
        content.modifier(
            MaskRevealChrome(progress: MaskReveal.progress(phase: phase), kind: self.kind)
        )
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）
//
// ⚠️ 每一种都有「无参 `var`」与「含参 `func`」两个成员，**登记表里算同一条**
// ——扫描器按 `Host.member` 去重，与 `#251`「计数单位是一种 transition 而不是
// 一个静态成员」同一口径。

public extension Transition where Self == MaskRevealTransition {

    /// 圆形光圈从中心向外张开。
    ///
    /// ```swift
    /// Badge("PRO").transition(.iris)
    /// ```
    static var iris: MaskRevealTransition { MaskRevealTransition(.iris(anchor: .center)) }

    /// 圆形光圈从 `anchor` 向外张开。
    ///
    /// - Parameter anchor: 光圈中心，内容 bounds 的单位坐标。半径自动取到最远角，
    ///   因此任何 anchor（含四角）在完全揭示时都铺满内容。
    static func iris(anchor: UnitPoint = .center) -> MaskRevealTransition {
        MaskRevealTransition(.iris(anchor: anchor))
    }

    /// 一条直边沿默认方向（左 → 右）扫过。
    static var wipe: MaskRevealTransition {
        MaskRevealTransition(.wipe(radians: MaskRevealTransition.defaultWipeAngle.radians))
    }

    /// 一条直边沿指定方向扫过。
    ///
    /// - Parameter angle: 扫过方向。`0°` 左 → 右，`90°` 上 → 下（SwiftUI 的 y 轴向下），
    ///   `180°` 右 → 左。任意角度都合法，边始终与该方向垂直。
    static func wipe(angle: Angle = MaskRevealTransition.defaultWipeAngle) -> MaskRevealTransition {
        MaskRevealTransition(.wipe(radians: angle.radians))
    }

    /// 若干条横向百叶各自从自己的中线向上下张开。
    static var blinds: MaskRevealTransition {
        MaskRevealTransition(.blinds(count: MaskRevealTransition.defaultBlindCount))
    }

    /// 指定条数的横向百叶。
    ///
    /// - Parameter count: 百叶条数。`0` 与负数会被钳到 1——否则整条转场退化成
    ///   "什么都不揭示"，而那是一个不会报错的死转场。
    static func blinds(count: Int = MaskRevealTransition.defaultBlindCount) -> MaskRevealTransition {
        MaskRevealTransition(.blinds(count: count))
    }

    /// 扇形扫针从 12 点方向顺时针扫一圈。
    static var clock: MaskRevealTransition { MaskRevealTransition(.clock(sign: 1)) }

    /// 扇形扫针，方向可选。
    ///
    /// - Parameter direction: 扫针方向。⚠️ 用语义枚举而不是 `clockwise: Bool`
    ///   ——`true` 在调用处读不出含义（J-1 禁未豁免 Bool 参数，`SpinDirection`
    ///   记着同一条裁决）。
    static func clock(direction: SpinDirection = .clockwise) -> MaskRevealTransition {
        MaskRevealTransition(.clock(sign: direction == .clockwise ? 1 : -1))
    }

    /// 斜掠的直边扫过，揭示边上骑一条柔光带。
    ///
    /// ⚠️ 几何与 `.wipe` 同族（同一条半平面数学），差别是**默认斜角**与**柔光带**。
    /// 柔光带取 `Color.specularHighlight`（第 3 层 token），两端不透明度恒为 0
    /// ——恒等相位不留任何永久高光。
    static var glare: MaskRevealTransition {
        MaskRevealTransition(.glare(radians: MaskRevealTransition.defaultGlareAngle.radians))
    }

    /// 指定方向的掠光揭示。
    static func glare(angle: Angle = MaskRevealTransition.defaultGlareAngle) -> MaskRevealTransition {
        MaskRevealTransition(.glare(radians: angle.radians))
    }

    /// 网格逐格随机浮现。
    static var dissolve: MaskRevealTransition {
        MaskRevealTransition(.dissolve(cellSize: MaskRevealTransition.defaultCellSize))
    }

    /// 指定格边长的逐格浮现。
    ///
    /// - Parameter cellSize: 格边长（pt）。⚠️ 过小的值会被自动放大到让格数落在
    ///   `MaskReveal.dissolveMaximumCells` 以内——否则全屏内容配 `0.5` 会是百万级
    ///   子路径逐帧重建。`0` / 负数 / 非有限值一律回落到默认值。
    static func dissolve(cellSize: CGFloat = MaskRevealTransition.defaultCellSize) -> MaskRevealTransition {
        MaskRevealTransition(.dissolve(cellSize: cellSize))
    }
}

#Preview("mask reveal 六种") {
    @Previewable @State var shown = true
    @Previewable @State var index = 0

    let cases: [(String, MaskRevealTransition)] = [
        ("iris", .iris), ("wipe", .wipe), ("blinds", .blinds),
        ("clock", .clock), ("glare", .glare), ("dissolve", .dissolve),
    ]
    let current = cases[index % cases.count]

    return VStack(spacing: CoreSpacing.xxl) {
        Text(current.0).font(.headline)

        ZStack {
            if shown {
                Text("PRO")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, CoreSpacing.xxl)
                    .padding(.vertical, CoreSpacing.md)
                    .background(Color.accent, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(Color.contentOnAccent)
                    .transition(current.1)
            }
        }
        .frame(height: 140)

        HStack(spacing: CoreSpacing.lg) {
            Button("切换") { withAnimation(.easeInOut(duration: 0.9)) { shown.toggle() } }
            Button("换一种") { index += 1; shown = true }
        }
    }
    .padding(CoreSpacing.huge)
}

#Preview("含参重载") {
    @Previewable @State var shown = true

    return VStack(spacing: CoreSpacing.xxl) {
        HStack(spacing: CoreSpacing.xxl) {
            ForEach(Array(previewParameterisedCases.enumerated()), id: \.offset) { pair in
                VStack(spacing: CoreSpacing.sm) {
                    ZStack {
                        if shown {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accent)
                                .frame(width: 84, height: 84)
                                .transition(pair.element.1)
                        }
                    }
                    .frame(width: 84, height: 84)
                    Text(pair.element.0).font(.caption)
                }
            }
        }
        Button("切换") { withAnimation(.easeInOut(duration: 1.2)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}

/// 预览用的含参重载样例。⚠️ 提到顶层是因为 `#Preview` 里写不下 `let` 数组的类型标注
/// 又要被两处引用；它只服务预览，不进产品路径。
private let previewParameterisedCases: [(String, MaskRevealTransition)] = [
    ("iris(.topLeading)", .iris(anchor: .topLeading)),
    ("wipe(90°)", .wipe(angle: .degrees(90))),
    ("blinds(3)", .blinds(count: 3)),
    ("clock(逆)", .clock(direction: .counterClockwise)),
    ("glare(-20°)", .glare(angle: .degrees(-20))),
    ("dissolve(12)", .dissolve(cellSize: 12)),
]
