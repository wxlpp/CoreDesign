import SwiftUI

// MARK: - Content Colors / 内容颜色

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

    // MARK: - Semantic content variants / 语义内容色变体

    /// 次要文本，如时间戳 / 元数据 / helper text。语义接近 `contentSecondary`，
    /// 新代码优先使用本 token。复用 `.secondaryLabel`，避免新建 colorset。
    static var contentMuted: Color {
        .secondaryLabel
    }

    /// 弱化辅助文本（弱于 `contentMuted`），用于占位 / 装饰文本。
    /// 复用 `.tertiaryLabel`，避免新建 colorset。
    static var contentSubtle: Color {
        .tertiaryLabel
    }

    /// 在 emphasis 强调背景上的白色文本，用于通用 emphasis 背景（含中性 emphasis）。
    /// 直接使用 `.white`，无需 colorset。
    static var contentOnEmphasis: Color {
        .white
    }
}
