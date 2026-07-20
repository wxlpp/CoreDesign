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
    /// 尺寸档位 / Size tier。
    ///
    /// 浮按钮（send / stop / shuffle 一类）语义上是 **large 档**控件，故默认
    /// `.large`（40pt，落在 `CoreControlMetrics.height` 的 24/28/32/40/48 序列内）。
    ///
    /// > 为何不读 `@Environment(\.controlSize)`：该环境值未被显式设置时是
    /// > `.regular`，而现有五个调用点都没设——直接采信会把浮按钮从 38pt 缩到
    /// > 32pt（实测）。若改为「忽略 `.regular` 按 `.large` 解释」，则下游**刻意**
    /// > 写 `.controlSize(.regular)` 时会静默得到 40pt，是永久的公开 API 陷阱。
    /// > 把档位存在 style 上既避免了这两者，也让意图显式可读。
    public var size: ControlSize = .large

    /// 显式直径覆写 / Explicit diameter override：绕过 `size` 直接指定。
    public var diameter: CGFloat?

    public init(size: ControlSize = .large, diameter: CGFloat? = nil) {
        self.size = size
        self.diameter = diameter
    }

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
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == CircularGlassButtonStyle {
    /// 默认档位（`.large`，40pt）的圆形玻璃按钮样式。
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
