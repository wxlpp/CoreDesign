import SwiftUI

// MARK: - 可注入的 EnvironmentValues 键 / Injectable environment keys

extension EnvironmentValues {
    /// **可注入**的低电量模式。`nil`（默认）⇒ 从 `ProcessInfo.processInfo.isLowPowerModeEnabled` 读。
    @Entry public var lowPowerModeOverride: Bool? = nil

    /// **可注入**的场景阶段。`nil`（默认）⇒ 从系统的 `\.scenePhase` 读。
    @Entry public var scenePhaseOverride: ScenePhase? = nil
}
