//
//  Timeline.swift
//  CoreDesign
//

import SwiftUI

// MARK: - TimelineItem

/// `Timeline` 单条节点的数据载体。
///
/// 节点状态色**直接复用 `StatusLevel`**（`info/success/warning/danger`），不新增公开
/// 状态语义枚举——承接 `.claude/epics/semi-mobile-components/phase0-decisions.md` §1
/// 的架构决定。
///
/// 两个 designated init：
/// - 省略 `node` → 使用默认圆点，颜色按 `status` 走 `Timeline.nodeColor(for:)`。
/// - 显式传 `node` → 调用方提供任意视图（图标 / 头像等）完全替代默认圆点，本类型不
///   对其施加颜色 / 样式。
///
/// `id` 默认由 `UUID()` 生成——若 `Timeline` 由外部可变状态驱动（增删节点），调用方
/// 应显式传入稳定 `id`，否则每次视图刷新重建 `TimelineItem` 会产生新 identity，
/// 引发不必要的插入/删除动画（与 SwiftUI `List`/`ForEach` 数据驱动组件的通用注意事项
/// 一致，`ToastItem` 同样如此）。
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
///
/// 判定依据：`docs/component-contract.md` §2 形态 **D2（配置枚举）**。⚠️ **为什么不是 D1**：
/// `TimelineItem.node:` 确是**真外观槽**（有默认画法 `TimelineNodeView`、替换的是
/// 组件的视觉主张），但它管的是**单个节点的画法**，而下面三个候选是**容器级排布**
/// （左右交替 / 换轴 / 删掉整个节点列）—— 槽**够不着**容器。⇒ D1 不完整成立。
///
/// ⚠️ **正交性的代价**（与 `StepsPresentation` 同一处置）：`.grouped` 下**不渲染节点列**
/// ⇒ 调用方传的 `node:` 槽**无处安放、静默不生效**。这是有意的静默——传了不生效不是错误、
/// 只是无效，因此不加运行期断言；`TimelineItem` 的存储层仍**原样保留** `node`，切回其余
/// 布局时不丢配置。
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
///
/// 纵向时间线：节点（node）+ 连线（line）+ 节点右侧内容（content）。
///
/// 数据驱动——`items: [TimelineItem]`，与 `ToastItem` / `List` 的通用形态一致。每条
/// `TimelineItem` 默认渲染为一个按 `status` 取色的圆点节点；调用方也可以在构造
/// `TimelineItem` 时显式传入 `node` 以任意视图（图标 / 头像等）替代默认圆点。
///
/// 节点状态色直接复用 `StatusLevel`（`info/success/warning/danger`），映射到
/// `StatusColors` 的 emphasis 档（见 `Timeline.nodeColor(for:)`）；连线颜色复用
/// `Color.dividerDefault`（= 系统 `separator` 色），随系统外观自动更新。
///
/// > 连线宽度取 `CoreBorderWidth.thin`（1pt）而非 phase0-decisions §1 所述的 separator
/// > hairline——竖向长连线在 hairline（0.5pt / 1 物理像素）下过淡、断续感明显，1pt 观感更实。
/// > 这是对「连线宽度对齐 Separator」决策的**有意偏离**（与 Steps 横向连线取 `.thick` 同源，
/// > 均因指示性连线需要比分隔线更强的存在感），phase0/013 收口时统一记录。
///
/// ## 布局
///
/// 每行是 `HStack(alignment: .top)`：左侧固定 `nodeColumnWidth × nodeColumnWidth` 的
/// 节点方框（默认圆点或自定义 `node` 均在此方框内居中），右侧 `content`。连线以
/// `.background(alignment:)` 挂在整行 `HStack` 之下——`.background` 的内容会被提议整行
/// **已解析出的具体尺寸**（而非未约束的 ideal 尺寸），这让 `Rectangle().frame(maxHeight:
/// .infinity)` 能正确撑到「本行实际高度」而不是无界展开或塌缩到 shape 的 10×10 缺省尺寸——
/// 若改用「line 作为 node 列内的普通子视图 + `frame(maxHeight: .infinity)`」，会在
/// `VStack`/`ScrollView` 这类本身按内容 hug 高度的容器里得到不可预期的结果（flexible
/// 子视图在未约束 proposal 下退化为 shape 缺省尺寸，或在祖先意外给出具体高度时被错误拉伸）。
/// 最后一行不渲染连线。
///
/// ```swift
/// Timeline(items: [
///     TimelineItem(status: .success) {
///         Text("审核通过")
///     },
///     TimelineItem(status: .warning) {
///         Text("即将过期")
///     },
///     TimelineItem(status: .danger) {
///         Image(systemName: "xmark.circle.fill")
///             .foregroundStyle(Color.statusDangerEmphasis)
///     } content: {
///         Text("处理失败")
///     },
/// ])
/// ```
///
/// ## Accessibility
///
/// 默认圆点节点携带 `accessibilityLabel`，取 Phase 0 预登记键
/// （`.claude/epics/semi-mobile-components/phase0-decisions.md` §2：
/// `StatusLevel.info/success/warning/danger` → `"Info"/"Success"/"Warning"/"Error"`），
/// 经 `String` → `LocalizedStringKey` 转换后以 `bundle: .module` 消费（见
/// `Timeline.accessibilityLabelKey(for:)`）。**自定义 `node` 不叠加该 label**——自定义
/// 内容可能自带其他语义（例如头像 + 姓名），由调用方自行决定 accessibility 表达，本组件
/// 不代为覆盖。
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

    /// `.alternate`：内容在**中轴**两侧交替 —— 偶数索引在左、奇数在右。
    ///
    /// ⚠️ 走**独立的居中三列行**（`TimelineAlternateRowView`）而不是给 `TimelineRowView`
    /// 传一个 `alignment`：后者是「节点列在最左 + 内容在右」的两列几何，它的连线画在
    /// `.background(alignment: .topLeading)` 并按 `nodeColumnWidth` 做 leading padding。
    /// 把内容换到左侧只会让**节点跑到行尾、连线仍留在最左**，两者各画各的、中轴根本不存在
    /// （PR #206 review 抓到）。交替形态的定义就是「节点恒在中轴、内容左右换边」⇒ 几何上
    /// 必须是「弹性左槽 | 固定节点列 | 弹性右槽」，节点列的水平位置与索引奇偶无关。
    private var alternateBody: some View {
        // ⚠️ **槽宽由 `TimelineAlternateRowLayout` 从 proposal 直接算**，既不能靠两个
        // `.frame(maxWidth: .infinity)` 各拿一半，也不能靠 `@State` 回填实测宽度。
        // 两版都错过，都记在这里：
        //
        // 1. **纯弹性槽**（初版）：`maxWidth: .infinity` **不会把子视图压到它自己的固有宽度
        //    以下**。内容一旦有大于半宽的固有宽度（固定尺寸图片 / `.fixedSize()` 文本 /
        //    不可断行的长 token），内容槽就拿走多于一半，节点列偏离行中心，而连线是按整行
        //    居中画的 ⇒ 中轴逐行左右横跳。
        // 2. **`@State` + `onGeometryChange` 回填**（第二版）：**反馈环自锁**。观测的是
        //    `VStack` 自己的已解析宽度，而定宽槽让行宽恒等于 `measuredWidth`，`VStack` 宽度
        //    随之恒定 ⇒ 观测值再不变化 ⇒ action 再不触发 ⇒ 宽度**永久冻结在首帧那个值**：
        //    旋转屏幕 / 拖 Split View / 缩窗口都不跟随，且首帧那次若碰上溢出行，溢出后的
        //    行宽会被当作基准固化下来，整块比容器还宽。
        //
        // ⇒ 用 `Layout`：它在 `sizeThatFits` / `placeSubviews` 里**直接拿到 `ProposedViewSize`**，
        // 一趟出结果 —— 无 `@State`、无反馈环、无首帧闪烁，proposal 变了自然重算。
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

    /// `.alternate` 单行的三列几何。**`Layout` 与测试共用这一份** —— 测试若自己重写一遍
    /// 公式，就变成「量本来就对的那一半」，改动 `placeSubviews` 也照绿（PR #206 第 4 轮
    /// review 抓到的正是这个形态）。
    struct AlternateRowMetrics: Equatable {
        /// 单侧内容槽宽度。
        let slotWidth: CGFloat
        /// 节点列**中心**相对行左边缘的 x。连线按整行居中画 ⇒ 这个值必须等于 `rowWidth / 2`。
        let nodeCenterX: CGFloat
        /// 行宽（回声，便于断言「两槽 + 固定部分正好铺满」）。
        let rowWidth: CGFloat
    }

    /// 由行宽求三列几何。三列：`槽 | nodeColumnWidth | 槽`，两处间距各 `CoreSpacing.md`。
    ///
    /// ⚠️ 窄到放不下固定部分、或行宽非有限（`.infinity` / `.nan`，见
    /// `TimelineAlternateRowLayout.sizeThatFits`）时槽宽取 `0` —— 负值或非有限值传进
    /// `place` 的 proposal 会让布局崩掉。
    nonisolated static func alternateRowMetrics(forRowWidth rowWidth: CGFloat) -> AlternateRowMetrics {
        let fixed = Self.nodeColumnWidth + 2 * CoreSpacing.md
        guard rowWidth.isFinite else {
            return AlternateRowMetrics(slotWidth: 0, nodeCenterX: fixed / 2, rowWidth: fixed)
        }
        let slot = Swift.max(0, (rowWidth - fixed) / 2)
        let width = Swift.max(rowWidth, fixed)
        return AlternateRowMetrics(slotWidth: slot, nodeCenterX: width / 2, rowWidth: width)
    }

    /// 单侧内容槽宽度（`alternateRowMetrics` 的便捷投影）。
    nonisolated static func alternateSlotWidth(forRowWidth rowWidth: CGFloat) -> CGFloat {
        Self.alternateRowMetrics(forRowWidth: rowWidth).slotWidth
    }

    /// `.horizontal`：节点沿水平轴排列，内容在节点下方。
    ///
    /// ⚠️ 横向下**不画节点间连线** —— 竖向连线的实现（`TimelineRowView` 的 background
    /// `Rectangle` + `padding(.top:)`）依赖「节点在上、内容在下」的纵向几何，换轴后那套
    /// padding 计算不成立。横向连线属独立形态，本轮不引入。
    ///
    /// ⚠️ 这条原先写作「`#60` 承接」，但**本 PR 就是 #60** —— 合并即成悬空引用（与
    /// `ComponentExtensionPointGuard` 里那两条「不再指向 #60」的缺口同型，PR #206 第 2 轮
    /// review 抓到）。横向连线**尚无承接 issue**，需要时另开。
    private var horizontalBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: CoreSpacing.lg) {
                ForEach(self.items) { item in
                    VStack(alignment: .center, spacing: CoreSpacing.sm) {
                        TimelineNodeView(item: item)
                            .frame(width: Self.nodeColumnWidth, height: Self.nodeColumnWidth)
                        item.content
                    }
                }
            }
        }
    }

    /// `.grouped`：删掉节点列与连线，只留内容 —— 判定时判「**槽**」的依据正是这一点。
    ///
    /// ⚠️ 本形态下 `item.node` **不被渲染**（存储层仍保留，见 `TimelineLayout` 正交性说明）。
    private var groupedBody: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            ForEach(self.items) { item in
                GroupedRow(item: item)
            }
        }
    }

    /// `.grouped` 下该项要补播的状态键；无需补播时为 `nil`。纯函数。
    ///
    /// ⚠️ PR #206 review 抓到的无障碍回归：本形态不渲染节点列，于是**默认圆点**原本挂在
    /// 自己身上的 `Info` / `Success` / `Warning` / `Error` 标签一并消失 —— 而 `Timeline`
    /// 的公共文档仍承诺默认节点携带这些状态语义。视觉上「没有节点」是本形态的定义，
    /// 状态信息却不该跟着消失。
    ///
    /// ⚠️ 只对**无自定义节点**的项补 —— 传了 `node:` 的项，其无障碍语义由调用方在自己的
    /// 节点视图里决定，本形态既然不渲染那个节点，也就不该替调用方臆造一个状态播报。
    ///
    /// ⚠️ **判据抽成返回 `String?` 的纯函数，而不是留在 `some View` 里**（PR #206 第 2 轮
    /// review 抓到）：上一版是 `static func applyGroupedStatusValue(_:item:) -> some View`，
    /// 号称「提成 static 是为了可测」，但不透明 `View` 断言不了，测试只能 `_ =` 掉返回值。
    /// 实测：把 `item.node == nil` 改成 `if false`，整套测试**照样 403 全绿**。
    static func groupedStatusKey(for item: TimelineItem) -> String? {
        item.node == nil ? Self.accessibilityLabelKey(for: item.status) : nil
    }

    // MARK: - Layout metrics

    /// 节点方框边长（pt）——默认圆点与自定义 `node` 均在此方框内居中对齐，保证连线的
    /// 竖直起点（方框底部）不因节点内容尺寸不同而错位。
    /// ⚠️ `nonisolated`：`TimelineAlternateRowLayout` 的 `Layout` 见证方法是 nonisolated 的，
    /// 而本库默认 MainActor 隔离。不可变常量跨隔离读取无数据竞争风险。
    nonisolated static let nodeColumnWidth: CGFloat = 24

    /// 默认圆点节点直径（pt）。
    static let nodeDiameter: CGFloat = 10

    // MARK: - Pure logic (unit-testable via `@testable import`)

    /// 节点状态 → 默认圆点颜色。取 `StatusColors` 的 emphasis 档（实色，与 `StateLabel`
    /// 的 emphasis 背景同档），保证在浅色/深色两端都有足够的辨识度。
    @MainActor
    static func nodeColor(for status: StatusLevel) -> Color {
        switch status {
        case .info: .statusAccentEmphasis
        case .success: .statusSuccessEmphasis
        case .warning: .statusAttentionEmphasis
        case .danger: .statusDangerEmphasis
        }
    }

    /// 节点状态 → accessibility label 的 Phase 0 预登记键（原始字符串，未做本地化查表）。
    /// 提取为纯函数：`bundle: .module` 漏传是静默 fallback（英文环境下输出恰好不变，直到
    /// 非英文本地化才暴露），需要能被单测锁定「danger → \"Error\"」这类非字面对应关系。
    static func accessibilityLabelKey(for status: StatusLevel) -> String {
        switch status {
        case .info: "Info"
        case .success: "Success"
        case .warning: "Warning"
        case .danger: "Error"
        }
    }

    /// 判断 `item` 是否是 `items` 中的最后一条——最后一条不渲染连线。用 `id` 而非位置
    /// 索引比较：与 `InsetGroupedSection` 的分隔线守卫（`row.id != rows.last?.id`）同一
    /// 理由，identity 判定不受调用方后续增删列表项影响。
    static func isLastItem(_ item: TimelineItem, in items: [TimelineItem]) -> Bool {
        item.id == items.last?.id
    }
}

// MARK: - TimelineRowView

/// 节点方框内的画法（internal）：有 `node:` 槽走槽，否则走默认圆点。
///
/// ⚠️ 从 `TimelineRowView` 抽出来，供 `.horizontal` 布局复用 —— 同一套节点画法在四种布局
/// 下必须一致，各写一份会让「传了 `node:` 在某个布局下长得不一样」这种 bug 无声发生。
struct TimelineNodeView: View {
    let item: TimelineItem

    var body: some View {
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

/// 单条时间线行（internal）：节点方框 + 连线（背景）+ content。
///
/// ⚠️ 本视图的几何是**「节点列在最左 + 内容在右」的两列**，连线随之钉死在
/// `.topLeading`。`.alternate` 需要的是「节点恒在中轴」，那是另一套几何 ⇒ 由
/// `TimelineAlternateRowView` 承担，不要给本视图加 `alignment` 参数把节点挪到行尾
/// （连线不会跟着走，PR #206 review 抓到过这个形态）。
private struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CoreSpacing.md) {
            TimelineNodeView(item: self.item)
                .frame(width: Timeline.nodeColumnWidth, height: Timeline.nodeColumnWidth)

            self.item.content
                .padding(.bottom, self.isLast ? CoreSpacing.none : CoreSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            if !self.isLast {
                TimelineConnector()
                    // 水平居中于最左侧的节点方框。
                    .padding(.leading, (Timeline.nodeColumnWidth - CoreBorderWidth.thin) / 2)
            }
        }
    }
}

/// `.alternate` 的单行（internal）：**弹性左槽 | 固定节点列 | 弹性右槽**。
///
/// 节点列的水平位置与索引奇偶**无关** —— 三列宽度分配固定，内容只是换边占用左槽或右槽，
/// 另一侧留空。因此中轴（节点中心）在整列行之间是**同一条竖线**，连线随之居中即可与所有
/// 节点对齐。这正是 `TimelineRowView` 的两列几何做不到的（PR #206 review 抓到：给它传
/// `alignment` 只把节点挪到行尾，连线仍留在最左，两者各画各的）。
private struct TimelineAlternateRowView: View {
    let item: TimelineItem
    let isLast: Bool
    /// 本行内容占左槽还是右槽。节点列不受它影响。
    let contentSide: HorizontalEdge

    var body: some View {
        TimelineAlternateRowLayout {
            self.slot(.leading)
            // ⚠️ **`.frame` 不能省，`place` 的 proposal 顶不了它的班**（PR #206 第 4 轮
            // review 抓到）：proposal 只是「提议」，而 `TimelineNodeView` 的默认圆点是
            // `Circle().frame(width: nodeDiameter, height: nodeDiameter)`，对任何提议都
            // 回报 10×10。搬去 `Layout` 时删掉这行，圆点就被 `anchor: .topLeading` 钉在
            // 24pt 列的左上角 ⇒ 比中轴左偏 (24-10)/2 = 7pt、比设计上移 7pt，连线整条从
            // 圆点右侧擦过去、不穿过任何一个点。
            // ⚠️ 另外这也是 `node:` 槽的公开契约（本文件类型文档「节点方框固定 24×24pt」）：
            // 四种布局必须一致装框，否则同一个自定义 `node:` 在不同布局下长得不一样 ——
            // 正是 `TimelineNodeView` 抽出来要防的那类 bug。
            TimelineNodeView(item: self.item)
                .frame(width: Timeline.nodeColumnWidth, height: Timeline.nodeColumnWidth)
            self.slot(.trailing)
        }
        // 连线居中于**整行** —— 三列几何下行中心恰好就是节点中心，见
        // `Timeline.alternateSlotWidth(forRowWidth:)` 的说明。
        .background(alignment: .top) {
            if !self.isLast {
                TimelineConnector()
            }
        }
    }

    /// 一侧的内容槽：本行内容归属该侧时渲染内容，否则渲染空槽以维持三列几何。
    ///
    /// ⚠️ 槽宽由 `TimelineAlternateRowLayout` 在 place 时下发，这里**不**加任何 `.frame`
    /// 宽度约束 —— 加了会与 Layout 的提议打架。
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

/// `.alternate` 单行的三列布局（internal）：**弹性左槽 | 固定节点列 | 弹性右槽**。
///
/// ⚠️ **为什么是 `Layout` 而不是 `HStack` + `.frame`**：见 `Timeline.alternateBody` 里记的
/// 两次失败。要点是 `Layout` 能**直接读到 `ProposedViewSize`** —— 槽宽是父级提议的纯函数，
/// 不需要把已解析尺寸绕回 `@State`，因而没有那个会自锁冻结的反馈环，proposal 一变就重算。
///
/// 三个 subview 的顺序固定为 `[左槽, 节点, 右槽]`。节点列的 x 只取决于槽宽与间距、**与索引
/// 奇偶无关** ⇒ 所有行的节点中心落在同一条竖线上。
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
        // ⚠️ 锚到**行中心**而不是「左边缘 + 槽宽 + 间距」：节点自身尺寸再变也不脱轴，
        // 与连线（`.background(alignment: .top)`，同样按行居中）用的是同一个 x。
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

    /// 由 proposal 求本行几何。
    ///
    /// ⚠️ **不能直接用 `proposal.replacingUnspecifiedDimensions().width`**（PR #206 第 4 轮
    /// review 抓到）：它对未指定宽度的缺省是 **10×10**，于是 `Timeline(..., layout: .alternate)`
    /// 放进 `ScrollView(.horizontal)`、或外加 `.fixedSize(horizontal: true, ...)`、或任何按
    /// ideal 宽度询问的容器时，整行会塌成 10pt 宽、两个槽被提议 0 宽。换 `Layout` 之前的
    /// `HStack` 写法在这里能给出合理的 ideal 宽（各槽回报固有宽），所以这是 `Layout` 引入
    /// 的**新**退化。宽度未指定或非有限时，回退到「两侧内容固有宽的较大者」撑出行宽。
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

    /// 三个 subview 在各自提议下的高度。
    ///
    /// ⚠️ 节点那项取 `nodeColumnWidth` 是**因为视图侧显式装了 `.frame(24×24)`**，不是因为
    /// `place` 的 proposal ——  两者必须同步改（PR #206 第 4 轮：`.frame` 被删掉后这里的
    /// 硬编码 24 还停在旧世界，成了错误几何的帮凶）。
    private static func subviewHeights(_ subviews: Subviews, slotWidth: CGFloat) -> [CGFloat] {
        guard subviews.count == 3 else { return [] }
        return [
            subviews[0].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height,
            Timeline.nodeColumnWidth,
            subviews[2].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height,
        ]
    }
}

/// `.grouped` 的单行（internal）：只渲染 content，并把默认节点丢失的状态语义补回。
///
/// ⚠️ **必须先 `.accessibilityElement(children: .combine)` 收成单个元素再挂
/// `accessibilityValue`**（PR #206 第 2 轮 review 抓到）：`accessibilityValue` 加在一个
/// 本身不是单一无障碍元素的容器上时，SwiftUI 会把它**下发给所有后代元素**。而
/// `item.content` 是调用方任意视图 —— 本文件 `.vertical` 预览里的标准形态就是
/// `VStack { Text(标题); Text(时间) }` 两个元素，不 combine 会读成「已创建, Success」
/// +「2026-07-20 10:00, Success」，状态播两遍。
///
/// ⚠️ **已知边界**：`.combine` 之后挂的 `accessibilityValue` 会**覆盖**调用方 content 自带的
/// value —— content 里若塞了 `ProgressView` / `Slider` 这类带值控件，其百分比 / 数值会被
/// 状态文案顶掉。今天没有用例命中（`.grouped` 的实际用法是分组列表行，content 基本是文本），
/// 但需要保留细粒度 value 语义的调用方应改用 `.vertical`。SwiftUI 读不到「content 已有的
/// value」，因而拼接不可行；`accessibilityCustomContent` 是另一条路，但要引入新的 A 类文案键，
/// 留给 `wxlpp/oh-my-story#49` 的文案迁移一并定。
///
/// ⚠️ 这是 `.grouped` **有意偏离** `.vertical` 的一处：后者刻意不合并 content
/// （见 `Timeline` 文档「content 的 accessibility 语义完全由调用方决定」），因为节点与
/// content 本就是分离的两块；而 `.grouped` 删掉了节点列，整行读作一条分组记录才成立
/// （Apple 邮件 / 信息的日期分组即此形态）。`.combine` 保留后代的可交互性（可交互元素
/// 提升为该元素的自定义 action），不是 `.ignore` 那种丢弃。
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

/// 节点之间的竖向连线（internal）—— `.vertical` 与 `.alternate` 共用同一段画法，
/// 两处各写一份会让「改了粗细/起点只改到一半」这类偏差无声发生。
private struct TimelineConnector: View {
    var body: some View {
        Rectangle()
            .fill(Color.dividerDefault)
            .frame(width: CoreBorderWidth.thin)
            .frame(maxHeight: .infinity)
            // 起点落在节点方框底部——见 `Timeline` doc comment「布局」一节。
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
                // ⚠️ PR #206 review 指出新排布只有 storage/body 求值测试、预览仍只画默认
                // `.vertical`，交替轴线是否真的对齐、分组项的状态播报是否还在，都无人可见。
                // 本仓的快照流水线**只生成 PNG、不做基线比对** —— `scripts/run-snapshots.sh`
                // 经 `App/Tests/SnapshotTests.swift`（`SnapshottingTests`）收集 `#Preview` 出图，但没有
                // 「与基线逐像素比对然后判红」的那一步 ⇒ **它检测不了视觉回归**，只是把图摆出来供人看。
                // 且默认模式只保留 `App/Sources/Previews.swift` 驱动的 `CoreDesignPreview_*`，库内
                // `#Preview` 产出的 `CoreDesign_*` 会被 `find -delete` 删掉（要留得加 `KEEP_LIBRARY_SNAPSHOTS=1`，
                // 且只落本地 scratch）。⇒ 新形态**已同步注册进 `App/Sources/Previews.swift`**，否则进不了流水线。

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

    /// 四种排布共用的一组样本 —— 同一份数据换 `layout`，差异才归因于排布本身。
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
