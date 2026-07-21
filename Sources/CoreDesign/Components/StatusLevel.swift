//
//  StatusLevel.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StatusLevel

/// 状态语义等级，决定组件的图标 + 配色映射。
///
/// 概念对应 GitHub Primer 的 `Flash` / `Toast` variant。由 `Toast` 与 `Banner`
/// 共用——两者此前各有一份 case 完全相同的枚举（`ToastLevel` / `MessageLevel`），
/// 现合并为单一类型（审计项 B8e）。具体颜色由
/// `Sources/CoreDesign/Colors/StatusColors.swift` 的 status color token 决定，
/// 随系统 colorScheme 自动适配 light / dark。
///
/// - `info`：中性提示（蓝）。例：版本可用、操作已记录。
/// - `success`：操作成功（绿）。例：保存成功、上传完成。
/// - `warning`：警告（橙）。例：即将过期、配额接近上限。
/// - `danger`：错误 / 风险（红）。例：保存失败、操作被拒绝。
public nonisolated enum StatusLevel: Sendable, Equatable {
    case info
    case success
    case warning
    case danger
}
