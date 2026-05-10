//
//  LightButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

// MARK: - LightButtonStyle

/// Primer 风格的"轻量"按钮（"light button"）样式：浅色 / 透明背景 + 角色色文字。
///
/// ## 使用场景 / Usage
///
/// 次要操作、对话框中的副按钮、与 `.solidButton(...)` 配对承载非主路径动作。
/// 与 Primer Web 端 `Button variant="default"` / `"invisible"` 的语义介于两者之间——
/// 视觉权重低于 solid，但有清晰的边界与背景以保持可点击感。
///
/// ## 关键参数 / Key Parameters
///
/// - `role`: `ButtonRoleStyleRole`——决定**文字**颜色与按下 / 禁用态的语义颜色映射
///   （注意：背景统一为 `surfaceInteractive`，role 不影响背景色，只影响 label）。
///
/// ## Primer 概念对应 / Primer Mapping
///
/// 对应 Primer `Button variant="default"`——浅灰背景 + 主题色文字，视觉重量轻于 solid。
/// 全部尺寸 / 圆角 / 描边 / 阴影走 v2-tokens：`CoreControlMetrics` / `CoreRadius.full` /
/// `CoreBorderWidth.{hairline,thin}` / `CoreElevation.small`。
///
/// ## Light / Dark 行为差异 / Color Scheme Behavior
///
/// **亮色模式**：去除 `.glassEffect`，改用 `surfaceInteractive` 实色 + `CoreElevation.small`
/// 柔和阴影，符合 Primer 桌面 UI 在亮色下"实色 + 1px 边框 + 轻阴影"的视觉语言。
///
/// **暗色模式**：**保留 `.glassEffect`**——按 PRD §US-3 的明确允许（暗色下浅色按钮的
/// glass 视觉是 SwiftUI / iOS 26 的设计语言之一，能在低对比环境下提供合理 elevation
/// 暗示）。
///
/// 两种模式的描边色也分支：暗色用 `Color.white.opacity(0.2)`，亮色用 `Color.borderSubtle`。
public struct LightButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoreControlMetrics.font(for: self.controlSize))
            .foregroundStyle(self.textColor(isPressed: configuration.isPressed))
            .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
            .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
            .contentShape(Capsule(style: .continuous))
            .background {
                if self.colorScheme == .dark {
                    // 暗色：保留 glass（per PRD §US-3 允许的"漂浮在内容上方"暗色场景）
                    Capsule(style: .continuous)
                        .fill(Color.surfaceInteractive)
                        .padding(CoreBorderWidth.thin)
                        .glassEffect()
                } else {
                    // 亮色：去 glass，改 token 化柔和阴影（CoreElevation.small）
                    Capsule(style: .continuous)
                        .fill(Color.surfaceInteractive)
                        .coreShadow(.small)
                }
            }
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        self.colorScheme == .dark
                            ? Color.white.opacity(0.2)
                            : Color.borderSubtle,
                        lineWidth: CoreBorderWidth.hairline
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }

    let role: ButtonRoleStyleRole

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize
    @Environment(\.colorScheme) private var colorScheme

    private func textColor(isPressed: Bool) -> Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return isPressed ? self.role.activeColor : self.role.color
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == LightButtonStyle {
    /// 以指定 role 构造 Primer 轻量按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。决定 label 文字颜色，**不**影响背景。
    /// - Returns: `LightButtonStyle` 实例，可直接传给 `.buttonStyle(...)`。
    static func lightButton(role: ButtonRoleStyleRole = .primary) -> LightButtonStyle {
        LightButtonStyle(role: role)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button {} label: { Text("Login") }
            .buttonStyle(.lightButton(role: .primary))

        Button {} label: { Text("Secondary") }
            .buttonStyle(.lightButton(role: .secondary))

        Button {} label: { Text("Warning") }
            .buttonStyle(.lightButton(role: .warning))

        Button {} label: { Text("Danger") }
            .buttonStyle(.lightButton(role: .danger))

        Button {} label: { Text("Disabled") }
            .buttonStyle(.lightButton(role: .primary))
            .disabled(true)
    }
    .padding()
}
