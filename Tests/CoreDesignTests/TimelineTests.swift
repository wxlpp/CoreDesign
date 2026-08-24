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

    @Test("Timeline.alternateSlotWidth：三列几何的槽宽，且节点中心恰落在行中心")
    func timelineAlternateSlotWidth() {
        // ⚠️ `.alternate` 的「节点恒在同一条中轴」全靠这个槽宽成立。这块栽过两次
        // （PR #206 两轮 review）：
        // 1. 纯 `.frame(maxWidth: .infinity)` 分不到等宽 —— 它不会把超过半宽固有宽度的
        //    内容压回去，节点被推离行中心；
        // 2. 改用 `@State` + `onGeometryChange` 回填实测行宽 —— **反馈环自锁**，定宽槽让
        //    行宽恒等于观测值，观测值再不变化 ⇒ 宽度永久冻结在首帧，旋转屏幕都不跟随。
        // 现在槽宽是 `ProposedViewSize` 的**纯函数**，由 `TimelineAlternateRowLayout` 消费。
        let fixed = Timeline.nodeColumnWidth + 2 * CoreSpacing.md

        // 正常行宽：两槽等分剩余空间。
        let w = Timeline.alternateSlotWidth(forRowWidth: 320)
        #expect(w == (320 - fixed) / 2)
        // 两槽 + 固定部分必须正好铺满行宽，否则节点列不在中心。
        #expect(w * 2 + fixed == 320)

        // ⚠️ **承重断言**：节点中心 x 必须等于行中心 x —— 连线是按整行居中画的，这条不成立
        // 连线就穿不过节点。
        // ⚠️ **本测试的覆盖边界，写明以免被读成比实际更强的保证**（PR #206 第 4 轮的教训是
        // 「假护栏比没护栏更危险」）：它锁的是**几何计算**。节点横向不脱轴现在由
        // `placeSubviews` 的 `anchor: .top` + 本函数的 `nodeCenterX` 共同保证 —— 那是结构性
        // 的，节点视图自身尺寸再变也居中。但节点视图上的 `.frame(24×24)` 保的是**另外两件
        // 本测试够不着的事**：纵向上连线起点空档（`TimelineConnector` 的 `padding(.top, 24)`
        // 假定节点占满 24pt，圆点若只有 10pt，空档从 7pt 变 14pt），以及 `node:` 槽「固定
        // 24×24 方框」的公开契约（四种布局必须一致，否则同一个自定义节点在不同布局下长得
        // 不一样）。删掉那行 `.frame`，**本测试照绿** —— 实测过。那两件事只能靠渲染验证：
        // 跑 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 后**量**「连线 x − 圆点中心 x」
        // 是否为 0，别只看整体像不像（第 4 轮我就是把「三行共线」读成了「连线穿过节点」）。
        //
        // ⚠️ **断言必须读 `alternateRowMetrics` 的 `nodeCenterX`，不能在测试里重写一遍公式**
        // （PR #206 第 4 轮 review 抓到）：上一版算的是 `slot + md + nodeColumnWidth / 2`，
        // 即**节点列的中心**，而不是布局实际把节点放在哪。于是「删掉节点的 `.frame(24×24)`、
        // 让 10pt 圆点被 `anchor: .topLeading` 钉在列左上角」这个真实回归发生时，它照绿 ——
        // 又一条「量的是本来就对的那一半」。现在 `Layout` 与本测试共用同一份 metrics。
        // ⚠️ **`as [CGFloat]` 不能省**：不标注时数组推断为 `[Double]`，`rowWidth / 2` 就是
        // `Double`，而另一边是 `CGFloat`。SE-0307 的隐式转换让这行**照常编译**，但 `#expect`
        // 跨这两个类型展开出的比较是**恒假**的 —— 实测：打印出来 `diff=0.0`、两边都显示
        // `160.0`，断言却报 failed。反过来用 `!=` 则得到一个恒真的假守卫。两边保持同类型。
        for rowWidth in [320.0, 390.0, 744.0, 1024.0] as [CGFloat] {
            let metrics = Timeline.alternateRowMetrics(forRowWidth: rowWidth)
            let rowCenter: CGFloat = rowWidth / 2
            #expect(metrics.nodeCenterX == rowCenter,
                    "行宽 \(rowWidth)：节点中心 \(metrics.nodeCenterX) 必须等于行中心 \(rowCenter)")
            // 两槽 + 节点列 + 两处间距必须正好铺满行宽。
            let fixed = Timeline.nodeColumnWidth + 2 * CoreSpacing.md
            #expect(metrics.slotWidth * 2 + fixed == rowWidth)
        }

        // ⚠️ 非有限行宽必须被挡住 —— `.infinity` / `.nan` 会一路带进 `place` 的 proposal。
        // `Swift.max(0, .nan)` 返回 `.nan`，不显式 guard 是拦不住的。
        for bad in [CGFloat.infinity, -CGFloat.infinity, CGFloat.nan] {
            let metrics = Timeline.alternateRowMetrics(forRowWidth: bad)
            #expect(metrics.slotWidth.isFinite, "槽宽必须有限，实际 \(metrics.slotWidth)")
            #expect(metrics.nodeCenterX.isFinite)
            #expect(metrics.rowWidth.isFinite)
            #expect(metrics.slotWidth >= 0)
        }

        // 退化：窄到放不下固定部分时返回 0，**不产生负宽** —— 负值传进 place 的 proposal 会 crash。
        #expect(Timeline.alternateSlotWidth(forRowWidth: 0) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed - 1) == 0)
        #expect(Timeline.alternateSlotWidth(forRowWidth: -10) == 0)
        // 刚过临界即为正宽。
        #expect(Timeline.alternateSlotWidth(forRowWidth: fixed + 2) > 0)
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
