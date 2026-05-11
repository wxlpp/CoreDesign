//
//  FlowLayout.swift
//  CoreDesign
//

import SwiftUI

// MARK: - FlowLayout

/// Tag 自动换行布局容器。
///
/// 使用 SwiftUI `Layout` 协议实现，子视图在行内容纳不下时自动折行。
/// 配合现有 `Tag` 组件使用，构建 label chip group。
///
/// ```swift
/// FlowLayout(spacing: CoreSpacing.xs) {
///     Tag("bug", color: .red)
///     Tag("enhancement", color: .blue)
/// }
/// ```
public struct FlowLayout: Layout {
    public let spacing: CGFloat

    public init(spacing: CGFloat = CoreSpacing.xs) {
        self.spacing = spacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = self.computeRows(proposalWidth: proposal.width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * self.spacing
        let width = proposal.width ?? rows.map(\.totalWidth).max() ?? 0
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = self.computeRows(proposalWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = item.sizeThatFits(.unspecified)
                item.place(at: CGPoint(x: x, y: y + (row.maxHeight - size.height) / 2), proposal: .unspecified)
                x += size.width + self.spacing
            }
            y += row.maxHeight + self.spacing
        }
    }

    private struct Row {
        let items: [LayoutSubview]
        let maxHeight: CGFloat
        let totalWidth: CGFloat
    }

    private func computeRows(proposalWidth: CGFloat?, subviews: Subviews) -> [Row] {
        let maxWidth = proposalWidth ?? .infinity
        var rows: [Row] = []
        var currentItems: [LayoutSubview] = []
        var currentWidth: CGFloat = 0

        func flushRow() {
            let maxHeight = currentItems.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            let itemWidths = currentItems.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
            let gaps = CGFloat(max(0, currentItems.count - 1)) * self.spacing
            rows.append(Row(items: currentItems, maxHeight: maxHeight, totalWidth: itemWidths + gaps))
            currentItems = []
            currentWidth = 0
        }

        for subview in subviews {
            let itemSize = subview.sizeThatFits(.unspecified)
            let gap = currentItems.isEmpty ? 0 : self.spacing
            let projectedWidth = currentWidth + itemSize.width + gap

            if projectedWidth > maxWidth && !currentItems.isEmpty {
                flushRow()
            }

            currentItems.append(subview)
            currentWidth += itemSize.width + (currentItems.count > 1 ? self.spacing : 0)
        }

        if !currentItems.isEmpty {
            flushRow()
        }

        return rows
    }
}

#Preview {
    FlowLayout(spacing: CoreSpacing.xs) {
        ForEach(["bug", "enhancement", "help wanted", "documentation", "good first issue", "dependencies"], id: \.self) { label in
            Tag(label, color: .blue)
        }
    }
    .padding()
    .frame(width: 280)
}
