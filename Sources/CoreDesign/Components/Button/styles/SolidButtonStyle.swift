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
/// ## 默认档位
///
/// 使用 role 色、muted hairline 描边、pressed scale，且无默认 elevation。
///
/// ⚠️ **#41 破坏性变更**：`glass: Bool`（legacy Telegram 玻璃模式开关）已按公约第 3 节
/// 终局条款 (b) **删除**——跨仓实测对外零调用点（`App/` / `scripts/downstream-probe` /
/// StoryUI 全仓均零命中，`glass:` 的命中全部落在 `.build/checkouts` 里的 vendored 本库
/// 副本），(b) 成立 ⇒ 删除而非记入豁免清单。需要玻璃观感的场景改用
/// `CircularGlassButtonStyle`（命名即语义、不带 Bool，正是「组合优先于配置开关」的正解）。
///
/// ## 使用场景 / Usage
///
/// 主要 CTA、表单提交、Merge 按钮等需要强烈视觉权重的主操作。
public struct SolidButtonStyle: ButtonStyle {
    public let role: ButtonRoleStyleRole

    public init(role: ButtonRoleStyleRole = .primary) {
        self.role = role
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let backgroundColor = self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: isPressed)

        configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.foregroundColor)
            .buttonBackground(
                shape: Capsule(style: .continuous),
                fill: backgroundColor,
                border: Color.borderMuted,
                isPressed: isPressed,
                pressedOpacity: 0.92
            )
    }

    /// 前景色：禁用态统一 `contentDisabled`，其余走 `contentOnAccent`。
    /// （原先还有一支「glass 用纯白」——随 `glass` 一并删除。）
    private var foregroundColor: Color {
        self.isEnabled ? .contentOnAccent : .contentDisabled
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == SolidButtonStyle {
    /// 构造主操作按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。
    static func solid(role: ButtonRoleStyleRole = .primary) -> SolidButtonStyle {
        SolidButtonStyle(role: role)
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
