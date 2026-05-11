//
//  EventRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - EventRow

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
        .accessibilityLabel("\(self.actor) \(self.action) \(self.timeAgo)")
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
