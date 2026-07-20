//
//  LightButtonStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - LightButtonStyle

/// 次要操作按钮样式（"light button"）。
///
/// 默认使用 `surfaceInteractive`、`borderSubtle` hairline、pressed scale，且无默认 elevation。
/// 显式传入 `glass: true` 时保留 legacy Telegram 玻璃模式，使用
/// `TelegramGlassButtonModifier` 和 `surfaceInteractive` 底色。
public struct LightButtonStyle: ButtonStyle {
    public let role: ButtonRoleStyleRole
    public let glass: Bool

    public init(role: ButtonRoleStyleRole = .primary, glass: Bool = false) {
        self.role = role
        self.glass = glass
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        // 共同结构只写一次（审计项 B3b）；按压变暗对两支都适用，故提到 Group 上，
        // 这也是 `buttonBackground` 不传 `pressedOpacity` 的原因。
        let base = configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: isPressed))

        Group {
            if self.glass {
                base
                    .backgroundStyle(Color.surfaceInteractive)
                    .modifier(TelegramGlassButtonModifier(
                        shape: Capsule(style: .continuous),
                        isPressed: isPressed
                    ))
            } else {
                base
                    .buttonBackground(
                        fill: Color.surfaceInteractive,
                        border: Color.borderSubtle,
                        isPressed: isPressed
                    )
            }
        }
        .opacity(isPressed ? 0.9 : 1)
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

}


// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == LightButtonStyle {
    static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> LightButtonStyle {
        LightButtonStyle(role: role, glass: glass)
    }
}

#Preview("Light — default") {
    VStack(spacing: 12) {
        Button {} label: { Text("Cancel") }
            .buttonStyle(.light(role: .secondary))
        Button {} label: { Text("Disabled") }
            .buttonStyle(.light(role: .secondary))
            .disabled(true)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Light — explicit glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Cancel") }
            .buttonStyle(.light(role: .secondary, glass: true))
    }
    .padding()
}
