//
//  SolidButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import SwiftUI

// MARK: - SolidButtonStyle

/// 主操作按钮样式（"solid button"）。
///
/// ## Native Primer 默认
///
/// 默认使用 role 色、muted hairline 描边、pressed scale，且无默认 elevation。
///
/// 显式传入 `glass: true` 时保留 legacy Telegram 玻璃模式，使用
/// `TelegramGlassButtonModifier` 四层结构：底色 + 2pt 内缩 + 玻璃壳 + 细白描边。
/// 底色由 `role.color` 通过 `.backgroundStyle()` 注入。
///
/// ## 使用场景 / Usage
///
/// 主要 CTA、表单提交、Merge 按钮等需要强烈视觉权重的主操作。
public struct SolidButtonStyle: ButtonStyle {
    public let role: ButtonRoleStyleRole
    public let glass: Bool

    public init(role: ButtonRoleStyleRole = .primary, glass: Bool = false) {
        self.role = role
        self.glass = glass
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let backgroundColor = self.backgroundColor(isPressed: isPressed)

        if self.glass {
            configuration.label
                .font(CoreControlMetrics.font(for: self.controlSize))
                .foregroundStyle(self.isEnabled ? Color.white : Color.contentDisabled)
                .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
                .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
                .contentShape(Capsule(style: .continuous))
                .backgroundStyle(backgroundColor)
                .modifier(
                    TelegramGlassButtonModifier(
                        shape: Capsule(style: .continuous),
                        isPressed: isPressed
                    )
                )
        } else {
            configuration.label
                .font(CoreControlMetrics.font(for: self.controlSize))
                .foregroundStyle(self.isEnabled ? Color.contentOnAccent : Color.contentDisabled)
                .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
                .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
                .contentShape(Capsule(style: .continuous))
                .modifier(
                    SolidButtonBackgroundModifier(
                        backgroundColor: backgroundColor,
                        isPressed: isPressed
                    )
                )
        }
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private func backgroundColor(isPressed: Bool) -> Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return isPressed ? self.role.activeColor : self.role.color
    }
}

// MARK: - SolidButtonBackgroundModifier (non-glass fallback)

private struct SolidButtonBackgroundModifier: ViewModifier {
    let backgroundColor: Color
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(self.backgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .opacity(self.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.16), value: self.isPressed)
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == SolidButtonStyle {
    /// 构造主操作按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。
    /// - Parameter glass: 是否启用 legacy Telegram 玻璃模式（默认 `false`）。
    static func solid(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> SolidButtonStyle {
        SolidButtonStyle(role: role, glass: glass)
    }
}

#Preview("Solid — default") {
    VStack(spacing: 12) {
        Button {} label: { Text("Primary") }
            .buttonStyle(.solid(role: .primary))
        Button {} label: { Text("Danger") }
            .buttonStyle(.solid(role: .danger))
        Button {} label: { Text("Disabled") }
            .buttonStyle(.solid(role: .primary))
            .disabled(true)
    }
    .padding()
}

#Preview("Solid — explicit glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Primary") }
            .buttonStyle(.solid(role: .primary, glass: true))
        Button {} label: { Text("Secondary") }
            .buttonStyle(.solid(role: .secondary, glass: true))
    }
    .padding()
}
