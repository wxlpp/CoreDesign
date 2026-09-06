import SwiftUI

// NFR-7 的**通用**能耗策略表（`#271` 下沉）。
//
// ⚠️ **为什么住在 `CoreDesign` 而不是 `CoreDesignEffects`**：原裁决理由逐字是
// 「别让只想要 shader 的消费者链上整个 `CoreDesignEffects` product」。`#252` 只把两个
// **信号键**（`\.lowPowerModeOverride` / `\.scenePhaseOverride`）下沉了，而从信号推出
// 「画不画 / 降不降帧」的那半张表仍在 Effects ⇒ `shipswift-shaders` 的 B-2 要么
// `import CoreDesignEffects`（推翻下沉的全部理由），要么自己把同一条映射再写一遍
//（本仓反复在堵的「两处各写一遍必然漂」）。⇒ 通用部分整体下沉。
//
// ⚠️ **边界用 `Bool` 而不是档位枚举**：`#252` 的裁决逐字是「键用 `Bool`」，而
// `ProcessInfo.isLowPowerModeEnabled` 的形状本来就是 `Bool`。在基座凭空造一个二态枚举
// 会命中公约第 3 节「两 case enum = 头号换皮反例」，且没有第二个消费者读它的 case
//（`#271` 落地前的 `EffectsPowerMode` 实测只剩一个语义消费点，已随本次删除）。
// ⇒ 代价是三个 `Bool` 参数各需一条署名豁免，逐条记在 `docs/bool-exemptions.json`。

/// 一层常驻渲染件在当前能耗状态下的渲染策略。
///
/// ⚠️ `nonisolated`：本包三个 target 都开了 `.defaultIsolation(MainActor.self)`，不标的话
/// 下游 **nonisolated 上下文**（在后台线程准备渲染参数的宿主代码）用不了它
/// —— 那是 `scripts/downstream-probe` 的 `CoreDesignOnlyProbe` 唯一能看见的那类问题。
public nonisolated enum RenderPolicy: Sendable, Equatable, CaseIterable {

    /// 满帧。
    case full

    /// 降帧，但**仍然在动**。
    case reduced

    /// 完全停摆：驱动动画的 `TimelineView` **不建**（不是「建了但暂停」）。
    case paused

    /// 是否还要画装饰层。`false` ⇒ 调用方应当**整层不建**。
    ///
    /// ⚠️ 命名是「draws**Anything**」而不是「isPaused」：调用点读起来是
    /// `guard policy.drawsAnything else { return AnyView(content) }`，
    /// 意思正好是「这一层一个像素都不画」。
    public var drawsAnything: Bool { self != .paused }

    /// 交给 `TimelineSchedule.animation(minimumInterval:)` 的最小间隔。
    /// `nil` ⇒ 跟随显示器刷新率。
    ///
    /// ⚠️ **15 fps 是本仓自选的降帧档，没有上游口径**（`#271` 实查：PRD 的 NFR-7 只写
    /// 「暂停渲染 / 降帧」，全仓 grep `1.0 / 15` 在 prds 与各 epic 下 0 命中）
    /// —— 别去找一条不存在的条款。
    public var minimumInterval: Double? { self == .reduced ? 1.0 / 15.0 : nil }
}

/// 「注入值优先、否则从系统读」的解析结果，以及它推出的渲染策略。
public nonisolated struct EnergyState: Sendable, Equatable {

    /// 生效的场景阶段。
    public let scenePhase: ScenePhase

    /// 生效的低电量状态。
    public let isLowPower: Bool

    public init(scenePhase: ScenePhase, isLowPower: Bool) {
        self.scenePhase = scenePhase
        self.isLowPower = isLowPower
    }

    /// 当前状态下的渲染策略。
    ///
    /// ⚠️ **`.inactive` 也判 `.paused`**，而这条限度**对所有消费者成立**（`#271`）——
    /// 不再是「effects 的小装饰可接受」那个较窄的记账：
    ///
    /// - **macOS**：`WindowGroup` 在 App 不是前台时即报 `.inactive`，窗口照常显示
    ///   ⇒ 用户点一下别的 App，接了本闸的层**当场从可见窗口里消失**，切回来又出现；
    /// - **iPadOS 多任务 / 台前调度**：完全可见但非聚焦的 App 同样是 `.inactive`。
    ///
    /// ⇒ 对**整块背景面**（`AnimatedMeshGradient`，以及将来的 shader 背景）它意味着
    /// 失焦时底色消失。**是否为此增设「停摆但保留静止帧」第四档，是独立裁决**
    /// —— 给本枚举加 case 是源码破坏（会打断下游 exhaustive switch），`#271` 有意不做。
    public var policy: RenderPolicy {
        guard self.scenePhase == .active else { return .paused }
        return self.isLowPower ? .reduced : .full
    }

    /// 解析「注入值优先，否则从系统读」。
    ///
    /// - Parameters:
    ///   - injectedScenePhase: `\.scenePhaseOverride` 的注入值；`nil` ⇒ 用 `systemScenePhase`。
    ///   - systemScenePhase: 宿主 `Scene` 供给的 `\.scenePhase`。
    ///   - lowPowerModeOverride: `\.lowPowerModeOverride` 的注入值；`nil` ⇒ 读 `ProcessInfo`。
    ///     ⚠️ **`nil` 与 `false` 必须可区分**：`false` 是「有人明确注入了『不低电量』」，
    ///     `nil` 才是「没人注入、去问系统」。这正是那个键是 `Bool?` 而不是 `Bool` 的理由。
    ///
    /// ⚠️ **`systemScenePhase` 是参数而不是在这里读环境**：本类型 `nonisolated`、
    /// 且要能被单测直接调用，读环境必须发生在 `View` 里。
    ///
    /// ⚠️ **已知限度：读系统那一路不是响应式的**。`ProcessInfo` 的低电量变化会发
    /// `NSProcessInfoPowerStateDidChange`，但环境默认值只在被读取时求值一次。
    /// 需要「用户中途打开低电量就立刻降级」的宿主，应自己订阅该通知并注入
    /// `.environment(\.lowPowerModeOverride, true)` —— 那也正是这个键存在的第二个用途。
    public static func resolve(
        injectedScenePhase: ScenePhase?,
        systemScenePhase: ScenePhase,
        lowPowerModeOverride: Bool?
    ) -> EnergyState {
        EnergyState(
            scenePhase: injectedScenePhase ?? systemScenePhase,
            isLowPower: lowPowerModeOverride ?? ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}

/// 两道闸（NFR-7 能耗闸 + Reduce Motion 闸）**一起**裁出来的结果：这一层到底呈现什么。
public nonisolated enum MotionPresentation: Sendable, Equatable, CaseIterable {

    /// 一个像素都不画（NFR-7 停摆）。**优先级最高**——它在 Reduce Motion 之前裁决。
    ///
    /// ⚠️ **「一个像素」指的是本件自己画的那些**。一个把**调用方内容**也放在自己
    /// 视图树里的效果，本档要摘掉的是**装饰层与调度器**，内容层必须静态留下
    /// —— 把调用方的内容藏掉不是停摆、是 bug。
    ///
    /// ⚠️ **名字是 `hidden` 不是 `none`**（`#271`）：`.none` 一旦公开，在
    /// `MotionPresentation?` 语境下 `x == .none` 会被解析成 `Optional.none` 并发警告，
    /// 而 `scripts/downstream-probe` 带 `-Xswiftc -warnings-as-errors` ⇒ 那是硬红。
    case hidden

    /// 画，但静止（Reduce Motion：保留视觉、去掉运动）。
    case resting

    /// 正常动。
    case animated
}

public extension EnergyState {

    /// 两道闸的**顺序**：能耗闸先于 Reduce Motion 闸。
    ///
    /// ⚠️⚠️ **顺序是承重的**：反过来写的话，开启「减弱动态效果」的用户恰好在系统规定
    /// 该停摆的状态下拿到一个还在跑动画的装饰层。本仓出过一次「两个调用点各写一遍就
    /// 写反了」的事故 —— 这也正是 `#271` 把它下沉的理由：留在上层就意味着
    /// 每个新消费者（如 shader 背景）都要自己再写一遍这条顺序。
    ///
    /// - Parameter reduceMotion: 调用点从 `\.accessibilityReduceMotion` 读到的值。
    ///   ⚠️ 作为参数传入而不是在这里读环境：本类型 `nonisolated`、且要能被单测直接调用。
    func presentation(reduceMotion: Bool) -> MotionPresentation {
        guard self.policy.drawsAnything else { return .hidden }
        return reduceMotion ? .resting : .animated
    }
}
