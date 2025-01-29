//
//  OverlayVStack.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/29.
//

import Foundation
import SwiftUI

public struct OverlayVStack: Layout {
    var spacing: CGFloat = 0

    public init(spacing: CGFloat) {
        self.spacing = spacing
    }

    public static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .vertical
        return properties
    }

    /// Returns a size that the layout container needs to arrange its subviews
    /// vertically with equal widths.
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let totalSpacing = self.spacing * CGFloat(subviews.count - 1)

        return CGSize(
            width: cache.totalSize.width,
            height: cache.totalSize.height - totalSpacing
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

        var nextY: CGFloat = bounds.minY
        for index in subviews.indices {
            let subviewSize = cache.subviewSizes[index]
            let nextX = bounds.minX + (cache.totalSize.width - subviewSize.width) / 2
            subviews[index].place(
                at: CGPoint(x: nextX, y: nextY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: subviewSize.width, height: subviewSize.height)
            )
            nextY += subviewSize.height - self.spacing
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
            CGSize(width: max(currentTotal.width, subviewSize.width), height: currentTotal.height + subviewSize.height)
        }
        return cacheData
    }
}

extension OverlayVStack {
    public struct CacheData {
        var subviewSizes: [CGSize] = []
        var totalSize: CGSize = .zero
    }
}
