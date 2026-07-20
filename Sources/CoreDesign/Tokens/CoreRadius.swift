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
///     .clipShape(Capsule())   // pill 形态用 Capsule，不要用大 cornerRadius // pill
/// ```
///
/// > Note: Primer 没有 `.none`（直角通常通过省略 `border-radius` 实现）。
/// > 本仓库引入 `.none = 0`，方便在统一类型签名下表达"无圆角"——譬如
/// > `BorderModifier` 默认不带圆角时仍走 token 路径，而不是字面量 0。
// `nonisolated`：理由同 `CoreSpacing`——纯数值常量，需要在 nonisolated 上下文
// （如 `BottomInputBarGlassEffectShape.path(in:)`）中被引用。
public nonisolated enum CoreRadius {
    /// 直角 (0pt)。**CoreDesign 扩展**，Primer 无对应。
    public static let none: CGFloat = 0

    /// 小圆角 (3pt)。Primer `borderRadius.small`。Badge、Tag、≤16pt 高度的元素。
    public static let small: CGFloat = 3

    /// 比小圆角略大 (4pt)。**CoreDesign 扩展**，介于 `small=3` 与 `medium=6` 之间。
    /// 选中态矩形（TabBar 选区、Sidebar 选区、segment thumb）等需要比 `medium=6`
    /// 略锐、但又比 `small=3` 略柔的场景；与相邻 6pt 元素并置时视觉更协调。
    /// 上游 Primer Primitives 当前锁定版本未定义此档；如果未来 Primer 引入对应级别，
    /// 切换该 token 数值即可。
    ///
    /// > Note: 命名采用 `*Plus` 后缀显式表达"大于 `small`"——避免与本仓库其它 token
    /// > （`CoreSpacing.xxs / xs / sm`、`CoreControlMetrics` 的 `xsmall` 语义）里
    /// > `x*` 一律表示"小于"的惯例冲突。
    public static let smallPlus: CGFloat = 4

    /// 中圆角 (6pt)。Primer `borderRadius.medium` / `.default`。按钮、输入框、Card、容器的默认。
    public static let medium: CGFloat = 6

    /// 比中圆角略大 (8pt)。**CoreDesign 扩展**，介于 `medium=6` 与 `large=12` 之间。
    /// 容器卡片（BackReferenceList 等）希望比按钮容器更柔和、又不到 Dialog 级别的场景。
    /// 上游 Primer Primitives 当前锁定版本未定义此档；如果未来 Primer 引入对应级别，
    /// 切换该 token 数值即可。
    ///
    /// > Note: 命名采用 `*Plus` 后缀显式表达"大于 `medium`"——避免与 `smallPlus`
    /// > 类似的层级语义混淆（曾考虑过的 `smallMid` 名称易被误读为"介于 small 与
    /// > medium 之间"）。
    public static let mediumPlus: CGFloat = 8

    /// 大圆角 (12pt)。Primer `borderRadius.large`。Dialog、Modal、希望视觉柔和的容器。
    public static let large: CGFloat = 12

}
