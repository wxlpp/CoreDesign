//
//  CoreSpacing.swift
//  CoreDesign
//

import CoreGraphics

// MARK: - CoreSpacing

/// 间距 token，提供一套固定的 8pt 网格标度，覆盖从紧密分隔线到顶级页面结构的常见间距需求。
///
/// 调用方式（caseless enum + `static let` of `CGFloat`，可直接传入 SwiftUI 修饰器）：
///
/// ```swift
/// VStack(spacing: CoreSpacing.md) { ... }
///     .padding(CoreSpacing.lg)
/// ```
///
/// `xxs`–`xl` 是核心标度（2/4/8/12/16/24pt）；`xxl`–`huge`（32/40/48/64pt）是本仓库
/// 为大尺寸布局需求扩展的档位。
///
/// > Important: 不要在组件中引入与本表无关的字面量（譬如 `padding(13)`），
/// > 这会破坏 token 化的初衷。需要新粒度时优先扩展本枚举。
// `nonisolated`：本枚举只含纯数值常量，需要在 `Layout` / `InsettableShape` 等
// nonisolated 协议要求中被引用（如 `FlowLayout.init` 的默认参数）。
// 注意不能对 `CoreElevation` / `CoreTypography` 做同样处理——它们持有
// `Color` / `Font`，SwiftUI 类型本身是 MainActor 隔离的。
public nonisolated enum CoreSpacing {
    /// 无间距 (0pt)。零值占位，避免组件内魔法数字 0。
    public static let none: CGFloat = 0

    /// 超紧凑 (2pt)。表单字段分隔、紧密分隔线。
    public static let xxs: CGFloat = 2

    /// 紧凑 (4pt)。Badge / Tag 内 padding、紧密列表项分隔。
    public static let xs: CGFloat = 4

    /// 默认 (8pt)。绝大多数组件的标准 padding 与 gap。
    public static let sm: CGFloat = 8

    /// 舒适 (12pt)。容器舒展型 padding、section 之间分隔。
    public static let md: CGFloat = 12

    /// 宽松 (16pt)。主要布局区块之间分隔、容器外缘 margin。
    public static let lg: CGFloat = 16

    /// 充裕 (24pt)。大段落分隔、顶级页面结构。
    public static let xl: CGFloat = 24

    /// 大 (32pt)。大尺寸布局场景扩展档位。
    public static let xxl: CGFloat = 32

    /// 加大 (40pt)。大尺寸布局场景扩展档位。
    public static let xxxl: CGFloat = 40

    /// 特大 (48pt)。大尺寸布局场景扩展档位。
    public static let xxxxl: CGFloat = 48

    /// 巨大 (64pt)。大尺寸布局场景扩展档位。
    public static let huge: CGFloat = 64
}
