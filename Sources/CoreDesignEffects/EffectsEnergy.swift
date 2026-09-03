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
// 本仓有 Bool 纪律（`BoolExemptionGuard` + `docs/bool-exemptions.json`，公约「配置开关
// 的替代路径」），公开 API 上的裸 `Bool` 参数要带署名理由抬棘轮基线。
// 而这里本来就有比 `Bool` 更好的形状：`EffectsPowerMode` 是一个**语义档位**，
// 将来若要加"极省电"这类第三档，enum 直接扩，`Bool` 就得改签名。
// ⇒ 键的类型是 `EffectsPowerMode?` 而不是 `Bool?`。
// NFR-7 只要求"可注入 + 默认从系统读"，没有规定键的类型。

// MARK: - 能耗档位 / Power mode

/// 设备的能耗档位。`nil` 注入值 ⇒ 从 `ProcessInfo` 读（见 `EffectsEnergyState.resolve`）。
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
// `public` 变成"冗余修饰符"，在 `-Xswiftc -warnings-as-errors` 下**直接编译红**
// （实测：`error: 'public' modifier is redundant for property declared in a public extension`）。
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
