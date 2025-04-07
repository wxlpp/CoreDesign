//
//  EqualWidthVStack.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/30.
//

import SwiftUI

public struct EqualWidthVStack: Layout {
    public init() {}

    /// Returns a size that the layout container needs to arrange its subviews
    /// vertically with equal widths.
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        cache.maxSize = self.maxSize(proposal: proposal, subviews: subviews)
        cache.heights = self.itemHeights(proposal: proposal, subviews: subviews)
        cache.totalHeight = cache.heights.reduce(0, +)
        return CGSize(
            width: cache.maxSize.width,
            height: cache.totalHeight + cache.totalSpacing
        )
    }

    /// Places the subviews in a vertical stack.
    /// - Tag: placeSubviewsVertical
    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) {
        guard !subviews.isEmpty else { return }

        // Load size and spacing information from the cache.
        let maxSize = cache.maxSize
        let spacing = cache.spacing
        let heights = cache.heights
        let placementProposal = ProposedViewSize(width: maxSize.width, height: bounds.height)
        var nextY = bounds.minY + (heights.first ?? 0) / 2

        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.midX, y: nextY),
                anchor: .center,
                proposal: placementProposal
            )
            nextY += heights[index] + spacing[index]
        }
    }

    /// A type that stores cached data.
    /// - Tag: CacheData
    public struct CacheData {
        var maxSize: CGSize
        let spacing: [CGFloat]
        var heights: [CGFloat]
        let totalSpacing: CGFloat
        var totalHeight: CGFloat
    }

    /// Creates a cache for a given set of subviews.
    ///
    /// When the subviews change, SwiftUI calls the ``updateCache(_:subviews:)``
    /// method. The ``MyEqualWidthVStack`` layout relies on the default
    /// implementation of that method, which just calls this method again
    /// to recreate the cache.
    /// - Tag: makeCache
    public func makeCache(subviews: Subviews) -> CacheData {
        let maxSize = maxSize(proposal: .unspecified, subviews: subviews)
        let spacing = spacing(subviews: subviews)
        let totalSpacing = spacing.reduce(0, +)
        let heights = self.itemHeights(proposal: .unspecified, subviews: subviews)
        let totalHeight = heights.reduce(0, +)
        return CacheData(
            maxSize: maxSize,
            spacing: spacing,
            heights: heights,
            totalSpacing: totalSpacing,
            totalHeight: totalHeight
        )
    }

    /// Finds the largest ideal size of the subviews.
    private func maxSize(proposal: ProposedViewSize, subviews: Subviews) -> CGSize {
        let subviewSizes = subviews.map { $0.sizeThatFits(proposal) }
        let maxSize: CGSize = subviewSizes.reduce(.zero) { currentMax, subviewSize in
            CGSize(
                width: max(currentMax.width, subviewSize.width),
                height: max(currentMax.height, subviewSize.height)
            )
        }

        return maxSize
    }

    private func itemHeights(proposal: ProposedViewSize, subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(proposal).height }
    }

    /// Gets an array of preferred spacing sizes between subviews in the
    /// vertical dimension.
    private func spacing(subviews: Subviews) -> [CGFloat] {
        subviews.indices.map { index in
            guard index < subviews.count - 1 else { return 0 }

            return subviews[index].spacing.distance(
                to: subviews[index + 1].spacing,
                along: .vertical
            )
        }
    }
}
