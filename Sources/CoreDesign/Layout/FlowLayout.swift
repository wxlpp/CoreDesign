import SwiftUI

// MARK: - FlowLayout

/// Tag 自动换行布局容器。
public struct FlowLayout: Layout {
    public typealias Cache = [CGSize]

    public let spacing: CGFloat

    public init(spacing: CGFloat = CoreSpacing.xs) {
        self.spacing = spacing
    }

    public func makeCache(subviews: Subviews) -> Cache {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }

    public func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        let rows = self.computeRows(proposalWidth: proposal.width, sizes: cache)
        let height = rows.reduce(0) { $0 + $1.maxHeight }
            + CGFloat(max(0, rows.count - 1)) * self.spacing
        let widest = rows.map(\.totalWidth).max() ?? 0
        let width = max(proposal.width ?? 0, widest)
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let rows = self.computeRows(proposalWidth: bounds.width, sizes: cache)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = cache[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.maxHeight - size.height) / 2),
                    proposal: .unspecified
                )
                x += size.width + self.spacing
            }
            y += row.maxHeight + self.spacing
        }
    }

    private struct Row {
        let indices: Range<Int>
        let maxHeight: CGFloat
        let totalWidth: CGFloat
    }

    private func computeRows(proposalWidth: CGFloat?, sizes: [CGSize]) -> [Row] {
        let maxWidth = proposalWidth ?? .infinity
        var rows: [Row] = []
        var rowStart = 0
        var currentCount = 0
        var currentWidth: CGFloat = 0
        var currentMaxHeight: CGFloat = 0

        for (index, size) in sizes.enumerated() {
            let gap = currentCount == 0 ? 0 : self.spacing
            let projectedWidth = currentWidth + size.width + gap

            if projectedWidth > maxWidth && currentCount > 0 {
                rows.append(
                    Row(
                        indices: rowStart..<index,
                        maxHeight: currentMaxHeight,
                        totalWidth: currentWidth
                    )
                )
                rowStart = index
                currentCount = 0
                currentWidth = 0
                currentMaxHeight = 0
            }

            currentWidth += size.width + (currentCount > 0 ? self.spacing : 0)
            currentMaxHeight = max(currentMaxHeight, size.height)
            currentCount += 1
        }

        if currentCount > 0 {
            rows.append(
                Row(
                    indices: rowStart..<sizes.count,
                    maxHeight: currentMaxHeight,
                    totalWidth: currentWidth
                )
            )
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
