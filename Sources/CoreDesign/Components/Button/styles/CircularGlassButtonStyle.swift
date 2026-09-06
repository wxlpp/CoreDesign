import SwiftUI

// MARK: - CircularGlassButtonStyle

/// 圆形玻璃浮按钮样式。
public struct CircularGlassButtonStyle: ButtonStyle {
    /// 尺寸档位 / Size tier。
    public let size: ControlSize

    /// 显式直径覆写 / Explicit diameter override：绕过 `size` 直接指定。
    public let diameter: CGFloat?

    public init(size: ControlSize = .large, diameter: CGFloat? = nil) {
        self.size = size
        self.diameter = diameter
    }

    @Environment(\.isEnabled) private var isEnabled

    private var resolvedDiameter: CGFloat {
        self.diameter ?? CoreControlMetrics.height(for: self.size)
    }

    public func makeBody(configuration: Configuration) -> some View {
        let diameter = self.resolvedDiameter

        configuration.label
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .backgroundStyle(Color.surfaceInteractive)
            .modifier(TelegramGlassButtonModifier(
                shape: Circle(),
                isPressed: configuration.isPressed
            ))
            .opacity(self.isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.4)
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == CircularGlassButtonStyle {
    /// 默认档位（`.large`，50pt）的圆形玻璃按钮样式。
    static var circularGlass: CircularGlassButtonStyle {
        CircularGlassButtonStyle()
    }

    /// 指定尺寸档位的圆形玻璃按钮样式。
    ///
    /// - Parameter size: 尺寸档位。
    /// - Returns: `CircularGlassButtonStyle` 实例。
    static func circularGlass(size: ControlSize) -> CircularGlassButtonStyle {
        CircularGlassButtonStyle(size: size)
    }

    /// 自定义直径的圆形玻璃按钮样式（**逃生舱**）。
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
