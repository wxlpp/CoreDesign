//
//  SettingsRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - SettingsRowMetrics

/// `SettingsRow` 与 `InsetGroupedSection` **共享**的布局常量——分组分隔线的 leading
/// inset 从这里推导（图标方块宽 + 图标↔标题间距），不在两个组件里各自硬编码,
/// 否则图标尺寸一改就错位。
enum SettingsRowMetrics {
    /// iOS 设置那种圆角色块的边长。iOS 系统约 29pt,这里取 30 便于对齐。
    static let iconSquareSize: CGFloat = 30
    /// 图标方块 ↔ 标题的水平间距。
    static let iconTitleGap: CGFloat = CoreSpacing.md
    /// 行内容的左右内边距。
    static let horizontalPadding: CGFloat = CoreSpacing.lg
    /// 图标色块的圆角。
    static let iconCornerRadius: CGFloat = CoreRadius.small

    /// 分隔线对齐**标题 leading**（越过图标列）时的 inset——iOS 有图标的分组行惯例。
    static var iconAlignedDividerInset: CGFloat {
        self.horizontalPadding + self.iconSquareSize + self.iconTitleGap
    }
    /// 分隔线对齐**内容 leading**（无图标列）时的 inset。
    static var textAlignedDividerInset: CGFloat {
        self.horizontalPadding
    }
}

// MARK: - SettingsRowIcon

/// iOS 设置行左侧的圆角色块 + 白色 SF Symbol。
public struct SettingsRowIcon: Equatable, Sendable {
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
///
/// **既能放进 `InsetGroupedSection`,也能直接作原生 `List` 的行**（ADR-2）——它只画
/// 内容与内边距,不画自己的背景/分隔线;背景与圆角由容器（`InsetGroupedSection` 或
/// `List`）负责。
///
/// > 放进 `List` 时:SettingsRow 自带 `horizontalPadding`(16pt),而 `List` 行默认
/// > 还有自己的 row insets,两者会叠加成过宽的 leading。要贴合 iOS 设置观感,给该行
/// > 加 `.listRowInsets(EdgeInsets())` 清零 List 侧 inset,由 SettingsRow 独占内边距。
/// > List 场景的最终观感以 #144 视觉终审为准。
///
/// accessory 用 `@ViewBuilder` 泛型,支持任意视图:value 文本、`SettingsRowChevron`、
/// `Toggle`、或自定义。**尾部挂 `Toggle` 时不写死强调色**——`Toggle` 自然读环境
/// `.tint`,与 #143 的 `.core` toggle 逃生口(用系统 Toggle + `.tint`)协同。
///
/// ```swift
/// SettingsRow(
///     icon: .init(systemName: "bell.badge.fill", background: .red),
///     title: "Notifications"
/// ) {
///     Toggle("", isOn: $on).labelsHidden()
/// }
/// .tint(.green) // Toggle 跟随
/// ```
public struct SettingsRow<Accessory: View>: View {
    private let icon: SettingsRowIcon?
    private let title: Text
    private let subtitle: Text?
    private let accessory: Accessory

    /// Designated init——accessory 用 `@ViewBuilder`。
    public init(
        icon: SettingsRowIcon? = nil,
        title: Text,
        subtitle: Text? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
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
            // 把标题 + 副标题合成**单个**无障碍元素（VoiceOver 读作 "Wi-Fi, HomeNetwork"）。
            // 只合这一格、**不含 accessory**——若把整行 combine，尾部的交互 accessory
            // （如 Toggle）会被并进静态元素、丢掉可操作性；accessory 保持独立焦点。
            .accessibilityElement(children: .combine)

            Spacer(minLength: CoreSpacing.md)

            self.accessory
        }
        .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
        .padding(.vertical, CoreSpacing.sm)
        // 命中高度地板 44pt（Apple HIG 最小可点击目标）；大字号下 minHeight 不裁切、自然撑高。
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
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(.white)
            }
            // 图标是装饰,语义由 title 承载（与 CoreLabelStyle 一致）。
            .accessibilityHidden(true)
    }
}

// MARK: - Convenience inits

public extension SettingsRow where Accessory == EmptyView {
    /// 无尾部 accessory。
    init(
        icon: SettingsRowIcon? = nil,
        title: Text,
        subtitle: Text? = nil
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
    @State private var wifiOn = true

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: .init(systemName: "wifi", background: .blue),
                title: Text("Wi-Fi"),
                subtitle: Text("HomeNetwork")
            ) {
                Text("On").foregroundStyle(.secondary)
                SettingsRowChevron()
            }
            Separator(inset: .leading(SettingsRowMetrics.iconAlignedDividerInset))
            SettingsRow(
                icon: .init(systemName: "bell.badge.fill", background: .red),
                title: Text("Notifications")
            ) {
                Toggle("", isOn: self.$wifiOn).labelsHidden()
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
