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
/// 3. **描边**：默认 `shape.strokeBorder(.white.opacity(0.2), lineWidth: .hairline)`
///    在外层 shape（未内缩）边缘叠加一条细白线；可经 `border:` 换成语义色
///    （`CoreMenuButton` 用 `Color.borderSubtle`）。
/// 4. **按下反馈**：默认 `scaleEffect(pressedScale)` + `.snappy` 动画；
///    可经 `pressFeedback: false` 关闭（非交互式容器不需要）。
///
/// > `border` / `pressFeedback` 两个参数都有默认值，且默认值 = 参数化之前的
/// > 原行为——既有三个调用点（Solid / Light / CircularGlass）无需传参、行为
/// > 逐字不变。**新增参数时务必保持这一契约。**
/// >
/// > 注：`pressFeedback: false` 时仍会产出 `.scaleEffect(1)` 与
/// > `.animation(nil, value:)` 两个恒等 modifier。`CoreMenuButton` 的两个调用点
/// > 传的 `isPressed` 是编译期常量 `false`，两者都是 no-op，观感等价成立——
/// > 但严格说不是「零 modifier」。
///
/// ## 使用方式 / Usage
///
/// ```swift
/// configuration.label
///     .modifier(TelegramGlassButtonModifier(
///         shape: Capsule(),
///         isPressed: configuration.isPressed
///     ))
///
/// // 语义色描边 + 无按压反馈（非交互式容器）
/// content
///     .modifier(TelegramGlassButtonModifier(
///         shape: Circle(),
///         isPressed: false,
///         border: .borderSubtle,
///         pressFeedback: false
///     ))
/// ```
///
/// Solid / Light / CircularGlass 三种有容器按钮样式共享此 modifier；
/// Borderless 不参与（无视觉容器）。
public struct TelegramGlassButtonModifier<S: InsettableShape>: ViewModifier {
    public let shape: S
    public let isPressed: Bool
    /// 描边色 / Border color：`nil` = 玻璃默认的半透明白。
    public let border: Color?
    /// 是否施加按压缩放与动画 / Whether to apply press scale + animation。
    public let pressFeedback: Bool

    public init(
        shape: S,
        isPressed: Bool,
        border: Color? = nil,
        pressFeedback: Bool = true
    ) {
        self.shape = shape
        self.isPressed = isPressed
        self.border = border
        self.pressFeedback = pressFeedback
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
                    self.border ?? Color.white.opacity(CoreButtonMetrics.glassBorderOpacity),
                    lineWidth: CoreBorderWidth.hairline
                )
            )
            .scaleEffect(self.pressFeedback && self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .animation(self.pressFeedback ? Animation.snappy(duration: 0.16) : nil, value: self.isPressed)
    }
}
