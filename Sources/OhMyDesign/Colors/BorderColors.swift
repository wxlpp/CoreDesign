import SwiftUI

// MARK: - Border Colors / 边框颜色

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

    // MARK: - Semantic border variants / 语义边框变体

    /// 比 `borderDefault` 更弱的次要分隔线 / 卡片边框；语义接近 `borderSubtle`，
    /// 但取值略强（透明度更高，0.42）。复用 `.separator.opacity(0.42)`，避免新建 colorset。
    static var borderMuted: Color {
        .separator.opacity(0.42)
    }

    /// 交互态边框的 hover 表现，取 `borderDefault` 的稍强表现作为高亮。
    /// 复用 `.opaqueSeparator`，避免新建 colorset。
    static var borderHover: Color {
        .opaqueSeparator
    }

    /// 键盘 focus / 强调描边专用。指向 `accent` 别名，不单独分流。
    static var borderFocus: Color {
        .accent
    }

    /// 选中态描边。语义上表示"已选中"而非"键盘 focus"，但与 `borderFocus` 同源 `accent`——
    /// 走别名而非直接引用第 1 层原子色，accent 重定向时自动跟随。
    static var borderSelected: Color {
        .accent
    }

    /// 比 `borderDefault` / `borderStrong` 更具视觉重量，用于需强调的容器边框。
    /// 复用 `.opaqueSeparator`（与 `borderStrong` 同值，仅语义命名差异）。
    static var borderEmphasis: Color {
        .opaqueSeparator
    }
}
