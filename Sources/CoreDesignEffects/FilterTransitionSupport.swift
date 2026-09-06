import SwiftUI

// MARK: - ⚠️ 写滤镜类转场前必读：这一簇为什么不套「降级为淡入淡出」

// MARK: - ⚠️⚠️ `TransitionProperties.hasMotion`：不写这一行，上面那张表在运行时全是假的

// MARK: - 相位 → 进度

nonisolated enum FilterTransitionPhase {
    static func clamped01(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.min(Swift.max(value, 0), 1)
    }

    static func progress(phase: TransitionPhase) -> Double {
        Self.clamped01(abs(phase.value))
    }
}

// MARK: - 安全档位

enum FilterTransitionSafety: Sendable, Equatable, CaseIterable {
    case full

    case calmed

    static let calmedBrightnessCeiling: Double = 0.08

    static func exposure(dimFlashingLights: Bool) -> FilterTransitionSafety {
        dimFlashingLights ? .calmed : .full
    }

    static func oscillation(dimFlashingLights: Bool, reduceMotion: Bool) -> FilterTransitionSafety {
        (dimFlashingLights || reduceMotion) ? .calmed : .full
    }

    func exposurePeak(_ requested: Double) -> Double {
        let sane = FilterTransitionPhase.clamped01(requested)
        switch self {
        case .full: return sane
        case .calmed: return Swift.min(sane, Self.calmedBrightnessCeiling)
        }
    }

    func oscillationCycles(_ requested: Int) -> Int {
        switch self {
        case .full: return Swift.max(0, requested)
        case .calmed: return 0
        }
    }
}
