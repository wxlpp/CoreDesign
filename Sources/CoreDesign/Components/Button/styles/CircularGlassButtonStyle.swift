//
//  CircularGlassButtonStyle.swift
//  CoreDesign
//
//  Created by GitHub Copilot on 2026/3/31.
//

import SwiftUI

// MARK: - CircularGlassButtonStyle

struct CircularGlassButtonStyle: ButtonStyle {
    var diameter: CGFloat = 38

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: self.diameter, height: self.diameter)
            .contentShape(Circle())
            .background(
                Circle()
                    .fill(.background)
                    .padding(2)
                    .glassEffect()
            )
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.8)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CircularGlassButtonStyle {
    static var circularGlass: CircularGlassButtonStyle {
        CircularGlassButtonStyle()
    }

    static func circularGlass(diameter: CGFloat) -> CircularGlassButtonStyle {
        CircularGlassButtonStyle(diameter: diameter)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        Button {} label: {
            Image(systemName: "wand.and.sparkles.inverse")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .buttonStyle(.circularGlass)
    }
}
