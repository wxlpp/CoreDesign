import SwiftUI

// MARK: - Sidebar Text Style

/// 侧栏内容的语义文字色别名。
public enum SidebarTextStyle {
    public static let primary = Color.contentPrimary
    public static let secondary = Color.contentMuted
    public static let tertiary = Color.contentSubtle
}

// MARK: - Sidebar Section

/// 带标题的侧栏分组容器。
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
                    Image(systemName: "chevron.forward")
                        .coreFont(.footnote)
                        .foregroundStyle(SidebarTextStyle.secondary)
                        .accessibilityHidden(true)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .coreFont(.callout)
                    .foregroundStyle(SidebarTextStyle.tertiary)
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
                    .accessibilityHidden(true)

                Text(self.title)
                    .coreFont(.body)
                    .foregroundStyle(SidebarTextStyle.primary)
                    .modifier(OptionalLineLimit(limit: self.titleLineLimit))

                Spacer()

                self.trailing
            }
            .frame(minHeight: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .sidebarSelectedBackground(self.isSelected)
            .contentShape(CoreShape.rounded(CoreRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

/// 带选中态的主导航行。
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
    init(systemImage: String, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.init(title: title, isSelected: isSelected, action: action) {
            AnyView(Image(systemName: systemImage).coreFont(.body))
        }
    }
}

// MARK: - SidebarUtilityRowPresentation

/// `SidebarUtilityRow` 的**呈现形态**。
public enum SidebarUtilityRowPresentation: Sendable, Equatable, CaseIterable {
    /// 默认：leading 字形 + 标题（现状形态）。
    case iconLeading
    /// 纯文字行：**不渲染 leading 字形、也不占位**。
    /// ⚠️ 本形态下 `systemImage` **静默不生效**——传了不是错误，只是无效。
    case textOnly
}

/// 次级工具行，可选尾部装饰。
public struct SidebarUtilityRow: View {
    /// - Parameters:
    ///   - systemImage: leading 字形。⚠️ `presentation == .textOnly` 时**静默不生效**
    ///     （见 `SidebarUtilityRowPresentation.textOnly`；该形态下约定统一传 `""`）。
    ///   - trailingSystemImage: 可选装饰性尾图标，默认 `nil`。⚠️ 与 `.textOnly` 组合即得
    ///     公约候选 2「字形移到 trailing、文字左对齐起首」。
    ///   - presentation: 呈现形态，默认 `.iconLeading`（现状形态）⇒ **现有调用方零影响**。
    public init(
        systemImage: String,
        title: String,
        trailingSystemImage: String? = nil,
        presentation: SidebarUtilityRowPresentation = .iconLeading,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.trailingSystemImage = trailingSystemImage
        self.presentation = presentation
        self.action = action
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: false,
            action: self.action
        ) {
            if self.presentation == .iconLeading {
                Image(systemName: self.systemImage)
                    .coreFont(.body)
            }
        } trailing: {
            if let trailingSystemImage = self.trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .coreFont(.body)
                    .foregroundStyle(SidebarTextStyle.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    let systemImage: String
    let trailingSystemImage: String?
    let presentation: SidebarUtilityRowPresentation
    private let title: String
    private let action: () -> Void
}

/// 带尾部 detail 文本的文档行。
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
            Image(systemName: "chevron.forward")
                .coreFont(.footnote)
                .foregroundStyle(SidebarTextStyle.tertiary)
                .accessibilityHidden(true)
        }
    }

    private let title: String
    private let action: () -> Void
}

/// 状态点 + 标题/详情文本的页脚。
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
    func sidebarSelectedBackground(_ isSelected: Bool) -> some View {
        self.modifier(SidebarSelectedBackgroundModifier(isSelected: isSelected))
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            SidebarSection(title: "Workspace") {
                SidebarNavigationRow(systemImage: "house", title: "Home", isSelected: true) {}
                SidebarNavigationRow(systemImage: "bell", title: "Notifications", isSelected: false) {}
            }

            SidebarSection(title: "Tools", showsChevron: false) {
                SidebarUtilityRow(systemImage: "gearshape", title: "Settings", trailingSystemImage: "chevron.forward") {}
                SidebarUtilityRow(systemImage: "trash", title: "Trash") {}
            }

            SidebarSection(title: "Documents") {
                SidebarDocumentRow(systemImage: "doc.text", title: "Design Spec", detail: "3d") {}
                SidebarDocumentRow(systemImage: "doc.richtext", title: "A very long document title that wraps", detail: "12") {}
            }

            SidebarSection(title: "Tags") {
                SidebarTagRow(title: "swiftui") {}
                SidebarTagRow(title: "design-system") {}
            }

            SidebarStatusFooter(title: "All systems operational", detail: "Updated just now")
        }
        .padding(CoreSpacing.md)
    }
    .background(Color.surfaceCanvas)
}
