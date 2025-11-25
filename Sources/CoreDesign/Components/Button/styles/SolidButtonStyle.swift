//
//  SolidButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

public struct SolidButtonStyle: PrimitiveButtonStyle {
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
            .foregroundStyle(Color.white)
            .background(self.backgroundColor)
            .clipShape(Capsule(style: .continuous))
            .animation(.easeInOut, value: self.isPressed)
            .simultaneousGesture(self.pressedStateGesture)
            .onTapGesture(count: 1, perform: configuration.trigger)
    }

    private var backgroundColor: Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return self.isPressed ? self.role.activeColor : self.role.color
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
}

extension PrimitiveButtonStyle where Self == SolidButtonStyle {
    public static func solidButton(role: ButtonRoleStyleRole = .primary) -> SolidButtonStyle {
        SolidButtonStyle(role: role)
    }
}

#Preview {
    VStack {
        Button {} label: {
            Text("Login")
        }
        .buttonStyle(.solidButton(role: .primary))
        .controlSize(.mini)
        .disabled(true)

        Button {} label: {
            Text("Register")
        }
        .buttonStyle(.solidButton(role: .secondary))
        .controlSize(.small)

        Button {} label: {
            Text("Forgot Password")
        }
        .buttonStyle(.solidButton(role: .warning))
        .controlSize(.regular)

        Button {} label: {
            Text("Submit")
        }
        .buttonStyle(.solidButton(role: .danger))
        .controlSize(.large)

        Button {} label: {
            Text("Cancel")
        }
        .buttonStyle(.solidButton(role: .tertiary))
        .controlSize(.extraLarge)
    }
}
