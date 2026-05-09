//
//  SolidButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

// MARK: - SolidButtonStyle

public struct SolidButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(self.textFont)
            .foregroundStyle(Color.contentOnAccent)
            .padding(self.edgeInsets)
            .contentShape(Capsule(style: .continuous))
            .background(
                Capsule(style: .continuous)
                    .fill(self.backgroundColor(isPressed: configuration.isPressed))
                    .padding(1)
                    .glassEffect()
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }

    let role: ButtonRoleStyleRole

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

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
        case .mini: .caption
        case .small: .callout
        case .regular: .body
        case .large: .title3
        case .extraLarge: .title
        @unknown default:
            .body
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return isPressed ? self.role.activeColor : self.role.color
    }
}

public extension ButtonStyle where Self == SolidButtonStyle {
    static func solidButton(role: ButtonRoleStyleRole = .primary) -> SolidButtonStyle {
        SolidButtonStyle(role: role)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button {} label: { Text("Login") }
            .buttonStyle(.solidButton(role: .primary))

        Button {} label: { Text("Register") }
            .buttonStyle(.solidButton(role: .secondary))

        Button {} label: { Text("Warning") }
            .buttonStyle(.solidButton(role: .warning))

        Button {} label: { Text("Danger") }
            .buttonStyle(.solidButton(role: .danger))

        Button {} label: { Text("Disabled") }
            .buttonStyle(.solidButton(role: .primary))
            .disabled(true)
    }
    .padding()
}
