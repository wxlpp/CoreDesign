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

    /// Primer `borderColor.accent.emphasis` (`base.color.blue.5`，light `#0969da` / dark `#1f6feb`)。
    /// 替代旧的 focus ring 颜色（原 `focusRing` 已删除，无别名）。键盘 focus / 选中等强调描边专用。
    /// 由 `border/border-focus.colorset` 提供 light/dark 双值。
    static var borderFocus: Color {
        Color("border-focus", bundle: .module)
    }

    /// Primer `borderColor.accent.emphasis` 在选中态的应用（与 `borderFocus` 同源 `accent`）。
    /// 语义层面表示"已选中"而非"键盘 focus"，取值复用品牌色 `brand5` 以与项目品牌色保持一致。
    static var borderSelected: Color {
        .brand5
    }

    /// Primer `borderColor.emphasis` (`base.color.neutral.8`)。比 `borderDefault` / `borderStrong` 更具视觉重量，
    /// 用于需强调的容器边框。复用 `.opaqueSeparator`（与 `borderStrong` 同值，仅语义命名差异）；
    /// 双轨保留，新代码按 emphasis 语义优先选用本 token。
    static var borderEmphasis: Color {
        .opaqueSeparator
    }
}
