//
//  CoreGradient.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Gradient Tokens / 渐变 token
//
// 暖悦风格的灵魂在渐变。本层以 `AnyShapeStyle` 统一返回类型，使纯色与渐变可
// 互换：调用方写 `.background(CoreGradient.canvas)` / `.fill(CoreGradient.cta)`
// 在两种主题下都成立。
//
// - Blossom trait 开启时：返回真实多色 `LinearGradient`。
// - 默认主题：退化为对应纯色，现有观感零变化。

public enum CoreGradient {

    /// 品牌渐变 / brand gradient.
    /// Blossom: 珊瑚粉 → 玫红。默认：纯 `Color.accent`。
    public static var brand: AnyShapeStyle {
        #if Blossom
        AnyShapeStyle(
            LinearGradient(
                colors: [.brand4, .brand6],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        #else
        AnyShapeStyle(Color.accent)
        #endif
    }

    /// 主操作按钮渐变 / primary CTA gradient.
    /// Blossom: 亮珊瑚 → 玫红。默认：纯 `Color.accent`。
    public static var cta: AnyShapeStyle {
        #if Blossom
        AnyShapeStyle(
            LinearGradient(
                colors: [.brand3, .brand5],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        #else
        AnyShapeStyle(Color.accent)
        #endif
    }

    /// 页面画布渐变 / page canvas gradient.
    /// Blossom: 粉 → 薰衣草紫 → 青 三色柔和渐变。默认：纯 `Color.surfaceCanvas`。
    public static var canvas: AnyShapeStyle {
        #if Blossom
        AnyShapeStyle(
            LinearGradient(
                colors: [.brand1, .violet2, .cyan1],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        #else
        AnyShapeStyle(Color.surfaceCanvas)
        #endif
    }
}
