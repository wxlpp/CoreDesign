//
//  EffectsEnergy.swift
//  CoreDesignEffects
//
//  NFR-7 能耗与生命周期：可注入的 EnvironmentValues + 渲染策略
//  / Injectable energy environment + render policy.
//

import CoreDesign
import Foundation
import SwiftUI

// MARK: - 为什么要有"可注入"这一层

// PRD 的 **NFR-7** 逐字要求：常驻渲染的效果（`colorEffect` 背景、Confetti、
// ScanningOverlay）必须**定义**并**可测**它们在 App 进入后台、以及低电量模式下的行为。
// ⚠️ 并且逐字写明「**不接受"或文档声明"**」——那会让这条退化成文档要求。
//
// 而这两个信号在单测里**都不可直接切换**：
// · `ProcessInfo.processInfo.isLowPowerModeEnabled` 是只读的系统状态；
// · `\.scenePhase` 由 SwiftUI 的 `Scene` 供给，`ImageRenderer` 下没有 Scene 可驱动。
//
// ⇒ 本文件把这两个信号做成**可注入的 `EnvironmentValues` 键**（**默认从系统读**，
// 注入值优先）。测试注入伪值 ⇒ 渲染行为可断言，判据落在机器上而不是文档里。
//
// ## ⚠️ 这两个键必须 `public` —— 一条**跨 epic 契约**
//
// `shipswift-shaders` 的 B-2（17 个 `colorEffect` 背景）要 `import CoreDesignEffects`
// **复用**它们，而 `@Entry` 宏展开时**默认不继承 `public`**（本仓 `Color.toastHost`
// 那条已经为同一件事显式标注过）。⇒ 这里逐个显式标 `public`；
// 跨模块的可见性证明在 `scripts/downstream-probe`（同模块内的断言证不了这条：
// internal 在同模块内一样能过）。
//
// ## ⚠️ 为什么低电量键不是 `Bool`
//
// 这里本来就有比 `Bool` 更好的形状：`EffectsPowerMode` 是一个**语义档位**，
// 读作 `.lowPower` 比读作 `true` 说明了更多东西。
// ⇒ 键的类型是 `EffectsPowerMode?` 而不是 `Bool?`。
// NFR-7 只要求"可注入 + 默认从系统读"，没有规定键的类型。
//
// ⚠️ **别把这条理由的射程写宽了**（第 1 轮终审 Preference）。本仓的 Bool 纪律
//（`BoolExemptionGuard` + `docs/bool-exemptions.json`）对两种声明**处置不同**：
// · public **函数/init 参数**（例如 `EffectsEnergyState.resolve(injectedPowerMode:)`）
//   ——裸 `Bool` 会命中判据、抬棘轮基线，换成枚举确实能省掉一条豁免；
// · public **属性本身**（`EnvironmentValues.effectsPowerMode` 就是属性）
//   ——`BoolParameterScanner.visit(_: VariableDeclSyntax)` 明写「public 的 Bool
//   **属性**：只清点，不判据（裁决 (d)）」，且这个清点**没有基线**。
//   ⇒ 就算这个键写成 `Bool?`，棘轮也一动不动。
// 「净增 0 条豁免」在两种写法下都成立；成立的是"枚举读起来更清楚 + 参数面不欠账"，
// 不是"写 Bool 会让棘轮判红"。

// MARK: - 能耗档位 / Power mode

/// 设备的能耗档位。`nil` 注入值 ⇒ 从 `ProcessInfo` 读（见 `EffectsEnergyState.resolve`）。
///
/// ⚠️ **「将来加第三档 enum 直接扩」这句要收窄**（第 1 轮终审 Preference）：
/// 本枚举是 **public 且非 `@frozen`**，但 Swift 的非 frozen 只对**库演进模式**
/// （`-enable-library-evolution`）下的二进制兼容有意义；本包以源码形式分发，
/// 下游对它写的 exhaustive `switch` 在加了新 case 之后**会编译红**——
/// 也就是说加档位是一次**源码破坏性变更**，只是不必改任何签名。
/// 相对 `Bool`（加档位要改签名、改所有调用点）它仍然更好，但"直接扩"不是免费的。
///
/// ⚠️ `nonisolated`：本包开了 `.defaultIsolation(MainActor.self)`，不标的话下游
/// **nonisolated 上下文**（例如在后台线程准备渲染参数的宿主代码）用不了它——
/// 这正是 `scripts/downstream-probe` 唯一能看见的那类问题（见 `CoreDesignEffects.moduleName`）。
public nonisolated enum EffectsPowerMode: Sendable, Equatable, CaseIterable {

    /// 常规供电。
    case standard

    /// 低电量模式（iOS「低电量模式」/ macOS「低电量」）。
    case lowPower

    /// 从系统读当前档位。
    ///
    /// ⚠️ **已知限度：它不是响应式的**。`ProcessInfo` 的低电量状态变化会发
    /// `NSProcessInfoPowerStateDidChange` 通知，但 `EnvironmentValues` 的默认值
    /// 只在被读取时求值一次，不会因为该通知而让视图失效。
    ///
    /// ⚠️ **这句话有一处例外，别当成整块成立**（#252 PR #269 第 1 轮终审 S-1）：
    /// `ProcessingSweepBody` 是在 `TimelineView` 闭包**内部**构造的，它每帧重跑
    /// 一次 `resolve(...)` ⇒ 它读出的 `usesGlow` **实际上是响应式的**（也因此每帧
    /// 都在读 `ProcessInfo`）。不响应的是驱动层求一次就交出去的 `minimumInterval`
    /// 与 `Confetti` 的粒子数。完整登记见 `ProcessingSweepBody` 的类型文档。
    /// 需要"用户中途打开低电量模式就立刻降级"的宿主 App，应当自己订阅该通知并
    /// `.environment(\.effectsPowerMode, .lowPower)` 注入——这也正是这个键存在的
    /// 第二个用途（第一个是可测）。
    public static var current: EffectsPowerMode {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? .lowPower : .standard
    }
}

// MARK: - 渲染策略 / Render policy

/// 常驻渲染件在当前能耗状态下**该画到什么程度**。
///
/// ⚠️ **这是一个纯函数的产物**（`EffectsEnergyState.policy`），不读任何全局状态
/// ——测试可以直接对它断言，不必先把 App 推进后台。
///
/// ## ⚠️⚠️ 待裁决：本类型把「通用能耗信号」和「effects 专用旋钮」混在了一起
///
/// （#252 PR #269 第 1 轮终审 S-2 登记。**本轮只登记，不改结构**——改法跨 epic，
/// 需要用户拍板；但 merge 之后再搬就是**破坏性变更**，故必须先写在这里。）
///
/// 本枚举现在同时承担两件事：
/// · **通用**的能耗判定（`drawsAnything` / `minimumInterval`）——任何常驻渲染件都要；
/// · **effects 专用**的旋钮（`particleScale`、多半还有 `usesGlow`）——
///   `shipswift-shaders` 的 B-2 那 17 个 `colorEffect` 背景**没有粒子**，
///   `particleScale` 对它们毫无意义。
///
/// 冲突在于：B-2 若为了前两个键 `import CoreDesignEffects`，那么**只想要 shader
/// 的消费者也必须链上整个 Effects product**——而 `Package.swift` 拆 product 的
/// 逐字理由正是「只想要系统原生观感的消费者不必背上动效与图表」。两者直接抵触。
///
/// 两条出路（未选定）：
/// 1. **键下沉到 `CoreDesign`**：把 `\.effectsPowerMode` / `\.effectsScenePhase`
///    与"通用"那半个策略挪进 `CoreDesign`，Effects 侧再包一层自己的策略
///    （`particleScale` 之类留在这里）。代价：`CoreDesign` 长出一块与"系统原生观感"
///    无关的表面；收益：shaders 不必依赖 Effects。
/// 2. **明确接受「Shaders 依赖 Effects」**：把这条依赖写进 `Package.swift` 的拆分理由里
///    （即修正那句话的射程），不再假装两者可分。代价：product 拆分的卖点缩水。
///
/// ⚠️ **B-2 开工前必须裁决**：这两个键与本枚举都是 `public`，一旦有第二个 target
/// 开始 `import` 它们，再搬就是下游可见的**破坏性变更**（改 import、改类型名）。
public nonisolated enum EffectsRenderPolicy: Sendable, Equatable, CaseIterable {

    /// 满帧、带光晕。
    case full

    /// 降帧、去掉离屏模糊（光晕）这类昂贵通道，但**仍然在动**。
    case reduced

    /// 完全停摆：驱动动画的 `TimelineView` **不建**（不是"建了但暂停"）。
    case paused

    /// 是否还要画装饰层。`false` ⇒ 调用方应当**整层不建**。
    ///
    /// ⚠️ 命名是"draws**Anything**"而不是"isPaused"：调用点读起来是
    /// `guard policy.drawsAnything else { return AnyView(content) }`，
    /// 意思正好是"这一层一个像素都不画"。
    public var drawsAnything: Bool { self != .paused }

    /// 是否使用离屏模糊做光晕。
    ///
    /// ⚠️ 这是**低电量下唯一在静态位图上可观测**的差异，因此也是 NFR-7
    /// 「注入伪值断言渲染行为」这条 AC 在低电量方向的判据落点：
    /// 降帧本身拍不进静态帧（`ImageRenderer` 拍的是一帧），而"有没有那圈模糊"拍得到。
    public var usesGlow: Bool { self == .full }

    /// 交给 `TimelineSchedule.animation(minimumInterval:)` 的最小间隔。
    /// `nil` ⇒ 跟随显示器刷新率。
    public var minimumInterval: Double? { self == .reduced ? 1.0 / 15.0 : nil }

    /// 粒子数量的缩放系数。低电量下少放一半，停摆时一个不放。
    public var particleScale: Double {
        switch self {
        case .full: 1
        case .reduced: 0.5
        case .paused: 0
        }
    }
}

// MARK: - 呈现档位 / Presentation

/// 两道闸（NFR-7 能耗闸 + Reduce Motion 闸）**一起**裁出来的结果：这一层到底呈现什么。
///
/// ⚠️⚠️ **它存在的唯一理由是「顺序是承重的」这句话必须有机器判据**
/// （#252 PR #269 第 1 轮终审 I-1 / I-2）。
///
/// 两个调用点（`ProcessingSweepDriver` / `ConfettiCore`）此前各写一遍这条链，
/// 结果是 `Confetti` 把顺序写反了：RM 闸在前 ⇒ 开启「减弱动态效果」的用户在
/// `.inactive` / `.background` 下**仍然**拿到一个静态庆祝层 + 1.55 s 透明度动画，
/// NFR-7 在这条路径上整条失效。而当时**两道闸对调也是 42/42 全绿**——
/// 终审做过这枚变异：没有任何判据看得见顺序。
///
/// ⇒ 裁决抽成本类型 + `EffectsEnergyState.presentation(reduceMotion:)` 一个纯函数，
/// 两个调用点共用同一份；顺序由函数体本身固定（能耗闸写在 `guard` 里、先求值），
/// 判据只需一行 `#expect(… .presentation(reduceMotion: true) == .none)`
/// 就同时钉死 I-1 且让它不可能被重新引入。
/// 这与本仓「纯函数 + 生产代码与判据共用同一份」的既有纪律一致
/// （`ConfettiBurst` / `ProcessingSweep` 都是这个形态）。
///
/// ⚠️ **为什么不走位图判据**：`\.accessibilityReduceMotion` **不可注入**
/// （`EnvironmentValues` 上它是只读的系统偏好，写它编译红——终审已实测）。
/// ⇒ "RM 开启 × 后台"这个组合在 `ImageRenderer` 下根本构造不出来，纯函数是唯一可行路径。
///
/// ⚠️ **刻意 `internal`**：本类型只服务同模块的两个调用点，没有跨模块消费者；
/// 而 `presentation(reduceMotion:)` 一旦 `public`，那个裸 `Bool` 参数就会命中
/// `BoolExemptionGuard` 的判据、要求一条署名豁免并抬棘轮基线
/// （`CoreDesignEffects` 当前是 0 条，见 `docs/bool-exemptions-baseline.json`）。
/// 测试走 `@testable import CoreDesignEffects`，够用。
enum EffectsPresentation: Sendable, Equatable, CaseIterable {

    /// 一个像素都不画（NFR-7 停摆）。**优先级最高**——它在 Reduce Motion 之前裁决。
    case none

    /// 画，但钉在静止呈现上（Reduce Motion 的降级形态 2）。
    case resting

    /// 正常动。
    case animated
}

// MARK: - 能耗状态 / Energy state

/// 「注入值优先、否则从系统读」的解析结果，以及它推出的渲染策略。
public nonisolated struct EffectsEnergyState: Sendable, Equatable {

    /// 生效的场景阶段。
    public let scenePhase: ScenePhase

    /// 生效的能耗档位。
    public let powerMode: EffectsPowerMode

    public init(scenePhase: ScenePhase, powerMode: EffectsPowerMode) {
        self.scenePhase = scenePhase
        self.powerMode = powerMode
    }

    /// 当前状态下的渲染策略。
    ///
    /// ⚠️ **`.inactive` 也判 `.paused`**：`.inactive` 是 App 切换器 / 通知中心拉下 /
    /// 来电覆盖这类"用户看不到或看不清"的时刻，继续满帧跑一个装饰动画纯属白烧电。
    /// 这与"后台"在能耗上是同一类，故不为它单列第四档。
    public var policy: EffectsRenderPolicy {
        guard self.scenePhase == .active else { return .paused }
        return self.powerMode == .lowPower ? .reduced : .full
    }

    /// 两道闸的**唯一裁决点**：先 NFR-7 的能耗闸，再 Reduce Motion 闸。
    ///
    /// ⚠️⚠️ **顺序是承重的，且现在有机器判据**（理由见 `EffectsPresentation`）：
    /// 能耗闸写在前面的 `guard` 里 ⇒ `.none` 永远压过 `.resting`。
    /// 对调两行 ⇒ `EffectsEnergyStateTests.energyGateOutranksReduceMotion` 判红。
    ///
    /// 为什么是这个顺序而不是反过来：后台 / 非活跃时连**静态层**都不该画
    /// （一个像素都不画才叫"停摆"，NFR-7）；而 Reduce Motion 是 a11y 偏好，
    /// 它要求的是"别动"，不是"别显示"——前台时仍要留下静止呈现。
    /// 反过来写的话，开启「减弱动态效果」的用户恰好在系统规定该停摆的状态下
    /// 拿到一个还在跑透明度动画的装饰层。
    ///
    /// - Parameter reduceMotion: 调用点从 `\.accessibilityReduceMotion` 读到的值。
    ///   ⚠️ 作为参数传入而不是在这里读环境：本类型 `nonisolated`、且要能被单测直接调用
    ///   （同 `resolve(injectedScenePhase:systemScenePhase:injectedPowerMode:)` 的理由）。
    func presentation(reduceMotion: Bool) -> EffectsPresentation {
        guard self.policy.drawsAnything else { return .none }
        return reduceMotion ? .resting : .animated
    }

    /// 解析「注入值优先，否则从系统读」。
    ///
    /// - Parameters:
    ///   - injectedScenePhase: `\.effectsScenePhase` 的注入值；`nil` ⇒ 用 `systemScenePhase`。
    ///   - systemScenePhase: 宿主 `Scene` 供给的 `\.scenePhase`。
    ///   - injectedPowerMode: `\.effectsPowerMode` 的注入值；`nil` ⇒ 读 `ProcessInfo`。
    ///
    /// ⚠️ **`systemScenePhase` 是参数而不是在这里读环境**：本类型 `nonisolated`、
    /// 且要能被单测直接调用，读环境必须发生在 `View` 里。调用点见
    /// `ProcessingSweepDriver` / `ConfettiCore`。
    public static func resolve(
        injectedScenePhase: ScenePhase?,
        systemScenePhase: ScenePhase,
        injectedPowerMode: EffectsPowerMode?
    ) -> EffectsEnergyState {
        EffectsEnergyState(
            scenePhase: injectedScenePhase ?? systemScenePhase,
            powerMode: injectedPowerMode ?? EffectsPowerMode.current
        )
    }
}

// MARK: - 可注入的 EnvironmentValues 键 / Injectable environment keys

// ⚠️ **扩展本身刻意写成 `extension` 而不是 `public extension`**：后者会让成员上的
// `public` 变成"冗余修饰符"。实测得到的**原样是一条 `warning:`**
// （`'public' modifier is redundant for property declared in a public extension`），
// **只有带上 `-Xswiftc -warnings-as-errors` 时才升级成编译红**
// ——而本仓的本地验证与 `verification-before-completion` 恰好都带这个 flag，
// 所以在我们的工作流里它确实是"红"。不带 flag 时它只是一条警告，别把这句读成无条件的。
// 而这两个键的 `public` 是本 task 的承重契约，必须写在成员上、在 diff 里看得见
// ——本仓 `\.toastHost` 用的也是这个形态（`extension EnvironmentValues` + `@Entry public var`）。
extension EnvironmentValues {

    /// **可注入**的能耗档位。`nil`（默认）⇒ 从 `ProcessInfo` 读。
    ///
    /// ```swift
    /// // 测试 / 预览里伪造低电量：
    /// ScanningOverlay { card }.environment(\.effectsPowerMode, .lowPower)
    /// ```
    ///
    /// ⚠️ **显式 `public`，不靠 `public extension` 推导**：`@Entry` 宏展开时是否继承
    /// 外层扩展的访问级别是隐式行为（本仓 `\.toastHost` 已为同一件事显式标注过），
    /// 而 `shipswift-shaders` 的 B-2 要跨模块读这个键——推导一旦不成立，
    /// 断的是一条**跨 epic 契约**，且要等到另一个 epic 才会被发现。
    ///
    /// ⚠️ **默认值是 `nil` 而不是 `EffectsPowerMode.current`**：`nil` 的语义是
    /// "**没有人注入**"，与"注入了 `.standard`"必须可区分——后者是宿主 App 明确说
    /// "按常规供电渲染"（例如它自己订阅了 `NSProcessInfoPowerStateDidChange`），
    /// 不该被系统读数覆盖。真正的"从系统读"发生在 `EffectsEnergyState.resolve`。
    @Entry public var effectsPowerMode: EffectsPowerMode? = nil

    /// **可注入**的场景阶段。`nil`（默认）⇒ 从系统的 `\.scenePhase` 读。
    ///
    /// ```swift
    /// // 测试 / 预览里伪造"App 进了后台"：
    /// ScanningOverlay { card }.environment(\.effectsScenePhase, .background)
    /// ```
    ///
    /// ⚠️ **为什么不直接注入 SwiftUI 自己的 `\.scenePhase`**：那个键的语义是
    /// "宿主 Scene 现在处于哪个阶段"，覆盖它会连带影响调用方视图里**任何**读
    /// `\.scenePhase` 的代码（包括宿主自己的业务逻辑）。本库只想影响**自己的**
    /// 装饰层，故另开一个键、且默认让位给系统值。
    @Entry public var effectsScenePhase: ScenePhase? = nil
}
