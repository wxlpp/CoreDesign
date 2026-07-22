//
//  CoreBorderWidth.swift
//  CoreDesign
//

import CoreGraphics

// MARK: - CoreBorderWidth

/// 描边宽度 token，提供一套固定的描边宽度标度。
///
/// 调用方式：
///
/// ```swift
/// CoreShape.rounded(CoreRadius.medium)
///     .stroke(.borderDefault, lineWidth: CoreBorderWidth.thin)
/// ```
///
/// `.thick` (2pt) 推荐用于交互元素的 focus ring、selected state、强调边框。
public nonisolated enum CoreBorderWidth {
    /// 无描边 (0pt)。零值占位。
    public static let none: CGFloat = 0

    /// 亚像素描边 (0.5pt)。Retina 显示屏上的 hairline 分隔线。
    public static let hairline: CGFloat = 0.5

    /// 标准描边 (1pt)。容器边框、分隔线、输入框边缘。
    public static let thin: CGFloat = 1

    /// 强调描边 (2pt)。Focus ring、selected state、强调边框。
    public static let thick: CGFloat = 2

    /// 极厚描边 (4pt)。极少使用，最大视觉强调。
    public static let thicker: CGFloat = 4
}
