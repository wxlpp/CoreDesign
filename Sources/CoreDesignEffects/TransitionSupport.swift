//
//  TransitionSupport.swift
//  CoreDesignEffects
//
//  转场簇的公共约定 / Shared conventions for the transition cluster.
//

import CoreDesign
import SwiftUI

// MARK: - ⚠️ 写转场前必读：本簇的三层形态

// `#267`（3D 与弹性 6 种：flip / rotate3D / swoosh / boing / skid / move）与
// `#253` 落下的 `ParticleTransition` 共用一套形态，但**在两处刻意与它不同**，
// 两处都是 `#267` 任务书点名的雷区：
//
// ## 层 1 `XTransition: Transition`（public）
//
// 只存参数、把绘制交给层 2。`Transition.body(content:phase:)` **拿不到
// `@Environment`**（它不是 `View`）⇒ Reduce Motion 只能在 `ViewModifier` 里读。
//
// ## 层 2 `XChrome: ViewModifier`（internal）
//
// 唯一职责：读 `@Environment(\.accessibilityReduceMotion)`，把它**作为一个普通
// `Bool` 实参**交给层 3，此外什么都不做。
//
// ## 层 3 `XMotion: ViewModifier, Animatable`（internal）
//
// 真正的绘制，**纯输入**：`phaseValue: Double` + 参数 + `isReduced: Bool`。
//
// ⚠️ **层 2 / 层 3 分开不是"多一层"，是本簇 Reduce Motion 判据能不能存在的前提**：
// `\.accessibilityReduceMotion` 在 `EnvironmentValues` 上**只读**，测试里注不进去
// （`EffectsPresentation` 的文档已实测过这条）。层 3 把它降成一个普通实参之后，
// 判据才能把**同一个相位**分别用 `isReduced: true` / `false` 渲两遍、逐字节比较
// ——「降级真的去掉了运动」与「降级不是 no-op」这两句话才有位图证据，
// 而不是只剩源码扫描（`MicroInteractionReduceMotionGuard` 那条链）。
//
// ## ⚠️ 与 `ParticleTransition` 的两处**有意**不同
//
// ### 1. **没有 `AnyView`，也没有 `if` / `guard` 早退**
//
// `ParticleTransitionChrome` 的 `body` 有两个 `AnyView` 出口（`guard !isReduced`
// 一个、正常路径一个）。`AnyView` **擦掉视图身份**，SwiftUI 的 attribute graph
// 在两个出口之间无法把动画属性对上号 ⇒ 动画退化成端点跳变而不是连续插值。
// 它在那里之所以无害，是因为 `\.accessibilityReduceMotion` 是**系统设置里手动切换**
// 的偏好、一次转场期间不会翻转 ⇒ 出口是固定的。
//
// ⇒ 本簇仍然不用它：六个转场的 `body` 都是**单一视图结构**，Reduce Motion 走
// **逐表达式三元门控**（`self.isReduced ? 恒等值 : 运动值`）。好处有三：
// · 结构上不可能出现"出口翻转导致子树换身份"；
// · `MicroInteractionReduceMotionGuard.everyMotionCallIsGated` 逐个实参检查门控与
//   **极性**，本簇每一处运动都落在它的射程里（早退形态是整段豁免，射程反而更窄）；
// · 六个文件因此**不进** `approvedEarlyExit` 名单（文件里没有早退标记）。
//
// ### 2. **`Animatable` 绑在有符号的 `phaseValue` 上，不是 `abs()` 后的进度**
//
// `TransitionPhase` 是 **3 case frozen enum**（`.willAppear` / `.identity` /
// `.didDisappear`，`value` 分别是 `-1` / `0` / `1`）⇒ `body(content:phase:)`
// 只可能拿到这三个值，**中间值全部来自 SwiftUI 对 `animatableData` 的插值**。
//
// ⚠️ 用**有符号**的 `phase.value` 而不是 `abs(phase.value)`：后者在进出两侧塌成同一个
// 数，`flip` / `swoosh` 这类"进来和出去朝相反方向"的转场就没法区分两端
// ——而且 `-1 → 0 → +1` 这条链插值出来是**连续单调**的，`abs` 之后是 `1 → 0 → 1`，
// 一个 V 形折点。判据：`TransitionClusterTests.interpolationIsContinuousNotAnEndpointJump`。
//
// ⚠️ **为什么必须自己 conform `Animatable`，而不是靠内层 `.rotation3DEffect` 等
// modifier 自带的可动画属性**：`boing` / `skid` 的取值是相位的**非线性函数**
// （阻尼余弦，见 `TransitionCurve.elastic`）。让 SwiftUI 直接插值最终的 scale / offset
// 只会得到两端之间的**直线**——过冲整个消失，"弹"这件事从未发生。
// 绑在 `phaseValue` 上则是先插值自变量、再逐帧过曲线，过冲才画得出来。
// 判据：`TransitionClusterTests.boingOvershootSurvivesInterpolation`（钉的是**渲染出的那一帧**，
// 不只是纯函数取值）。
// 六个转场**统一**走这条，不按"这个需不需要"分两套——两套必然漂移。

// MARK: - 位移档位

/// 位移类转场的行程档位（pt）。
///
/// ⚠️ 与 `MicroInteractionStrength` 并列而不是复用它：那个枚举的 `displacement`
/// 是 4 / 9 / 16 pt，量级是"抖一下"；转场要把内容整个送出视野，量级差一个数量级。
/// 硬把两件事塞进同一个枚举，会逼其中一边接受不合适的数。
///
/// ⚠️ `public` 且 `nonisolated`：它被 `.move(angle:distance:)` 的**默认实参**引用，
/// 而 Swift 不允许默认实参引用 internal 符号；`nonisolated` 是因为本包开了
/// `.defaultIsolation(MainActor.self)`，不标的话下游 nonisolated 上下文用不了它
///（同 `EffectsPowerMode` 的理由）。
public nonisolated enum TransitionTravel: Sendable, Equatable, CaseIterable {

    /// 36 pt —— 徽标、行内小件。
    case short

    /// 80 pt —— 卡片、面板。
    case regular

    /// 160 pt —— 整屏级的大块内容。
    case long

    /// 行程（pt）。
    public var points: CGFloat {
        switch self {
        case .short: 36
        case .regular: 80
        case .long: 160
        }
    }
}

// MARK: - 3D 轴

/// 3D 旋转的轴。**命名按内容看起来往哪个方向转**，不是按数学轴名。
///
/// ⚠️ 这一条容易记反，写在明处：`.horizontal` 指"内容**水平地**翻过去"，
/// 于是转轴是**竖直**的 Y 轴 `(0, 1, 0)`。下面每个 case 的注释都写了向量。
///
/// ⚠️ **`flip` 与 `rotate3D` 共用这一个枚举**，不各自定义一份——本仓对
/// "同一族参数的唯一来源"已有成法（`ButtonRoleStyleRole` 是 role 调色板的唯一来源，
/// 新增 role 扩枚举而不是每个样式各自定义一份）。
public nonisolated enum TransitionAxis3D: Sendable, Equatable, CaseIterable {

    /// 内容水平翻转 —— 转轴 `(0, 1, 0)`。
    case horizontal

    /// 内容垂直翻转 —— 转轴 `(1, 0, 0)`。
    case vertical

    /// 内容在自己平面内打转 —— 转轴 `(0, 0, 1)`。
    case depth

    /// 斜向翻滚 —— 转轴 `(1, 1, 0)`。
    ///
    /// ⚠️ **有意不归一化**（`#267` 终审 S-4）：另外三个 case 是单位向量，这个长度是 √2。
    /// `rotation3DEffect(_:axis:)` 的 `axis` 是一个**方向**，整体乘一个正标量不改变
    /// 旋转 ⇒ `(1, 1, 0)` 与 `(√2/2, √2/2, 0)` 渲出的那一帧**逐字节相同**
    ///（判据 `TransitionClusterTests.axisVectorLengthDoesNotChangeTheRenderedRotation`
    /// 实测钉住）。写成可读的整数三元组是取舍，不是漏掉了归一化；
    /// 哪天那条判据判红，才该来改这里。
    case tilted

    /// `rotation3DEffect(_:axis:)` 要的那个三元组。
    var vector: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch self {
        case .horizontal: (0, 1, 0)
        case .vertical: (1, 0, 0)
        case .depth: (0, 0, 1)
        case .tilted: (1, 1, 0)
        }
    }
}

// MARK: - 相位曲线（纯函数，生产代码与判据共用同一份）

/// 转场簇的**相位契约与共享几何**：把 `TransitionPhase.value` 抬成各转场要的几何量。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `ParticleBurst` / `ConfettiBurst` / `ShineBand`
/// 同一条纪律）：判据要能对**这条真曲线**求值，而不是在测试里重抄一遍常量。
/// ⚠️ **不要把字面量写回绘制层**——那会让钉帧判据重新变成"测试自说自话"。
nonisolated enum TransitionCurve {

    /// 相位 → 有符号相位值。三个真实相位分别是 `-1` / `0` / `1`。
    ///
    /// ⚠️ 中间值**不来自本函数**：它只可能返回那三个数（`TransitionPhase` 是 3 case
    /// frozen enum）。连续的中间值全部来自 SwiftUI 对 `animatableData` 的插值。
    static func value(of phase: TransitionPhase) -> Double { phase.value }

    /// 「离恒等有多远」，钳在 `0...1`。
    ///
    /// ⚠️ 钳位是承重的：`animatableData` 在带过冲的动画曲线（`.bouncy` / `.spring`）下
    /// **会越过端点**（实测可到 1.1 以上），不钳会让不透明度变成负数、缩放翻过头。
    static func distance(_ phaseValue: Double) -> Double { min(1, abs(phaseValue)) }

    /// 内容自身的不透明度：恒等 ⇒ **恰为 1**，两端 ⇒ 0。
    ///
    /// ⚠️ **这条曲线同时是整簇的 Reduce Motion 降级形态**：开启该偏好时六个转场
    /// 只剩它（运动量一律门控到恒等值）⇒ 降级 = 一次纯淡入淡出，**不是 no-op**。
    static func opacity(_ phaseValue: Double) -> Double {
        max(0, 1 - Self.distance(phaseValue))
    }

    /// 阻尼余弦弹性窗：两端取 `amplitude`，恒等**恰为 0**，中途换向形成过冲。
    ///
    /// 令 `u = 1 - distance`（两端 0、恒等 1）：
    ///
    /// ```
    /// elastic = amplitude · (1 - u)² · cos(2π · cycles · u)
    /// ```
    ///
    /// - `u = 0`（两端）：`(1-0)² · cos 0 = 1` ⇒ 恰为 `amplitude`；
    /// - `u = 1`（恒等）：`(1-1)² = 0` ⇒ **恰为 0**，转场停住后不留残余形变；
    /// - 中间：余弦在 `cycles` 给定的窗口里翻负号 ⇒ 越过目标再回落，就是"弹"。
    ///
    /// ⚠️ **衰减窗 `(1-u)²` 不能换成 `exp(-ku)`**：指数在 `u = 1` 处不为 0，
    /// 恒等相位会留下一点点残余缩放 / 位移——那是**永久**的，因为恒等是转场停住后
    /// 长期停留的那一帧（`ParticleBurst.progress` 的文档记着同一条教训）。
    static func elastic(_ phaseValue: Double, amplitude: Double, cycles: Double) -> Double {
        let u = 1 - Self.distance(phaseValue)
        let decay = (1 - u) * (1 - u)
        return amplitude * decay * cos(2 * .pi * cycles * u)
    }

    /// `edge` 的单位方向向量（**指向那条边的外侧**）。
    ///
    /// ⚠️ 三个位移类转场（`swoosh` / `skid` / 以及 `move` 的极角）共用这一份，
    /// 不各写一遍 `switch edge`——三份 `switch` 必然在某次改动里漂移，
    /// 而"方向反了"这种缺陷在静态截图上看不出来。
    /// ⚠️⚠️ **这四个向量的取值是绝对的，判据必须逐个钉死**（`#267` 终审 I-1）：
    /// 把它们**整体取反**，`swoosh` / `skid` / `move` 的所有**对称性**判据
    ///（`travel(-1) == -travel(1)`、同侧两端相等）**一条都不会红**，
    /// 而 `.swoosh(edge: .trailing)` 已经变成从左边进了。
    /// ⇒ `TransitionClusterTests.absoluteDirectionsMatchTheDocumentedEdges`（纯函数）
    /// 与 `absoluteDirectionsReachThePixels`（位图重心）钉绝对方向，
    /// 并覆盖 `.top` / `.bottom` 与 `Skid.tilt` 的纵向分支。
    static func direction(of edge: Edge) -> CGSize {
        switch edge {
        case .leading: CGSize(width: -1, height: 0)
        case .trailing: CGSize(width: 1, height: 0)
        case .top: CGSize(width: 0, height: -1)
        case .bottom: CGSize(width: 0, height: 1)
        }
    }
}
