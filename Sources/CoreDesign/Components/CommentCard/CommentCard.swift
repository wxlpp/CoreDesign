//
//  CommentCard.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CommentCard

/// 通用评论卡片。
///
/// Header（作者名 + 可选 role badge + 时间戳）+ 主体内容 slot + 最小化提示。
/// Avatar 由外层 `TimelineItem` 的 icon 槽提供，不在卡片内。
///
/// `isMinimized` 为 `Binding<Bool>` 可选：`nil` 时不可折叠（始终展开）；
/// 非 nil 时由调用方控制折叠/展开状态。
public struct CommentCard<BodyContent: View>: View {
    public let author: String
    public let role: String?
    public let timestamp: String
    public let isMinimized: Binding<Bool>?
    @ViewBuilder let content: () -> BodyContent

    public init(
        author: String,
        role: String? = nil,
        timestamp: String,
        isMinimized: Binding<Bool>? = nil,
        @ViewBuilder content: @escaping () -> BodyContent
    ) {
        self.author = author
        self.role = role
        self.timestamp = timestamp
        self.isMinimized = isMinimized
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            // Header
            HStack(spacing: CoreSpacing.xs) {
                Text(self.author)
                    .font(CoreTypography.bodyMediumFont)
                    .fontWeight(.semibold)
                if let role = self.role {
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, CoreSpacing.xs)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(Color.surfaceCanvasInset)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
                        )
                }
                Spacer()
                Text(self.timestamp)
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(.tertiary)
            }

            // Body or minimized placeholder
            if let binding = self.isMinimized, binding.wrappedValue {
                HStack(spacing: CoreSpacing.sm) {
                    Text("This content has been minimized.")
                        .font(CoreTypography.bodySmallFont)
                        .foregroundStyle(.secondary)
                    Button("Show") {
                        binding.wrappedValue = false
                    }
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(Color.accent)
                    .accessibilityLabel("Show minimized comment")
                    .accessibilityHint("Expands the comment from \(self.author)")
                }
            } else {
                self.content()
            }
        }
        .padding(CoreSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CoreRadius.medium)
                .fill(Color.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoreRadius.medium)
                .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Comment by \(self.author)")
    }
}

#Preview("Normal") {
    CommentCard(author: "evan", role: "Contributor", timestamp: "2 hours ago") {
        Text("This is a sample comment body.").font(.body)
    }
    .padding()
}

#Preview("Minimized") {
    CommentCard(
        author: "renovate",
        role: "Bot",
        timestamp: "2 days ago",
        isMinimized: Binding.constant(true)
    ) {
        Text("chore(deps): update github actions")
    }
    .padding()
}
