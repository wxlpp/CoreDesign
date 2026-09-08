import OhMyDesign
import SwiftUI

// MARK: - 位移档位

/// 位移类转场的行程档位（pt）。
public nonisolated enum TransitionTravel: Sendable, Equatable, CaseIterable {
    /// 36 pt —— 徽标、行内小件。
    case short

    /// 80 pt —— 卡片、面板。
    case regular

    /// 160 pt —— 整屏级的大块内容。
    case long

    /// 行程（pt）。
    public var points: CGFloat {
        switch self {
        case .short: 36
        case .regular: 80
        case .long: 160
        }
    }
}

// MARK: - 3D 轴

/// 3D 旋转的轴。**命名按内容看起来往哪个方向转**，不是按数学轴名。
public nonisolated enum TransitionAxis3D: Sendable, Equatable, CaseIterable {
    /// 内容水平翻转 —— 转轴 `(0, 1, 0)`。
    case horizontal

    /// 内容垂直翻转 —— 转轴 `(1, 0, 0)`。
    case vertical

    /// 内容在自己平面内打转 —— 转轴 `(0, 0, 1)`。
    case depth

    /// 斜向翻滚 —— 转轴 `(1, 1, 0)`。
    case tilted

    var vector: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch self {
        case .horizontal: (0, 1, 0)
        case .vertical: (1, 0, 0)
        case .depth: (0, 0, 1)
        case .tilted: (1, 1, 0)
        }
    }
}

// MARK: - 相位曲线（纯函数，生产代码与判据共用同一份）

nonisolated enum TransitionCurve {
    static func value(of phase: TransitionPhase) -> Double { phase.value }

    static func distance(_ phaseValue: Double) -> Double { min(1, abs(phaseValue)) }

    static func opacity(_ phaseValue: Double) -> Double {
        max(0, 1 - Self.distance(phaseValue))
    }

    static func elastic(_ phaseValue: Double, amplitude: Double, cycles: Double) -> Double {
        let u = 1 - Self.distance(phaseValue)
        let decay = (1 - u) * (1 - u)
        return amplitude * decay * cos(2 * .pi * cycles * u)
    }

    static func direction(of edge: Edge) -> CGSize {
        switch edge {
        case .leading: CGSize(width: -1, height: 0)
        case .trailing: CGSize(width: 1, height: 0)
        case .top: CGSize(width: 0, height: -1)
        case .bottom: CGSize(width: 0, height: 1)
        }
    }
}
