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
        let backgroundColor = self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: isPressed)

        // 共同结构只写一次（审计项 B3b）；两支各自只剩尾部的背景层差异。
        let base = configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.foregroundColor)

        if self.glass {
            base
                .backgroundStyle(backgroundColor)
                .modifier(TelegramGlassButtonModifier(
                    shape: Capsule(style: .continuous),
                    isPressed: isPressed
                ))
        } else {
            base
                .buttonBackground(
                    shape: Capsule(style: .continuous),
                    fill: backgroundColor,
                    border: Color.borderMuted,
                    isPressed: isPressed,
                    pressedOpacity: 0.92
                )
        }
    }

    /// glass 用纯白、非 glass 用 `contentOnAccent`；禁用态统一 `contentDisabled`。
    private var foregroundColor: Color {
        guard self.isEnabled else { return .contentDisabled }
        return self.glass ? .white : .contentOnAccent
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

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
