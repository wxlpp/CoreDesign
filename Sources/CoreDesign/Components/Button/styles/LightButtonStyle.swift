//
//  LightButtonStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - LightButtonStyle

/// 次要操作按钮样式（"light button"）。
///
/// `glass: true`（默认）时使用 `TelegramGlassButtonModifier`，`surfaceInteractive` 底色。
/// `glass: false` 时退回到 Primer 浅灰实色 + CoreElevation.small 阴影 + borderSubtle 1px。
public struct LightButtonStyle: ButtonStyle {
    public let role: ButtonRoleStyleRole
    public let glass: Bool

    public init(role: ButtonRoleStyleRole = .primary, glass: Bool = true) {
        self.role = role
        self.glass = glass
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        if self.glass {
            configuration.label
                .font(CoreControlMetrics.font(for: self.controlSize))
                .foregroundStyle(self.textColor(isPressed: isPressed))
                .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
                .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
                .contentShape(Capsule(style: .continuous))
                .backgroundStyle(Color.surfaceInteractive)
                .modifier(
                    TelegramGlassButtonModifier(
                        shape: Capsule(style: .continuous),
                        isPressed: isPressed
                    )
                )
                .opacity(isPressed ? 0.9 : 1)
        } else {
            configuration.label
                .font(CoreControlMetrics.font(for: self.controlSize))
                .foregroundStyle(self.textColor(isPressed: isPressed))
                .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
                .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
                .contentShape(Capsule(style: .continuous))
                .modifier(LightButtonBackgroundModifier(isPressed: isPressed))
                .opacity(isPressed ? 0.9 : 1)
        }
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private func textColor(isPressed: Bool) -> Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return isPressed ? self.role.activeColor : self.role.color
    }
}

// MARK: - LightButtonBackgroundModifier (non-glass fallback)

private struct LightButtonBackgroundModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(Color.surfaceInteractive)
                    .coreShadow(.small)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .animation(.snappy(duration: 0.16), value: self.isPressed)
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == LightButtonStyle {
    static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = true) -> LightButtonStyle {
        LightButtonStyle(role: role, glass: glass)
    }
}

#Preview("Light — glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Cancel") }
            .buttonStyle(.light(role: .secondary))
        Button {} label: { Text("Disabled") }
            .buttonStyle(.light(role: .secondary))
            .disabled(true)
    }
    .padding()
    .background(Color.systemGroupedBackground)
}

#Preview("Light — no glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Cancel") }
            .buttonStyle(.light(role: .secondary, glass: false))
    }
    .padding()
}
