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
    /// `.large`（50pt，落在 `CoreControlMetrics.height` 的 28/32/44/50/56 序列内）。
    ///
    /// > 为何不读 `@Environment(\.controlSize)`：该环境值未被显式设置时是
    /// > `.regular`，而现有五个调用点都没设——直接采信会把浮按钮显著缩小。
    /// > （原注释此处记有「从 38pt 缩到 32pt（实测）」，那是 Issue #119 换值**之前**
    /// > 的实测值；height 标度已整体从 24/28/32/40/48 换成 28/32/44/50/56，该经验数字
    /// > 已失效。结论方向不受影响——`.regular` 仍显著小于 `.large`——但具体数值待
    /// > Task #122 重新实测。）若改为「忽略 `.regular` 按 `.large` 解释」，则下游**刻意**
    /// > 写 `.controlSize(.regular)` 时会静默得到 44pt，是永久的公开 API 陷阱。
    /// > 把档位存在 style 上既避免了这两者，也让意图显式可读。
    public let size: ControlSize

    /// 显式直径覆写 / Explicit diameter override：绕过 `size` 直接指定。
    public let diameter: CGFloat?

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
    /// 默认档位（`.large`，50pt）的圆形玻璃按钮样式。
    static var circularGlass: CircularGlassButtonStyle {
        CircularGlassButtonStyle()
    }

    /// 指定尺寸档位的圆形玻璃按钮样式。
    ///
    /// 这是**主通道**——档位取自 `CoreControlMetrics.height(for:)`，与其余
    /// 三个 style 的尺寸来源一致。
    ///
    /// - Parameter size: 尺寸档位。
    /// - Returns: `CircularGlassButtonStyle` 实例。
    static func circularGlass(size: ControlSize) -> CircularGlassButtonStyle {
        CircularGlassButtonStyle(size: size)
    }

    /// 自定义直径的圆形玻璃按钮样式（**逃生舱**）。
    ///
    /// 绕过 `size` 档位直接给值，用于 metrics 序列覆盖不到的非标尺寸。
    /// 常规场景请用 `circularGlass(size:)`。
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
