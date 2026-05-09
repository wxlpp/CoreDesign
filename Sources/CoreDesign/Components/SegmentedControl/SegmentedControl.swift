//
//  SegmentedControl.swift
//  CoreDesign
//
//  Created by AnyWriter on 2026/4/14.
//

import SwiftUI

public struct SegmentedControl<Item: Hashable>: View {
    public init(
        items: [Item],
        selection: Binding<Item>,
        title: @escaping (Item) -> String
    ) {
        self.items = items
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(self.items, id: \.self) { item in
                self.segment(for: item)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.surfaceMuted)
        )
        .frame(height: 32)
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
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.contentPrimary : Color.contentSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.surfaceRaised)
                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
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
