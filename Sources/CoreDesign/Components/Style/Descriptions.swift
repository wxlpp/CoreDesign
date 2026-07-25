//
//  Descriptions.swift
//  CoreDesign
//

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

/// `Descriptions` 的纯布局计算——不依赖 View / Environment，独立可测（见
/// `Tests/CoreDesignTests/DescriptionsTests.swift`）。
enum DescriptionsLayout {
    /// 大字号可访问性档位下，无论调用方传入的 `columns` 是什么，都强制单列——
    /// 可访问性优先于调用方偏好，是本组件既定约束（非 bug）。
    static func effectiveColumns(
        _ columns: DescriptionsColumns,
        dynamicTypeSize: DynamicTypeSize
    ) -> DescriptionsColumns {
        dynamicTypeSize.isAccessibilitySize ? .one : columns
    }

    /// 把 `rowCount` 行按 `columns` 切分成「渲染组」，每组是一组行索引（`[Int]`）：
    /// - `.one`：每组恰好 1 个索引（每行独占一组）。
    /// - `.two`：相邻两行配成一组；行数为奇数时，最后一组只含 1 个索引
    ///   （渲染时占满整行，而不是配对出一个空单元格）。
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
///
/// ```swift
/// Descriptions(columns: .two, header: "Order") {
///     LabeledContent("Status") { Text("Active") }
///     LabeledContent("Total") { Text("$42.00") }
///     LabeledContent("Placed") { Text("2026-07-20") }
/// }
/// ```
///
/// **列切分**：`columns == .two` 时相邻两行配成一组、用 `Grid` 排布；行数为奇数时
/// 最后一行单独成组、占满整行（`DescriptionsLayout.rowGroups`，纯函数，见其 doc）。
/// `columns == .one` 时每行单独纵向排布，不套 `Grid`。
///
/// **大字号塌列**：`dynamicTypeSize.isAccessibilitySize == true` 时，无论
/// `columns` 传入什么都强制单列渲染——可访问性优先于调用方偏好，是既定约束而非
/// bug（`DescriptionsLayout.effectiveColumns`）。
///
/// **分隔线密度**：`dividerDensity` 控制行（组）之间是否出现 `InsetGroupedSection`
/// 的自动分隔线——`.row` 时把每个行组作为独立顶层视图交给它（其内部
/// `Group(subviews:)` 逐一识别、组间插入 `Separator`）；`.none` 时把所有行组
/// 包进同一个 `VStack`，使它只看到一个顶层视图、不产生分隔线。**不在
/// `InsetGroupedSection` 内重复实现分隔线逻辑**——两种密度都只是改变喂给它的
/// 顶层视图形状，分隔线本身仍由它绘制。
///
/// **无障碍**：每行 `LabeledContent` 天然带有系统无障碍语义（label + value
/// 合成播报），本组件不额外定制。
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
            // `.core` 统一套用给所有传入的 `LabeledContent` 行——调用方无需在每行
            // 手动追加 `.labeledContentStyle(.core)`。环境修饰符在 `Group(subviews:)`
            // 解析之前施加，随子视图正常向下传递。
            Group(subviews: self.content.labeledContentStyle(.core)) { rows in
                let rowsArray = Array(rows)
                let groups = DescriptionsLayout.rowGroups(rowCount: rowsArray.count, columns: self.effectiveColumns)
                self.groupedRows(groups: groups, rows: rowsArray)
            }
        }
    }

    @ViewBuilder
    private func groupedRows(groups: [[Int]], rows: [Subview]) -> some View {
        // 行组身份挂到组内首行 Subview 的**稳定 id**（而非位置 offset）——中途增删行时
        // 既有组不因位移而重建（避免行内 `@State` 错配 / 过渡动画错乱），与
        // `InsetGroupedSection` 用 `Subview` 稳定 id 的先例一致。
        let identified = groups.map { (id: rows[$0[0]].id, indices: $0) }
        switch self.dividerDensity {
        case .row:
            // 每个行组都是顶层视图——`InsetGroupedSection` 自身的 `Group(subviews:)`
            // 会把它们逐一识别为独立的行，按其默认逻辑在相邻行组之间插入分隔线。
            ForEach(identified, id: \.id) { group in
                self.rowContainer(indices: group.indices, rows: rows)
            }
        case .none:
            // 所有行组包进同一个 `VStack`——对 `InsetGroupedSection` 而言这只是
            // **一个**顶层视图，其分隔线逻辑（行数 − 1）自然产出 0 条分隔线。
            VStack(alignment: .leading, spacing: CoreSpacing.md) {
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
                                // 奇数行数的最后一组只含 1 个索引——占满整行，而不是
                                // 空出第二列（`DescriptionsLayout.rowGroups` 已保证
                                // 这类组恰好 1 个元素）。
                                .gridCellColumns(indices.count == 1 ? 2 : 1)
                        }
                    }
                }
            }
        }
        // 行自内边距——`InsetGroupedSection` 的卡片不提供行内边距（既有观感全靠行自带
        // padding，见 `SettingsRow`）。水平 inset 取 `SettingsRowMetrics.horizontalPadding`，
        // 与 `.textAligned` 分隔线 inset 同源，从而文字 leading 与分隔线 leading 对齐、
        // 首末行不顶卡片圆角；垂直取 `CoreSpacing.sm`（对照 `SettingsRow`，但不强制 44pt
        // minHeight——键值行可比设置行更紧凑）。
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
