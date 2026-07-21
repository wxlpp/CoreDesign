import SwiftUI

// MARK: - Border Colors / 边框颜色
// Source of truth: docs/PRIMER_VERSION.md

public extension Color {
    static var borderSubtle: Color {
        .separator.opacity(0.28)
    }

    static var borderDefault: Color {
        .separator
    }

    static var borderStrong: Color {
        .opaqueSeparator
    }

    static var dividerDefault: Color {
        .separator
    }

    static var dividerOpaque: Color {
        .opaqueSeparator
    }

    // MARK: - Primer-aligned semantic borders / Primer 对齐语义边框

    /// Primer `borderColor.muted`. 比 `borderDefault` 更弱的次要分隔线 / 卡片边框；语义接近现有 `borderSubtle`，
    /// 但取值略强（透明度更高）。Craft workbench 调整后透明度为 0.42；旧 `borderSubtle` 双轨保留。
    /// 复用 `.separator.opacity(0.42)`，避免新建 colorset。
    static var borderMuted: Color {
        .separator.opacity(0.42)
    }

    /// Primer `borderColor.muted` 的 hover 表现（Primer Web 端无独立 token，此处取 `borderDefault`
    /// 的稍强表现作为 hover 高亮）。语义接近现有 `borderDefault`，新代码用于交互态边框。
    /// 复用 `.opaqueSeparator`，避免新建 colorset。
    static var borderHover: Color {
        .opaqueSeparator
    }

    /// 键盘 focus / 强调描边专用。指向 `accent` 别名，不单独分流。
    ///
    /// > 此前由独立的 `border/border-focus.colorset` 提供 Primer 蓝（light `#0969da` /
    /// > dark `#1f6feb`），与紧邻的 `borderSelected` 各走各的取值——而下一行的注释却
    /// > 声称两者「同源 `accent`」。Issue #93 让它们真的同源：都指向 `accent`，
    /// > 默认主题下因此从 Primer 蓝变为品牌蓝。
    static var borderFocus: Color {
        .accent
    }

    /// 选中态描边。语义上表示"已选中"而非"键盘 focus"，但与 `borderFocus` 同源 `accent`——
    /// 走别名而非直接引用第 1 层原子色，accent 重定向时自动跟随。
    static var borderSelected: Color {
        .accent
    }

    /// Primer `borderColor.emphasis` (`base.color.neutral.8`)。比 `borderDefault` / `borderStrong` 更具视觉重量，
    /// 用于需强调的容器边框。复用 `.opaqueSeparator`（与 `borderStrong` 同值，仅语义命名差异）；
    /// 双轨保留，新代码按 emphasis 语义优先选用本 token。
    static var borderEmphasis: Color {
        .opaqueSeparator
    }
}
