//
//  InsetGroupedSection.swift
//  CoreDesign
//

import SwiftUI

// MARK: - InsetGroupedSection

/// iOS `.insetGrouped` 分组容器的**视觉**复刻（ADR-2:只复刻观感,不复刻 `List` 的
/// 数据/滚动/编辑能力）——圆角卡片 + raised 背景浮于画布之上（依赖 #140）+ 可选页眉
/// 页脚 + **相邻行自动分隔线**。
///
/// 与 `List` 不同,它能直接嵌进已有的 `ScrollView` / `VStack`——「在自定义页面里放
/// 一两个设置分组」这一最常见用法,`List` 反而做不到。
///
/// **分隔线 leading inset 自动对齐**:同一分组内相邻行之间的分隔线,默认从图标列右缘
/// 起始(`.iconAligned`),对齐 `SettingsRow` 的标题 leading。inset 值从
/// `SettingsRowMetrics`（图标方块宽 + 间距）**推导**,调用方无需计算;无图标的分组
/// 用 `.textAligned`。
///
/// ```swift
/// InsetGroupedSection(header: "General", footer: "Applies to all accounts.") {
///     SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: Text("Wi-Fi")) {
///         SettingsRowChevron()
///     }
///     SettingsRow(icon: .init(systemName: "bell.fill", background: .red), title: Text("Notifications")) {
///         Toggle("", isOn: $on).labelsHidden()
///     }
/// }
/// ```
public struct InsetGroupedSection<Content: View>: View {
    /// 分隔线的 leading 对齐方式。
    public enum DividerInset: Equatable, Sendable {
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

    private let header: LocalizedStringKey?
    private let footer: LocalizedStringKey?
    private let dividerInset: DividerInset
    private let content: Content

    /// - Parameters:
    ///   - header: 可选分组页眉（复用 `SectionHeader` 的大写 footnote 样式）。
    ///   - footer: 可选分组页脚（复用 `SectionFooter`）。
    ///   - dividerInset: 相邻行分隔线的 leading 对齐,默认 `.iconAligned`。
    ///   - content: 分组内的行（通常是若干 `SettingsRow`）。
    public init(
        header: LocalizedStringKey? = nil,
        footer: LocalizedStringKey? = nil,
        dividerInset: DividerInset = .iconAligned,
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
                ForEach(rows.indices, id: \.self) { index in
                    rows[index]
                    if index != rows.count - 1 {
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
                        Toggle("", isOn: self.$airplaneOn).labelsHidden()
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
