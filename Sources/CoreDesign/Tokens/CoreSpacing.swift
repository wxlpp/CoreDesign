//
//  CoreSpacing.swift
//  CoreDesign
//
//  Source of truth: Tokens/PRIMER_VERSION.md
//

import CoreGraphics

// MARK: - CoreSpacing

/// 间距 token，对齐 GitHub Primer Primitives 的 `space.*` 标度。
///
/// 调用方式（caseless enum + `static let` of `CGFloat`，可直接传入 SwiftUI 修饰器）：
///
/// ```swift
/// VStack(spacing: CoreSpacing.md) { ... }
///     .padding(CoreSpacing.lg)
/// ```
///
/// 取值参考：见 `Tokens/PRIMER_VERSION.md` 中锁定的 Primer 版本下 functional `space.*` token。
/// `xxs`–`xl` 与 Primer 一一对应；`xxl`–`huge` 是本仓库扩展，对应 Primer `base.size.32` / `.40` / `.48` / `.64`。
///
/// > Important: 不要在组件中引入与本表无关的字面量（譬如 `padding(13)`），
/// > 这会破坏 token 化的初衷。需要新粒度时优先扩展本枚举。
public enum CoreSpacing {
    /// 无间距 (0pt)。零值占位，避免组件内魔法数字 0。
    public static let none: CGFloat = 0

    /// 超紧凑 (2pt)。Primer `space.xxs`。表单字段分隔、紧密分隔线。
    public static let xxs: CGFloat = 2

    /// 紧凑 (4pt)。Primer `space.xs`。Badge / Tag 内 padding、紧密列表项分隔。
    public static let xs: CGFloat = 4

    /// 默认 (8pt)。Primer `space.sm`。绝大多数组件的标准 padding 与 gap。
    public static let sm: CGFloat = 8

    /// 舒适 (12pt)。Primer `space.md`。容器舒展型 padding、section 之间分隔。
    public static let md: CGFloat = 12

    /// 宽松 (16pt)。Primer `space.lg`。主要布局区块之间分隔、容器外缘 margin。
    public static let lg: CGFloat = 16

    /// 充裕 (24pt)。Primer `space.xl`。大段落分隔、顶级页面结构。
    public static let xl: CGFloat = 24

    /// 大 (32pt)。**CoreDesign 扩展**，对应 Primer `base.size.32`。
    public static let xxl: CGFloat = 32

    /// 加大 (40pt)。**CoreDesign 扩展**，对应 Primer `base.size.40`。
    public static let xxxl: CGFloat = 40

    /// 特大 (48pt)。**CoreDesign 扩展**，对应 Primer `base.size.48`。
    public static let xxxxl: CGFloat = 48

    /// 巨大 (64pt)。**CoreDesign 扩展**，对应 Primer `base.size.64`。
    public static let huge: CGFloat = 64
}
