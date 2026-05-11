//
//  CoreButtonMetrics.swift
//  CoreDesign
//

import CoreGraphics

// MARK: - CoreButtonMetrics

/// 按钮专用度量 token，服务于 Telegram 玻璃按钮四层结构。
///
/// 调用方式（caseless enum + `static let` of `CGFloat` / `Double`）：
///
/// ```swift
/// shape.padding(CoreButtonMetrics.glassInset)
///     .overlay(shape.strokeBorder(.white.opacity(CoreButtonMetrics.glassBorderOpacity), ...))
/// ```
public enum CoreButtonMetrics {
    /// 底色内缩量 (2pt)。让底色从玻璃壳边缘微微透出，形成 Telegram 分层按钮的视觉纵深。
    public static let glassInset: CGFloat = 2

    /// 玻璃壳顶层细白描边的不透明度 (0.2)。配合 `CoreBorderWidth.hairline` 使用。
    public static let glassBorderOpacity: Double = 0.2

    /// 按钮按下时的缩放比例 (0.94)。提供 Telegram 风格的轻微凹陷反馈。
    public static let pressedScale: Double = 0.94
}
