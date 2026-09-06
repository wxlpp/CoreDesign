import SwiftUI

// MARK: - Fill Colors / 填充颜色

public extension Color {
    /// 为细小形状的叠加填充颜色。
    static var fill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .systemFill)
        #else
            return Color(nsColor: .systemFill)
        #endif
    }

    /// 中等大小形状的叠加填充颜色。
    static var secondaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .secondarySystemFill)
        #else
            return Color(nsColor: .secondarySystemFill)
        #endif
    }

    /// 大型形状的叠加填充颜色。
    static var tertiaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .tertiarySystemFill)
        #else
            return Color(nsColor: .tertiarySystemFill)
        #endif
    }

    /// 大区域复杂内容的覆盖填充颜色。
    static var quaternaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .quaternarySystemFill)
        #else
            return Color(nsColor: .quaternarySystemFill)
        #endif
    }

    // MARK: - Skeleton 占位取色（semi-mobile-components Phase 0 定案）

    /// 骨架屏占位底色。Skeleton placeholder base fill.
    static var skeletonBase: Color { Color.fill }

    /// 骨架屏 shimmer 扫光高光色。Skeleton shimmer highlight.
    static var skeletonHighlight: Color { Color.skeletonBase.mix(with: .white, by: 0.5) }

    /// 扫光高光色（`.shine()` 这类掠过内容的高光带）。Specular sweep highlight.
    static var specularHighlight: Color { Color.white.opacity(0.45) }
}
