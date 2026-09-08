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

    /// 压在 `accent` 之上的前景色。⚠️ **随主题反转**（accent 是墨色，浅色下黑 / 深色下白），
    /// 故本色取 `systemBackground` 而非白。
    /// ⚠️ 只服务真正坐在 `accent` 上的点；压在**固定饱和色**上的前景走 `contentOnEmphasis`。
    static var contentOnAccent: Color {
        .systemBackground
    }

    static var contentOnDanger: Color {
        .white
    }

    /// ⚠️ 单色体系下取 `label`。**本仓没有任何链接样式施加下划线** ⇒ 改色后链接与正文
    /// 视觉上不可区分；下划线约定本次未定，是登记在案的缺口。
    static var contentLink: Color {
        .label
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
