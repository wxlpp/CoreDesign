//
//  BorderlessButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

// MARK: - BorderlessButtonStyle

/// Primer 风格的无边框 / 无背景按钮（"borderless" / "invisible button"）样式。
///
/// ## 使用场景 / Usage
///
/// 行内文本链接、工具栏的次要触发器、表格单元格内的轻量动作；与 Primer
/// `Button variant="invisible"` / `Link` 的语义一致——**仅 label 自身可见**，
/// 无视觉容器（无背景、无边框、无阴影），按下时通过文字色 + 不透明度反馈。
///
/// ## 关键参数 / Key Parameters
///
/// - `role`: `ButtonRoleStyleRole`——决定文字颜色（normal / pressed / disabled 三态）。
///
/// ## Primer 概念对应 / Primer Mapping
///
/// 对应 Primer `Button variant="invisible"` 与 `IconButton variant="invisible"`：
/// 不渲染任何 chrome，仅 label 着色。padding 仍按 `CoreControlMetrics` 走 token，
/// 保证多按钮并排时点击区域大小一致。
///
/// ## Light / Dark 行为差异 / Color Scheme Behavior
///
/// 无视觉容器，颜色完全由 `role.color` / `role.activeColor` / `role.disabledColor`
/// 决定；这些 token 自身已支持 light / dark adaptive，无需在本样式分支处理。
public struct BorderlessButtonStyle: PrimitiveButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
            .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
            .foregroundStyle(self.textColor)
            .clipShape(Capsule(style: .continuous))
            .animation(.easeInOut, value: self.isPressed)
            .simultaneousGesture(self.pressedStateGesture)
            .onTapGesture(count: 1, perform: configuration.trigger)
    }

    let role: ButtonRoleStyleRole

    @GestureState private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private var pressedStateGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(self.$isPressed) { _, isPressed, _ in
                isPressed = true
            }
    }

    private var textColor: Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return self.isPressed ? self.role.activeColor : self.role.color
    }
}

// MARK: - PrimitiveButtonStyle convenience

public extension PrimitiveButtonStyle where Self == BorderlessButtonStyle {
    /// 以指定 role 构造 Primer 无边框按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。仅决定 label 文字颜色。
    /// - Returns: `BorderlessButtonStyle` 实例，可直接传给 `.buttonStyle(...)`。
    static func borderless(role: ButtonRoleStyleRole = .primary) -> BorderlessButtonStyle {
        BorderlessButtonStyle(role: role)
    }
}

#Preview {
    VStack {
        Button {} label: {
            Text("Login")
        }
        .buttonStyle(.borderless(role: .primary))

        Button {} label: {
            Text("Register")
        }
        .buttonStyle(.borderless(role: .secondary))

        Button {} label: {
            Text("Forgot Password")
        }
        .buttonStyle(.borderless(role: .warning))

        Button {} label: {
            Text("Submit")
        }
        .buttonStyle(.borderless(role: .danger))

        Button {} label: {
            Text("Cancel")
        }
        .buttonStyle(.borderless(role: .tertiary))
    }
}
