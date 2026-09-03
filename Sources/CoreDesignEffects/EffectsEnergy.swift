//
//  EffectsEnergy.swift
//  CoreDesignEffects
//
//  NFR-7 能耗与生命周期：动效层的渲染策略（两个可注入键住在 CoreDesign）
//  / Effects-side render policy derived from CoreDesign's injectable energy keys.
//

import CoreDesign
import Foundation
import SwiftUI

// MARK: - 两个可注入键在哪 / Where the injectable keys live

// PRD 的 **NFR-7** 逐字要求：常驻渲染的效果（`colorEffect` 背景、Confetti、
// ScanningOverlay）必须**定义**并**可测**它们在 App 进入后台、以及低电量模式下的行为。
// ⚠️ 并且逐字写明「**不接受"或文档声明"**」——那会让这条退化成文档要求。
// 两个信号在单测里都不可直接切换（`ProcessInfo` 只读、`ImageRenderer` 下没有 `Scene`）
// ⇒ 必须有可注入的 `EnvironmentValues` 键。
//
// ⚠️ **那两个键不在本文件、也不在本 target**：`\.lowPowerModeOverride` 与
// `\.scenePhaseOverride` 住在 `CoreDesign`（`Environment/EnergySignalEnvironment.swift`），
// 因为它们是**任何**常驻渲染件都要的通用信号——理由见下面 `EffectsRenderPolicy`
// 的类型文档「S-2 已裁决」一节。本文件保留的是**动效层专用**的那一半：
// 把两个通用信号抬成语义档位（`EffectsPowerMode`）、再裁出渲染策略
// （`EffectsRenderPolicy`，含 `particleScale` 这类只有动效层认得的旋钮）。

// MARK: - 能耗档位 / Power mode

/// 设备的能耗档位（**动效层的语义分级**）。
///
/// ⚠️ **它不是那个可注入键的类型**：键是 `CoreDesign` 的 `\.lowPowerModeOverride`
/// （`Bool?`，形状跟着 `ProcessInfo.processInfo.isLowPowerModeEnabled` 走）。
/// 本枚举是本 target 在它上面包的一层——`EffectsPowerMode.lifted(from:)` 负责抬升。
/// 通用底座不该替所有消费者定义"档位"（`shipswift-shaders` 的 17 个 `colorEffect`
/// 只关心"要不要省电"，没有分级），而动效层这边确实要分级：`.reduced` 与 `.paused`
/// 的差别读作 `.lowPower` 比读作 `true` 说明了更多东西。
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
    /// `.environment(\.lowPowerModeOverride, true)` 注入——这也正是那个键存在的
    /// 第二个用途（第一个是可测）。
    public static var current: EffectsPowerMode {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? .lowPower : .standard
    }

    /// 把 `CoreDesign` 的通用键 `\.lowPowerModeOverride`（`Bool?`）抬成本层的语义档位。
    /// `nil`（没人注入）原样传下去 ⇒ 由 `EffectsEnergyState.resolve` 去读系统。
    ///
    /// ⚠️ **刻意 `internal`**：三个调用点（`ConfettiCore` / `ProcessingSweepDriver` /
    /// `ProcessingSweepBody`）都在本 target 内，没有跨模块消费者。
    /// 而它一旦 `public`，那个 `Bool?` 参数就从「public 属性只清点」的档
    /// （裁决 (d)）掉进「public 函数参数命中判据」的档
    /// （`BoolParameterScanner.collect(_:decl:modifiers:at:)`），要一条署名豁免并抬
    /// `docs/bool-exemptions-baseline.json` 的棘轮——为一个纯内部的抬升函数付这个价不值。
    static func lifted(from lowPowerModeOverride: Bool?) -> EffectsPowerMode? {
        lowPowerModeOverride.map { $0 ? .lowPower : .standard }
    }
}

// MARK: - 渲染策略 / Render policy

/// 常驻渲染件在当前能耗状态下**该画到什么程度**。
///
/// ⚠️ **这是一个纯函数的产物**（`EffectsEnergyState.policy`），不读任何全局状态
/// ——测试可以直接对它断言，不必先把 App 推进后台。
///
/// ## ✅ 已裁决（2026-09-04）：通用能耗信号下沉 `CoreDesign`，本类型留在 Effects
///
/// **裁决时点**：#252 / PR #269 第 1 轮终审提出 S-2，第 2 轮由用户拍板（2026-09-04），
/// 本轮（#269 后续提交）落地。
///
/// ### 当初记下的冲突（原样保留，不删成只剩结论）
///
/// 本枚举当时同时承担两件事：
/// · **通用**的能耗判定（`drawsAnything` / `minimumInterval`）——任何常驻渲染件都要；
/// · **effects 专用**的旋钮（`particleScale`、多半还有 `usesGlow`）——
///   `shipswift-shaders` 的 B-2 那 17 个 `colorEffect` 背景**没有粒子**，
///   `particleScale` 对它们毫无意义。
///
/// 冲突在于：B-2 若为了两个能耗键 `import CoreDesignEffects`，那么**只想要 shader
/// 的消费者也必须链上整个 Effects product**——而 `Package.swift` 拆 product 的
/// 逐字理由正是「只想要系统原生观感的消费者不必背上动效与图表」。两者直接抵触。
/// 且这是唯一一条**merge 后修改成本显著上升**的：两个键与本枚举都是 `public`，
/// 一旦 B-2 开始 `import` 它们，再搬就是下游可见的破坏性变更（改 import、改类型名）。
///
/// 当时列出的两条出路：
/// 1. **键下沉到 `CoreDesign`**：把两个键挪进 `CoreDesign`，Effects 侧再包一层自己的
///    策略（`particleScale` 之类留在这里）。代价：`CoreDesign` 长出一块与"系统原生观感"
///    无关的表面；收益：shaders 不必依赖 Effects。
/// 2. **明确接受「Shaders 依赖 Effects」**：把这条依赖写进 `Package.swift` 的拆分理由里
///    （即修正那句话的射程），不再假装两者可分。代价：product 拆分的卖点缩水。
///
/// ### 裁决内容与理由
///
/// **选出路 1，并把低电量键的类型定为 `Bool?`**：
/// · 两个键搬到 `CoreDesign/Environment/EnergySignalEnvironment.swift`，改名
///   `\.lowPowerModeOverride` / `\.scenePhaseOverride`（`effects` 前缀在通用底座上名实不符）；
/// · 理由：`Package.swift` 那句拆分承诺是**产品级**的，出路 2 等于用文字修正把它作废；
///   而出路 1 付出的"`CoreDesign` 新增表面"只有两个 `EnvironmentValues` 键，
///   **不含任何渲染策略**——通用底座只提供信号，不替消费者裁决画到什么程度。
/// · 低电量键用 `Bool` 而非枚举：在通用底座这一层它就是
///   `ProcessInfo.processInfo.isLowPowerModeEnabled` 的可注入镜像，形状本就是 `Bool`；
///   要分级的模块自己包一层（本 target 的 `EffectsPowerMode.lifted(from:)`）。
///
/// ### 落地后本类型的位置
///
/// 本枚举**继续住在 `CoreDesignEffects`**，只是它的输入改为**从 `CoreDesign` 的两个键派生**
/// （`EffectsEnergyState.resolve` ← `EffectsPowerMode.lifted(from:)` ← `\.lowPowerModeOverride`）。
/// `particleScale` / `usesGlow` 这类只有动效层认得的旋钮**没有下沉**——这正是
/// 出路 1 里「Effects 侧再包一层策略」那句话的落点。
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
/// 判据只需一行 `#expect(… .presentation(reduceMotion: true) == .none)`。
/// 这与本仓「纯函数 + 生产代码与判据共用同一份」的既有纪律一致
/// （`ConfettiBurst` / `ProcessingSweep` 都是这个形态）。
///
/// ⚠️⚠️ **这条纯函数判据的射程只到函数体内，"让它不可能被重新引入"是过头话**
/// （#252 PR #269 第 2 轮终审 I-A；上一版这里逐字写着那句话，现按实际射程改写）。
///
/// 它钉死的是「给定 `scenePhase` 与 `reduceMotion`，**这个函数**返回什么」。
/// **调用点是否真的用这个结论**是另一条链——`ConfettiCore` / `ProcessingSweepDriver`
/// 各有一行把 `\.accessibilityReduceMotion` 喂进来，那一行此前**零覆盖**：
/// · 位图路不可能覆盖：该环境键不可注入，测试里恒为 `false`，
///   「读 `presentation`」与「自己再读一遍 `reduceMotion`」两种写法渲染**逐字节相同**；
/// · 当时的三条字符串守卫（`timelineOnlyExistsDuringBurst` /
///   `reduceMotionFallsBackToStaticCelebration` / `MicroInteractionReduceMotionGuard`）
///   终审逐条实测：变异后**全绿**。
/// ⇒ 把调用点改回 `let isReduced = self.reduceMotion`，**I-1 原封不动回来而全套测试仍绿**。
///
/// ⇒ 调用点那一环现由源码判据接管：
/// `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`
/// ——凡走能耗闸的文件（名单 `energyGatedFiles` 与实际双向差集），
/// `self.reduceMotion` 的出现次数必须恰好等于喂给 `presentation(reduceMotion:)` 的次数。
/// **两条判据合起来才覆盖「顺序」这件事**：纯函数管函数体，源码判据管调用点。
///
/// ⚠️ **为什么不走位图判据**：`\.accessibilityReduceMotion` **不可注入**
/// （`EnvironmentValues` 上它是只读的系统偏好，写它编译红——终审已实测）。
/// ⇒ "RM 开启 × 后台"这个组合在 `ImageRenderer` 下根本构造不出来，纯函数是唯一可行路径。
///
/// ⚠️ **刻意 `internal`**：本类型只服务同模块的两个调用点，没有跨模块消费者；
/// 而 `presentation(reduceMotion:)` 一旦 `public`，那个裸 `Bool` 参数就会命中
/// `BoolExemptionGuard` 的判据、要求一条署名豁免并抬棘轮基线
/// （`CoreDesignEffects` 当前是 0 条，见 `docs/bool-exemptions-baseline.json`）。
/// ⚠️ 本轮把低电量键改成 `Bool?` 之后这条**重新核过、结论不变**：改的是
/// `EnvironmentValues` 上的一个 public **属性**，走裁决 (d)「只清点、不判据」；
/// 而 `presentation(reduceMotion:)` 是**函数参数**，走的是另一条判据。两者不互相牵动。
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
    ///   - injectedScenePhase: `CoreDesign` 的 `\.scenePhaseOverride` 注入值；
    ///     `nil` ⇒ 用 `systemScenePhase`。
    ///   - systemScenePhase: 宿主 `Scene` 供给的 `\.scenePhase`。
    ///   - injectedPowerMode: 由 `CoreDesign` 的 `\.lowPowerModeOverride`（`Bool?`）
    ///     经 `EffectsPowerMode.lifted(from:)` 抬上来的档位；`nil` ⇒ 读 `ProcessInfo`。
    ///     ⚠️ 本参数保持**枚举**而不是跟着键改成 `Bool?`：它是本 target 的语义面，
    ///     `Bool?` 的通用形状只活在 `CoreDesign` 的键上（见 `EffectsPowerMode` 的类型文档）。
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
