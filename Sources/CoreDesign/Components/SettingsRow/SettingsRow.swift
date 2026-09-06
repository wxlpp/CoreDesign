import SwiftUI

// MARK: - SettingsRowMetrics

/// `SettingsRow` 与 `InsetGroupedSection` **共享**的布局常量——分组分隔线的 leading
/// inset 从这里推导（图标方块宽 + 图标↔标题间距），不在两个组件里各自硬编码,
/// 否则图标尺寸一改就错位。
public nonisolated enum SettingsRowMetrics {
    /// iOS 设置那种圆角色块的边长。iOS 系统约 29pt,这里取 30 便于对齐。
    public static let iconSquareSize: CGFloat = 30
    /// 图标方块 ↔ 标题的水平间距。
    public static let iconTitleGap: CGFloat = CoreSpacing.md
    /// 行内容的左右内边距。
    public static let horizontalPadding: CGFloat = CoreSpacing.lg
    /// 图标色块的圆角。
    public static let iconCornerRadius: CGFloat = CoreRadius.small

    /// 分隔线对齐**标题 leading**（越过图标列）时的 inset——iOS 有图标的分组行惯例。
    public static var iconAlignedDividerInset: CGFloat {
        self.horizontalPadding + self.iconSquareSize + self.iconTitleGap
    }
    /// 分隔线对齐**内容 leading**（无图标列）时的 inset。
    public static var textAlignedDividerInset: CGFloat {
        self.horizontalPadding
    }
}

// MARK: - SettingsRowIcon

/// iOS 设置行左侧的圆角色块 + 白色 SF Symbol。
public struct SettingsRowIcon: Sendable {
    let systemName: String
    let background: Color

    /// - Parameters:
    ///   - systemName: SF Symbol 名。
    ///   - background: 色块背景色（图标本身固定白色，如同 iOS 设置）。
    public init(systemName: String, background: Color) {
        self.systemName = systemName
        self.background = background
    }
}

// MARK: - SettingsRowChevron

/// 设置行尾部的 disclosure chevron（">"），供 accessory 组合。自动镜像 RTL。
public struct SettingsRowChevron: View {
    public init() {}

    public var body: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.contentTertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - SettingsRow

/// iOS 设置页 / 偏好面板的行：可着色图标方块 + 标题 + 可选副标题 + 尾部 accessory。
public struct SettingsRow<Accessory: View>: View {
    private let icon: SettingsRowIcon?
    private let title: Text
    private let subtitle: Text?
    private let accessory: Accessory

    @ScaledMetric(relativeTo: .body) private var glyphSize = CoreControlMetrics.iconSize(for: .regular)

    private init(
        icon: SettingsRowIcon?,
        title: Text,
        subtitle: Text?,
        accessory: Accessory
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    /// LocalizedStringKey——字面量在 **`Bundle.main`** 本地化（与直接写 `Text(key)` 一致；对 App 调用方即其自身 bundle）。
    /// accessory 用 `@ViewBuilder`。
    public init(
        icon: SettingsRowIcon? = nil,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.init(icon: icon, title: Text(title), subtitle: subtitle.map { Text($0) }, accessory: accessory())
    }

    /// 运行期字符串（数据来的分类名等），verbatim 显示、不走本地化查表。
    @_disfavoredOverload
    public init<S: StringProtocol>(
        icon: SettingsRowIcon? = nil,
        title: S,
        subtitle: S? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.init(icon: icon, title: Text(title), subtitle: subtitle.map { Text($0) }, accessory: accessory())
    }

    public var body: some View {
        HStack(spacing: SettingsRowMetrics.iconTitleGap) {
            if let icon = self.icon {
                self.iconSquare(icon)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                self.title
                    .coreFont(.body)
                    .foregroundStyle(Color.contentPrimary)
                if let subtitle = self.subtitle {
                    subtitle
                        .coreFont(.footnote)
                        .foregroundStyle(Color.contentSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: CoreSpacing.md)

            HStack(spacing: CoreSpacing.xs) {
                self.accessory
            }
        }
        .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
        .padding(.vertical, CoreSpacing.sm)
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
    }

    // MARK: - Icon square

    private func iconSquare(_ icon: SettingsRowIcon) -> some View {
        CoreShape.rounded(SettingsRowMetrics.iconCornerRadius)
            .fill(icon.background)
            .frame(
                width: SettingsRowMetrics.iconSquareSize,
                height: SettingsRowMetrics.iconSquareSize
            )
            .overlay {
                Image(systemName: icon.systemName)
                    .font(.system(size: min(self.glyphSize, SettingsRowMetrics.iconSquareSize - CoreSpacing.sm * 2)))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Convenience inits

public extension SettingsRow where Accessory == EmptyView {
    /// 无尾部 accessory（LocalizedStringKey）。
    init(
        icon: SettingsRowIcon? = nil,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil
    ) {
        self.init(icon: icon, title: title, subtitle: subtitle) { EmptyView() }
    }

    /// 无尾部 accessory（运行期字符串，verbatim）。
    @_disfavoredOverload
    init<S: StringProtocol>(
        icon: SettingsRowIcon? = nil,
        title: S,
        subtitle: S? = nil
    ) {
        self.init(icon: icon, title: title, subtitle: subtitle) { EmptyView() }
    }
}

#Preview("SettingsRow — Light") {
    SettingsRowPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("SettingsRow — Dark") {
    SettingsRowPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SettingsRowPreviewGallery: View {
    @State private var notificationsOn = true

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: .init(systemName: "wifi", background: .blue),
                title: "Wi-Fi",
                subtitle: "HomeNetwork"
            ) {
                Text("On").foregroundStyle(.secondary)
                SettingsRowChevron()
            }
            Separator(inset: .leading(SettingsRowMetrics.iconAlignedDividerInset))
            SettingsRow(
                icon: .init(systemName: "bell.badge.fill", background: .red),
                title: "Notifications"
            ) {
                Toggle("Notifications", isOn: self.$notificationsOn).labelsHidden()
            }
            .tint(.green)
        }
        .background(Color.surfaceCard)
        .clipShape(CoreShape.rounded(CoreRadius.medium))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
