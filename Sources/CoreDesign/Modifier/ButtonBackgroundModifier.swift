//
//  ButtonBackgroundModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ButtonBackgroundModifier

/// 非 glass 按钮的背景层 / Non-glass button background：填充 + 描边 + 按压反馈。
///
/// 合并自原先的 `SolidButtonBackgroundModifier` 与 `LightButtonBackgroundModifier`
/// ——两者结构完全相同，仅填充色、描边 token 与按压不透明度不同。
///
/// > `pressedOpacity` 默认 `nil`（不施加）：`LightButtonStyle` 的按压变暗写在
/// > 本 modifier **之外**，因为它的 glass 分支同样需要；`SolidButtonStyle` 则只在
/// > 非 glass 分支变暗，故由本参数承担。合并时保持这一位置差异，否则 Light 的
/// > glass 分支会丢掉按压反馈。
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
    /// 套用非 glass 按钮的背景层（填充 / 描边 / 按压反馈）。
    ///
    /// **有意保持 internal**（与 `buttonChrome` 同）：这是按钮体系的内部收敛
    /// 产物，四个 style 都在包内。纯重构不对外承诺新 modifier。
    ///
    /// - Parameters:
    ///   - shape: 背景与描边的形状。泛型化而非写死 `Capsule`——将来的圆角矩形
    ///     CTA / 方形 icon button 能复用本层，不必再开一个平行实现。
    ///   - pressedOpacity: 按压时的不透明度；`nil` 表示不施加
    ///     （`LightButtonStyle` 的按压变暗写在本 modifier 之外，因为它的 glass
    ///     分支同样需要）。
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
