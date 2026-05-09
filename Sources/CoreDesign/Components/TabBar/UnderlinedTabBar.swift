//
//  UnderlinedTabBar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - UnderlinedTabBar

/// 横向可滚动的下划线分栏组件。
///
/// - 选中项文字加粗 + 主色，并以下划线胶囊标记，切换时用 `matchedGeometryEffect` 做顺滑过渡。
/// - 选中变化时，自动把选中项滚到居中位置。
/// - `trailing` 视图固定在右侧，不随 tabs 滚动；左侧自带 0.5pt 分隔线。
public struct UnderlinedTabBar<Item: Hashable, Trailing: View>: View {
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
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
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
                    .padding(.horizontal, 12)
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
                            .frame(width: 0.5)
                            .padding(.vertical, 6)
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

    var body: some View {
        Button(action: self.action) {
            VStack(spacing: 6) {
                Text(self.title)
                    .font(.callout.weight(self.isSelected ? .semibold : .regular))
                    .foregroundStyle(self.isSelected ? Color.contentPrimary : Color.contentSecondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                ZStack {
                    Capsule()
                        .fill(Color.clear)
                        .frame(height: 3)
                    if self.isSelected {
                        Capsule()
                            .fill(Color.accent)
                            .frame(height: 3)
                            .matchedGeometryEffect(id: "underline", in: self.namespace)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
