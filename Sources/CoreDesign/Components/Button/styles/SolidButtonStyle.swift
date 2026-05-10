//
//  SolidButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

// MARK: - SolidButtonStyle

/// Primer 风格的实色按钮（"solid button"）样式。
///
/// ## 使用场景 / Usage
///
/// 主要 CTA、表单提交、需要强烈视觉权重的主操作；与 Primer Web 端
/// `Button variant="primary" | "danger" | "warning"` 对应。在按钮密度较高的
/// 表单场景，建议优先此样式承载主操作，搭配 `.lightButton(...)` 承载次操作。
///
/// ## 关键参数 / Key Parameters
///
/// - `role`: `ButtonRoleStyleRole`——决定背景色与按下 / 禁用态的语义颜色映射
///   （`primary` → `.accent`，`secondary` → `.secondaryAccent`，`tertiary` →
///   `.neutralAccent`，`warning` → `.warning`，`danger` → `.danger`）。
///
/// ## Primer 概念对应 / Primer Mapping
///
/// 对应 Primer `Button` 组件的 "solid" / "primary" / "danger" / "warning" 变体——
/// 实色背景 + 极细 hairline 描边强化边缘对比，按 v2-tokens 的 `CoreControlMetrics`
/// / `CoreRadius.full` (Capsule) / `CoreBorderWidth.hairline` / `CoreElevation.small`
/// 收齐尺寸 / 圆角 / 描边 / 阴影。
///
/// ## Light / Dark 行为差异 / Color Scheme Behavior
///
/// 同样使用 `CoreElevation.small`，shadow 颜色由 `Resources.xcassets/shadow/shadow-small`
/// colorset 在 light / dark 双取值之间切换（dark 不透明度约 light 的 8 倍以补偿暗色背景下
/// elevation 视觉的损失）。**本样式不使用 `.glassEffect`**——按 epic ADR #3，glass
/// 仅保留在 `BottomInputBar` / `MenuButton` / `CircularGlassButtonStyle` 三个白名单文件。
public struct SolidButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoreControlMetrics.font(for: self.controlSize))
            .foregroundStyle(Color.contentOnAccent)
            .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
            .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
            .contentShape(Capsule(style: .continuous))
            .background(
                Capsule(style: .continuous)
                    .fill(self.backgroundColor(isPressed: configuration.isPressed))
                    .coreShadow(.small)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }

    let role: ButtonRoleStyleRole

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private func backgroundColor(isPressed: Bool) -> Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return isPressed ? self.role.activeColor : self.role.color
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == SolidButtonStyle {
    /// 以指定 role 构造 Primer 实色按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。详见 `ButtonRoleStyleRole`。
    /// - Returns: `SolidButtonStyle` 实例，可直接传给 `.buttonStyle(...)`。
    static func solidButton(role: ButtonRoleStyleRole = .primary) -> SolidButtonStyle {
        SolidButtonStyle(role: role)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button {} label: { Text("Login") }
            .buttonStyle(.solidButton(role: .primary))

        Button {} label: { Text("Register") }
            .buttonStyle(.solidButton(role: .secondary))

        Button {} label: { Text("Warning") }
            .buttonStyle(.solidButton(role: .warning))

        Button {} label: { Text("Danger") }
            .buttonStyle(.solidButton(role: .danger))

        Button {} label: { Text("Disabled") }
            .buttonStyle(.solidButton(role: .primary))
            .disabled(true)
    }
    .padding()
}
