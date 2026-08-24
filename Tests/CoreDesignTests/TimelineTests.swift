import SwiftUI
import Testing
@testable import CoreDesign

// Timeline（Issue #164）——覆盖面：`StatusLevel` → 默认圆点颜色 / accessibility label 键
// 的映射逻辑，`TimelineItem` 两种 designated init 的构造参数保留，以及「最后一条不渲染
// 连线」的 identity 判定。真实纵向排布 / 连线几何渲染留给 iOS Simulator 视觉评审
// （见 CLAUDE.md 验证边界章节），与 `RatingTests` 同样的取舍。
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
        // ⚠️ 破坏性变更的防线：新参数带默认值（源码兼容）+ 默认值 == 现状（行为兼容）。
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
        // ⚠️ 公约 §2 形态 D2 的正交性约定：.grouped 不渲染节点列 ⇒ node: 槽**不生效**，
        // 但存储层**仍保留**它——「不生效」是渲染层的事，不是存储层的事。改写掉会让调用方
        // 切回 .vertical 时丢配置。
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
        // ⚠️ 只证「不 crash」，**不证渲染正确** —— 视觉正确性靠 #Preview 人工抽查。
        let items = [
            TimelineItem(status: .info) { Text(verbatim: "A") },
            TimelineItem(status: .danger) { Text(verbatim: "B") },
            TimelineItem(status: .success) { Text(verbatim: "C") },
        ]
        for layout in [TimelineLayout.vertical, .alternate, .horizontal, .grouped] {
            _ = Timeline(items: items, layout: layout).body
        }
    }

    @Test("Timeline.alternateSlotWidth：三列几何的槽宽，窄行退回弹性")
    func timelineAlternateSlotWidth() {
        // ⚠️ `.alternate` 的「节点恒在同一条中轴」全靠这个槽宽成立：只用两个
        // `.frame(maxWidth: .infinity)` 分不到等宽 —— 它不会把超过半宽固有宽度的内容压回去
        // （PR #206 第 2 轮 review 抓到），必须实测行宽后显式下发定宽。
        let fixed = Timeline.nodeColumnWidth + 2 * CoreSpacing.md

        // 正常行宽：两槽等分剩余空间 ⇒ 节点列几何居中。
        let w = Timeline.alternateSlotWidth(forRowWidth: 320)
        #expect(w == (320 - fixed) / 2)
        // 两槽 + 固定部分必须正好铺满行宽，否则节点列不在中心。
        #expect(w.map { $0 * 2 + fixed } == 320)

        // 首帧行宽未知 ⇒ nil ⇒ 退回弹性槽，不把内容压成 0 宽。
        #expect(Timeline.alternateSlotWidth(forRowWidth: 0) == nil)
        // 窄到放不下节点列本身 ⇒ 同样退回弹性，不产生负宽（`.frame(width:)` 传负值会 crash）。
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed) == nil)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed - 1) == nil)
        #expect(Timeline.alternateSlotWidth(forRowWidth: -10) == nil)
        // 刚过临界即为正宽。
        #expect((Timeline.alternateSlotWidth(forRowWidth: fixed + 2) ?? -1) > 0)
    }

    @MainActor
    @Test("Timeline：.grouped 删掉节点列后，默认节点项的状态语义经 accessibilityValue 补回")
    func timelineGroupedKeepsDefaultNodeStatusSemantics() {
        // PR #206 review 抓到的无障碍回归：.grouped 不渲染节点列 ⇒ 默认圆点原本挂在自己
        // 身上的 Info/Success/Warning/Error 标签一并消失，而 Timeline 的公共文档仍承诺
        // 默认节点携带这些状态语义。视觉上「没有节点」是本形态的定义，状态信息不该跟着没。
        // ⚠️ 断言打在 `groupedStatusKey(for:)` 的**返回值**上。上一版调的是
        // `applyGroupedStatusValue(_:item:) -> some View` 并 `_ =` 丢弃返回值 —— 不透明
        // View 断言不了，实测把 `item.node == nil` 改成 `if false`，整套测试照样 403
        // 全绿（PR #206 第 2 轮 review 抓到的恒真测试）。
        let defaultNodeItem = TimelineItem(status: .danger) { Text(verbatim: "失败") }
        #expect(defaultNodeItem.node == nil, "前提：这是默认节点项")
        // ⚠️ danger → "Error" 是非字面对应，一并锁住。
        #expect(Timeline.groupedStatusKey(for: defaultNodeItem) == "Error")

        let infoItem = TimelineItem(status: .info) { Text(verbatim: "已创建") }
        #expect(Timeline.groupedStatusKey(for: infoItem) == "Info")

        // ⚠️ 传了 node: 的项**不补** —— 其无障碍语义由调用方在自己的节点视图里决定，
        // 本形态既然不渲染那个节点，也就不该替调用方臆造一个状态播报。
        let customNodeItem = TimelineItem(status: .danger) {
            Circle()
        } content: {
            Text(verbatim: "失败")
        }
        #expect(customNodeItem.node != nil, "前提：这是自定义节点项")
        #expect(Timeline.groupedStatusKey(for: customNodeItem) == nil,
                "自定义节点项不补状态播报，否则会覆盖调用方自己的语义")

        // 四种状态的键与默认节点那条通路同源，不另立一套。
        for status in [StatusLevel.info, .success, .warning, .danger] {
            let item = TimelineItem(status: status) { Text(verbatim: "x") }
            #expect(Timeline.groupedStatusKey(for: item) == Timeline.accessibilityLabelKey(for: status))
        }
    }
}
