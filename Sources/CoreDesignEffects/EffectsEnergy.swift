import CoreDesign
import SwiftUI

public extension RenderPolicy {
    /// 是否使用离屏模糊做光晕。
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
    nonisolated func frozenIfPeriodIsDegenerate(_ rotationPeriod: Double) -> MotionPresentation {
        guard self == .animated, !(rotationPeriod.isFinite && rotationPeriod > 0) else { return self }
        return .resting
    }
}
