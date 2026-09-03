// ⚠️⚠️ **本文件刻意只 `import CoreDesign`（外加 SwiftUI）——这是承重的，别加 import。**
//
// `\.lowPowerModeOverride` / `\.scenePhaseOverride` 是 NFR-7 的两个可注入能耗信号
// （Issue #252）。它们本来住在 `CoreDesignEffects`，PR #269 终审 S-2 裁决后**下沉到
// `CoreDesign`**，理由是 `shipswift-shaders` 的 B-2（17 个 `colorEffect` 背景）也要读
// 它们，而键留在 Effects 会逼「只想要 shader 的消费者」链上整个 Effects product。
//
// ⇒ 这条裁决要换来的东西，逐字就是「**`import CoreDesign` 就够**」。
// Swift 的 import 是**逐文件**的：同 target 的 `PublicVisibility.swift` 顶上写了
// `import CoreDesignEffects`，对本文件一个符号都不泄漏。所以本文件编译得过
// **就是**那句话的机器判据；哪天有人把键搬回 Effects，本文件当场
// `cannot find 'lowPowerModeOverride' in scope`。
//
// ⚠️ 同时它仍是那条 `public` 契约的唯一跨模块证明：`@Entry` 宏展开时**默认不继承
// `public`**，而库内断言证不了这一条——internal 在同模块内一样能过。
// 去掉任一成员上的 `public`，库自身的 `swift build` / `swift test` **全绿**，
// 只有这里会红：`error: 'lowPowerModeOverride' is inaccessible due to 'internal'
// protection level`。
//
// ⚠️ **写侧与读侧都要覆盖，且都不能退化成"可见性摆设"**：
// · 写侧走 `.environment(\.key, value)` ⇒ 它要 `WritableKeyPath`，
//   于是 **setter** 也必须 public，光有 getter 编译不过；
// · 读侧把值 `return` 出去、并写死返回类型 `(Bool?, ScenePhase?)` ⇒ 类型推断绕不开，
//   键的类型改了这里就红。只"读一下丢掉"是证不到类型的。
//
// ⚠️ 这些函数必须 `@MainActor`——`EnvironmentValues` 的这两个访问器落在 `CoreDesign`
// 的 `defaultIsolation(MainActor.self)` 上（与 `PublicVisibility.swift` 里其余
// View / modifier 同类，见那边文件头的分工说明；本文件属于**可见性**那一侧）。

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
