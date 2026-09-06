import CoreGraphics
import SwiftUI

// MARK: - CoreControlMetrics

/// 控件尺寸 token，按 SwiftUI `ControlSize`（mini / small / regular / large / extraLarge）
/// 暴露 5 个查询 helper（height / horizontalPadding / verticalPadding / font / iconSize）。
public nonisolated enum CoreControlMetrics {
    // MARK: - height

    /// 控件高度（pt）。用于 capsule / pill / SegmentedControl / SearchField 等需要固定外框
    /// 高度的场景。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下的推荐外框高度，单位 pt。
    public static func height(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 28
        case .small: return 32
        case .regular: return 44
        case .large: return 50
        case .extraLarge: return 56
        @unknown default:
            return 44
        }
    }

    // MARK: - horizontalPadding

    /// 控件横向 padding（pt）。包裹 label 的左右内边距，配合 `height(for:)` 决定外框宽度。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的左右 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func horizontalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.sm
        case .small: return CoreSpacing.md
        case .regular: return CoreSpacing.lg
        case .large: return CoreSpacing.lg
        case .extraLarge: return CoreSpacing.xl
        @unknown default:
            return CoreSpacing.lg
        }
    }

    // MARK: - verticalPadding

    /// 控件纵向 padding（pt）。包裹 label 的上下内边距。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的上下 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func verticalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.xs
        case .small: return CoreSpacing.xs
        case .regular: return CoreSpacing.md
        case .large: return CoreSpacing.lg
        case .extraLarge: return CoreSpacing.lg
        @unknown default:
            return CoreSpacing.md
        }
    }

    // MARK: - font

    /// 控件 label 推荐字号 token。直接返回 `CoreTypography.Token`，调用方经
    /// `.coreFont(_:)` 施加。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的 `CoreTypography.Token`。
    public static func fontToken(for controlSize: ControlSize) -> CoreTypography.Token {
        switch controlSize {
        case .mini:       .footnote
        case .small:      .footnote
        case .regular:    .callout
        case .large:      .body
        case .extraLarge: .title2
        @unknown default: .callout
        }
    }

    // MARK: - iconSize

    /// 控件内联 icon 边长（pt），比对应字号大 1.0–1.2 倍以与 label 文字视觉等重。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的 icon 边长，单位 pt。
    public static func iconSize(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 12
        case .small: return 14
        case .regular: return 16
        case .large: return 20
        case .extraLarge: return 24
        @unknown default:
            return 16
        }
    }
}
