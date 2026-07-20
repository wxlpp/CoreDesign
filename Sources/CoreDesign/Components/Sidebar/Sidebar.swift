//
//  Sidebar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Sidebar Text Style

/// Semantic text-color aliases for sidebar content.
///
/// Maps to the content semantic tokens (`contentPrimary` / `contentMuted` /
/// `contentSubtle`) so custom sidebar content stays visually consistent with
/// the built-in rows. Use these instead of raw color hues.
///
/// 侧栏文本配色语义别名 / SidebarTextStyle：自定义侧栏内容时复用，保证与内置
/// row 一致。
public enum SidebarTextStyle {
    public static let primary = Color.contentPrimary
    public static let secondary = Color.contentMuted
    public static let tertiary = Color.contentSubtle
}

// MARK: - Sidebar Section

/// Titled group container for sidebar rows.
///
/// Renders a section header (title + optional disclosure chevron + decorative
/// overflow glyph) above a leading-aligned stack of row content.
///
/// **Material layer**: container. **Surface role**: sidebar.
///
/// 侧栏分组容器 / SidebarSection：标题 + 可选 chevron 头部 + 内容行堆叠。
public struct SidebarSection<Content: View>: View {
    public init(
        title: String,
        showsChevron: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsChevron = showsChevron
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            HStack(spacing: CoreSpacing.xs) {
                Text(self.title)
                    .font(CoreTypography.titleSmallFont)
                    .foregroundStyle(SidebarTextStyle.primary)

                if self.showsChevron {
                    Image(systemName: "chevron.right")
                        .font(CoreTypography.bodySmallFont)
                        .foregroundStyle(SidebarTextStyle.secondary)
                        // 纯装饰：标题已表达分组语义，避免 VoiceOver 朗读
                        // "chevron right" 噪音 / Decorative chevron.
                        .accessibilityHidden(true)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(CoreTypography.bodyMediumFont)
                    .foregroundStyle(SidebarTextStyle.tertiary)
                    // 装饰性占位符，当前无 action；对 VoiceOver 隐藏避免
                    // 暴露成无标签图片 / Decorative placeholder, no action.
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, CoreSpacing.sm)

            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                self.content
            }
        }
    }

    private let title: String
    private let showsChevron: Bool
    private let content: Content
}

// MARK: - Sidebar Rows

// MARK: OptionalLineLimit (helper)

/// 条件性 lineLimit / Conditional line limit。
///
/// `.lineLimit(nil)` 会**显式重置**祖先设过的值，与「不写 lineLimit」不等价。
/// 本 modifier 在 `limit == nil` 时原样返回 content，保证三个不限行的 row
/// 与收敛前逐字等价。
private struct OptionalLineLimit: ViewModifier {
    let limit: Int?

    func body(content: Content) -> some View {
        if let limit = self.limit {
            content.lineLimit(limit)
        } else {
            content
        }
    }
}

// MARK: - SidebarRow (shared skeleton)

/// 四种 sidebar row 的共享骨架 / Shared skeleton for the four sidebar rows.
///
/// 收敛自原先四份逐字重复的实现（审计项 B5）。差异全部由调用方经
/// `leading` / `trailing` 两个 `@ViewBuilder` 与 `isSelected` 表达：
///
/// - `leading`：图标或 `#` 字形，字号各 row 不同（`bodyLarge` / `titleMedium`）
/// - `trailing`：可选尾部内容；**a11y 语义由调用方决定**——`SidebarDocumentRow`
///   的 detail 承载信息须可读，`SidebarUtilityRow` / `SidebarTagRow` 的是纯装饰
///   须 `.accessibilityHidden(true)`。骨架不代为决定。
/// - `isSelected`：仅 `SidebarNavigationRow` 使用，驱动 floating-glass 背景与
///   `.isSelected` 辅助技术 trait。
private struct SidebarRow<Leading: View, Trailing: View>: View {
    let title: String
    let titleLineLimit: Int?
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: CoreSpacing.sm) {
                self.leading
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .frame(width: CoreControlMetrics.iconSize(for: .large))
                    // 装饰性 leading 字形：button 的可访问名由 title 驱动，隐藏它
                    // 避免 VoiceOver 朗读 SF Symbol 名 / Decorative leading glyph.
                    .accessibilityHidden(true)

                Text(self.title)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.primary)
                    .modifier(OptionalLineLimit(limit: self.titleLineLimit))

                Spacer()

                self.trailing
            }
            // minHeight 而非固定 height：大字号下不裁切（审计项 B2b），
            // 与 ListRow / SearchField 的既有写法一致。
            .frame(minHeight: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .sidebarSelectedBackground(self.isSelected)
            .contentShape(RoundedRectangle(cornerRadius: CoreRadius.mediumPlus))
        }
        .buttonStyle(.plain)
        // 向辅助技术暴露选中态，让 VoiceOver 用户感知当前导航目标
        // （对齐 SegmentedControl）/ Expose selected state to a11y.
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

/// Primary navigation entry with a selected state.
///
/// Icon + title button row; when `isSelected` is true it carries the
/// floating-glass selected background (see `sidebarSelectedBackground(_:)`).
///
/// 侧栏主导航行 / SidebarNavigationRow：图标 + 标题，选中态带 floating-glass 背景。
public struct SidebarNavigationRow: View {
    public init(
        systemImage: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: self.isSelected,
            action: self.action
        ) {
            Image(systemName: self.systemImage)
                .font(CoreTypography.bodyLargeFont)
        } trailing: {
            EmptyView()
        }
    }

    private let systemImage: String
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void
}

/// Secondary utility entry with an optional trailing affordance.
///
/// Single-action row: leading icon + title, with an optional decorative
/// `trailingSystemImage` (no separate action — the whole row is one button).
///
/// 侧栏工具行 / SidebarUtilityRow：图标 + 标题 + 可选装饰性 trailing 图标，整行单一 action。
public struct SidebarUtilityRow: View {
    public init(
        systemImage: String,
        title: String,
        trailingSystemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.trailingSystemImage = trailingSystemImage
        self.action = action
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: false,
            action: self.action
        ) {
            Image(systemName: self.systemImage)
                .font(CoreTypography.bodyLargeFont)
        } trailing: {
            if let trailingSystemImage = self.trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.tertiary)
                    // 次级装饰性 affordance：随主 button 单一 action 触发，
                    // 不单独暴露给 VoiceOver / Decorative trailing affordance.
                    .accessibilityHidden(true)
            }
        }
    }

    private let systemImage: String
    private let title: String
    private let trailingSystemImage: String?
    private let action: () -> Void
}

/// Document entry with a trailing detail label.
///
/// Leading icon + title with a trailing `detail` string (e.g. a count or
/// relative date); `detail` stays VoiceOver-readable while the icon is hidden.
///
/// 侧栏文档行 / SidebarDocumentRow：图标 + 标题 + 尾部 detail（计数 / 日期等）。
public struct SidebarDocumentRow: View {
    public init(
        systemImage: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
        self.action = action
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: 1,
            isSelected: false,
            action: self.action
        ) {
            Image(systemName: self.systemImage)
                .font(CoreTypography.titleMediumFont)
        } trailing: {
            // detail 承载信息（计数 / 日期），**不**隐藏，保持 VoiceOver 可读
            Text(self.detail)
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(SidebarTextStyle.tertiary)
                .lineLimit(1)
        }
    }

    private let systemImage: String
    private let title: String
    private let detail: String
    private let action: () -> Void
}

/// Tag entry rendered with a leading `#` glyph.
///
/// Title-only navigation row prefixed by a decorative `#`; the accessible
/// name is driven by `title` alone.
///
/// 侧栏标签行 / SidebarTagRow：`#` 前缀 + 标题。
public struct SidebarTagRow: View {
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: false,
            action: self.action
        ) {
            Text("#")
                .font(CoreTypography.titleMediumFont)
        } trailing: {
            Image(systemName: "chevron.right")
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(SidebarTextStyle.tertiary)
                // 装饰性指示箭头：行整体可点击，标题已表达目标
                // Decorative trailing chevron.
                .accessibilityHidden(true)
        }
    }

    private let title: String
    private let action: () -> Void
}

/// Footer showing a status dot with title/detail text.
///
/// Non-interactive footer (status dot + two-line label) combined into a
/// single accessibility element. `statusColor` defaults to the semantic
/// `statusSuccessForeground` token.
///
/// 侧栏状态页脚 / SidebarStatusFooter：状态点 + 标题/详情，默认成功语义色。
public struct SidebarStatusFooter: View {
    public init(
        title: String,
        detail: String,
        statusColor: Color = .statusSuccessForeground
    ) {
        self.title = title
        self.detail = detail
        self.statusColor = statusColor
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Circle()
                .fill(self.statusColor)
                .frame(
                    width: CoreSpacing.sm,
                    height: CoreSpacing.sm
                )
                // 状态点纯装饰：title / detail 已传达语义
                // Decorative status dot.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                Text(self.title)
                    .font(CoreTypography.bodySmallFont)
                    .fontWeight(.medium)
                    .foregroundStyle(SidebarTextStyle.primary)
                Text(self.detail)
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(CoreSpacing.sm)
        // 合并 title / detail 为单个可访问元素（对齐 EventRow / StatusRow 惯例）
        // Combine title + detail into one accessibility element.
        .accessibilityElement(children: .combine)
    }

    private let title: String
    private let detail: String
    private let statusColor: Color
}

// MARK: - Selected Background

private struct SidebarSelectedBackgroundModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if self.isSelected {
            // `floatingGlass(isInteractive: true)` 已提供 interactive regular
            // glass 材质 + subtle 边框；此处仅在其上叠加 selected 色描边强调
            // 选中态 + 阴影。原先额外的 `.glassEffect(.regular.interactive())`
            // 会与 floatingGlass 内部的 glass 双重渲染材质，已移除。
            // floatingGlass already applies the interactive glass; the extra
            // outer glassEffect was redundant double material — removed.
            // 单一 shape 来源：floatingGlass 与描边 overlay 共用，避免 corner
            // radius / style 改动时两处不同步 / Single shape source.
            let shape = RoundedRectangle(cornerRadius: CoreRadius.mediumPlus)
            content
                .floatingGlass(in: shape, isInteractive: true)
                .overlay {
                    shape
                        .strokeBorder(Color.borderSelected, lineWidth: CoreBorderWidth.thin)
                }
                .coreShadow(.medium)
        } else {
            content
        }
    }
}

public extension View {
    /// Applies the sidebar selected-state background when `isSelected` is true.
    ///
    /// Floating-glass material + selected-color stroke + shadow. Used by
    /// `SidebarNavigationRow`; reuse on custom rows to match selection styling.
    ///
    /// 侧栏选中态背景 modifier / sidebarSelectedBackground：floating-glass + 选中描边 + 阴影。
    func sidebarSelectedBackground(_ isSelected: Bool) -> some View {
        self.modifier(SidebarSelectedBackgroundModifier(isSelected: isSelected))
    }
}
