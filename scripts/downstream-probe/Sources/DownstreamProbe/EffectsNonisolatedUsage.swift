import CoreDesignEffects
import SwiftUI

// `CoreDesignEffects` 的 nonisolated 消费面（#247 建结构）。
//
// ⚠️ **本文件目前只有模块标识这一条**——`CoreDesignEffects` 现在是**骨架 target**
// （#245 建，不含任何组件）。36 个动效 API 落地后，**由 `shipswift-effects` 的 A-7
// 按 API 单位清单逐个补齐调用点**。
//
// ⚠️ **A-7 的验收措辞不要写成「覆盖全部**公开**值类型」**——那是自指的：漏写
// `public` 的类型压根不算「公开」，probe 自然不覆盖它，`FR-5` 就没人查。
// **按 API 单位清单点名。**
//
//  ⚠️ **A-7 补调用点时必须按类型形态分流**（#260 终审 Important-2）——不是所有 API 单位
//  都能进本文件：
//
//  | 类型形态 | 落哪 | 为什么 |
//  |---|---|---|
//  | 值类型 / 配置类型 / 数据入参（枚举、struct 参数、图表数据点…） | **本文件**（`nonisolated func`） | 它们是调用方在自己模型层构造的东西，被 `MainActor` 隔离会让下游在后台线程准备数据时用不了——**这只有本 probe 看得见** |
//  | `View` struct / `public extension View` 的 modifier / style | **`PublicVisibility.swift`**（`@MainActor func`） | 本包开了 `.defaultIsolation(MainActor.self)`，View 的 `init` 与 modifier 函数**天然是 MainActor 隔离的**；从 `nonisolated func` 里构造它们必然编译失败，除非给所有 View init 标 `nonisolated`——**那不是我们要的契约** |
//
//  ⇒ 「按 API 单位清单点名」的意思是：**每个单位在这两个文件之一必有引用**，
//  不是"全部塞进本文件"。`PublicVisibility.swift` 的文件头已经写明了这个分工
//  （那边守**可见性**、这边守**隔离**）。
//
//  ⚠️ **"漏 `public` 会在这里炸出来"只覆盖类型名与被实际构造的 `init`**——
//  `body` 漏 `public` 不影响下游把它当 View 用，probe 结构上抓不到。
//  那一条靠 `scripts/api-surface-diff.sh` 或别的守卫。

nonisolated func readEffectsModuleName() -> String {
    CoreDesignEffects.moduleName
}

// MARK: - NFR-7 的能耗值类型（Issue #252）
//
// ⚠️ 这三个类型走**本文件**而不是 `PublicVisibility.swift`，按文件头的分流表：
// 它们是**值类型 / 配置类型**——`shipswift-shaders` 的 17 个 `colorEffect` 会在
// 渲染参数准备阶段用它们，而那段代码不一定跑在 `MainActor` 上。
// 若哪天有人把 `EffectsEnergyState` 上的 `nonisolated` 拿掉，本函数当场编译红
// （`main actor-isolated ... can not be referenced from a nonisolated context`）。

nonisolated func resolveEffectsRenderPolicy() -> EffectsRenderPolicy {
    EffectsEnergyState.resolve(
        injectedScenePhase: nil,
        systemScenePhase: .active,
        injectedPowerMode: EffectsPowerMode.current
    ).policy
}

nonisolated func readEffectsPolicyKnobs() -> (Bool, Bool, Double?, Double) {
    let policy = EffectsRenderPolicy.reduced
    return (policy.drawsAnything, policy.usesGlow, policy.minimumInterval, policy.particleScale)
}
