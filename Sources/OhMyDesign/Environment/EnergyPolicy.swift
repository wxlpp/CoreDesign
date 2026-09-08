import SwiftUI

/// 一层常驻渲染件在当前能耗状态下的渲染策略。
public nonisolated enum RenderPolicy: Sendable, Equatable, CaseIterable {
    /// 满帧。
    case full

    /// 降帧，但**仍然在动**。
    case reduced

    /// 完全停摆：驱动动画的 `TimelineView` **不建**（不是「建了但暂停」）。
    case paused

    /// 是否还要画装饰层。`false` ⇒ 调用方应当**整层不建**。
    public var drawsAnything: Bool { self != .paused }

    /// 交给 `TimelineSchedule.animation(minimumInterval:)` 的最小间隔。
    /// `nil` ⇒ 跟随显示器刷新率。
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
    case hidden

    /// 画，但静止（Reduce Motion：保留视觉、去掉运动）。
    case resting

    /// 正常动。
    case animated
}

public extension EnergyState {
    /// 两道闸的**顺序**：能耗闸先于 Reduce Motion 闸。
    ///
    /// - Parameter reduceMotion: 调用点从 `\.accessibilityReduceMotion` 读到的值。
    ///   ⚠️ 作为参数传入而不是在这里读环境：本类型 `nonisolated`、且要能被单测直接调用。
    func presentation(reduceMotion: Bool) -> MotionPresentation {
        guard self.policy.drawsAnything else { return .hidden }
        return reduceMotion ? .resting : .animated
    }
}
