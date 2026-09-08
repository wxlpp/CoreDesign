import SwiftUI

// MARK: - LightButtonStyle

/// 次要操作按钮样式（"light button"）。
public struct LightButtonStyle: ButtonStyle {
    public let role: ButtonRoleStyleRole

    public init(role: ButtonRoleStyleRole = .primary) {
        self.role = role
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.role.resolvedColor(accent: self.coreAccent, isEnabled: self.isEnabled, isPressed: isPressed))
            .buttonBackground(
                shape: Capsule(style: .continuous),
                fill: Color.surfaceInteractive,
                border: Color.borderSubtle,
                isPressed: isPressed
            )
            .opacity(isPressed ? 0.9 : 1)
    }

    @Environment(\.coreAccent) private var coreAccent
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
