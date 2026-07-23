import SwiftUI

// MARK: - Border Colors / 边框颜色
//
// 全部 token 直接指向系统色（`separator` / `opaqueSeparator`），随系统外观自动更新；
// `borderFocus` / `borderSelected` 走 `accent` 别名，随 accent 改值自动继承。
//
// `borderSubtle` 取 `separator.opacity(0.28)` 而非直接等于 `opaqueSeparator`：
// 后者会让 `borderSubtle` 与 `borderStrong` / `dividerOpaque` / `borderHover` /
// `borderEmphasis` 四个"更重"的 token 同值、且比 `borderDefault` 更不透明，与
// "subtle 应比 default 更弱"的既有语义倒挂。`separator.opacity(0.28)` 本就是系统色
// `separator` 的不透明度调制，梯度为
// `subtle 0.28 < muted 0.42 < default 1.0 < strong opaqueSeparator`。

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
    ///
    /// > 此前由独立的 colorset 提供一套固定蓝（light `#0969da` / dark `#1f6feb`），
    /// > 与紧邻的 `borderSelected` 各走各的取值——而两者的文档注释却互相声称"同源
    /// > `accent`"。现已让它们真的同源：都指向 `accent`，默认主题下因此从固定蓝
    /// > 变为品牌蓝。
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
