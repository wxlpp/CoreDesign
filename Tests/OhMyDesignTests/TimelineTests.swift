import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("Timeline")
@MainActor
struct TimelineTests {
    // MARK: - 节点状态 → 默认圆点颜色

    @Test(
        "nodeColor：StatusLevel 各档映射到对应 StatusColors emphasis token",
        arguments: [
            (StatusLevel.info, "status-accent-emphasis"),
            (StatusLevel.success, "status-success-emphasis"),
            (StatusLevel.warning, "status-attention-emphasis"),
            (StatusLevel.danger, "status-danger-emphasis"),
        ]
    )
    func nodeColorMapsToStatusColorsAsset(_ pair: (StatusLevel, String)) {
        let (status, expectedAsset) = pair
        #expect(assetName(of: Timeline.nodeColor(for: status)) == expectedAsset)
    }

    // MARK: - 节点状态 → accessibility label 键（Phase 0 预登记）

    @Test(
        "accessibilityLabelKey：StatusLevel 各档映射到 Phase 0 预登记键",
        arguments: [
            (StatusLevel.info, "Info"),
            (StatusLevel.success, "Success"),
            (StatusLevel.warning, "Warning"),
        ]
    )
    func accessibilityLabelKeyMapsDirectly(_ pair: (StatusLevel, String)) {
        let (status, expectedKey) = pair
        #expect(Timeline.accessibilityLabelKey(for: status) == expectedKey)
    }

    @Test("accessibilityLabelKey：danger 映射到 \"Error\"（非字面 \"Danger\"，对 VoiceOver 更清晰）")
    func accessibilityLabelKeyDangerMapsToError() {
        #expect(Timeline.accessibilityLabelKey(for: .danger) == "Error")
        #expect(Timeline.accessibilityLabelKey(for: .danger) != "Danger")
    }

    // MARK: - TimelineItem：默认圆点节点 init

    @Test("TimelineItem(status:content:)：node 为 nil，status 原样保留")
    func defaultNodeInitStoresStatus() {
        let item = TimelineItem(status: .success) {
            Text("Done")
        }
        #expect(item.node == nil)
        #expect(item.status == .success)
    }

    @Test("TimelineItem(content:)：status 缺省为 .info")
    func defaultNodeInitDefaultsToInfo() {
        let item = TimelineItem {
            Text("Created")
        }
        #expect(item.status == .info)
    }

    // MARK: - TimelineItem：自定义节点 init

    @Test("TimelineItem(status:node:content:)：node 非 nil（自定义节点覆盖默认圆点）")
    func customNodeInitStoresNode() {
        let item = TimelineItem(status: .danger) {
            Image(systemName: "xmark.circle.fill")
        } content: {
            Text("Failed")
        }
        #expect(item.node != nil)
        #expect(item.status == .danger)
    }

    // MARK: - id：显式传入原样保留

    @Test("TimelineItem：显式传入的 id 原样保留（不被 UUID() 缺省值覆盖）")
    func explicitIDIsPreserved() {
        let id = UUID()
        let item = TimelineItem(id: id, status: .info) {
            Text("Note")
        }
        #expect(item.id == id)
    }

    // MARK: - isLastItem：最后一条不渲染连线的 identity 判定

    @Test("isLastItem：数组末条返回 true")
    func isLastItemTrueForLastElement() {
        let items = [
            TimelineItem { Text("1") },
            TimelineItem { Text("2") },
            TimelineItem { Text("3") },
        ]
        #expect(Timeline.isLastItem(items[2], in: items) == true)
    }

    @Test("isLastItem：非末条返回 false")
    func isLastItemFalseForNonLastElements() {
        let items = [
            TimelineItem { Text("1") },
            TimelineItem { Text("2") },
            TimelineItem { Text("3") },
        ]
        #expect(Timeline.isLastItem(items[0], in: items) == false)
        #expect(Timeline.isLastItem(items[1], in: items) == false)
    }

    @Test("isLastItem：单条数组，唯一元素即末条")
    func isLastItemSingleElementArray() {
        let items = [TimelineItem { Text("only") }]
        #expect(Timeline.isLastItem(items[0], in: items) == true)
    }

    @Test("isLastItem：item 不在 items 中（不同 id）返回 false，不崩溃")
    func isLastItemNotInArrayReturnsFalse() {
        let items = [TimelineItem { Text("1") }]
        let stray = TimelineItem { Text("stray") }
        #expect(Timeline.isLastItem(stray, in: items) == false)
    }

    // MARK: - Timeline：items 原样保留

    @Test("Timeline(items:)：items 数量与顺序原样保留")
    func timelineStoresItemsInOrder() {
        let items = [
            TimelineItem(status: .info) { Text("1") },
            TimelineItem(status: .success) { Text("2") },
        ]
        let timeline = Timeline(items: items)
        #expect(timeline.items.count == 2)
        #expect(timeline.items.map(\.id) == items.map(\.id))
    }

    @Test("Timeline(items:)：空数组不崩溃")
    func timelineEmptyItemsDoesNotCrash() {
        let timeline = Timeline(items: [])
        #expect(timeline.items.isEmpty)
    }
    // MARK: - TimelineLayout（`#60` 形态 D2）

    @Test("Timeline：layout 默认 .vertical —— 现有调用方零影响")
    func timelineLayoutDefaultsToVertical() {
        let timeline = Timeline(items: [TimelineItem(status: .info) { Text(verbatim: "A") }])
        #expect(timeline.layout == .vertical)
    }

    @Test("Timeline：layout 原样保留")
    func timelineStoresLayout() {
        for layout in [TimelineLayout.vertical, .alternate, .horizontal, .grouped] {
            let timeline = Timeline(
                items: [TimelineItem(status: .info) { Text(verbatim: "A") }], layout: layout
            )
            #expect(timeline.layout == layout)
        }
    }

    @Test("TimelineLayout：四个 case 互不相等（Equatable 不是恒真）")
    func timelineLayoutEquatableIsNotDegenerate() {
        let all: [TimelineLayout] = [.vertical, .alternate, .horizontal, .grouped]
        for (i, lhs) in all.enumerated() {
            for (j, rhs) in all.enumerated() where i != j {
                #expect(lhs != rhs, "\(lhs) 与 \(rhs) 不应相等")
            }
        }
    }

    @Test("Timeline：.grouped 下 node: 槽仍被原样保留（不生效 ≠ 被改写）")
    func timelineGroupedPreservesNodeSlot() {
        let item = TimelineItem(status: .info) {
            Text(verbatim: "custom-node")
        } content: {
            Text(verbatim: "content")
        }
        let timeline = Timeline(items: [item], layout: .grouped)
        #expect(timeline.items.first?.node != nil, ".grouped 下 node 槽仍应原样保留")
        #expect(timeline.layout == .grouped)
    }

    @Test("Timeline：四种布局都能构造且 body 可求值（不 crash）")
    func timelineAllLayoutsRender() {
        let items = [
            TimelineItem(status: .info) { Text(verbatim: "A") },
            TimelineItem(status: .danger) { Text(verbatim: "B") },
            TimelineItem(status: .success) { Text(verbatim: "C") },
        ]
        for layout in [TimelineLayout.vertical, .alternate, .horizontal, .grouped] {
            _ = Timeline(items: items, layout: layout).body
        }
    }

    @Test("Timeline.alternateSlotWidth：三列几何的槽宽，且节点中心恰落在行中心")
    func timelineAlternateSlotWidth() {
        let fixed = Timeline.nodeColumnWidth + 2 * CoreSpacing.md

        let w = Timeline.alternateSlotWidth(forRowWidth: 320)
        #expect(w == (320 - fixed) / 2)
        #expect(w * 2 + fixed == 320)

        for rowWidth in [320.0, 390.0, 744.0, 1024.0] as [CGFloat] {
            let metrics = Timeline.alternateRowMetrics(forRowWidth: rowWidth)
            let rowCenter: CGFloat = rowWidth / 2
            #expect(metrics.nodeCenterX == rowCenter,
                    "行宽 \(rowWidth)：节点中心 \(metrics.nodeCenterX) 必须等于行中心 \(rowCenter)")
            let fixed = Timeline.nodeColumnWidth + 2 * CoreSpacing.md
            #expect(metrics.slotWidth * 2 + fixed == rowWidth)
        }

        for bad in [CGFloat.infinity, -CGFloat.infinity, CGFloat.nan] {
            let metrics = Timeline.alternateRowMetrics(forRowWidth: bad)
            #expect(metrics.slotWidth.isFinite, "槽宽必须有限，实际 \(metrics.slotWidth)")
            #expect(metrics.nodeCenterX.isFinite)
            #expect(metrics.rowWidth.isFinite)
            #expect(metrics.slotWidth >= 0)
        }

        #expect(Timeline.alternateSlotWidth(forRowWidth: 0) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed - 1) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: -10) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed + 2) > 0)
    }

    @MainActor
    @Test("Timeline：.grouped 删掉节点列后，默认节点项的状态语义经 accessibilityValue 补回")
    func timelineGroupedKeepsDefaultNodeStatusSemantics() {
        let defaultNodeItem = TimelineItem(status: .danger) { Text(verbatim: "失败") }
        #expect(defaultNodeItem.node == nil, "前提：这是默认节点项")
        #expect(Timeline.groupedStatusKey(for: defaultNodeItem) == "Error")

        let infoItem = TimelineItem(status: .info) { Text(verbatim: "已创建") }
        #expect(Timeline.groupedStatusKey(for: infoItem) == "Info")

        let customNodeItem = TimelineItem(status: .danger) {
            Circle()
        } content: {
            Text(verbatim: "失败")
        }
        #expect(customNodeItem.node != nil, "前提：这是自定义节点项")
        #expect(Timeline.groupedStatusKey(for: customNodeItem) == nil,
                "自定义节点项不补状态播报，否则会覆盖调用方自己的语义")

        for status in [StatusLevel.info, .success, .warning, .danger] {
            let item = TimelineItem(status: status) { Text(verbatim: "x") }
            #expect(Timeline.groupedStatusKey(for: item) == Timeline.accessibilityLabelKey(for: status))
        }
    }
}
