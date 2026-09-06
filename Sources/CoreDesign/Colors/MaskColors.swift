import SwiftUI

// MARK: - Mask Colors / 遮罩基色（Issue #276）

public extension Color {
    /// 纯 alpha 遮罩的**不透明**基色（`α = 1`）。
    static var maskOpaque: Color {
        .white
    }
}
