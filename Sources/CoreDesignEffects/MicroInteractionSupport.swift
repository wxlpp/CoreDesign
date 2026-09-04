//
//  MicroInteractionSupport.swift
//  CoreDesignEffects
//
//  微交互的公共约定 / Shared conventions for micro-interactions.
//

import CoreDesign
import SwiftUI

// MARK: - 强度档位

/// 微交互的强度。**所有**微交互共用这一个枚举。
///
/// ⚠️ 不暴露"位移像素数""旋转角度"这类裸数值——本仓的调参惯例是语义档位单一来源
/// （对照 `ButtonRoleStyleRole`：role 调色板的唯一来源，新增 role 扩枚举而不是各自定义）。
/// ⚠️⚠️ **`nonisolated` 是必需的、不是装饰**（`#256` probe 补齐调用点时炸出来的）：
/// 本 target 开了 `.defaultIsolation(MainActor.self)` ⇒ 不标它，这个枚举**派生的
/// `Equatable` 一致性**是 MainActor 隔离的，下游从 nonisolated 上下文写
/// `strength == .regular` 会拿到**硬 error**（不是 warning，实测原文照录）：
///
///     error: main actor-isolated conformance of 'MicroInteractionStrength' to 'Equatable'
///            cannot be used in nonisolated context [#IsolatedConformances]
///
/// 而库自身的 `swift build` / `swift test` 全跑在被隔离的 target **内部**，全绿
/// —— 这条只有 `scripts/downstream-probe` 看得见。判据在
/// `EffectsNonisolatedUsage.swift` 的 `readMicroInteractionStrengths()`。
/// 与 `TransitionTravel` / `TransitionAxis3D`（#267 已标）同一形态。
public nonisolated enum MicroInteractionStrength: Sendable, CaseIterable {
    case subtle, regular, pronounced

    /// 位移类效果的振幅（pt）。
    var displacement: CGFloat {
        switch self {
        case .subtle: 4
        case .regular: 9
        case .pronounced: 16
        }
    }

    /// 缩放类效果的形变量（1.0 = 不变）。
    var scaleDelta: CGFloat {
        switch self {
        case .subtle: 0.06
        case .regular: 0.14
        case .pronounced: 0.24
        }
    }

    /// 粒子类效果的数量。
    var particleCount: Int {
        switch self {
        case .subtle: 6
        case .regular: 12
        case .pronounced: 22
        }
    }
}

// MARK: - TriggerRelay

/// 把**泛型的 trigger** 转成一个非泛型的自增计数，供内层动画 modifier 使用。
///
/// ⚠️ **这是为了让公开签名保持 `some Equatable`（与 SwiftUI 自己的
/// `keyframeAnimator(trigger:)` 一致），而不必要求调用方的 trigger 是 `Sendable`。**
///
/// 初版直接把泛型 `T` 传进动画 modifier，于是 `keyframeAnimator` 的
/// `PlaceholderContentView<XModifier<T>>` 依赖 `T`，报
/// `capture of non-Sendable type 'T.Type' in an isolated closure`（10 条）。
/// 当时的处置是给 `T` 加 `Sendable` 约束——**那个处置是错的**：
///
/// ⚠️ **「下游 App 通常不设 `defaultIsolation`」这个前提不成立** ——
/// Xcode 26 新建工程模板默认 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，
/// 而本库面向 iOS 26+。新项目里任何 `enum Step: Equatable` 当 trigger 都会撞上
/// `main actor-isolated conformance ... cannot satisfy ... 'Sendable'`。
/// 这不是"本包测试 target 的私事"。
///
/// ⇒ 改为**泛型只停在本类型**：外层拿 trigger 记计数，内层动画 modifier 非泛型
/// （只吃 `Int`），警告消失、公开签名不必加 `Sendable`。
/// 代价是每个效果多一个 `@State` + 一次 `onChange`。
struct TriggerRelay<T: Equatable, Core: ViewModifier>: ViewModifier {
    let trigger: T
    let makeCore: (Int) -> Core

    @State private var fire = 0

    func body(content: Content) -> some View {
        content
            .modifier(self.makeCore(self.fire))
            // ⚠️ `&+=` 而非 `+=`：长会话里理论上会溢出，溢出崩比动画少放一次糟得多。
            .onChange(of: self.trigger) { self.fire &+= 1 }
    }
}

// MARK: - ⚠️ 写微交互前必读：隔离约束

// 1. **`keyframeAnimator` / `phaseAnimator` 的 body 闭包是 `@Sendable`（nonisolated）**。
//    本包开了 `.defaultIsolation(MainActor.self)`，所以在闭包里读 `@Environment` 属性
//    （如 `self.reduceMotion`）会报
//    `main actor-isolated property ... can not be referenced from a Sendable closure`。
//    ⇒ **在 `body` 里先取成局部 `let`，再捕获进闭包。**
//
// 2. **泛型只停在 `TriggerRelay`，动画 modifier 一律非泛型（只吃 `Int`）**。
//    直接把泛型 `T` 传进动画 modifier 会报
//    `capture of non-Sendable type 'T.Type' in an isolated closure`（实测 10 条），
//    触发点是 `keyframeAnimator` 的 `PlaceholderContentView<XModifier<T>>` 依赖 `T`
//    ——**与 trigger 本身是不是 Sendable 无关**。见 `TriggerRelay` 的文档。
//
// ⚠️ 这两条是**同一类问题**：本包的 `defaultIsolation` 让"闭包里随手读 self"变成一个
// 反复出现的坑。⚠️ 初版这里写的是「与 `CoreDesignShaders` 踩到的是同一类问题」——
// **那是一句过去时陈述，而当时 `CoreDesignShaders` 这个 target 还不存在**
//（它在另一个 epic 里、尚未合入）。改为不指名的同族描述。

// MARK: - Reduce Motion 降级

extension View {

    /// Reduce Motion 开启时把**位移 / 旋转 / 缩放**换成一次不移动的透明度脉冲。
    ///
    /// ⚠️ **降级不是"什么都不做"**：微交互承载的是"这件事发生了"这个信息，
    /// 直接抹掉会让开启该偏好的用户收不到反馈。⇒ 保留"有反馈"，去掉"有运动"（FR-11）。
    ///
    /// ⚠️ 本仓的降级基线由此统一。各效果**不要**各自实现降级路径——那样必然漂移。
    ///
    /// ## 两种被批准的降级形态（终审 I-2：初版同一个 commit 里有四种走法）
    ///
    /// - **形态 1（默认）**：调用本函数，把运动换成一次透明度脉冲。
    ///   `Shake` / `Jump` / `Spin`（逐表达式门控 + 链尾调用）与
    ///   `Spray` / `Shine` / `Ping`（早退整层装饰 + 调用）都走这条。
    /// - **形态 2（保留"长什么样"、只去掉运动）**：不叠脉冲——叠了就是两次反馈。
    ///   `Rise`（"+1 上浮"）保留淡入淡出、把位移换成**静止位移**；
    ///   `Confetti` 降级为**一次淡入淡出的静态庆祝层**（`#252` AC 逐字，且明写"不是 no-op"）；
    ///   `ProcessingSweep`（`ScanningOverlay` / `GlowSweep` / `LightSweep`）把相位钉在
    ///   `ProcessingSweep.restingPhase` 上静止呈现——它们是**常驻状态呈现**、没有 trigger，
    ///   而 `OpacityPulse` 是 trigger 驱动的一次性反馈，形态上对不上。
    ///   ⚠️ **名单从 1 个长到 3 个不等于形态 2 被放宽**：它的判据始终是那两句
    ///   （保留呈现、去掉运动、不叠脉冲），且由下面那条双向差集守着。
    ///
    /// ⚠️ **形态 2 的门禁是集中豁免名单，不是文件内标记**（#262 第 2 轮 review 纠正
    /// 本段失真）：本段初版写「走形态 2 的文件必须带一行 `// RM-FORM-2:` 标记，
    /// 守卫按此放行」——那是第 3 轮终审 I-5 **之前**的形态，早已被铲掉。
    /// 理由：自证标记长在被审对象自己的文件里，任何人加一行注释即可放行，
    /// 评审时没有集中位置能看见「谁又新领了一张豁免」；而守卫的 `stripComments`
    /// 现在会先把 `//` 行注释整段剥掉，**那行标记连被读到的机会都没有**。
    ///
    /// 现状：真正的门禁是 `MicroInteractionReduceMotionGuard.approvedFormTwo`
    /// （测试 target 里的集中名单，`#252` 起是
    /// `["Rise.swift", "Confetti.swift", "ProcessingSweep.swift"]`），并由
    /// `formTwoListMatchesReality` 做**双向差集**——名单里有而文件没走形态 2、
    /// 或文件走了形态 2 而不在名单里，两个方向都判红。
    /// ⇒ 新领一张形态 2 豁免必须改那份名单，在 diff 里必然可见。
    /// `Rise.swift` 里那行 `// RM-FORM-2:` 只是给人读的理由说明，**不构成放行条件**。
    ///
    /// ⚠️ **不写第三种**。初版的第四种走法（部分门控、无降级）已按 I-1 修掉——
    /// 那不是一种形态，是漏。
    @ViewBuilder
    func reduceMotionFallback(active: Bool, trigger: Int) -> some View {
        if active {
            self.modifier(OpacityPulse(trigger: trigger))
        } else {
            self
        }
    }
}

/// Reduce Motion 下的统一降级形态：一次快速的透明度脉冲。
private struct OpacityPulse: ViewModifier {
    /// ⚠️ 只吃 `Int`（`TriggerRelay` 的计数）——泛型只停在 `TriggerRelay`。
    let trigger: Int

    func body(content: Content) -> some View {
        content.phaseAnimator([1.0, 0.45, 1.0], trigger: self.trigger) { view, opacity in
            view.opacity(opacity)
        } animation: { _ in
            .easeInOut(duration: 0.12)
        }
    }
}
