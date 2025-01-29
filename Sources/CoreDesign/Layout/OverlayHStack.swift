//
//  File.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/29.
//

import Foundation
import SwiftUI

public struct OverlayHStack: Layout {
    var spacing: CGFloat = 0

    public init(spacing: CGFloat) {
        self.spacing = spacing
    }

    public static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .horizontal
        return properties
    }

    /// Returns a size that the layout container needs to arrange its subviews
    /// horizontally.
    /// - Tag: sizeThatFitsHorizontal
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let totalSpacing = self.spacing * CGFloat(subviews.count - 1)

        return CGSize(
            width: cache.totalSize.width - totalSpacing,
            height: cache.totalSize.height
        )
    }

    /// Places the subviews in a horizontal stack.
    /// - Tag: placeSubviewsHorizontal
    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) {
        guard !subviews.isEmpty else { return }

        var nextX: CGFloat = bounds.minX
        for index in subviews.indices {
            let subviewSize = cache.subviewSizes[index]
            let nextY = bounds.minY + (cache.totalSize.height - subviewSize.height) / 2
            subviews[index].place(
                at: CGPoint(x: nextX, y: nextY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: subviewSize.width, height: subviewSize.height)
            )
            nextX += subviewSize.width - self.spacing
        }
    }

    /// Creates a cache for a given set of subviews.
    ///
    /// When the subviews change, SwiftUI calls the ``updateCache(_:subviews:)``
    /// method. The ``MyEqualWidthVStack`` layout relies on the default
    /// implementation of that method, which just calls this method again
    /// to recreate the cache.
    /// - Tag: makeCache
    public func makeCache(subviews: Subviews) -> CacheData {
        var cacheData = CacheData()
        cacheData.subviewSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cacheData.totalSize = cacheData.subviewSizes.reduce(.zero) { currentTotal, subviewSize in
            CGSize(width: currentTotal.width + subviewSize.width, height: max(currentTotal.height, subviewSize.height))
        }
        return cacheData
    }

    /// Finds the largest ideal size of the subviews.
    private func maxSize(subviews: Subviews) -> CGSize {
        let subviewSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxSize: CGSize = subviewSizes.reduce(.zero) { currentMax, subviewSize in
            CGSize(
                width: max(currentMax.width, subviewSize.width),
                height: max(currentMax.height, subviewSize.height)
            )
        }

        return maxSize
    }
}

extension OverlayHStack {
    public struct CacheData {
        var subviewSizes: [CGSize] = []
        var totalSize: CGSize = .zero
    }
}
