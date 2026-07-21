//
//  StateLabel.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StateLabelStyle

/// 通用状态标签的语义样式。
///
/// 颜色映射通过 `StatusColors` 系统的 emphasis 背景 + foreground 文字实现，
/// 详见下方 `backgroundColor` / `foregroundColor`。
public nonisolated enum StateLabelStyle: Sendable, Equatable {
    case active      // success (green) — in progress
    case draft       // attention (yellow) — not ready / WIP
    case completed   // done (purple) — finished
    case cancelled   // danger (red) — cancelled
    case inProgress  // attention (yellow) — transient / in-flight (e.g. saving)
    case error       // danger (red) — recoverable failure (e.g. save failed)
}

// MARK: - StateLabel

/// Native Primer lifecycle state label.
///
/// Control-layer status pill driven by `StateLabelStyle` (`active` /
/// `draft` / `completed` / `cancelled`). Compact, color-for-meaning, no
/// decorative material — same restraint rules as `Badge`, with a fixed icon
/// + label payload tuned for lifecycle scanning.
///
/// **Material layer**: control. **Surface role**: control.
///
/// 通用状态标识 pill。
///
/// 大圆角 + 彩色背景 + SF Symbol 图标 + 文字。颜色由 `StateLabelStyle` 枚举驱动，
/// 映射到 `StatusColors` 系统的 emphasis 背景 + foreground 文字。
public struct StateLabel: View {
    public let style: StateLabelStyle
    public let label: String

    public init(_ style: StateLabelStyle, label: String? = nil) {
        self.style = style
        self.label = label ?? style.defaultLabel
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Image(systemName: self.iconName)
                .coreFont(.caption)
            Text(self.label)
                .coreFont(.bodySmall)
        }
        .foregroundStyle(self.foregroundColor)
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xxs)
        .background(
            Capsule(style: .continuous)
                .fill(self.backgroundColor)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.label)
    }

    private var iconName: String {
        switch self.style {
        case .active: return "circle.fill"
        case .draft: return "circle.dashed"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    /// 前景统一走 `contentOnEmphasis`（白），因为背景用的是 `status*Emphasis`——
    /// Primer 的 emphasis 是饱和填充，配对的前景就是 `fgColor.onEmphasis`。
    ///
    /// > 此处原按 style 返回 `status*Foreground`。那在 emphasis 的 light 值被误填成
    /// > 同组 muted（浅色洗色）时可读，但 Issue #93 把 emphasis 修正为 Primer 语义的
    /// > 饱和实色后，前景与背景会变成同一个颜色（对比度 1.00，文字不可见）。
    /// > `BookCover.swift:155` 是同一配对的既有先例。
    private var foregroundColor: Color {
        .contentOnEmphasis
    }

    private var backgroundColor: Color {
        switch self.style {
        case .active: return .statusSuccessEmphasis
        case .draft: return .statusAttentionEmphasis
        case .completed: return .statusDoneEmphasis
        case .cancelled: return .statusDangerEmphasis
        case .inProgress: return .statusAttentionEmphasis
        case .error: return .statusDangerEmphasis
        }
    }
}

private extension StateLabelStyle {
    var defaultLabel: String {
        switch self {
        case .active: return "Active"
        case .draft: return "Draft"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .inProgress: return "In Progress"
        case .error: return "Error"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StateLabel(.active)
        StateLabel(.draft)
        StateLabel(.completed)
        StateLabel(.cancelled)
        StateLabel(.inProgress)
        StateLabel(.error)
        StateLabel(.inProgress, label: "Saving…")
        StateLabel(.error, label: "Save failed")
    }
    .padding()
}
