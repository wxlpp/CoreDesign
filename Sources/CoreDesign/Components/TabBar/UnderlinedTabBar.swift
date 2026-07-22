//
//  UnderlinedTabBar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - UnderlinedTabBar

/// Native Primer underlined tab bar.
///
/// Control-layer chrome for primary navigation. Selected tab is marked by a
/// short, low-noise underline (`Color.accent` token, matching the
/// `borderColor.accent.emphasis` Primer mapping documented below) plus
/// active label emphasis. No global glass treatment — the host scene
/// supplies the background, this component supplies the indicator and labels.
///
/// **Material layer**: control. **Surface role**: control.
///
/// Per the Native Primer baseline, navigation chrome does not use Liquid
/// Glass; selected states stay typographic + line-based (see spec §Controls).
///
/// 横向可滚动的下划线分栏组件，按 Primer 视觉语言收齐于 v2-tokens。
///
/// ## 使用场景
/// - 内容主屏的「页签 / 分类」切换：当 tab 数量超过单屏宽度时优先选用本组件（对应
///   `SegmentedControl` 适用于固定 ≤ 5 项的紧凑场景）。
/// - 带右侧固定操作（譬如「筛选」「排序」）的 tab 行；通过 `trailing` 注入。
///
/// ## 关键参数语义
/// - `items`：tab 数据源；元素需 `Hashable` 以支持选中比较与 `ScrollViewReader.scrollTo`。
/// - `selection`：受控选中态；切换时触发布局动画 + 自动滚动到居中位置。
/// - `title`：从 `Item` 抽取展示文本；按视觉是「中文 4–8 字 / 英文 1–3 词」的短 label。
/// - `trailing`：右侧固定视图（不随 tabs 滚动）；存在时左侧自带 hairline 分隔线。
///
/// ## 与 Primer 概念对应
/// - 选中文字色 = `Color.contentPrimary`（Primer `fgColor.default`），
///   非选中 = `Color.contentSecondary`（Primer `fgColor.muted`）。
/// - 选中下划线 = `Color.accent`（Primer `borderColor.accent.emphasis`），
///   厚度采用 `CoreBorderWidth.thick`（2pt，对齐 Primer focus indicator / selected state 标度）。
/// - 字号采用 `.coreFont(.callout)`（Primer `text.body.medium` 的迁移目标，
///   推荐的默认 UI 文字字号），选中态额外 `.fontWeight(.semibold)` 加强。
/// - 间距 / padding 全部走 `CoreSpacing.*`；左侧分隔线宽度走 `CoreBorderWidth.hairline`。
///
/// ## Light / Dark 行为
/// - 颜色全部使用语义 token，自动跟随 colorScheme：light 下分隔线偏浅灰、dark 下偏暗；
///   accent 在 dark 模式下色相略亮以维持对比度（由 `Color.accent` 自身的 colorset 决定）。
/// - 不使用 `.glassEffect`（PRD §US-3 白名单不包含 TabBar 类控件 chrome）。
public struct UnderlinedTabBar<Item: Hashable, Trailing: View>: View {
    /// 创建带 trailing 视图的下划线 tab 栏。
    ///
    /// - Parameters:
    ///   - items: tab 数据源；首次渲染时会自动滚动到 `selection` 居中位置。
    ///   - selection: 受控选中态；切换由本组件内部 `withAnimation` 驱动 underline 切换 + 滚动。
    ///   - title: 从 `Item` 抽取展示文本的纯函数。
    ///   - trailing: 右侧固定视图，不随 tabs 横向滚动；左侧自带 hairline 分隔线。
    public init(
        items: [Item],
        selection: Binding<Item>,
        title: @escaping (Item) -> String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.items = items
        self._selection = selection
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.none) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CoreSpacing.xs) {
                        ForEach(self.items, id: \.self) { item in
                            UnderlinedTabItem(
                                title: self.title(item),
                                isSelected: self.selection == item,
                                namespace: self.indicatorNamespace
                            ) {
                                withAnimation(.snappy(duration: 0.22)) {
                                    self.selection = item
                                }
                            }
                            .id(item)
                        }
                    }
                    .padding(.horizontal, CoreSpacing.md)
                }
                .onAppear {
                    proxy.scrollTo(self.selection, anchor: .center)
                }
                .onChange(of: self.selection) { _, new in
                    withAnimation(.snappy(duration: 0.2)) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }

            if Trailing.self != EmptyView.self {
                self.trailing()
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.dividerDefault)
                            .frame(width: CoreBorderWidth.hairline)
                            .padding(.vertical, CoreSpacing.sm)
                    }
            }
        }
    }

    @Binding private var selection: Item
    @Namespace private var indicatorNamespace

    private let items: [Item]
    private let title: (Item) -> String
    private let trailing: () -> Trailing
}

public extension UnderlinedTabBar where Trailing == EmptyView {
    /// 无 trailing 的便捷初始化：编译期确定不会渲染分隔线，避免动态类型判断误判。
    init(
        items: [Item],
        selection: Binding<Item>,
        title: @escaping (Item) -> String
    ) {
        self.init(
            items: items,
            selection: selection,
            title: title,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - UnderlinedTabItem

/// 单个 tab 项的内部视图。
///
/// 私有实现细节：选中态文字加粗 + `Color.contentPrimary`；
/// underline 通过 `matchedGeometryEffect(id: "underline", in: namespace)` 在切换时
/// 顺滑过渡（**不要**修改 namespace key 或动画 driver——`UnderlinedTabBar` 的切换逻辑
/// 依赖该 ID 在所有 item 中保持一致）。
private struct UnderlinedTabItem: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(spacing: CoreSpacing.sm) {
                Text(self.title)
                    .coreFont(.callout)
                    .fontWeight(self.isSelected ? .semibold : .regular)
                    .foregroundStyle(self.isSelected ? Color.contentPrimary : Color.contentSecondary)
                    .padding(.horizontal, CoreSpacing.md)
                    .padding(.top, CoreSpacing.sm)

                ZStack {
                    Capsule()
                        .fill(Color.clear)
                        .frame(height: CoreBorderWidth.thick)
                    if self.isSelected {
                        Capsule()
                            .fill(Color.accent)
                            .frame(height: CoreBorderWidth.thick)
                            .matchedGeometryEffect(id: "underline", in: self.namespace)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CoreSpacing.xs)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection = "全部"
    let items = ["全部", "人物", "地点", "物品", "设定", "势力"]

    return UnderlinedTabBar(
        items: items,
        selection: $selection,
        title: { $0 },
        trailing: {
            Button {} label: {
                Image(systemName: "slider.horizontal.3")
                    .padding(14)
            }
            .buttonStyle(.plain)
        }
    )
    .padding(.vertical, 8)
}
