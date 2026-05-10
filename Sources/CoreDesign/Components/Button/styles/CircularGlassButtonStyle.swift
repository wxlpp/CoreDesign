//
//  CircularGlassButtonStyle.swift
//  CoreDesign
//
//  Created by GitHub Copilot on 2026/3/31.
//

import SwiftUI

// MARK: - CircularGlassButtonStyle

/// 圆形玻璃浮按钮样式（"circular glass button"）。
///
/// ## 使用场景 / Usage
///
/// `BottomInputBar` 的 send / stop / suggestion shuffle 浮按钮；任何漂浮在内容
/// 之上、需要清晰 elevation 暗示的圆形 icon 按钮。
///
/// ## 关键参数 / Key Parameters
///
/// - `diameter`: 按钮直径（pt），默认 38。直径不属于 control-size 标度（圆按钮通常
///   在浮层 UI 中由调用方按视觉精确设定），保持参数可调；非 token 化是有意为之。
///
/// ## Primer 概念对应 / Primer Mapping
///
/// 与 Primer Web 端的 `IconButton variant="invisible" + size="medium"` 形态接近，
/// 但视觉上叠加 SwiftUI / iOS 26 原生的 `.glassEffect`——这是 Apple HIG 在浮层 /
/// Lock Screen / Dynamic Island 等场景的视觉语言（"漂浮在内容上方"），与 Primer
/// 桌面 chrome "1px 边框 + 实色"刚好互补。
///
/// ## Light / Dark 行为差异 / Color Scheme Behavior
///
/// `.glassEffect` 由 SwiftUI 系统 material 提供——自动随 colorScheme 切换 light / dark
/// 表现，组件层无需分支。背景层 `Color.background` 系统色作为玻璃材质后的 fallback。
///
/// > Important: 本样式是 epic ADR #3 glass 白名单文件之一——**保留** `.glassEffect`
/// > 是设计意图，不是遗漏。
struct CircularGlassButtonStyle: ButtonStyle {
    var diameter: CGFloat = 38

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: self.diameter, height: self.diameter)
            .contentShape(Circle())
            .background(
                Circle()
                    .fill(.background)
                    .padding(CoreSpacing.xxs)
                    .glassEffect()
            )
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - ButtonStyle convenience

extension ButtonStyle where Self == CircularGlassButtonStyle {
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
