import SwiftUI

// MARK: - ButtonBackgroundModifier

private struct ButtonBackgroundModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let fill: Color
    let border: Color
    let isPressed: Bool
    var pressedOpacity: Double?

    func body(content: Content) -> some View {
        content
            .background(
                self.shape
                    .fill(self.fill)
            )
            .overlay(
                self.shape
                    .strokeBorder(self.border, lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .opacity(self.isPressed ? (self.pressedOpacity ?? 1) : 1)
            .animation(.snappy(duration: 0.16), value: self.isPressed)
    }
}

// MARK: - View extension

extension View {
    func buttonBackground(
        shape: some InsettableShape,
        fill: Color,
        border: Color,
        isPressed: Bool,
        pressedOpacity: Double? = nil
    ) -> some View {
        self.modifier(ButtonBackgroundModifier(
            shape: shape,
            fill: fill,
            border: border,
            isPressed: isPressed,
            pressedOpacity: pressedOpacity
        ))
    }
}
