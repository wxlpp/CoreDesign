// ⚠️⚠️ **本 target 只接 `CoreDesign` 一个 product——这是承重的，别加依赖、别加文件 import。**
//
// `\.lowPowerModeOverride` / `\.scenePhaseOverride` 是 NFR-7 的两个可注入能耗信号
// （Issue #252）。它们本来住在 `CoreDesignEffects`，PR #269 终审 S-2 裁决后**下沉到
// `CoreDesign`**，理由是 `shipswift-shaders` 的 B-2（17 个 `colorEffect` 背景）也要读
// 它们，而键留在 Effects 会逼「只想要 shader 的消费者」链上整个 Effects product。
//
// ⇒ 这条裁决要换来的东西，逐字就是「**`import CoreDesign` 就够**」，而本 target
// 编译得过**就是**那句话的机器判据：把两个键搬回 `CoreDesignEffects`，库自身的
// `swift build` / `swift test` 全绿，只有这里会红
// （`cannot find 'lowPowerModeOverride' in scope`，写侧读侧各一处）。
//
// ⚠️ **为什么这必须是独立 target，而不是 `DownstreamProbe` 里一个"只写 `import
// CoreDesign`"的文件**——**变异实证现场抓到的**，不是预防性设计：初版正是那个形态，
// 而"键搬回 Effects"那枚变异让 probe **照样全绿**。Swift 对**扩展成员**的名字查找是
// **逐模块**的：同 target 里只要有**任何一个文件** `import CoreDesignEffects`
// （`PublicVisibility.swift` 就是），该模块挂在 `EnvironmentValues` 上的成员在同 target
// 的其它文件里也可见，哪怕那个文件自己没 import 它。文件级 import 隔离对扩展成员不成立。
//
// ⚠️ 它同时仍是那条 `public` 契约的跨模块证明：`@Entry` 宏展开时**默认不继承 `public`**。
//（下沉之后这条已不再是 probe 独有：键与它在 `CoreDesignEffects` 的消费点现在隔着模块
// 边界，去掉 `public` 连 `swift build` 都红——实测报
// `'lowPowerModeOverride' is inaccessible due to 'internal' protection level`。
// 契约因此变成两道，而不是一道；本文件守的是**对外产品面**那道。）
//
// ⚠️ **写侧与读侧都要覆盖，且都不能退化成"可见性摆设"**：
// · 写侧走 `.environment(\.key, value)` ⇒ 它要 `WritableKeyPath`，
//   于是 **setter** 也必须 public，光有 getter 编译不过；
// · 读侧把值 `return` 出去、并写死返回类型 `(Bool?, ScenePhase?)` ⇒ 类型推断绕不开，
//   键的类型改了这里就红。只"读一下丢掉"是证不到类型的。
//
// ⚠️ 这些函数必须 `@MainActor`——`EnvironmentValues` 的这两个访问器落在 `CoreDesign`
// 的 `defaultIsolation(MainActor.self)` 上（同 `DownstreamProbe/PublicVisibility.swift`
// 里其余 View / modifier；本 target 属于**可见性**那一侧，不是隔离那一侧）。

import CoreDesign
import SwiftUI

@MainActor
func injectEnergySignalEnvironment() -> some View {
    Text("content")
        .environment(\.lowPowerModeOverride, true)
        .environment(\.scenePhaseOverride, .background)
}

@MainActor
func readEnergySignalEnvironment(_ values: EnvironmentValues) -> (Bool?, ScenePhase?) {
    (values.lowPowerModeOverride, values.scenePhaseOverride)
}
