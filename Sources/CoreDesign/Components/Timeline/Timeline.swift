import SwiftUI

// MARK: - TimelineItem

/// `Timeline` 单条节点的数据载体。
public struct TimelineItem: Identifiable {
    public let id: UUID
    let status: StatusLevel
    let node: AnyView?
    let content: AnyView

    /// 使用默认圆点节点构造。
    ///
    /// - Parameters:
    ///   - id: stable identity，缺省由 `UUID()` 生成。
    ///   - status: 节点状态，决定默认圆点颜色，缺省 `.info`。
    ///   - content: 节点右侧内容，任意视图。
    public init<Content: View>(
        id: UUID = UUID(),
        status: StatusLevel = .info,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.status = status
        self.node = nil
        self.content = AnyView(content())
    }

    /// 使用自定义节点视图构造（替代默认圆点）。
    ///
    /// - Parameters:
    ///   - id: stable identity，缺省由 `UUID()` 生成。
    ///   - status: 节点状态。当 `node` 已显式提供时，`status` 只作为语义标记保留
    ///     （例如未来筛选/排序场景），不再驱动默认圆点颜色——颜色完全由 `node` 自身决定。
    ///   - node: 自定义节点视图（图标 / 头像等），完全替代默认圆点，不叠加任何强制颜色。
    ///     **尺寸约束**：节点方框固定 24×24pt（`Timeline.nodeColumnWidth`）且**不裁剪**——
    ///     自定义 node 应 ≤ 24×24；更大的视图（如 32–40pt 头像）会上下溢出方框、上沿侵入
    ///     上一行、下沿被连线穿过。需要更大节点时请自行把内容缩放到 24pt（如
    ///     `.frame(width: 24, height: 24)` + `.clipShape(Circle())`），或等节点列高度自适应
    ///     的后续增强（归 Phase 3 视觉评审裁决）。
    ///   - content: 节点右侧内容，任意视图。
    public init<Node: View, Content: View>(
        id: UUID = UUID(),
        status: StatusLevel = .info,
        @ViewBuilder node: () -> Node,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.status = status
        self.node = AnyView(node())
        self.content = AnyView(content())
    }
}

// MARK: - TimelineLayout

/// `Timeline` 的**整体排布形态**——与 `TimelineItem` 的 `node:` 外观槽**正交**：
/// 本枚举决定「这组节点怎么排」，`node:` 决定「单个节点画成什么」。
public enum TimelineLayout: Sendable, Equatable {
    /// 默认：左侧固定节点列 + 右侧内容，节点间竖向连线（现状形态）。
    case vertical
    /// 左右交替：内容在中轴两侧交替排布。
    /// 业界来源：Ant Design Timeline 的 `mode="alternate"`。
    case alternate
    /// 横向：节点沿水平轴排列，内容在节点下方。
    /// 业界来源：PowerPoint SmartArt 的 Basic Timeline / Final Cut Pro 的横向事件时间线。
    case horizontal
    /// 无连线的分组列表：删掉节点列与连线，只留内容。
    /// 业界来源：Apple 邮件与信息的日期分组 / GitHub 活动流。
    /// ⚠️ 本形态下 `TimelineItem.node:` 槽不生效（见上方正交性说明）。
    case grouped
}

// MARK: - Timeline

/// **材质层**: 内容. **表面角色**: 内容.
public struct Timeline: View {
    let items: [TimelineItem]
    let layout: TimelineLayout

    /// - Parameters:
    ///   - items: 时间线节点数据，按数组顺序排列。
    ///   - layout: 整体排布形态，默认 `.vertical`（现状形态）⇒ **现有调用方零影响**。
    ///     ⚠️ `.grouped` 下 `TimelineItem.node:` 槽不生效，见 `TimelineLayout` 的正交性说明。
    public init(items: [TimelineItem], layout: TimelineLayout = .vertical) {
        self.items = items
        self.layout = layout
    }

    public var body: some View {
        switch self.layout {
        case .vertical: self.verticalBody
        case .alternate: self.alternateBody
        case .horizontal: self.horizontalBody
        case .grouped: self.groupedBody
        }
    }

    private var verticalBody: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.none) {
            ForEach(self.items) { item in
                TimelineRowView(item: item, isLast: Self.isLastItem(item, in: self.items))
            }
        }
    }

    private var alternateBody: some View {
        VStack(spacing: CoreSpacing.none) {
            ForEach(Array(self.items.enumerated()), id: \.element.id) { index, item in
                TimelineAlternateRowView(
                    item: item,
                    isLast: Self.isLastItem(item, in: self.items),
                    contentSide: index.isMultiple(of: 2) ? .leading : .trailing
                )
            }
        }
    }

    struct AlternateRowMetrics: Equatable {
        let slotWidth: CGFloat
        let nodeCenterX: CGFloat
        let rowWidth: CGFloat
    }

    nonisolated static func alternateRowMetrics(forRowWidth rowWidth: CGFloat) -> AlternateRowMetrics {
        let fixed = Self.nodeColumnWidth + 2 * CoreSpacing.md
        guard rowWidth.isFinite else {
            return AlternateRowMetrics(slotWidth: 0, nodeCenterX: fixed / 2, rowWidth: fixed)
        }
        let slot = Swift.max(0, (rowWidth - fixed) / 2)
        let width = Swift.max(rowWidth, fixed)
        return AlternateRowMetrics(slotWidth: slot, nodeCenterX: width / 2, rowWidth: width)
    }

    nonisolated static func alternateSlotWidth(forRowWidth rowWidth: CGFloat) -> CGFloat {
        Self.alternateRowMetrics(forRowWidth: rowWidth).slotWidth
    }

    private var horizontalBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: CoreSpacing.lg) {
                ForEach(self.items) { item in
                    VStack(alignment: .center, spacing: CoreSpacing.sm) {
                        TimelineNodeView(item: item)
                        item.content
                    }
                }
            }
        }
    }

    private var groupedBody: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            ForEach(self.items) { item in
                GroupedRow(item: item)
            }
        }
    }

    static func groupedStatusKey(for item: TimelineItem) -> String? {
        item.node == nil ? Self.accessibilityLabelKey(for: item.status) : nil
    }

    // MARK: - Layout metrics

    nonisolated static let nodeColumnWidth: CGFloat = 24

    static let nodeDiameter: CGFloat = 10

    // MARK: - Pure logic (unit-testable via `@testable import`)

    @MainActor
    static func nodeColor(for status: StatusLevel) -> Color {
        switch status {
        case .info: .statusAccentEmphasis
        case .success: .statusSuccessEmphasis
        case .warning: .statusAttentionEmphasis
        case .danger: .statusDangerEmphasis
        }
    }

    static func accessibilityLabelKey(for status: StatusLevel) -> String {
        switch status {
        case .info: "Info"
        case .success: "Success"
        case .warning: "Warning"
        case .danger: "Error"
        }
    }

    static func isLastItem(_ item: TimelineItem, in items: [TimelineItem]) -> Bool {
        item.id == items.last?.id
    }
}

// MARK: - TimelineRowView

struct TimelineNodeView: View {
    let item: TimelineItem

    var body: some View {
        self.nodeContent
            .frame(width: Timeline.nodeColumnWidth, height: Timeline.nodeColumnWidth)
    }

    @ViewBuilder
    private var nodeContent: some View {
        if let node = self.item.node {
            node
        } else {
            Circle()
                .fill(Timeline.nodeColor(for: self.item.status))
                .frame(width: Timeline.nodeDiameter, height: Timeline.nodeDiameter)
                .accessibilityLabel(
                    Text(LocalizedStringKey(Timeline.accessibilityLabelKey(for: self.item.status)), bundle: .module)
                )
        }
    }
}

private struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CoreSpacing.md) {
            TimelineNodeView(item: self.item)

            self.item.content
                .padding(.bottom, self.isLast ? CoreSpacing.none : CoreSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            if !self.isLast {
                TimelineConnector()
                    .padding(.leading, (Timeline.nodeColumnWidth - CoreBorderWidth.thin) / 2)
            }
        }
    }
}

private struct TimelineAlternateRowView: View {
    let item: TimelineItem
    let isLast: Bool
    let contentSide: HorizontalEdge

    var body: some View {
        TimelineAlternateRowLayout {
            self.slot(.leading)
            TimelineNodeView(item: self.item)
            self.slot(.trailing)
        }
        .background(alignment: .top) {
            if !self.isLast {
                TimelineConnector()
            }
        }
    }

    @ViewBuilder
    private func slot(_ side: HorizontalEdge) -> some View {
        if side == self.contentSide {
            self.item.content
                .padding(.bottom, self.isLast ? CoreSpacing.none : CoreSpacing.lg)
                .frame(maxWidth: .infinity, alignment: side == .leading ? .trailing : .leading)
        } else {
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
        }
    }
}

private struct TimelineAlternateRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let metrics = Self.metrics(for: proposal, subviews: subviews)
        let heights = Self.subviewHeights(subviews, slotWidth: metrics.slotWidth)
        return CGSize(width: metrics.rowWidth, height: heights.max() ?? 0)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        guard subviews.count == 3 else { return }
        let metrics = Timeline.alternateRowMetrics(forRowWidth: bounds.width)
        let slot = metrics.slotWidth
        let node = Timeline.nodeColumnWidth
        let gap = CoreSpacing.md

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
            proposal: ProposedViewSize(width: slot, height: nil)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + metrics.nodeCenterX, y: bounds.minY), anchor: .top,
            proposal: ProposedViewSize(width: node, height: node)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.minX + slot + gap + node + gap, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: slot, height: nil)
        )
    }

    private static func metrics(
        for proposal: ProposedViewSize, subviews: Subviews
    ) -> Timeline.AlternateRowMetrics {
        if let width = proposal.width, width.isFinite {
            return Timeline.alternateRowMetrics(forRowWidth: width)
        }
        guard subviews.count == 3 else { return Timeline.alternateRowMetrics(forRowWidth: 0) }
        let idealSlot = Swift.max(
            subviews[0].sizeThatFits(.unspecified).width,
            subviews[2].sizeThatFits(.unspecified).width
        )
        let rowWidth = idealSlot * 2 + Timeline.nodeColumnWidth + 2 * CoreSpacing.md
        return Timeline.alternateRowMetrics(forRowWidth: rowWidth)
    }

    private static func subviewHeights(_ subviews: Subviews, slotWidth: CGFloat) -> [CGFloat] {
        guard subviews.count == 3 else { return [] }
        return [
            subviews[0].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height,
            Timeline.nodeColumnWidth,
            subviews[2].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height,
        ]
    }
}

private struct GroupedRow: View {
    let item: TimelineItem

    var body: some View {
        let base = self.item.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        if let key = Timeline.groupedStatusKey(for: self.item) {
            base.accessibilityValue(Text(LocalizedStringKey(key), bundle: .module))
        } else {
            base
        }
    }
}

private struct TimelineConnector: View {
    var body: some View {
        Rectangle()
            .fill(Color.dividerDefault)
            .frame(width: CoreBorderWidth.thin)
            .frame(maxHeight: .infinity)
            .padding(.top, Timeline.nodeColumnWidth)
    }
}

// MARK: - Preview

#Preview("Timeline — Light") {
    TimelinePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Timeline — Dark") {
    TimelinePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct TimelinePreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.xl) {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("默认圆点节点（4 种 StatusLevel 状态色）")
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                    Timeline(items: [
                        TimelineItem(status: .info) {
                            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                                Text("已创建").coreFont(.callout)
                                Text("2026-07-20 10:00").coreFont(.footnote).foregroundStyle(.secondary)
                            }
                        },
                        TimelineItem(status: .success) {
                            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                                Text("审核通过").coreFont(.callout)
                                Text("2026-07-21 14:30").coreFont(.footnote).foregroundStyle(.secondary)
                            }
                        },
                        TimelineItem(status: .warning) {
                            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                                Text("即将过期提醒").coreFont(.callout)
                                Text("2026-07-23 09:15").coreFont(.footnote).foregroundStyle(.secondary)
                            }
                        },
                        TimelineItem(status: .danger) {
                            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                                Text("处理失败").coreFont(.callout)
                                Text("2026-07-24 18:45").coreFont(.footnote).foregroundStyle(.secondary)
                            }
                        },
                    ])
                }

                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("自定义节点（图标 / 头像替代默认圆点）")
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                    Timeline(items: [
                        TimelineItem(status: .success) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.statusSuccessEmphasis)
                        } content: {
                            Text("订单已发货").coreFont(.callout)
                        },
                        TimelineItem(status: .info) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 20, height: 20)
                        } content: {
                            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                                Text("客服已接入").coreFont(.callout)
                                Text("由「小 A」跟进处理，预计 30 分钟内响应。")
                                    .coreFont(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        },
                        TimelineItem(status: .danger) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.statusDangerEmphasis)
                        } content: {
                            Text("配送异常").coreFont(.callout)
                        },
                    ])
                }

                // MARK: `#60` 形态 D2 新增的三种排布

                self.section("交替 · alternate（节点须在**同一条中轴**上，连线贯穿）") {
                    Timeline(items: Self.statusItems, layout: .alternate)
                }

                self.section("交替 · 单条（无连线）") {
                    Timeline(items: [Self.statusItems[0]], layout: .alternate)
                }

                self.section("横向 · horizontal（可横向滚动，无连线）") {
                    Timeline(items: Self.statusItems, layout: .horizontal)
                }

                self.section("分组 · grouped（无节点列；默认节点项仍播报状态）") {
                    Timeline(items: Self.statusItems, layout: .grouped)
                }

                self.section("分组 · 自定义节点项（状态播报交还调用方，不臆造）") {
                    Timeline(
                        items: [
                            TimelineItem(status: .success) {
                                Image(systemName: "checkmark.circle.fill")
                            } content: {
                                Text("订单已发货").coreFont(.callout)
                            },
                        ],
                        layout: .grouped
                    )
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }

    private static var statusItems: [TimelineItem] {
        [
            TimelineItem(status: .info) { Text("已创建").coreFont(.callout) },
            TimelineItem(status: .success) { Text("审核通过").coreFont(.callout) },
            TimelineItem(status: .warning) { Text("即将过期提醒").coreFont(.callout) },
            TimelineItem(status: .danger) { Text("处理失败").coreFont(.callout) },
        ]
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Text(verbatim: title)
                .coreFont(.footnote)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
