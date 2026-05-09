import SwiftUI

// MARK: - Surface Colors / 表面颜色
// Source of truth: docs/PRIMER_VERSION.md

public extension Color {
    static var surfaceBase: Color {
        .systemBackground
    }

    static var surfaceRaised: Color {
        .secondarySystemBackground
    }

    static var surfaceElevated: Color {
        .tertiarySystemBackground
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
        .secondaryFill
    }

    static var surfaceOverlay: Color {
        .quaternaryFill
    }

    // MARK: - Primer-aligned semantic surfaces / Primer 对齐语义表面

    /// Primer `bgColor.default` (`base.color.neutral.0`，light `#FFFFFF` / dark `#0D1117`)。
    /// 页面级最底层背景；接近现有 `surfaceBase`，新代码优先使用本 token。
    /// 由 `canvas/canvas-default.colorset` 提供 light/dark 双值。
    static var surfaceCanvas: Color {
        Color("canvas-default", bundle: .module)
    }

    /// Primer `bgColor.muted` (`base.color.neutral.1`，light `#F6F8FA` / dark `#151B23`)。
    /// 次级内容区背景（侧栏 / 表格头），接近现有 `surfaceRaised`，新代码优先使用本 token。
    /// 由 `canvas/canvas-subtle.colorset` 提供 light/dark 双值。
    static var surfaceCanvasSubtle: Color {
        Color("canvas-subtle", bundle: .module)
    }

    /// Primer `bgColor.inset` (light `#F6F8FA` / dark `#0D1117`)。
    /// 凹陷 well / 输入框内底色；现有 token 中无对应项，必须用新 colorset。
    /// 由 `canvas/canvas-inset.colorset` 提供 light/dark 双值。
    static var surfaceCanvasInset: Color {
        Color("canvas-inset", bundle: .module)
    }

    /// Primer concept: panel surface (Web 端 `bgColor.muted` 的容器化表现)。
    /// 用于卡片群之上的面板容器；接近现有 `surfaceGroupedRaised`，新代码优先使用本 token。
    /// 复用 `.secondarySystemGroupedBackground`，避免新建 colorset。
    static var surfacePanel: Color {
        .secondarySystemGroupedBackground
    }

    /// Primer concept: sidebar surface (Web 端 `bgColor.muted` 用于侧栏的语义专门化命名)。
    /// 接近现有 `surfaceGrouped`，新代码用于侧栏 / 导航容器优先使用本 token。
    /// 复用 `.systemGroupedBackground`，避免新建 colorset。
    static var surfaceSidebar: Color {
        .systemGroupedBackground
    }

    /// Primer concept: card surface (Web 端 `bgColor.default` 在 grouped 容器内的卡片表现)。
    /// 接近现有 `surfaceGroupedElevated`，新代码优先使用本 token 表示卡片容器。
    /// 复用 `.tertiarySystemGroupedBackground`，避免新建 colorset。
    static var surfaceCard: Color {
        .tertiarySystemGroupedBackground
    }
}
