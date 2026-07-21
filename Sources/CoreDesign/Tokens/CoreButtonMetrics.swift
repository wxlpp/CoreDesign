//
//  CoreButtonMetrics.swift
//  CoreDesign
//

import CoreGraphics

// MARK: - CoreButtonMetrics

/// 按钮专用度量 token，服务于 Telegram 玻璃按钮四层结构。
///
/// 典型使用方式（参考 `TelegramGlassButtonModifier`）——通过 `InsettableShape.inset(by:)`
/// 把底色 path 真正内缩，避免用 `.padding` 撑外框：
///
/// ```swift
/// content
///     .background(
///         shape
///             .inset(by: CoreButtonMetrics.glassInset)
///             .fill(.background)
///             .glassEffect()
///     )
///     .overlay(
///         shape.strokeBorder(
///             .white.opacity(CoreButtonMetrics.glassBorderOpacity),
///             lineWidth: CoreBorderWidth.hairline
///         )
///     )
/// ```
public nonisolated enum CoreButtonMetrics {
    /// 底色内缩量 (2pt)。让底色从玻璃壳边缘微微透出，形成 Telegram 分层按钮的视觉纵深。
    /// 通过 `InsettableShape.inset(by:)` 应用于底色 path，不要用 `.padding` 替代。
    public static let glassInset: CGFloat = 2

    /// 玻璃壳顶层细白描边的不透明度 (0.2)。配合 `CoreBorderWidth.hairline` 使用。
    public static let glassBorderOpacity: Double = 0.2

    /// 按钮按下时的缩放比例 (0.94)。提供 Telegram 风格的轻微凹陷反馈。
    public static let pressedScale: Double = 0.94
}
