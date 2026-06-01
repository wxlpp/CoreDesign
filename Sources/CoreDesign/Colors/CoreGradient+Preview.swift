//
//  CoreGradient+Preview.swift
//  CoreDesign
//

import SwiftUI

// 视觉冒烟预览 / visual smoke check.
// 在 Xcode 中开启 Blossom trait 可见珊瑚粉 + 紫 + 渐变；默认主题下渐变退化为纯色。
#Preview("Theme Smoke") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accent / Secondary")
                .font(.headline)
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12).fill(Color.accent).frame(height: 56)
                RoundedRectangle(cornerRadius: 12).fill(Color.secondary).frame(height: 56)
            }

            Text("Gradients")
                .font(.headline)
            RoundedRectangle(cornerRadius: 12).fill(CoreGradient.brand).frame(height: 56)
            RoundedRectangle(cornerRadius: 12).fill(CoreGradient.cta).frame(height: 56)
            RoundedRectangle(cornerRadius: 20).fill(CoreGradient.canvas).frame(height: 120)
        }
        .padding()
    }
    .background(CoreGradient.canvas)
}
