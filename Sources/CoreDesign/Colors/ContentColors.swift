import SwiftUI

// MARK: - Content Colors / 内容颜色
//
// 全部 token 直接指向系统 label 色族（`label` / `secondaryLabel` / `tertiaryLabel` /
// `quaternaryLabel` / `placeholderText` / `link`），随系统外观与对比度设置自动更新。
// `contentInverse` / `contentOnAccent` / `contentOnDanger` / `contentOnEmphasis`
// 固定为 `.white`——Apple 没有"保证与当前外观相反"的系统色 API，且这些 token 的
// 消费点均为固定饱和色背景（非动态色），白字对比度可靠。
//
// `contentOnAccent` 已知限制：`accent` 现指向 `Color.accentColor`（宿主可任意设置）。
// 若宿主把 AccentColor 设成一个很浅的颜色（如浅黄），白字前景在其上的对比度可能
// 不足。修复需要基于 accent 实际亮度动态计算对比前景色，SwiftUI 的 `Color` 层
// 没有公开的亮度探测 API 能在不进入 View 渲染上下文的情况下做到这件事，留作
// 已知问题。

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
