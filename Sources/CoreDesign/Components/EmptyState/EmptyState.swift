//
//  EmptyState.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//

import SwiftUI

// MARK: - EmptyState

/// 空状态占位视图（无搜索结果 / 列表为空 / 错误后兜底）。
///
/// 概念对应 GitHub Primer 的 `Blankslate`：在数据缺席的位置以居中布局给出
/// "图标 + 标题 + 说明 + 可选行动按钮" 的引导，让界面在无内容时仍然可读、
/// 可点。典型场景：搜索 0 命中、列表初次加载完成但为空、加载失败需要用户
/// 重试、首次进入需要引导创建。
///
/// 形态固定为垂直 `VStack`：icon → title → optional description → optional action。
/// padding / spacing / 字号 / 颜色全部来自 v2-tokens（`CoreSpacing.*` /
/// `CoreTypography.*` / `Color.contentMuted` / `Color.contentPrimary`），随系统
/// `colorScheme` 自动适配 light / dark：light 模式标题深色 / 描述与图标灰；
/// dark 模式标题浅色 / 描述与图标在深色背景上保持低对比但仍可读。
///
/// `Action` 泛型用于可选行动按钮：当不需要 CTA 时使用便利初始化方法，
/// `Action` 自动推断为 `EmptyView`，调用方无需显式传 `{ EmptyView() }`。
///
/// ```swift
/// // 仅 icon + title
/// EmptyState(systemName: "tray", title: "No items")
///
/// // 含描述
/// EmptyState(
///     systemName: "magnifyingglass",
///     title: "No results",
///     description: "Try a different search term."
/// )
///
/// // 含 CTA 按钮
/// EmptyState(
///     systemName: "doc.text",
///     title: "No documents yet",
///     description: "Create your first document to get started."
/// ) {
///     Button("New document") { /* ... */ }
/// }
/// ```
public struct EmptyState<Action: View>: View {

    // MARK: - Designated init

    /// 创建带可选 CTA 的空状态视图。
    ///
    /// - Parameters:
    ///   - icon: 顶部图标，通常为 `Image(systemName:)`；按 `iconSize` 渲染，
    ///     `foregroundStyle` 固定为 `Color.contentMuted`。
    ///   - title: 标题文本，使用 `CoreTypography.titleMediumFont` 渲染，
    ///     `foregroundStyle` 为 `Color.contentPrimary`。
    ///   - description: 说明文本（可选），使用 `CoreTypography.bodyMediumFont`
    ///     渲染，`foregroundStyle` 为 `Color.contentMuted`，多行居中。
    ///   - iconSize: 图标尺寸（pt）。默认 `CoreSpacing.xxxxl` (48pt)；如需更大
    ///     占位（hero 空状态）可传 `CoreSpacing.huge` (64pt)。**禁止**传 `xxxl`
    ///     (40pt)：PRD R3 已修正过此映射错误。
    ///   - action: 可选的 CTA 视图（通常为 `Button`）。不需要时使用便利初始化
    ///     方法，`Action` 自动推断为 `EmptyView`。
    public init(
        icon: Image,
        title: String,
        description: String? = nil,
        iconSize: CGFloat = CoreSpacing.xxxxl,
        @ViewBuilder action: () -> Action
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.iconSize = iconSize
        self.action = action()
    }

    public var body: some View {
        VStack(spacing: CoreSpacing.none) {
            // 把 icon + title + description 合并为一个 a11y 元素，
            // 让 VoiceOver 一次性朗读完空状态的描述性内容；CTA Button
            // 仍以独立元素留在外层 VStack 中，保持可聚焦与可点击。
            VStack(spacing: CoreSpacing.none) {
                self.icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: self.iconSize, height: self.iconSize)
                    .foregroundStyle(Color.contentMuted)
                    .accessibilityHidden(true)
                    .padding(.bottom, CoreSpacing.lg)

                Text(self.title)
                    .font(CoreTypography.titleMediumFont)
                    .foregroundStyle(Color.contentPrimary)
                    .multilineTextAlignment(.center)

                if let description = self.description {
                    Text(description)
                        .font(CoreTypography.bodyMediumFont)
                        .foregroundStyle(Color.contentMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, CoreSpacing.xs)
                }
            }
            .accessibilityElement(children: .combine)

            // 仅当调用方真正提供了 CTA（Action ≠ EmptyView）时才把
            // action 子树插入视图层级，避免便利初始化路径下仍然吃掉
            // 24pt 的顶部 padding，留下视觉上的空白。
            if Action.self != EmptyView.self {
                self.action
                    .padding(.top, CoreSpacing.xl)
            }
        }
        .padding(CoreSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    let icon: Image
    let title: String
    let description: String?
    let iconSize: CGFloat
    let action: Action
}

// MARK: - Convenience inits

public extension EmptyState where Action == EmptyView {

    /// 创建无 CTA 的空状态视图。
    ///
    /// 便利初始化：当不需要行动按钮时，无需显式传 `{ EmptyView() }`。
    ///
    /// - Parameters:
    ///   - icon: 顶部图标，通常为 `Image(systemName:)`。
    ///   - title: 标题文本。
    ///   - description: 说明文本（可选），多行居中。
    ///   - iconSize: 图标尺寸（pt）。默认 `CoreSpacing.xxxxl` (48pt)。
    init(
        icon: Image,
        title: String,
        description: String? = nil,
        iconSize: CGFloat = CoreSpacing.xxxxl
    ) {
        self.init(
            icon: icon,
            title: title,
            description: description,
            iconSize: iconSize,
            action: { EmptyView() }
        )
    }

    /// 创建无 CTA 的空状态视图（直接传入 SF Symbol 名）。
    ///
    /// 便利初始化：内部转 `Image(systemName:)`，省去调用方手写。
    ///
    /// - Parameters:
    ///   - systemName: SF Symbol 名（如 `"tray"` / `"magnifyingglass"`）。
    ///   - title: 标题文本。
    ///   - description: 说明文本（可选）。
    ///   - iconSize: 图标尺寸（pt）。默认 `CoreSpacing.xxxxl` (48pt)。
    init(
        systemName: String,
        title: String,
        description: String? = nil,
        iconSize: CGFloat = CoreSpacing.xxxxl
    ) {
        self.init(
            icon: Image(systemName: systemName),
            title: title,
            description: description,
            iconSize: iconSize,
            action: { EmptyView() }
        )
    }
}

public extension EmptyState {

    /// 创建带 CTA 的空状态视图（直接传入 SF Symbol 名）。
    ///
    /// 便利初始化：内部转 `Image(systemName:)`，省去调用方手写。
    ///
    /// - Parameters:
    ///   - systemName: SF Symbol 名（如 `"doc.text"` / `"exclamationmark.triangle"`）。
    ///   - title: 标题文本。
    ///   - description: 说明文本（可选）。
    ///   - iconSize: 图标尺寸（pt）。默认 `CoreSpacing.xxxxl` (48pt)。
    ///   - action: CTA 视图（通常为 `Button`）。
    init(
        systemName: String,
        title: String,
        description: String? = nil,
        iconSize: CGFloat = CoreSpacing.xxxxl,
        @ViewBuilder action: () -> Action
    ) {
        self.init(
            icon: Image(systemName: systemName),
            title: title,
            description: description,
            iconSize: iconSize,
            action: action
        )
    }
}

// MARK: - Previews

#Preview("Light - icon + title only") {
    EmptyState(systemName: "tray", title: "No items")
        .preferredColorScheme(.light)
}

#Preview("Dark - icon + title only") {
    EmptyState(systemName: "tray", title: "No items")
        .preferredColorScheme(.dark)
}

#Preview("Light - icon + title + description") {
    EmptyState(
        systemName: "magnifyingglass",
        title: "No results",
        description: "Try a different search term or clear the filters."
    )
    .preferredColorScheme(.light)
}

#Preview("Dark - icon + title + description") {
    EmptyState(
        systemName: "magnifyingglass",
        title: "No results",
        description: "Try a different search term or clear the filters."
    )
    .preferredColorScheme(.dark)
}

#Preview("Light - full + action") {
    EmptyState(
        systemName: "doc.text",
        title: "No documents yet",
        description: "Create your first document to start writing."
    ) {
        Button("New document") {}
            .buttonStyle(.borderedProminent)
    }
    .preferredColorScheme(.light)
}

#Preview("Dark - full + action") {
    EmptyState(
        systemName: "doc.text",
        title: "No documents yet",
        description: "Create your first document to start writing."
    ) {
        Button("New document") {}
            .buttonStyle(.borderedProminent)
    }
    .preferredColorScheme(.dark)
}

#Preview("Light - hero size") {
    EmptyState(
        systemName: "exclamationmark.triangle",
        title: "Something went wrong",
        description: "We couldn't load your data. Check your connection and try again.",
        iconSize: CoreSpacing.huge
    ) {
        Button("Retry") {}
    }
    .preferredColorScheme(.light)
}
