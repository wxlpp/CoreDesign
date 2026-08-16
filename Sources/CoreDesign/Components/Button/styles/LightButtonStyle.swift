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

#Preview("Light — Light") {
    LightButtonStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Light — Dark") {
    LightButtonStylePreviewGallery()
        .preferredColorScheme(.dark)
}

/// 明暗两态检验的是**语义色 token 在两种外观下是否都拉得开对比**——
/// `makeBody` 里没有任何 `colorScheme` 分支，两态的差异全部来自
/// `Color.surfaceInteractive` / `Color.borderSubtle` / `role.resolvedColor` 这三处
/// 系统语义色的自动适配。填充与描边都很弱（`surfaceInteractive` + `borderSubtle`），
/// 正是这种低 chrome 的样式最容易在某一种外观下糊掉，所以两态都要看。
///
/// ⚠️ 仓库 `CLAUDE.md` 曾写「`LightButtonStyle` 会按 `colorScheme` 分支：暗色用
/// `glassEffect`，亮色用柔和阴影代替」——**实测为假**（本文件零 `colorScheme`、
/// 零 `.glassEffect` 调用；#41 之前的 base `95c29cf` 上同样零命中，不是本轮删掉的）。
/// 该句已在同一个 commit 里改正，此处留痕以免它再被抄回来。
///
/// 五个 role 全列的理由同 `SolidButtonStyle`：新增 role 时漏配色能在视觉上兜住。
private struct LightButtonStylePreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            Button {} label: { Text("Primary") }
                .buttonStyle(.light(role: .primary))
            Button {} label: { Text("Secondary") }
                .buttonStyle(.light(role: .secondary))
            Button {} label: { Text("Tertiary") }
                .buttonStyle(.light(role: .tertiary))
            Button {} label: { Text("Warning") }
                .buttonStyle(.light(role: .warning))
            Button {} label: { Text("Danger") }
                .buttonStyle(.light(role: .danger))
            Button {} label: { Text("Disabled") }
                .buttonStyle(.light(role: .secondary))
                .disabled(true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
