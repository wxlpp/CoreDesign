import SwiftUI

// MARK: - UnderlinedTabBar

/// 主导航 chrome：选中项以一条下划线加字重标记（下划线色取环境 `\.coreAccent`），背景由宿主 scene 提供。
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

private struct UnderlinedTabItem: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.coreAccent) private var resolvedAccent

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
                            .fill(self.resolvedAccent)
                            .frame(height: CoreBorderWidth.thick)
                            .matchedGeometryEffect(id: "underline", in: self.namespace)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CoreSpacing.xs)
            }
            .frame(minHeight: CoreControlMetrics.height(for: .regular))
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
