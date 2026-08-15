//
//  LightButtonStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - LightButtonStyle

/// 次要操作按钮样式（"light button"）。
///
/// 使用 `surfaceInteractive` 底色、`borderSubtle` hairline、pressed scale，且无默认 elevation。
///
/// ⚠️ **#41 破坏性变更**：`glass: Bool`（legacy Telegram 玻璃模式开关）已按公约第 3 节
/// 终局条款 (b) **删除**，理由与 `SolidButtonStyle` 同（跨仓零调用点）。需要玻璃观感
/// 改用 `CircularGlassButtonStyle`。
public struct LightButtonStyle: ButtonStyle {
    public let role: ButtonRoleStyleRole

    public init(role: ButtonRoleStyleRole = .primary) {
        self.role = role
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        // 原先两支（glass / 非 glass）共用的按压变暗提到 `Group` 上；只剩一支之后
        // `Group` 没有存在理由，`.opacity` 直接挂在链尾，语义逐字不变。
        // 这也是 `buttonBackground` 不传 `pressedOpacity` 的原因——按压变暗在这里统一施加。
        configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: isPressed))
            .buttonBackground(
                shape: Capsule(style: .continuous),
                fill: Color.surfaceInteractive,
                border: Color.borderSubtle,
                isPressed: isPressed
            )
            .opacity(isPressed ? 0.9 : 1)
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == LightButtonStyle {
    /// 构造次要操作按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。
    static func light(role: ButtonRoleStyleRole = .primary) -> LightButtonStyle {
        LightButtonStyle(role: role)
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
