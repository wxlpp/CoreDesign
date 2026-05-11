//
//  CircularGlassButtonStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CircularGlassButtonStyle

/// 圆形玻璃浮按钮样式。
///
/// 始终使用 Telegram 玻璃四层结构（命名即语义），不使用 `glass:` 参数。
/// 为 BottomInputBar 的 send / stop / shuffle 浮按钮，或任何漂浮在内容之上的
/// 圆形 icon 按钮提供清晰的 elevation 暗示。
public struct CircularGlassButtonStyle: ButtonStyle {
    public var diameter: CGFloat = 38

    public init(diameter: CGFloat = 38) {
        self.diameter = diameter
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: self.diameter, height: self.diameter)
            .contentShape(Circle())
            .backgroundStyle(Color.surfaceInteractive)
            .modifier(TelegramGlassButtonModifier(
                shape: Circle(),
                isPressed: configuration.isPressed
            ))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == CircularGlassButtonStyle {
    /// 默认直径（38pt）的圆形玻璃按钮样式。
    static var circularGlass: CircularGlassButtonStyle {
        CircularGlassButtonStyle()
    }

    /// 自定义直径的圆形玻璃按钮样式。
    ///
    /// - Parameter diameter: 按钮直径（pt）。
    /// - Returns: `CircularGlassButtonStyle` 实例。
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
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular), weight: .semibold))
                .foregroundStyle(.white)
        }
        .buttonStyle(.circularGlass)
    }
}
