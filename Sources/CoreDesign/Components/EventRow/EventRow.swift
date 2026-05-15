//
//  EventRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - EventRow

/// Native Primer event row.
///
/// Content-layer row. Activity-stream entry with actor / action / object
/// pill / timestamp layout. Density and readability are the priority; no
/// glass, no cardification — the row sits flat on its container's surface.
///
/// **Material layer**: content. **Surface role**: content.
///
/// 紧凑单行时间线事件。
///
/// Actor + 动作文本 + 可选 object pill + 时间戳。用于 TimelineItem 内容槽中
/// 的非评论事件行。
public struct EventRow<PillContent: View>: View {
    public let actor: String
    public let action: String
    public let timeAgo: String
    @ViewBuilder let pill: () -> PillContent

    public init(
        actor: String,
        action: String,
        timeAgo: String,
        @ViewBuilder pill: @escaping () -> PillContent = { EmptyView() }
    ) {
        self.actor = actor
        self.action = action
        self.timeAgo = timeAgo
        self.pill = pill
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Text(self.actor)
                .font(CoreTypography.bodyMediumFont)
                .fontWeight(.medium)
            Text(self.action)
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(.secondary)
            self.pill()
            Text(self.timeAgo)
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        // 不显式重写 `accessibilityLabel`——\`.combine\` 自动合并 actor / action / pill
        // (Tag / RefPill 自身已带 a11y 文本) / timeAgo；若强行覆盖会丢失 pill 内容。
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        EventRow(actor: "renovate", action: "added the", timeAgo: "2 days ago") {
            Tag("dependencies", color: .blue)
        }
        EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2 days ago") {
            RefPill("4d2040c")
        }
        EventRow(actor: "evan", action: "commented", timeAgo: "1 hour ago")
    }
    .padding()
}
