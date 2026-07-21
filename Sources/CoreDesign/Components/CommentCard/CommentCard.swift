//
//  CommentCard.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CommentCard

/// Native Primer comment card.
///
/// Content-layer card. Preserves GitHub-like density and readability —
/// polish comes from spacing, thin borders (`CoreBorderWidth.thin`), and
/// typography hierarchy, **not** Liquid Glass. Restrained radius
/// (`CoreRadius.medium`, 6pt) per spec §Radius And Density.
///
/// **Material layer**: content. **Surface role**: content.
///
/// 通用评论卡片。
///
/// Header（作者名 + 可选 role badge + 时间戳）+ 主体内容 slot + 最小化提示。
/// Avatar 由外层 `TimelineItem` 的 icon 槽提供，不在卡片内。
///
/// `isMinimized` 为 `Binding<Bool>` 可选：`nil` 时不可折叠（始终展开）；
/// 非 nil 时由调用方控制折叠/展开状态。
public struct CommentCard<BodyContent: View>: View {
    let author: String
    let role: String?
    let timestamp: String
    let isMinimized: Binding<Bool>?
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
                    .coreFont(.bodyMedium)
                    .fontWeight(.semibold)
                if let role = self.role {
                    Text(role)
                        .coreFont(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, CoreSpacing.xs)
                        // 1pt hairline 纵向内衬：刻意低于最小 spacing 档位（xxs=2pt），
                        // 让 role badge 胶囊维持紧凑高度。无对应 token；snap 到 xxs 会使
                        // 徽标可见变高，单点使用提常量属过度抽象 —— 保留裸值 + 本注释。
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
                    .coreFont(.bodySmall)
                    .foregroundStyle(.tertiary)
            }

            // Body or minimized placeholder
            if let binding = self.isMinimized, binding.wrappedValue {
                HStack(spacing: CoreSpacing.sm) {
                    Text("This content has been minimized.")
                        .coreFont(.bodySmall)
                        .foregroundStyle(.secondary)
                    Button("Show") {
                        binding.wrappedValue = false
                    }
                    .coreFont(.bodySmall)
                    // 渐变 token 层的首个生产消费点（审计项 B7a）。默认主题下
                    // `CoreGradient.brand` 就是 `AnyShapeStyle(Color.accent)`——与改前
                    // 逐像素相同；Blossom 下自动变成珊瑚粉→玫红渐变。
                    .foregroundStyle(CoreGradient.brand)
                    .accessibilityLabel("Show minimized comment")
                    .accessibilityHint("Expands the comment from \(self.author)")
                }
            } else {
                self.content()
            }
        }
        .padding(CoreSpacing.md)
        // 三件套（background + overlay + 圆角）收敛为语义 surface（审计项 B8c）。
        // 两处受控变化：`.surface(_:)` 额外施加 `clipShape`（子视图会被裁到圆角内），
        // 且用 `.continuous` 圆角而非手写时默认的 `.circular`。
        .surface(.card)
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
