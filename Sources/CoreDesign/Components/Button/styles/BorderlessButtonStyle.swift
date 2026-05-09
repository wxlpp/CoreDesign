//
//  BorderlessButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

// MARK: - BorderlessButtonStyle

public struct BorderlessButtonStyle: PrimitiveButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .foregroundStyle(self.textColor)
            .clipShape(Capsule(style: .continuous))
            .animation(.easeInOut, value: self.isPressed)
            .simultaneousGesture(self.pressedStateGesture)
            .onTapGesture(count: 1, perform: configuration.trigger)
    }

    let role: ButtonRoleStyleRole

    @GestureState private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    private var pressedStateGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(self.$isPressed) { _, isPressed, _ in
                isPressed = true
            }
    }

    private var textColor: Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return self.isPressed ? self.role.activeColor : self.role.color
    }
}

public extension PrimitiveButtonStyle where Self == BorderlessButtonStyle {
    static func borderless(role: ButtonRoleStyleRole = .primary) -> BorderlessButtonStyle {
        BorderlessButtonStyle(role: role)
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
