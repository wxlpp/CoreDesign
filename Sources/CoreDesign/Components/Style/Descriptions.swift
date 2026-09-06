import SwiftUI

// MARK: - DescriptionsColumns

/// `Descriptions` 的列数配置。
public enum DescriptionsColumns: Sendable {
    /// 单列纵向排布。
    case one
    /// 两列网格排布——大字号可访问性档位下自动强制塌成单列，见 `Descriptions` doc-comment。
    case two
}

// MARK: - DescriptionsDividerDensity

/// `Descriptions` 相邻行（`columns == .two` 时为「相邻行组」）之间的分隔线密度。
public enum DescriptionsDividerDensity: Sendable {
    /// 无分隔线。
    case none
    /// 每行之间都有分隔线（对齐 `InsetGroupedSection` 默认行为）。
    case row
}

// MARK: - DescriptionsLayout

enum DescriptionsLayout {
    static func effectiveColumns(
        _ columns: DescriptionsColumns,
        dynamicTypeSize: DynamicTypeSize
    ) -> DescriptionsColumns {
        dynamicTypeSize.isAccessibilitySize ? .one : columns
    }

    static func rowGroups(rowCount: Int, columns: DescriptionsColumns) -> [[Int]] {
        guard rowCount > 0 else { return [] }

        switch columns {
        case .one:
            return (0..<rowCount).map { [$0] }
        case .two:
            var groups: [[Int]] = []
            var index = 0
            while index < rowCount {
                if index + 1 < rowCount {
                    groups.append([index, index + 1])
                } else {
                    groups.append([index])
                }
                index += 2
            }
            return groups
        }
    }
}

// MARK: - Descriptions

/// 描述列表——`.core` `LabeledContentStyle` + `InsetGroupedSection` 分组容器的组合，
/// 换皮不重造：分组卡片 / 分隔线视觉全部继承 `InsetGroupedSection`，本组件只负责把
/// 传入的 `LabeledContent` 行按 1/2 列重新排布，再交给它渲染。
public struct Descriptions<Content: View>: View {
    private let columns: DescriptionsColumns
    private let dividerDensity: DescriptionsDividerDensity
    private let header: LocalizedStringKey?
    private let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameters:
    ///   - columns: 列数偏好，默认两列。大字号可访问性档位下会被强制覆盖为单列。
    ///   - dividerDensity: 相邻行（组）分隔线密度，默认 `.row`。
    ///   - header: 可选分组页眉，透传给内部 `InsetGroupedSection`。
    ///   - content: 描述列表的行，通常是若干 `LabeledContent`。
    public init(
        columns: DescriptionsColumns = .two,
        dividerDensity: DescriptionsDividerDensity = .row,
        header: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.dividerDensity = dividerDensity
        self.header = header
        self.content = content()
    }

    private var effectiveColumns: DescriptionsColumns {
        DescriptionsLayout.effectiveColumns(self.columns, dynamicTypeSize: self.dynamicTypeSize)
    }

    public var body: some View {
        InsetGroupedSection(header: self.header, dividerInset: .textAligned) {
            Group(subviews: self.content.labeledContentStyle(.core)) { rows in
                let rowsArray = Array(rows)
                let groups = DescriptionsLayout.rowGroups(rowCount: rowsArray.count, columns: self.effectiveColumns)
                self.groupedRows(groups: groups, rows: rowsArray)
            }
        }
    }

    @ViewBuilder
    private func groupedRows(groups: [[Int]], rows: [Subview]) -> some View {
        let identified = groups.map { (id: rows[$0[0]].id, indices: $0) }
        switch self.dividerDensity {
        case .row:
            ForEach(identified, id: \.id) { group in
                self.rowContainer(indices: group.indices, rows: rows)
            }
        case .none:
            VStack(alignment: .leading, spacing: 0) {
                ForEach(identified, id: \.id) { group in
                    self.rowContainer(indices: group.indices, rows: rows)
                }
            }
        }
    }

    @ViewBuilder
    private func rowContainer(indices: [Int], rows: [Subview]) -> some View {
        Group {
            if self.effectiveColumns == .one, indices.count == 1 {
                rows[indices[0]]
            } else {
                Grid(alignment: .leading, horizontalSpacing: CoreSpacing.lg, verticalSpacing: CoreSpacing.xs) {
                    GridRow {
                        ForEach(indices, id: \.self) { index in
                            rows[index]
                                .gridCellColumns(indices.count == 1 ? 2 : 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
        .padding(.vertical, CoreSpacing.sm)
    }
}

#Preview("Descriptions — Light") {
    DescriptionsPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Descriptions — Dark") {
    DescriptionsPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct DescriptionsPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.xl) {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("两列（默认）").coreFont(.footnote).foregroundStyle(.secondary)
                    Descriptions(header: "Order") {
                        LabeledContent("Status") { Text("Active") }
                        LabeledContent("Total") { Text("$42.00") }
                        LabeledContent("Placed") { Text("2026-07-20") }
                    }
                }

                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("单列（columns: .one）").coreFont(.footnote).foregroundStyle(.secondary)
                    Descriptions(columns: .one, header: "Contact") {
                        LabeledContent("Name") { Text("Jane Appleseed") }
                        LabeledContent("Email") { Text("jane@example.com") }
                    }
                }

                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("无分隔线（dividerDensity: .none）").coreFont(.footnote).foregroundStyle(.secondary)
                    Descriptions(dividerDensity: .none, header: "Device") {
                        LabeledContent("Model") { Text("iPhone 17 Pro") }
                        LabeledContent("Storage") { Text("512 GB") }
                        LabeledContent("Color") { Text("Titanium") }
                    }
                }

                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("大字号强制塌成单列（accessibility3，columns: .two）")
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                    Descriptions(header: "Order") {
                        LabeledContent("Status") { Text("Active") }
                        LabeledContent("Total") { Text("$42.00") }
                        LabeledContent("Placed") { Text("2026-07-20") }
                    }
                    .dynamicTypeSize(.accessibility3)
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }
}
