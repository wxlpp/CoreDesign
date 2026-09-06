import SwiftUI

// MARK: - Surface Colors / 表面颜色

public extension Color {
    static var surfaceBase: Color {
        .systemBackground
    }

    static var surfaceRaised: Color {
        .secondarySystemGroupedBackground
    }

    static var surfaceElevated: Color {
        .tertiarySystemGroupedBackground
    }

    static var surfaceGrouped: Color {
        .systemGroupedBackground
    }

    static var surfaceGroupedRaised: Color {
        .secondarySystemGroupedBackground
    }

    static var surfaceGroupedElevated: Color {
        .tertiarySystemGroupedBackground
    }

    static var surfaceMuted: Color {
        .tertiaryFill
    }

    static var surfaceInteractive: Color {
        .surfaceCanvasInset
    }

    /// 浮层表面背景（服务 `.surface(.floating)`：toast、浮动工具栏、底部栏）。
    static var surfaceOverlay: Color {
        #if canImport(UIKit)
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.secondarySystemFill
                    : UIColor.systemBackground
            })
        #else
            .secondaryFill
        #endif
    }

    // MARK: - Semantic surface variants / 语义表面变体

    /// 页面级最底层背景。指向 `systemGroupedBackground`，随系统浅色/深色与未来的
    /// 外观调整自动更新。与 `surfaceGrouped` 同值——刻意的双轨命名，见文件顶部说明。
    static var surfaceCanvas: Color {
        .systemGroupedBackground
    }

    /// 次级内容区背景（侧栏 / 表格头）。指向 `secondarySystemGroupedBackground`，
    /// 与 `surfaceRaised` 同值。
    static var surfaceCanvasSubtle: Color {
        .secondarySystemGroupedBackground
    }

    /// 凹陷 well / 输入框内底色。指向 `FillColors.tertiaryFill`——其官方 HIG 语义
    /// （输入字段/搜索栏/按钮）与本 token 的实际消费点（头像环、进度条轨道、经
    /// `surfaceInteractive` 服务的搜索框/分段控件/按钮背景）精确对应。
    static var surfaceCanvasInset: Color {
        .tertiaryFill
    }

    /// 面板 / 覆盖层容器背景（服务 `.surface(.panel)` 与 `.surface(.overlay)`）。
    static var surfacePanel: Color {
        .quaternaryFill
    }

    /// 侧栏 / 导航容器背景。走 `surfaceElevated`（= `tertiarySystemGroupedBackground`），
    /// 使它在 **iOS 深色**下与画布（`#000000`）、内容表面（`#1C1C1E`）三档分开
    /// （侧栏得 `#2C2C2E`）。
    static var surfaceSidebar: Color {
        .surfaceElevated
    }

    /// 卡片容器背景。Phase 1 曾让卡片刻意贴近画布、只靠边框拉开层级
    /// （`surfaceCard` 别名 `surfaceCanvas`）；Phase 2 视觉终审（#125/#136）
    /// 推翻了这一判断——深色模式下卡片与页面画布完全同色、无描边时视觉塌缩、
    /// 隐形。现改为浮在画布之上：`surfaceCard` 别名 `surfaceRaised`
    /// （= `secondarySystemGroupedBackground`），符合 iOS 分组容器（列表/卡片
    /// 浮于分组画布之上）的系统惯例。
    static var surfaceCard: Color {
        .surfaceRaised
    }
}
