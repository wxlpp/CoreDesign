//
//  FillColors.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/28.
//

import SwiftUI

// MARK: - Fill Colors / 填充颜色
//
// 全部 token 直接指向系统填充色族（`systemFill` / `secondarySystemFill` /
// `tertiarySystemFill` / `quaternarySystemFill`），UIKit / AppKit 双端均正确桥接，
// 随系统外观自动更新。`tertiaryFill` 另被 `SurfaceColors.surfaceCanvasInset` 复用。
public extension Color {
    /// 为细小形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充细小形状，例如滑动条的轨迹。
    static var fill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .systemFill)
        #else
            return Color(nsColor: .systemFill)
        #endif
    }

    /// 中等大小形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充中等大小的形状，例如开关的背景。
    static var secondaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .secondarySystemFill)
        #else
            return Color(nsColor: .secondarySystemFill)
        #endif
    }

    /// 大型形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充大型形状，例如输入字段、搜索栏或按钮。
    static var tertiaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .tertiarySystemFill)
        #else
            return Color(nsColor: .tertiarySystemFill)
        #endif
    }

    /// 大区域复杂内容的覆盖填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充包含复杂内容的大区域，例如展开的表格单元格。
    static var quaternaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .quaternarySystemFill)
        #else
            return Color(nsColor: .quaternarySystemFill)
        #endif
    }

    // MARK: - Skeleton 占位取色（semi-mobile-components Phase 0 定案）
    //
    // 取色决策：骨架屏占位与 shimmer 高亮**不新增 colorset**，一律从 `systemFill` 族派生
    // ——底色直接取 `.fill`（系统填充，含透明度、随外观/对比度自动更新），高光由底色经
    // `.opacity()` 调制出更透明的扫光带（承 accent 衍生态「对系统色调制、不取固定色阶」先例）。
    // 由此免掉新增 colorset 才需要的 `swift package clean` 与 `ColorAssetGuardTests` 登记两环。
    // `Skeleton` 的 shimmer modifier 应复用这两个 token，不要各自重新取色。

    /// 骨架屏占位底色。Skeleton placeholder base fill.
    ///
    /// 直接复用系统 `systemFill`，随系统外观/对比度自动更新；用于骨架屏 line / rect / circle
    /// 占位形状的底色（`.redacted(reason: .placeholder)` 之外、需要显式绘制占位形状时）。
    static var skeletonBase: Color { Color.fill }

    /// 骨架屏 shimmer 扫光高光色。Skeleton shimmer highlight.
    ///
    /// 由 `skeletonBase` 经 `.opacity()` 派生的更透明高光——用于 shimmer 渐变的亮带，
    /// 与底色形成微弱明暗差。无需新增 colorset，随底色一并跟随系统外观。
    ///
    /// > Note: `.opacity()` 降透明造亮带在亮色下更接近浅背景（变亮 ✓），暗色下 systemFill
    /// > 是低透明白、更透明反而更接近深背景（可能变暗，与「暗色亮扫」直觉相反）。此为 Phase 0
    /// > 的初始取值；**暗色观感留给 Skeleton（Issue #162）的视觉评审裁决**——若暗色需要反向亮扫，
    /// > 允许改为 `Color.mix(with:by:in:)` 派生（如向 `Color.contentPrimary` 微调），此 token 可动。
    static var skeletonHighlight: Color { Color.skeletonBase.opacity(0.35) }
}
