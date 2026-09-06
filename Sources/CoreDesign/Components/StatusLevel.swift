import SwiftUI

// MARK: - StatusLevel

/// 状态语义等级，决定组件的图标 + 配色映射。
public nonisolated enum StatusLevel: Sendable, Equatable {
    case info
    case success
    case warning
    case danger
}
