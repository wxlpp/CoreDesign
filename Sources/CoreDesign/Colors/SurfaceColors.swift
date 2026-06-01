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
        .surfaceCanvasInset
    }

    static var surfaceOverlay: Color {
        .surfacePanel
    }

    // MARK: - Primer-aligned semantic surfaces / Primer 对齐语义表面

    /// Craft-tuned canvas default，源自 Primer `bgColor.default` 语义，但取值改为
    /// light `#FCFBF7` / dark `#11110F` 以形成更温润的编辑工作台画布。
    /// 页面级最底层背景；接近现有 `surfaceBase`，新代码优先使用本 token。
    /// 由 `canvas/canvas-default.colorset` 提供 light/dark 双值。
    static var surfaceCanvas: Color {
        #if Blossom
        Color("blossom-canvas-default", bundle: .module)
        #else
        Color("canvas-default", bundle: .module)
        #endif
    }

    /// Craft-tuned muted canvas，源自 Primer `bgColor.muted` 语义，但取值改为
    /// light `#F3F0EA` / dark `#1A1916`。
    /// 次级内容区背景（侧栏 / 表格头），接近现有 `surfaceRaised`，新代码优先使用本 token。
    /// 由 `canvas/canvas-subtle.colorset` 提供 light/dark 双值。
    static var surfaceCanvasSubtle: Color {
        #if Blossom
        Color("blossom-canvas-subtle", bundle: .module)
        #else
        Color("canvas-subtle", bundle: .module)
        #endif
    }

    /// Craft-tuned inset canvas，源自 Primer `bgColor.inset` 语义，但取值改为
    /// light `#F8F5EF` / dark `#0F0F0D`。
    /// 凹陷 well / 输入框内底色；现有 token 中无对应项，必须用新 colorset。
    /// 由 `canvas/canvas-inset.colorset` 提供 light/dark 双值。
    static var surfaceCanvasInset: Color {
        #if Blossom
        Color("blossom-canvas-inset", bundle: .module)
        #else
        Color("canvas-inset", bundle: .module)
        #endif
    }

    /// Primer concept: panel surface (Web 端 `bgColor.muted` 的容器化表现)。
    /// 用于卡片群之上的面板容器；接近现有 `surfaceGroupedRaised`，新代码优先使用本 token。
    /// Craft workbench 风格下复用暖灰 `surfaceCanvasSubtle`。
    static var surfacePanel: Color {
        .surfaceCanvasSubtle
    }

    /// Primer concept: sidebar surface (Web 端 `bgColor.muted` 用于侧栏的语义专门化命名)。
    /// 接近现有 `surfaceGrouped`，新代码用于侧栏 / 导航容器优先使用本 token。
    /// Craft workbench 风格下复用暖灰 `surfaceCanvasSubtle`。
    static var surfaceSidebar: Color {
        .surfaceCanvasSubtle
    }

    /// Primer concept: card surface (Web 端 `bgColor.default` 在 grouped 容器内的卡片表现)。
    /// 接近现有 `surfaceGroupedElevated`，新代码优先使用本 token 表示卡片容器。
    /// Craft workbench 风格下卡片保持接近画布，只靠边框和相邻 panel 拉开层级。
    static var surfaceCard: Color {
        .surfaceCanvas
    }
}
