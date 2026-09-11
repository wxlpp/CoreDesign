import SwiftUI

// MARK: - Mask Colors / 遮罩基色（Issue #276）

public extension Color {
    /// 亮度转 alpha 遮罩的灰度值；始终不透明，不受系统主题影响。
    static func maskLuminance(_ value: Double) -> Color {
        Color(white: min(1, max(0, value)))
    }

    /// 纯 alpha 遮罩的**不透明**基色（`α = 1`）。
    static var maskOpaque: Color {
        .white
    }
}
