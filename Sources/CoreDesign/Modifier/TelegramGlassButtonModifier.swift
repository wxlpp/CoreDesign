//
//  TelegramGlassButtonModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - TelegramGlassButtonModifier

/// Telegram 风格的玻璃按钮四层结构，抽取为可复用 modifier。
///
/// ## 四层结构 / Layer Stack
///
/// 1. **底色填充**：`Shape.fill(.background)`，颜色由调用方的 `.backgroundStyle()` 注入。
/// 2. **内缩**：`CoreButtonMetrics.glassInset` (2pt) padding，让底色从玻璃边缘微微透出。
/// 3. **玻璃壳**：`.glassEffect()`，iOS 26 液态玻璃材质。
/// 4. **细白描边**：`Shape.strokeBorder(.white.opacity(0.2), lineWidth: .hairline)`。
///
/// ## 使用方式 / Usage
///
/// ```swift
/// configuration.label
///     .modifier(TelegramGlassButtonModifier(
///         shape: Capsule(),
///         isPressed: configuration.isPressed
///     ))
/// ```
///
/// Solid / Light / CircularGlass 三种有容器按钮样式共享此 modifier；
/// Borderless 不参与（无视觉容器）。
public struct TelegramGlassButtonModifier<S: InsettableShape>: ViewModifier {
    public let shape: S
    public let isPressed: Bool

    public init(shape: S, isPressed: Bool) {
        self.shape = shape
        self.isPressed = isPressed
    }

    public func body(content: Content) -> some View {
        content
            .background(
                self.shape.fill(.background)
                    .padding(CoreButtonMetrics.glassInset)
                    .glassEffect()
            )
            .overlay(
                self.shape.strokeBorder(
                    .white.opacity(CoreButtonMetrics.glassBorderOpacity),
                    lineWidth: CoreBorderWidth.hairline
                )
            )
            .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .animation(.snappy(duration: 0.16), value: self.isPressed)
    }
}
