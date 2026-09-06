import Foundation
import SwiftUI

// MARK: - BorderModifier

struct BorderModifier<S: InsettableShape, Style: ShapeStyle>: ViewModifier {
    var shape: S
    var style: Style
    var width: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                self.shape
                    .strokeBorder(self.style, lineWidth: self.width)
            )
    }
}

public extension View {
    /// 叠加一圈描边 / Add a border.
    ///
    /// - Parameters:
    ///   - style: 描边样式，任意 `ShapeStyle`（含 `Color` 与渐变）。
    ///   - width: 线宽，默认 `CoreBorderWidth.thin`。
    ///   - shape: 描边形状，默认 `Rectangle()`（直角矩形）；pill 传 `Capsule()`、圆形传 `Circle()`。
    func bordered(
        style: some ShapeStyle = Color.borderDefault,
        width: CGFloat = CoreBorderWidth.thin,
        shape: some InsettableShape = Rectangle()
    ) -> some View {
        self.modifier(BorderModifier(shape: shape, style: style, width: width))
    }
}
