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

    /// `.horizontal`：节点沿水平轴排列，内容在节点下方。
    ///
    /// ⚠️ 横向下**不画节点间连线** —— 竖向连线的实现（`TimelineRowView` 的 background
    /// `Rectangle` + `padding(.top:)`）依赖「节点在上、内容在下」的纵向几何，换轴后那套
    /// padding 计算不成立。横向连线属独立形态，本轮不引入（`#60` 承接）。
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
                Self.applyGroupedStatusValue(
                    item.content
                        .frame(maxWidth: .infinity, alignment: .leading),
                    item: item
                )
            }
        }
    }

    /// `.grouped` 下把默认节点携带的状态语义补回给内容。
    ///
    /// ⚠️ PR #206 review 抓到的无障碍回归：本形态不渲染节点列，于是**默认圆点**原本挂在
    /// 自己身上的 `Info` / `Success` / `Warning` / `Error` 标签一并消失 —— 而 `Timeline`
    /// 的公共文档仍承诺默认节点携带这些状态语义。视觉上「没有节点」是本形态的定义，
    /// 状态信息却不该跟着消失。
    ///
    /// ⚠️ 用 `accessibilityValue` 而**不是** `accessibilityLabel`：label 是调用方 `content`
    /// 自己的语义，覆盖它会吞掉真正要读的内容。
    /// ⚠️ 只对**无自定义节点**的项补 —— 传了 `node:` 的项，其无障碍语义由调用方在自己的
    /// 节点视图里决定，本形态既然不渲染那个节点，也就不该替调用方臆造一个状态播报。
    @ViewBuilder
    static func applyGroupedStatusValue(_ content: some View, item: TimelineItem) -> some View {
        if item.node == nil {
            content.accessibilityValue(
                Text(LocalizedStringKey(Self.accessibilityLabelKey(for: item.status)), bundle: .module)
            )
        } else {
            content
        }
    }

    // MARK: - Layout metrics

    /// 节点方框边长（pt）——默认圆点与自定义 `node` 均在此方框内居中对齐，保证连线的
    /// 竖直起点（方框底部）不因节点内容尺寸不同而错位。
    static let nodeColumnWidth: CGFloat = 24

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
        HStack(alignment: .top, spacing: CoreSpacing.md) {
            self.slot(.leading)

            TimelineNodeView(item: self.item)
                .frame(width: Timeline.nodeColumnWidth, height: Timeline.nodeColumnWidth)

            self.slot(.trailing)
        }
        // 连线居中于**整行**——与节点列在三列布局中的居中位置重合。
        .background(alignment: .top) {
            if !self.isLast {
                TimelineConnector()
            }
        }
    }

    /// 一侧的内容槽：本行内容归属该侧时渲染内容，否则渲染等宽空槽以维持三列几何。
    @ViewBuilder
    private func slot(_ side: HorizontalEdge) -> some View {
        if side == self.contentSide {
            self.item.content
                .padding(.bottom, self.isLast ? CoreSpacing.none : CoreSpacing.lg)
                .frame(maxWidth: .infinity, alignment: side == .leading ? .trailing : .leading)
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 0)
                .accessibilityHidden(true)
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
                // ⚠️ 本仓**无快照测试**，`#Preview` 是这些分支唯一的视觉冒烟通路
                // （CLAUDE.md「`#Preview` 是组件的主要视觉冒烟检查方式」）——
                // PR #206 review 指出新排布只有 storage/body 求值测试、预览仍只画默认
                // `.vertical`，交替轴线是否真的对齐、分组项的状态播报是否还在，都无人可见。

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
