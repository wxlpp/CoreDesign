import Foundation
import SwiftUI

// MARK: - CoreBorderlessButtonStyle

/// 无边框 / 无背景按钮样式。
public struct CoreBorderlessButtonStyle: PrimitiveButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: self.isPressed))
            .clipShape(Capsule(style: .continuous))
            .animation(.easeInOut, value: self.isPressed)
            .simultaneousGesture(self.pressedStateGesture)
            .onTapGesture(count: 1, perform: configuration.trigger)
    }

    public let role: ButtonRoleStyleRole

    /// 以指定 role 构造 / Init with role。
    public init(role: ButtonRoleStyleRole = .primary) {
        self.role = role
    }

    @GestureState private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private var pressedStateGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(self.$isPressed) { _, isPressed, _ in
                isPressed = true
            }
    }
}

// MARK: - PrimitiveButtonStyle convenience

public extension PrimitiveButtonStyle where Self == CoreBorderlessButtonStyle {
    /// 以指定 role 构造无边框按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。仅决定 label 文字颜色。
    /// - Returns: `CoreBorderlessButtonStyle` 实例，可直接传给 `.buttonStyle(...)`。
    static func borderless(role: ButtonRoleStyleRole = .primary) -> CoreBorderlessButtonStyle {
        CoreBorderlessButtonStyle(role: role)
    }
}

#Preview {
    VStack {
        Button {} label: {
            Text("Login")
        }
        .buttonStyle(.borderless(role: .primary))

        Button {} label: {
            Text("Register")
        }
        .buttonStyle(.borderless(role: .secondary))

        Button {} label: {
            Text("Forgot Password")
        }
        .buttonStyle(.borderless(role: .warning))

        Button {} label: {
            Text("Submit")
        }
        .buttonStyle(.borderless(role: .danger))

        Button {} label: {
            Text("Cancel")
        }
        .buttonStyle(.borderless(role: .tertiary))
    }
}
