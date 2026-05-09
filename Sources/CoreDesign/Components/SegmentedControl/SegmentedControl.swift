//
//  SegmentedControl.swift
//  CoreDesign
//
//  Created by AnyWriter on 2026/4/14.
//

import SwiftUI

// MARK: - SegmentedControl

/// 分段控件 / Segmented control。
///
/// **使用场景**：在视觉等价的少量选项（通常 2–4 个）之间二选一切换，譬如视图模式、
/// 时间范围、内容分类。当选项 ≥ 5 个、需要溢出 / 滚动、或选项之间存在层级关系时，
/// 改用 `UnderlinedTabBar` 或 `Picker`。
///
/// **与 Primer 概念对应**：对应 Primer `SegmentedControl`（GitHub 桌面 UI 的"组合式
/// 按钮组"）。本实现复刻其 thumb 滑动 + 选中态 semibold 强调的视觉。
///
/// **关键参数语义**：
/// - `items` —— 选项数据源；`Item` 必须 `Hashable`（用于 `selection` 比较与 `ForEach` 标识）。
/// - `selection` —— 当前选中项的双向绑定；切换时触发 `withAnimation` thumb 过渡 +
///   `.sensoryFeedback(.selection)`。
/// - `title` —— 把 `Item` 映射到展示文字的闭包；调用方控制本地化与字符串构造。
///
/// **light / dark 行为**：
/// - 外框背景 `Color.surfaceMuted`、thumb 背景 `Color.surfaceRaised`、文字
///   `Color.contentPrimary` / `Color.contentSecondary` 均走 v2-tokens 语义色，
///   light / dark 双模式自动切换。
/// - thumb 阴影通过 `View.coreShadow(.small)` 应用，`shadow-small` colorset
///   在 dark 模式下会自动加深 alpha 以保持 elevation 视觉。
///
/// **不使用 `.glassEffect`**——本组件属于"嵌入页面内容"的 chrome，per PRD §US-3
/// glass 仅用于浮层 UI（`BottomInputBar` / `MenuButton` / `CircularGlassButtonStyle`），
/// 容器类组件统一走实色 + 阴影。
public struct SegmentedControl<Item: Hashable>: View {
    /// 创建分段控件。
    ///
    /// - Parameters:
    ///   - items: 选项数据源；`Item` 必须 `Hashable`，用于 `selection` 比较与
    ///     `ForEach` 标识。
    ///   - selection: 当前选中项的双向绑定。
    ///   - title: 把 `Item` 映射到展示文字的闭包。
    public init(
        items: [Item],
        selection: Binding<Item>,
        title: @escaping (Item) -> String
    ) {
        self.items = items
        self._selection = selection
        self.title = title
    }

    /// 视图主体：横向 HStack 排列分段，外框走 `surfaceMuted` 容器，
    /// thumb 通过 `matchedGeometryEffect` 在选中分段间无缝滑动。
    public var body: some View {
        HStack(spacing: CoreSpacing.xxs) {
            ForEach(self.items, id: \.self) { item in
                self.segment(for: item)
            }
        }
        .padding(CoreSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .fill(Color.surfaceMuted)
        )
        .frame(height: CoreControlMetrics.height(for: .regular))
        .sensoryFeedback(.selection, trigger: self.selection)
    }

    @Binding private var selection: Item
    @Namespace private var namespace

    private let items: [Item]
    private let title: (Item) -> String

    @ViewBuilder
    private func segment(for item: Item) -> some View {
        let isSelected = self.selection == item
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                self.selection = item
            }
        } label: {
            Text(self.title(item))
                .font(CoreTypography.bodyMediumFont)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.contentPrimary : Color.contentSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)
                            .fill(Color.surfaceRaised)
                            .coreShadow(.small)
                            .matchedGeometryEffect(id: "SegmentedControl.thumb", in: self.namespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var selection = "A"
        var body: some View {
            VStack(spacing: 16) {
                SegmentedControl(
                    items: ["A", "B"],
                    selection: self.$selection,
                    title: { $0 }
                )
                SegmentedControl(
                    items: ["世界观", "设定", "大纲"],
                    selection: self.$selection,
                    title: { $0 }
                )
            }
            .padding()
        }
    }
    return PreviewHost()
}
