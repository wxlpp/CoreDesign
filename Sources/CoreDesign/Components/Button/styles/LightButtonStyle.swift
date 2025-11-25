//
//  SolidButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

public struct LightButtonStyle: PrimitiveButtonStyle {
    @GestureState private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    let role: ButtonRoleStyleRole

    private var pressedStateGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(self.$isPressed) { _, isPressed, _ in
                isPressed = true
            }
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(self.textFont)
            .padding(self.edgeInsets)
            .foregroundStyle(self.textColor)
            .background(Color.tertiaryFill)
            .clipShape(Capsule(style: .continuous))
            .animation(.easeInOut, value: self.isPressed)
            .simultaneousGesture(self.pressedStateGesture)
            .onTapGesture(count: 1, perform: configuration.trigger)
    }

    private var edgeInsets: EdgeInsets {
        switch self.controlSize {
        case .mini: EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12)
        case .small: EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12)
        case .regular: EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        case .large: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        case .extraLarge: EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        @unknown default:
            EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        }
    }

    private var textFont: Font {
        switch self.controlSize {
        case .mini: .systemCaption
        case .small: .systemCallout
        case .regular: .systemBody
        case .large: .systemTitle3
        case .extraLarge: .systemTitle
        @unknown default:
            .systemBody
        }
    }

    private var textColor: Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return self.isPressed ? self.role.activeColor : self.role.color
    }
}

extension PrimitiveButtonStyle where Self == LightButtonStyle {
    public static func lightButton(role: ButtonRoleStyleRole = .primary) -> LightButtonStyle {
        LightButtonStyle(role: role)
    }
}

#Preview {
    VStack {
        Button {} label: {
            Text("Login")
        }
        .buttonStyle(.lightButton(role: .primary))
        .controlSize(.mini)

        Button {} label: {
            Text("Register")
        }
        .buttonStyle(.lightButton(role: .secondary))
        .controlSize(.small)

        Button {} label: {
            Text("Forgot Password")
        }
        .buttonStyle(.lightButton(role: .warning))
        .controlSize(.regular)

        Button {} label: {
            Text("Submit")
        }
        .buttonStyle(.lightButton(role: .danger))
        .controlSize(.large)

        Button {} label: {
            Text("Cancel")
        }
        .buttonStyle(.lightButton(role: .tertiary))
        .controlSize(.extraLarge)
    }
}
