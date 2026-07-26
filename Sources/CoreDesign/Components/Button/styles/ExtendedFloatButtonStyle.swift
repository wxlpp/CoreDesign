//
//  ExtendedFloatButtonStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ExtendedFloatButtonStyle

/// 胶囊形悬浮按钮样式（icon + 文字的 extended FAB 形态）。
///
/// 与 `CircularGlassButtonStyle` 同属"漂浮于内容之上"的玻璃语汇，但服务的是
/// **有文字标签**的场景（"New" "生成" 一类主要动作）——`configuration.label`
/// 直接承载调用方的 icon+文字组合（通常是 `Label(_:systemImage:)`），本样式
/// 只负责胶囊玻璃背景与内边距，不重新拼装 icon/文字排布。
///
/// > Important: **icon-only 悬浮按钮请使用 `CircularGlassButtonStyle`
/// > （`.circularGlass`）**，本样式只服务图标+文字的 extended 形态——不要为纯
/// > icon 场景套本样式再自行隐藏文字，那样会带着胶囊的横向 padding 冗余。
///
/// 背景复用 `FloatingGlassModifier`（`.floatingGlass(in:isInteractive:)`），与
/// `CircularGlassButtonStyle` 底层的 `TelegramGlassButtonModifier` 是同一套玻璃
/// 语汇的两种参数化——本样式选 `FloatingGlassModifier` 是因为它已经把
/// "内缩底色 fill + `.glassEffect` + `strokeBorder`" 三层封装成与 shape 无关的
/// 通用 modifier，且 `isInteractive: true` 会切到 `Glass.regular.interactive()`，
/// 天然贴合按钮的可交互语义；按压时的视觉反馈单独用 `.opacity(...)`
/// 处理（与 `CircularGlassButtonStyle` 一致），不借 `TelegramGlassButtonModifier`
/// 的 `pressFeedback` scale 动画——胶囊形状在横向拉伸场景下 scale 观感不如
/// 纯粹的 opacity 淡出稳定。
///
/// 强调色：本样式**不**对 label 做额外着色（FR-3：若要着色须经 `.tint`，不得写死
/// `Color.accent`）——推荐调用方在自己的 `Label` 上用 `.foregroundStyle`/`.tint`
/// 表达强调色，样式本身保持中性。
///
/// ```swift
/// Button {
///     // ...
/// } label: {
///     Label("New", systemImage: "plus")
/// }
/// .buttonStyle(.extendedFloat)
/// ```
public struct ExtendedFloatButtonStyle: ButtonStyle {
    /// 尺寸档位 / Size tier。取值来源与 `CircularGlassButtonStyle` 一致，走
    /// `CoreControlMetrics.height(for:)`；默认 `.large`（50pt），与悬浮按钮的
    /// large-CTA 语义匹配。
    public let size: ControlSize

    public init(size: ControlSize = .large) {
        self.size = size
    }

    @Environment(\.isEnabled) private var isEnabled

    private var resolvedHeight: CGFloat {
        CoreControlMetrics.height(for: self.size)
    }

    /// 胶囊横向内边距——随 `size` 档位缩放（Phase 3 / #173 收口项：此前恒定
    /// `CoreSpacing.lg`，`.regular` 与默认 `.large` 档视觉密度不成比例）。直接复用
    /// `CoreControlMetrics.horizontalPadding(for:)`，与库内其它 `ButtonStyle` /
    /// `SearchField` 等控件的横向 padding 取值同一来源，不新造独立标度。
    private var resolvedHorizontalPadding: CGFloat {
        CoreControlMetrics.horizontalPadding(for: self.size)
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: self.resolvedHeight)
            .padding(.horizontal, self.resolvedHorizontalPadding)
            .contentShape(Capsule(style: .continuous))
            .floatingGlass(in: Capsule(style: .continuous), isInteractive: true)
            // 禁用视觉，与 `CircularGlassButtonStyle` 同一手法（见其 doc-comment）：
            // 禁用态固定 0.4 不透明度，覆盖按压态的 0.9，二者不叠乘。
            .opacity(self.isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.4)
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == ExtendedFloatButtonStyle {
    /// 默认档位（`.large`，50pt）的胶囊玻璃悬浮按钮样式。
    static var extendedFloat: ExtendedFloatButtonStyle {
        ExtendedFloatButtonStyle()
    }

    /// 指定尺寸档位的胶囊玻璃悬浮按钮样式。
    ///
    /// - Parameter size: 尺寸档位。
    /// - Returns: `ExtendedFloatButtonStyle` 实例。
    static func extendedFloat(size: ControlSize) -> ExtendedFloatButtonStyle {
        ExtendedFloatButtonStyle(size: size)
    }
}

#Preview("ExtendedFloatButton — Light") {
    ExtendedFloatButtonPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("ExtendedFloatButton — Dark") {
    ExtendedFloatButtonPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct ExtendedFloatButtonPreviewGallery: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: CoreSpacing.xl) {
                // extended（.large，默认档）
                Button {} label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.extendedFloat)
                .foregroundStyle(.white)

                // extended（.regular 档）
                Button {} label: {
                    Label("生成", systemImage: "wand.and.sparkles")
                }
                .buttonStyle(.extendedFloat(size: .regular))
                .foregroundStyle(.white)

                // 对照态：icon-only 场景引导至 CircularGlassButtonStyle
                Button {} label: {
                    Image(systemName: "plus")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .regular), weight: .semibold))
                }
                .buttonStyle(.circularGlass)
                .foregroundStyle(.white)
            }
            .padding(CoreSpacing.xxxl)
        }
    }
}
