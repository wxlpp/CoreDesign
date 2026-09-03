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
    /// 由 `skeletonBase` 经 `Color.mix(with: .white, by:)` 向白提亮派生——shimmer 渐变里
    /// 比底色更亮的扫光带。无需新增 colorset，随底色一并跟随系统外观。
    ///
    /// > Note（Issue #162 裁决，闭合 Phase 0 留口）：初版曾用 `.opacity(0.35)`，但那是**同色叠加**
    /// > ——在底色上再叠一层同样的半透明灰只会更**深**，扫光读作暗带而非高光（评审 #176 确认）。
    /// > 改为向 `.white` 掺色 0.5：两端外观下都得到比底色明显更亮的扫光带（暗色下即「亮扫」，
    /// > 亮色下近白）。承 `InteractionColors` accent 衍生态「对系统色调制」的先例，token 可动——
    /// > 后续若视觉评审要微调，改这里的掺色因子即可，`Skeleton` 组件复用本 token、不在组件内绕开。
    static var skeletonHighlight: Color { Color.skeletonBase.mix(with: .white, by: 0.5) }

    /// 扫光高光色（`.shine()` 这类掠过内容的高光带）。Specular sweep highlight.
    ///
    /// **固定为白**，与 `contentOnAccent` 族同理——扫光是**光源反射**，
    /// 它在明暗两端都应当比底下的内容**更亮**，而不是"跟随外观取反"。
    ///
    /// > Note（承 Issue #162 / 评审 #176 的裁决）：`skeletonHighlight` 当初正是因为
    /// > 用了**同色叠加**（`.opacity(0.35)`）而被判「扫光读作暗带而非高光」，改为向
    /// > `.white` 掺色。`.shine()` 的初版默认值 `Color.contentPrimary.opacity(0.35)`
    /// > 重犯了同一形态——`contentPrimary` 是 `.label`，浅色外观下近黑 ⇒ 浅色下扫过去
    /// > 的是一道 35% 的**黑带**。`label` 保证的是「与背景对比」，**不是**「比背景亮」。
    /// > ⇒ 本 token 建立，`.shine()` 的默认值改指它，不在组件内绕开。
    static var specularHighlight: Color { Color.white.opacity(0.45) }
}
