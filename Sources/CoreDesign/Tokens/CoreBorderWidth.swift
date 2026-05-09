//
//  CoreBorderWidth.swift
//  CoreDesign
//
//  Source of truth: Tokens/PRIMER_VERSION.md
//

import CoreGraphics

// MARK: - CoreBorderWidth

/// 描边宽度 token，对齐 Primer Primitives 的 `borderWidth.*` 标度。
///
/// 调用方式：
///
/// ```swift
/// RoundedRectangle(cornerRadius: CoreRadius.medium)
///     .stroke(.borderDefault, lineWidth: CoreBorderWidth.thin)
/// ```
///
/// `.thick` (2pt) **必须** 用于交互元素的 focus ring（Primer LLM 规则强制要求）。
public enum CoreBorderWidth {
    /// 无描边 (0pt)。**CoreDesign 扩展**。零值占位。
    public static let none: CGFloat = 0

    /// 亚像素描边 (0.5pt)。**CoreDesign 扩展**，Primer 无对应。Retina 显示屏上的 hairline 分隔线。
    public static let hairline: CGFloat = 0.5

    /// 标准描边 (1pt)。Primer `borderWidth.thin` / `.default`。容器边框、分隔线、输入框边缘。
    public static let thin: CGFloat = 1

    /// 强调描边 (2pt)。Primer `borderWidth.thick`。Focus ring、selected state、强调边框。
    public static let thick: CGFloat = 2

    /// 极厚描边 (4pt)。Primer `borderWidth.thicker`。极少使用，最大视觉强调。
    public static let thicker: CGFloat = 4
}
