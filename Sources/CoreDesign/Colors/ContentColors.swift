import SwiftUI

// MARK: - Content Colors / 内容颜色
// Source of truth: docs/PRIMER_VERSION.md

public extension Color {
    static var contentPrimary: Color {
        .label
    }

    static var contentSecondary: Color {
        .secondaryLabel
    }

    static var contentTertiary: Color {
        .tertiaryLabel
    }

    static var contentQuaternary: Color {
        .quaternaryLabel
    }

    static var contentPlaceholder: Color {
        .placeholderText
    }

    static var contentInverse: Color {
        .white
    }

    static var contentOnAccent: Color {
        .white
    }

    static var contentOnDanger: Color {
        .white
    }

    static var contentLink: Color {
        .link
    }

    static var contentDisabled: Color {
        .quaternaryLabel
    }

    // MARK: - Primer-aligned semantic content / Primer 对齐语义内容色

    /// Primer `fgColor.muted` (`base.color.neutral.9`)。次要文本，如时间戳 / 元数据 / helper text。
    /// 接近现有 `contentSecondary`，新代码优先使用本 token；旧 `contentSecondary` 双轨保留。
    /// 复用 `.secondaryLabel`，避免新建 colorset。
    static var contentMuted: Color {
        .secondaryLabel
    }

    /// Primer 概念：弱化辅助文本（弱于 `fgColor.muted`，对应 Web 端 disabled / hint 表现）。
    /// 接近现有 `contentTertiary`（doc 提示 ≈ contentQuaternary，但 Primer 取值实际更接近 tertiary 档位），
    /// 新代码用于占位 / 装饰文本优先使用本 token。
    /// 复用 `.tertiaryLabel`，避免新建 colorset。
    static var contentSubtle: Color {
        .tertiaryLabel
    }

    /// Primer `fgColor.onEmphasis` (`base.color.neutral.0`)。在 emphasis 强调背景上的白色文本。
    /// 接近现有 `contentOnAccent` / `contentOnDanger`，新代码用于通用 emphasis 背景上的文本（含中性 emphasis）
    /// 优先使用本 token；旧 onAccent / onDanger 双轨保留。
    /// 直接使用 `.white`，无需 colorset。
    static var contentOnEmphasis: Color {
        .white
    }
}
