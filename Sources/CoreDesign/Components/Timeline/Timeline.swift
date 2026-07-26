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

    /// - Parameter items: 时间线节点数据，按数组顺序纵向排列。
    public init(items: [TimelineItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.none) {
            ForEach(self.items) { item in
                TimelineRowView(item: item, isLast: Self.isLastItem(item, in: self.items))
            }
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

/// 单条时间线行（internal）：节点方框 + 连线（背景）+ content。
private struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CoreSpacing.md) {
            self.nodeView
                .frame(width: Timeline.nodeColumnWidth, height: Timeline.nodeColumnWidth)

            self.item.content
                .padding(.bottom, self.isLast ? CoreSpacing.none : CoreSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            if !self.isLast {
                Rectangle()
                    .fill(Color.dividerDefault)
                    .frame(width: CoreBorderWidth.thin)
                    .frame(maxHeight: .infinity)
                    // 起点落在节点方框底部——见 `Timeline` doc comment「布局」一节。
                    .padding(.top, Timeline.nodeColumnWidth)
                    // 水平居中于节点方框。
                    .padding(.leading, (Timeline.nodeColumnWidth - CoreBorderWidth.thin) / 2)
            }
        }
    }

    @ViewBuilder
    private var nodeView: some View {
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
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }
}
