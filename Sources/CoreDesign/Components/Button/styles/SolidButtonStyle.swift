import SwiftUI

// MARK: - SolidButtonStyle

/// 主操作按钮样式（"solid button"）。
public struct SolidButtonStyle: ButtonStyle {
    public let role: ButtonRoleStyleRole

    public init(role: ButtonRoleStyleRole = .primary) {
        self.role = role
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let backgroundColor = self.role.resolvedColor(accent: self.coreAccent, isEnabled: self.isEnabled, isPressed: isPressed)

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

    private var foregroundColor: Color {
        self.isEnabled ? self.role.onColor : .contentDisabled
    }

    @Environment(\.coreAccent) private var coreAccent
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

#Preview("Solid — Light") {
    SolidButtonStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Solid — Dark") {
    SolidButtonStylePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SolidButtonStylePreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            Button {} label: { Text("Primary") }
                .buttonStyle(.solid(role: .primary))
            Button {} label: { Text("Secondary") }
                .buttonStyle(.solid(role: .secondary))
            Button {} label: { Text("Tertiary") }
                .buttonStyle(.solid(role: .tertiary))
            Button {} label: { Text("Warning") }
                .buttonStyle(.solid(role: .warning))
            Button {} label: { Text("Danger") }
                .buttonStyle(.solid(role: .danger))
            Button {} label: { Text("Disabled") }
                .buttonStyle(.solid(role: .primary))
                .disabled(true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
