import SwiftUI

// MARK: - TelegramGlassButtonModifier

/// Telegram 风格的玻璃按钮四层结构，抽取为可复用 modifier。
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

#Preview {
    VStack(spacing: CoreSpacing.xl) {
        Text("Capsule · default border")
            .padding(.horizontal, CoreSpacing.md)
            .padding(.vertical, CoreSpacing.sm)
            .modifier(TelegramGlassButtonModifier(shape: Capsule(), isPressed: false))

        Image(systemName: "plus")
            .padding(CoreSpacing.md)
            .modifier(TelegramGlassButtonModifier(
                shape: Circle(),
                isPressed: true,
                border: .borderSubtle,
                pressFeedback: true
            ))
    }
    .foregroundStyle(Color.contentPrimary)
    .padding(CoreSpacing.xxxl)
    .background(Color.surfaceCanvas)
    .preferredColorScheme(.dark)
}
