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
public enum StateLabelStyle: Sendable, Equatable {
    case active      // success (green) — in progress
    case draft       // attention (yellow) — not ready / WIP
    case completed   // done (purple) — finished
    case cancelled   // danger (red) — cancelled
}

// MARK: - StateLabel

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
                .font(.caption2)
            Text(self.label)
                .font(CoreTypography.bodySmallFont)
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
        }
    }

    private var foregroundColor: Color {
        switch self.style {
        case .active: return .statusSuccessForeground
        case .draft: return .statusAttentionForeground
        case .completed: return .statusDoneForeground
        case .cancelled: return .statusDangerForeground
        }
    }

    private var backgroundColor: Color {
        switch self.style {
        case .active: return .statusSuccessEmphasis
        case .draft: return .statusAttentionEmphasis
        case .completed: return .statusDoneEmphasis
        case .cancelled: return .statusDangerEmphasis
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
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StateLabel(.active)
        StateLabel(.draft)
        StateLabel(.completed)
        StateLabel(.cancelled)
        StateLabel(.active, label: "In Progress")
    }
    .padding()
}
