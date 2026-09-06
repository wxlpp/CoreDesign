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

    /// 页面级最底层背景，指向 `systemGroupedBackground`。
    /// 与 `surfaceGrouped` 同值——两个名字服务不同的调用语境，是刻意的双轨命名。
    static var surfaceCanvas: Color {
        .systemGroupedBackground
    }

    /// 次级内容区背景（侧栏 / 表格头）。指向 `secondarySystemGroupedBackground`，
    /// 与 `surfaceRaised` 同值。
    static var surfaceCanvasSubtle: Color {
        .secondarySystemGroupedBackground
    }

    /// 凹陷 well / 输入框内底色，指向 `FillColors.tertiaryFill`。
    static var surfaceCanvasInset: Color {
        .tertiaryFill
    }

    /// 面板 / 覆盖层容器背景（服务 `.surface(.panel)` 与 `.surface(.overlay)`）。
    static var surfacePanel: Color {
        .quaternaryFill
    }

    /// 侧栏 / 导航容器背景，走 `surfaceElevated`——**在 iOS 上**与画布、内容表面拉开三档；
    /// macOS 上三者同色（系统无分层背景 API）。
    static var surfaceSidebar: Color {
        .surfaceElevated
    }

    /// 卡片容器背景，别名 `surfaceRaised`——**在 iOS 上**浮于画布之上、深色下不与画布塌缩同色；
    /// macOS 上与画布同色。
    static var surfaceCard: Color {
        .surfaceRaised
    }
}
