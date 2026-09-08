import OhMyDesign
import SwiftUI

// `#271` 下沉的 NFR-7 通用能耗策略表，在**只链 `OhMyDesign`** 的语境下的消费证明。
//
// ⚠️⚠️ **本文件必须住在 `OhMyDesignOnlyProbe` 这个 target，不能放进 `DownstreamProbe`**。
// 理由与同 target 的 `EnergySignalEnvironment.swift` 一致，且那条是**变异实证现场抓到的**：
// Swift 对**扩展成员**的名字查找是**逐模块**而不是逐文件的 —— 只要同一个 target 里
// 任何一个文件 `import OhMyDesignEffects`，该模块挂的成员在同 target 的其它文件里
// **也可见**，哪怕那个文件自己没 import 它。⇒ 文件级的 import 隔离对扩展成员不成立，
// **只有 target 边界才成立**。放错地方 ⇒ 把策略表搬回 Effects 时 probe 照样全绿。
//
// ⚠️ **别读成"三个类型的 `nonisolated` 都靠本 probe"**：去掉 `RenderPolicy` /
// `MotionPresentation` 的 ⇒ 库 `swift build` 当场红（`[#IsolatedConformances]`）；
// 只有 `EnergyState` 是「库绿、本文件红」（它没有同模块的 nonisolated `==` 读者）。
// 本 probe 的**共同**增量是「不靠 `@testable`、只链 product 也拿得到」⇒ 证 `public`。

nonisolated func consumeRenderPolicyGenericKnobs() -> (Bool, Double?) {
    let policy = RenderPolicy.reduced
    return (policy.drawsAnything, policy.minimumInterval)
}

nonisolated func consumeEnergyStateResolve() -> RenderPolicy {
    EnergyState.resolve(
        injectedScenePhase: nil,
        systemScenePhase: .active,
        lowPowerModeOverride: nil
    ).policy
}

/// ⚠️ 这一条钉的是「`nil` 与 `false` 可区分」：`Bool?` 的形状若被收成 `Bool`，本行不编译。
nonisolated func consumeExplicitFalseInjection() -> Bool {
    EnergyState.resolve(
        injectedScenePhase: .active,
        systemScenePhase: .active,
        lowPowerModeOverride: false
    ).isLowPower
}

nonisolated func consumeMotionPresentation() -> MotionPresentation {
    EnergyState(scenePhase: .active, isLowPower: false).presentation(reduceMotion: true)
}

/// ⚠️ 逐 case 列举：`MotionPresentation` 少一个 case 或改名，本行不编译。
nonisolated func consumeMotionPresentationCases() -> [MotionPresentation] {
    [.hidden, .resting, .animated]
}
