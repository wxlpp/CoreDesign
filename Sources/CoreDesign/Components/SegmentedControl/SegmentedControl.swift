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
/// Apple-native control surface. The base uses a restrained Liquid Glass shell
/// by default; only the selected segment gets a lightly raised thumb.
public struct SegmentedControl<Item: Hashable>: View {
    /// 创建分段控件。
    ///
    /// - Parameters:
    ///   - items: 选项数据源；`Item` 必须 `Hashable`，用于 `selection` 比较与
    ///     `ForEach` 标识。
    ///   - selection: 当前选中项的双向绑定。
    ///   - glass: 是否使用 Liquid Glass 外壳；默认 `true`。
    ///   - title: 把 `Item` 映射到展示文字的闭包。
    public init(
        items: [Item],
        selection: Binding<Item>,
        glass: Bool = true,
        title: @escaping (Item) -> String
    ) {
        self.items = items
        self._selection = selection
        self.glass = glass
        self.title = title
    }

    /// 视图主体：横向 HStack 排列分段，外框走 `surfaceInteractive` 容器，
    /// thumb 通过 `matchedGeometryEffect` 在选中分段间无缝滑动。
    @ViewBuilder
    public var body: some View {
        let shape = Capsule(style: .continuous)
        if self.glass {
            GlassEffectContainer(spacing: CoreSpacing.xxs) {
                self.segments
                    .modifier(SegmentedControlBackgroundModifier(shape: shape, glass: self.glass))
            }
            .frame(height: CoreControlMetrics.height(for: .regular))
            .sensoryFeedback(.selection, trigger: self.selection)
        } else {
            self.segments
                .modifier(SegmentedControlBackgroundModifier(shape: shape, glass: self.glass))
                .frame(height: CoreControlMetrics.height(for: .regular))
                .sensoryFeedback(.selection, trigger: self.selection)
        }
    }

    @Binding private var selection: Item
    @Namespace private var namespace

    private let items: [Item]
    private let glass: Bool
    private let title: (Item) -> String

    private var segments: some View {
        HStack(spacing: CoreSpacing.xxs) {
            ForEach(self.items, id: \.self) { item in
                self.segment(for: item)
            }
        }
        .padding(CoreSpacing.xxs)
    }

    @ViewBuilder
    private func segment(for item: Item) -> some View {
        let isSelected = self.selection == item
        Text(self.title(item))
            .font(CoreTypography.bodyMediumFont)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? Color.contentPrimary : Color.contentSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    if self.glass {
                        self.selectedThumb
                            .glassEffectID("SegmentedControl.thumb", in: self.namespace)
                    } else {
                        self.selectedThumb
                            .matchedGeometryEffect(id: "SegmentedControl.thumb", in: self.namespace)
                    }
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction { self.select(item) }
            .onTapGesture { self.select(item) }
    }

    @ViewBuilder
    private var selectedThumb: some View {
        let shape = Capsule(style: .continuous)
        if self.glass {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
                .coreShadow(.small)
        } else {
            shape
                .fill(Color.surfaceCanvasSubtle)
                .overlay(
                    shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
                .coreShadow(.small)
        }
    }

    private func select(_ item: Item) {
        withAnimation(.easeInOut(duration: 0.18)) {
            self.selection = item
        }
    }
}

private struct SegmentedControlBackgroundModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let glass: Bool

    func body(content: Content) -> some View {
        if self.glass {
            content
                .background(
                    self.shape
                        .inset(by: CoreButtonMetrics.glassInset)
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: self.shape)
                )
        } else {
            content
                .background(
                    self.shape.fill(Color.surfaceInteractive)
                )
                .overlay(
                    self.shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
        }
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
