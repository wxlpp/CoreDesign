import CoreDesign
import SwiftUI

// `CoreDesignEffects` 在 NFR-7 通用策略表之上加的**effects 专用**旋钮（`#271`）。
//
// ⚠️ **通用部分已下沉到 `CoreDesign`**（`Environment/EnergyPolicy.swift`）：
// `RenderPolicy` / `EnergyState` / `MotionPresentation` 与 `resolve(...)`。
// 本文件只留「离屏模糊」「粒子数」这两个 effects 独有的概念，以及自转专用的退化保护。
//
// ⚠️ **`EffectsPowerMode` 已删除**（`#271`，用户裁决）：它在整个 target 里只剩一个
// 语义消费点，下沉后那个点也改用 `Bool` ⇒ 没有任何代码读它的 case。边界改用
// `Bool`（`ProcessInfo.isLowPowerModeEnabled` 的形状本来就是 `Bool`），
// 三个 `Bool` 参数各有一条署名豁免，见 `docs/bool-exemptions.json`。
//
// ⚠️ **本文件的 extension 成员必须逐个显式 `nonisolated`**：本 target 开了
// `.defaultIsolation(MainActor.self)`，而它**确实**作用于「同包内类型的扩展」
//（`CLAUDE.md` 里「往 `public extension Color` 加常量不带 `@MainActor`」讲的是**外来模块**
// 类型的扩展，不是同一回事）。
// ⚠️ 漏标**不会**让下游编译红 —— 编译器只在同模块有 nonisolated 读者时才红。
// 这条由 `ExtensionIsolationGuard.pinnedExtensionMembersAreExplicitlyNonisolated` 守，
// 理由见那个文件头；新增成员必须去那张名单登记。

public extension RenderPolicy {

    /// 是否使用离屏模糊做光晕。
    ///
    /// ⚠️ 这是**低电量下唯一在静态位图上可观测**的差异，因此也是 NFR-7
    /// 「注入伪值断言渲染行为」这条 AC 在低电量方向的判据落点：降帧本身拍不进静态帧
    ///（`ImageRenderer` 拍的是一帧），而「有没有那圈模糊」拍得到。
    nonisolated var usesGlow: Bool { self == .full }

    /// 粒子数量的缩放系数。低电量下少放一半，停摆时一个不放。
    nonisolated var particleScale: Double {
        switch self {
        case .full: 1
        case .reduced: 0.5
        case .paused: 0
        }
    }
}

public extension MotionPresentation {

    /// 自转周期退化（非有限、或 `<= 0`）时把「正常动」降级为「静止」。
    ///
    /// ⚠️ 只有自转类效果需要它：周期为 0 会让相位计算除零 / 恒定跳变。
    /// 非自转的效果不该调它 —— 它们没有「周期」这个概念。
    nonisolated func frozenIfPeriodIsDegenerate(_ rotationPeriod: Double) -> MotionPresentation {
        // ⚠️ **判据必须是 `!(isFinite && > 0)` 而不是 `<= 0`**：`nan` 对两个比较
        // **都为假**，写成 `<= 0` 会让 `nan` 从退化保护里漏过去。
        guard self == .animated, !(rotationPeriod.isFinite && rotationPeriod > 0) else { return self }
        return .resting
    }
}
