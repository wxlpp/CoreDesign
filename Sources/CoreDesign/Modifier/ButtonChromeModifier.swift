import SwiftUI

// MARK: - ButtonChromeModifier

private struct ButtonChromeModifier<S: Shape>: ViewModifier {
    let shape: S
    let controlSize: ControlSize

    func body(content: Content) -> some View {
        content
            .coreFont(CoreControlMetrics.fontToken(for: self.controlSize))
            .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
            .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
            .contentShape(self.shape)
    }
}

// MARK: - View extension

extension View {
    func buttonChrome(shape: some Shape, controlSize: ControlSize) -> some View {
        self.modifier(ButtonChromeModifier(shape: shape, controlSize: controlSize))
    }
}
