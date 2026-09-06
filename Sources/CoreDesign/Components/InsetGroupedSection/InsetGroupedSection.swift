import SwiftUI

// MARK: - SettingsDividerInset

/// `InsetGroupedSection` 相邻行分隔线的 leading 对齐方式。
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
public struct InsetGroupedSection<Content: View>: View {
    private let header: SectionHeader?
    private let footer: SectionFooter?
    private let dividerInset: SettingsDividerInset
    private let content: Content

    /// LocalizedStringKey 页眉/页脚——字面量在 `Bundle.main` 本地化（对 App 调用方即其自身 bundle）。
    ///
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
        self.header = header.map { SectionHeader($0) }
        self.footer = footer.map { SectionFooter($0) }
        self.dividerInset = dividerInset
        self.content = content()
    }

    /// 运行期字符串页眉/页脚（数据来的分组名等），verbatim 显示。
    @_disfavoredOverload
    public init<S: StringProtocol>(
        header: S? = nil,
        footer: S? = nil,
        dividerInset: SettingsDividerInset = .iconAligned,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header.map { SectionHeader($0) }
        self.footer = footer.map { SectionFooter($0) }
        self.dividerInset = dividerInset
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            if let header = self.header {
                header
                    .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
            }

            self.card

            if let footer = self.footer {
                footer
                    .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
            }
        }
    }

    // MARK: - Card（行 + 自动分隔线）

    private var card: some View {
        Group(subviews: self.content) { rows in
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    row
                    if row.id != rows.last?.id {
                        Separator(inset: .leading(self.dividerInset.value))
                    }
                }
            }
        }
        .surface(.grouped)
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
                        title: "Airplane Mode"
                    ) {
                        Toggle("Airplane Mode", isOn: self.$airplaneOn).labelsHidden()
                    }
                    SettingsRow(
                        icon: .init(systemName: "wifi", background: .blue),
                        title: "Wi-Fi"
                    ) {
                        Text("HomeNetwork").foregroundStyle(.secondary)
                        SettingsRowChevron()
                    }
                    SettingsRow(
                        icon: .init(systemName: "personalhotspot", background: .green),
                        title: "Personal Hotspot"
                    ) {
                        Text("Off").foregroundStyle(.secondary)
                        SettingsRowChevron()
                    }
                }
                .tint(.green)

                InsetGroupedSection(header: "About", dividerInset: .textAligned) {
                    SettingsRow(title: "Version") {
                        Text("0.4.0").foregroundStyle(.secondary)
                    }
                    SettingsRow(title: "Legal") {
                        SettingsRowChevron()
                    }
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }
}
