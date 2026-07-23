//
//  InsetGroupedSection.swift
//  CoreDesign
//

import SwiftUI

// MARK: - SettingsDividerInset

/// `InsetGroupedSection` 相邻行分隔线的 leading 对齐方式。
///
/// **顶层类型**（非嵌套在 `InsetGroupedSection<Content>` 内）：嵌套类型会随外层泛型
/// 参数特化，`InsetGroupedSection<A>.X` 与 `InsetGroupedSection<B>.X` 是不同类型、
/// 不可互换——下游想把 inset 存进配置就得捏造幻影 `Content`。顶层类型避免这个陷阱。
public enum SettingsDividerInset: Equatable, Sendable {
    /// 越过图标列、对齐标题 leading（有图标分组的 iOS 惯例,默认）。
    case iconAligned
    /// 对齐内容 leading（无图标分组）。
    case textAligned
    /// 自定义 leading inset（pt）。
    case custom(CGFloat)

    var value: CGFloat {
        switch self {
        case .iconAligned: SettingsRowMetrics.iconAlignedDividerInset
        case .textAligned: SettingsRowMetrics.textAlignedDividerInset
        case let .custom(amount): amount
        }
    }
}

// MARK: - InsetGroupedSection

/// iOS `.insetGrouped` 分组容器的**视觉**复刻（ADR-2:只复刻观感,不复刻 `List` 的
/// 数据/滚动/编辑能力）——圆角卡片 + raised 背景浮于画布之上（依赖 #140）+ 可选页眉
/// 页脚 + **相邻行自动分隔线**。
///
/// 与 `List` 不同,它能直接嵌进已有的 `ScrollView` / `VStack`——「在自定义页面里放
/// 一两个设置分组」这一最常见用法,`List` 反而做不到。
///
/// **分隔线 leading inset 自动对齐**:同一分组内相邻行之间的分隔线,默认对齐
/// `SettingsRow` 的**标题 leading**(`.iconAligned`)。inset 值从 `SettingsRowMetrics`
/// **推导**,调用方无需计算;无图标的分组用 `.textAligned`。
///
/// > 裁定记录:`.iconAligned` = `横向 padding + 图标方块宽 + 图标↔标题间距`
/// > (16+30+12 = **58pt**),对齐标题文本 leading——这是真实 iOS 设置页的分隔线惯例。
/// > 任务 AC 字面写的是「对齐图标方块**右缘**」(16+30 = 46pt),本实现有意取标题
/// > leading(多 12pt 的间距),观感更贴近系统;此 12pt 偏离列入 #144 视觉终审确认。
///
/// ```swift
/// InsetGroupedSection(header: "General", footer: "Applies to all accounts.") {
///     SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: Text("Wi-Fi")) {
///         SettingsRowChevron()
///     }
///     SettingsRow(icon: .init(systemName: "bell.fill", background: .red), title: Text("Notifications")) {
///         Toggle("Notifications", isOn: $on).labelsHidden()
///     }
/// }
/// ```
public struct InsetGroupedSection<Content: View>: View {
    private let header: LocalizedStringKey?
    private let footer: LocalizedStringKey?
    private let dividerInset: SettingsDividerInset
    private let content: Content

    /// - Parameters:
    ///   - header: 可选分组页眉（复用 `SectionHeader` 的大写 footnote 样式）。
    ///   - footer: 可选分组页脚（复用 `SectionFooter`）。
    ///   - dividerInset: 相邻行分隔线的 leading 对齐,默认 `.iconAligned`。
    ///   - content: 分组内的行（通常是若干 `SettingsRow`）。
    public init(
        header: LocalizedStringKey? = nil,
        footer: LocalizedStringKey? = nil,
        dividerInset: SettingsDividerInset = .iconAligned,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header
        self.footer = footer
        self.dividerInset = dividerInset
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            if let header = self.header {
                SectionHeader(header)
                    .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
            }

            self.card

            if let footer = self.footer {
                SectionFooter(footer)
                    .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
            }
        }
    }

    // MARK: - Card（行 + 自动分隔线）

    private var card: some View {
        // Group(subviews:)（iOS 18+）遍历**真实渲染的子视图**,在相邻两行之间插一条
        // 分隔线——因此分隔线数量恒等于 行数−1,不受行的条件渲染影响,也无需调用方摆放。
        Group(subviews: self.content) { rows in
            VStack(spacing: 0) {
                // 用 `Subview` 自带的稳定 identity（`ForEach(rows)`）而非位置索引：
                // content 里若含动态 `ForEach`（设置页常见的账户列表行），增删首行会让
                // 位置索引全体平移、过渡动画错乱、行内 @State 错配到相邻行；subview
                // identity 挂在声明来源上,不受行数增减影响。分隔线守卫改用 `last?.id`。
                ForEach(rows) { row in
                    row
                    if row.id != rows.last?.id {
                        Separator(inset: .leading(self.dividerInset.value))
                    }
                }
            }
        }
        .background(Color.surfaceCard)
        // 裁到圆角内——否则分隔线会溢出卡片的圆角缺口。经 CoreShape,非裸 RoundedRectangle。
        .clipShape(CoreShape.rounded(CoreRadius.medium))
    }
}

#Preview("InsetGroupedSection — Light") {
    InsetGroupedSectionPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("InsetGroupedSection — Dark") {
    InsetGroupedSectionPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct InsetGroupedSectionPreviewGallery: View {
    @State private var wifiOn = true
    @State private var airplaneOn = false

    var body: some View {
        ScrollView {
            VStack(spacing: CoreSpacing.xl) {
                InsetGroupedSection(header: "Connectivity", footer: "Turning on Airplane Mode disables Wi-Fi.") {
                    SettingsRow(
                        icon: .init(systemName: "airplane", background: .orange),
                        title: Text("Airplane Mode")
                    ) {
                        Toggle("Airplane Mode", isOn: self.$airplaneOn).labelsHidden()
                    }
                    SettingsRow(
                        icon: .init(systemName: "wifi", background: .blue),
                        title: Text("Wi-Fi")
                    ) {
                        Text("HomeNetwork").foregroundStyle(.secondary)
                        SettingsRowChevron()
                    }
                    SettingsRow(
                        icon: .init(systemName: "personalhotspot", background: .green),
                        title: Text("Personal Hotspot")
                    ) {
                        Text("Off").foregroundStyle(.secondary)
                        SettingsRowChevron()
                    }
                }
                .tint(.green)

                // 无图标分组：分隔线对齐内容 leading。
                InsetGroupedSection(header: "About", dividerInset: .textAligned) {
                    SettingsRow(title: Text("Version")) {
                        Text("0.4.0").foregroundStyle(.secondary)
                    }
                    SettingsRow(title: Text("Legal")) {
                        SettingsRowChevron()
                    }
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }
}
