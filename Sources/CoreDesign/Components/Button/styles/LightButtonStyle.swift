//
//  LightButtonStyle.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

// MARK: - LightButtonStyle

public struct LightButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(self.textFont)
            .foregroundStyle(self.textColor(isPressed: configuration.isPressed))
            .padding(self.edgeInsets)
            .contentShape(Capsule(style: .continuous))
            .background {
                if self.colorScheme == .dark {
                    Capsule(style: .continuous)
                        .fill(Color.surfaceInteractive)
                        .padding(1)
                        .glassEffect()
                } else {
                    Capsule(style: .continuous)
                        .fill(Color.surfaceInteractive)
                        .shadow(
                            color: .black.opacity(configuration.isPressed ? 0.04 : 0.08),
                            radius: configuration.isPressed ? 2 : 6,
                            x: 0,
                            y: configuration.isPressed ? 1 : 2
                        )
                }
            }
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        self.colorScheme == .dark
                            ? Color.white.opacity(0.2)
                            : Color.borderSubtle,
                        lineWidth: 0.8
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

    private func textColor(isPressed: Bool) -> Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return isPressed ? self.role.activeColor : self.role.color
    }
}

public extension ButtonStyle where Self == LightButtonStyle {
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
