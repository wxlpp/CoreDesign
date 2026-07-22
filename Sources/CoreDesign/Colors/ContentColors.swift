import SwiftUI

// MARK: - Content Colors / 内容颜色
// Source of truth: docs/PRIMER_VERSION.md
//
// Issue #120 完整映射表（第 3 层 ContentColors 全部 token）——全部保持现值，逐项定案：
//
// | token               | 值               | 判定 |
// |---------------------|-------------------|------|
// | contentPrimary      | label             | 保持现值——已是系统色，且已满足核心映射 |
// | contentSecondary    | secondaryLabel    | 保持现值——同上 |
// | contentTertiary     | tertiaryLabel     | 保持现值——同上 |
// | contentQuaternary   | quaternaryLabel   | 保持现值——已是系统色 |
// | contentPlaceholder  | placeholderText   | 保持现值——已是系统色 |
// | contentInverse      | .white            | 保持现值——Apple 无"保证与当前外观相反"的系统色 API；`.colorInvert()` 是 View 层修饰符而非 Color 层能力，超出本层可做的范围 |
// | contentOnAccent     | .white            | 保持现值——已知限制见下方说明 |
// | contentOnDanger     | .white            | 保持现值——`danger` 是固定 `red5`，非动态色，白字对比度可靠 |
// | contentLink         | link              | 保持现值——已是系统色 |
// | contentDisabled     | quaternaryLabel   | 保持现值——已是系统色 |
// | contentMuted        | secondaryLabel    | 保持现值——已是系统色 |
// | contentSubtle       | tertiaryLabel     | 保持现值——已是系统色 |
// | contentOnEmphasis   | .white            | 保持现值——消费点均为固定 status emphasis 色，非动态色，白字对比度可靠 |
//
// `contentOnAccent` 已知限制：Issue #120 把 `accent` 由固定 `brand5` 改为
// `Color.accentColor`（宿主可任意设置）。若宿主把 AccentColor 设成一个很浅的颜色
// （如浅黄），白字前景在其上的对比度可能不足。修复需要基于 accent 实际亮度动态
// 计算对比前景色，SwiftUI 的 `Color` 层没有公开的亮度探测 API 能在不进入 View
// 渲染上下文的情况下做到这件事；这与 epic ADR-3 "不承诺跟随每视图 .tint(_:)" 是
// 同一类限制的延伸，本任务不解决，留作已知问题。

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
