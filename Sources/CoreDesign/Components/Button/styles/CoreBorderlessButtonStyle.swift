//
//  CoreBorderlessButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

// MARK: - CoreBorderlessButtonStyle

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
///
/// ## 玻璃效果 / Glass Effect
///
/// 本样式有意不使用玻璃效果——无边框按钮没有视觉容器，玻璃效果需要背景材质，
/// 与 "invisible" 语义矛盾。
///
/// ## ⚠️ 与 SwiftUI 的同名冲突 / SwiftUI collision
///
/// 本类型原名 `BorderlessButtonStyle`，与 SwiftUI 自带类型同名——下游写该名**能编译**
/// 但静默拿到 SwiftUI 的版本。Issue #94 加 `Core` 前缀正是为此，**不要为了"简洁"把
/// 前缀去掉**。
///
/// 但要注意：**访问器名 `borderless` 仍与 SwiftUI 的 `PrimitiveButtonStyle.borderless`
/// 重合**，两者只差一对括号，且都能编译、无任何诊断：
///
/// ```swift
/// .buttonStyle(.borderless)              // ← SwiftUI 的，不是本样式
/// .buttonStyle(.borderless())            // ← 本样式（role 默认 .primary）
/// .buttonStyle(.borderless(role: .danger))  // ← 本样式
/// ```
///
/// 保留 `borderless` 这个访问器名是有意的取舍（它让 `App/` 与 docs 示例在改名后
/// 零改动），代价就是上面这处残留歧义。**调用时务必带括号。**
public struct CoreBorderlessButtonStyle: PrimitiveButtonStyle {
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

    public let role: ButtonRoleStyleRole

    /// 以指定 role 构造 / Init with role。
    ///
    /// 显式声明才能让下游可达——Swift 合成的 memberwise init 取决于成员可见性，
    /// 此前 `role` 是 internal，下游实测报 `initializer is inaccessible`。
    public init(role: ButtonRoleStyleRole = .primary) {
        self.role = role
    }

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

public extension PrimitiveButtonStyle where Self == CoreBorderlessButtonStyle {
    /// 以指定 role 构造 Primer 无边框按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。仅决定 label 文字颜色。
    /// - Returns: `CoreBorderlessButtonStyle` 实例，可直接传给 `.buttonStyle(...)`。
    static func borderless(role: ButtonRoleStyleRole = .primary) -> CoreBorderlessButtonStyle {
        CoreBorderlessButtonStyle(role: role)
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
