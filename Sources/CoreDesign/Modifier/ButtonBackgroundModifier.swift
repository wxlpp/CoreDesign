//
//  ButtonBackgroundModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ButtonBackgroundModifier

/// 非 glass 按钮的背景层 / Non-glass button background：填充 + 描边 + 按压反馈。
///
/// 合并自原先的 `SolidButtonBackgroundModifier` 与 `LightButtonBackgroundModifier`
/// （审计项 B3c）——两者结构完全相同，仅填充色、描边 token 与按压不透明度不同。
///
/// > `pressedOpacity` 默认 `nil`（不施加）：`LightButtonStyle` 的按压变暗写在
/// > 本 modifier **之外**，因为它的 glass 分支同样需要；`SolidButtonStyle` 则只在
/// > 非 glass 分支变暗，故由本参数承担。合并时保持这一位置差异，否则 Light 的
/// > glass 分支会丢掉按压反馈。
private struct ButtonBackgroundModifier: ViewModifier {
    let fill: Color
    let border: Color
    let isPressed: Bool
    var pressedOpacity: Double?

    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(self.fill)
            )
            .overlay(
                Capsule(style: .continuous)
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
    /// - Parameter pressedOpacity: 按压时的不透明度；`nil` 表示不施加
    ///   （`LightButtonStyle` 的按压变暗写在本 modifier 之外，因为它的 glass
    ///   分支同样需要）。
    func buttonBackground(
        fill: Color,
        border: Color,
        isPressed: Bool,
        pressedOpacity: Double? = nil
    ) -> some View {
        self.modifier(ButtonBackgroundModifier(
            fill: fill,
            border: border,
            isPressed: isPressed,
            pressedOpacity: pressedOpacity
        ))
    }
}
