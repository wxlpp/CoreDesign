//
//  CoreRadius.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//

import CoreGraphics

// MARK: - CoreRadius

/// 圆角 token，对齐 Primer Primitives 的 `borderRadius.*` 标度。
///
/// 调用方式：
///
/// ```swift
/// RoundedRectangle(cornerRadius: CoreRadius.medium)
///     .clipShape(RoundedRectangle(cornerRadius: CoreRadius.full)) // pill
/// ```
///
/// > Note: Primer 没有 `.none`（直角通常通过省略 `border-radius` 实现）。
/// > 本仓库引入 `.none = 0`，方便在统一类型签名下表达"无圆角"——譬如
/// > `BorderModifier` 默认不带圆角时仍走 token 路径，而不是字面量 0。
public enum CoreRadius {
    /// 直角 (0pt)。**CoreDesign 扩展**，Primer 无对应。
    public static let none: CGFloat = 0

    /// 小圆角 (3pt)。Primer `borderRadius.small`。Badge、Tag、≤16pt 高度的元素。
    public static let small: CGFloat = 3

    /// 中圆角 (6pt)。Primer `borderRadius.medium` / `.default`。按钮、输入框、Card、容器的默认。
    public static let medium: CGFloat = 6

    /// 大圆角 (12pt)。Primer `borderRadius.large`。Dialog、Modal、希望视觉柔和的容器。
    public static let large: CGFloat = 12

    /// 完全圆角 (9999pt)。Primer `borderRadius.full`。Pill / Capsule / 头像。
    public static let full: CGFloat = 9999
}
