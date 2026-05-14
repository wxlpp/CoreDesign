//
//  SegmentedControl.swift
//  CoreDesign
//
//  Created by AnyWriter on 2026/4/14.
//

import SwiftUI

// MARK: - SegmentedControl

/// Native Primer segmented control.
///
/// The component keeps GitHub-like utility and density while rendering as an
/// Apple-native control surface. The base stays quiet; only the selected segment
/// gets a lightly raised thumb. This is a control-layer component, so it does
/// not use Liquid Glass by default.
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

    /// 视图主体：横向 HStack 排列分段，外框走 `surfaceInteractive` 容器，
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
                .fill(Color.surfaceInteractive)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
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
                            .fill(Color.surfaceCanvas)
                            .overlay(
                                RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)
                                    .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                            )
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
