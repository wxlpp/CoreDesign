//
//  Sidebar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Sidebar Text Style

/// 侧栏内容的语义文字色别名。
///
/// 映射到第 3 层语义文字色（`contentPrimary` / `contentMuted` / `contentSubtle`），
/// 使自定义侧栏内容与内置行保持视觉一致。**用这些别名，不要直接取色相。**
///
/// 自定义侧栏内容时复用，保证与内置
/// row 一致。
public enum SidebarTextStyle {
    public static let primary = Color.contentPrimary
    public static let secondary = Color.contentMuted
    public static let tertiary = Color.contentSubtle
}

// MARK: - Sidebar Section

/// 带标题的侧栏分组容器。
///
/// 在 leading 对齐的行内容堆叠之上渲染一个 section header（标题 + 可选展开
/// chevron + 装饰性溢出字形）。
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
                    .coreFont(.headline)
                    .foregroundStyle(SidebarTextStyle.primary)

                if self.showsChevron {
                    Image(systemName: "chevron.right")
                        .coreFont(.footnote)
                        .foregroundStyle(SidebarTextStyle.secondary)
                        // 纯装饰：标题已表达分组语义，避免 VoiceOver 朗读
                        // "chevron right" 噪音 / Decorative chevron.
                        .accessibilityHidden(true)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .coreFont(.callout)
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
/// 收敛自原先四份逐字重复的实现。差异全部由调用方经
/// `leading` / `trailing` 两个 `@ViewBuilder` 与 `isSelected` 表达：
///
/// - `leading`：图标或 `#` 字形，字号各 row 不同（`body` / `title2`）
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
                    .coreFont(.body)
                    .foregroundStyle(SidebarTextStyle.primary)
                    .modifier(OptionalLineLimit(limit: self.titleLineLimit))

                Spacer()

                self.trailing
            }
            // minHeight 而非固定 height，与 ListRow / SearchField 一致。
            //
            // **实际收益是长 title 换行不再被压出框**——三个 row 传
            // `titleLineLimit: nil`，标题过长会换到 2+ 行，固定 height 会把
            // 第二行裁掉。`SidebarDocumentRow` 传 `1` 且 detail 也限 1 行，
            // 对它是纯预防性改动。
            .frame(minHeight: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .sidebarSelectedBackground(self.isSelected)
            .contentShape(CoreShape.rounded(CoreRadius.medium))
        }
        .buttonStyle(.plain)
        // 向辅助技术暴露选中态，让 VoiceOver 用户感知当前导航目标
        // （对齐 SegmentedControl）/ Expose selected state to a11y.
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

/// 带选中态的主导航行。
///
/// 图标 + 标题的按钮行；`isSelected` 为 true 时带上浮层玻璃选中背景
/// （见 `sidebarSelectedBackground(_:)`）。
///
/// 侧栏主导航行 / SidebarNavigationRow：图标 + 标题，选中态带 floating-glass 背景。
public struct SidebarNavigationRow<Leading: View>: View {
    /// 以任意 leading 视图构造（可插图标 / 富文本）。
    public init(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.leading = leading()
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: self.isSelected,
            action: self.action
        ) {
            self.leading
        } trailing: {
            EmptyView()
        }
    }

    private let title: String
    private let isSelected: Bool
    private let action: () -> Void
    private let leading: Leading
}

public extension SidebarNavigationRow where Leading == AnyView {
    /// SF Symbol 便利构造（保留原签名，既有调用点不变）。
    ///
    /// `AnyView` 擦除在此可接受：leading 只是单个 `.coreFont(.body)` 图标、
    /// 无测试断言其具体类型（与 `Badge` 需保留 `Text` 精确类型的场景不同），
    /// 擦除代价可忽略，且能一比一复现改前的 body 字号观感。
    init(systemImage: String, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.init(title: title, isSelected: isSelected, action: action) {
            AnyView(Image(systemName: systemImage).coreFont(.body))
        }
    }
}

/// 次级工具行，可选尾部装饰。
///
/// 单动作行：leading 图标 + 标题，尾部可挂一个装饰性的 `trailingSystemImage`
/// （**不是独立动作**——整行就是一个按钮）。
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
                .coreFont(.body)
        } trailing: {
            if let trailingSystemImage = self.trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .coreFont(.body)
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

/// 带尾部 detail 文本的文档行。
///
/// leading 图标 + 标题 + 尾部 `detail` 字符串（计数、相对日期等）；
/// `detail` 对 VoiceOver 可读，而图标被标记为装饰性隐藏。
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
                .coreFont(.title2)
        } trailing: {
            // detail 承载信息（计数 / 日期），**不**隐藏，保持 VoiceOver 可读
            Text(self.detail)
                .coreFont(.callout)
                .foregroundStyle(SidebarTextStyle.tertiary)
                .lineLimit(1)
        }
    }

    private let systemImage: String
    private let title: String
    private let detail: String
    private let action: () -> Void
}

/// 以 `#` 字形开头的标签行。
///
/// 仅含标题的导航行，前缀 `#` 是装饰性的；无障碍名称只由 `title` 决定。
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
                .coreFont(.title2)
        } trailing: {
            Image(systemName: "chevron.right")
                .coreFont(.footnote)
                .foregroundStyle(SidebarTextStyle.tertiary)
                // 装饰性指示箭头：行整体可点击，标题已表达目标
                // Decorative trailing chevron.
                .accessibilityHidden(true)
        }
    }

    private let title: String
    private let action: () -> Void
}

/// 状态点 + 标题/详情文本的页脚。
///
/// 非交互式页脚（状态点 + 两行标签），合并为**单个无障碍元素**。
/// `statusColor` 默认取语义 token `statusSuccessForeground`。
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
                    .coreFont(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(SidebarTextStyle.primary)
                Text(self.detail)
                    .coreFont(.footnote)
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(CoreSpacing.sm)
        // 合并 title / detail 为单个可访问元素
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
            let shape = CoreShape.rounded(CoreRadius.medium)
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
    /// `isSelected` 为 true 时施加侧栏选中态背景。
    ///
    /// 浮层玻璃材质 + 选中色描边 + 阴影。`SidebarNavigationRow` 在用；
    /// 自定义行复用它即可与内置选中样式保持一致。
    ///
    /// 侧栏选中态背景 modifier / sidebarSelectedBackground：floating-glass + 选中描边 + 阴影。
    func sidebarSelectedBackground(_ isSelected: Bool) -> some View {
        self.modifier(SidebarSelectedBackgroundModifier(isSelected: isSelected))
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            // 1) SidebarSection 容器 + 2) SidebarNavigationRow（选中 / 未选中两态）
            SidebarSection(title: "Workspace") {
                SidebarNavigationRow(systemImage: "house", title: "Home", isSelected: true) {}
                SidebarNavigationRow(systemImage: "bell", title: "Notifications", isSelected: false) {}
            }

            // 3) SidebarUtilityRow（带装饰性 trailing 图标）
            SidebarSection(title: "Tools", showsChevron: false) {
                SidebarUtilityRow(systemImage: "gearshape", title: "Settings", trailingSystemImage: "chevron.right") {}
                SidebarUtilityRow(systemImage: "trash", title: "Trash") {}
            }

            // 4) SidebarDocumentRow（尾部 detail 可读）
            SidebarSection(title: "Documents") {
                SidebarDocumentRow(systemImage: "doc.text", title: "Design Spec", detail: "3d") {}
                SidebarDocumentRow(systemImage: "doc.richtext", title: "A very long document title that wraps", detail: "12") {}
            }

            // 5) SidebarTagRow（# 前缀）
            SidebarSection(title: "Tags") {
                SidebarTagRow(title: "swiftui") {}
                SidebarTagRow(title: "design-system") {}
            }

            // 6) SidebarStatusFooter（默认成功语义色）
            SidebarStatusFooter(title: "All systems operational", detail: "Updated just now")
        }
        .padding(CoreSpacing.md)
    }
    .background(Color.surfaceCanvas)
}
