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
/// 1. **底色填充**：`shape.inset(by: glassInset).fill(.background)`，
///    通过 `InsettableShape.inset(by:)` 把底色 path 真正内缩 2pt（不是用 `.padding`
///    撑开外框），颜色由调用方的 `.backgroundStyle()` 注入。
/// 2. **玻璃壳**：`.glassEffect()` 应用在底色填充视图上。注意 `glassEffect`
///    是 **view-level** material 修饰器（材质渲染在视图自身 frame 上），不会
///    跟随上一步 `inset(by:)` 收缩——底色 path 内缩，但视图 frame 仍是原始
///    shape 全尺寸，因此玻璃材质实际覆盖原始 shape 全尺寸；视觉上呈现“内缩
///    底色透过玻璃微微透出”的分层效果。
/// 3. **细白描边**：`shape.strokeBorder(.white.opacity(0.2), lineWidth: .hairline)`
///    在外层 shape（未内缩）边缘叠加一条细白线。
/// 4. **按下反馈**：`scaleEffect(pressedScale)`。
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
                self.shape
                    .inset(by: CoreButtonMetrics.glassInset)
                    .fill(.background)
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
