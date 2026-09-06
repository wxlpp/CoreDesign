import SwiftUI

// MARK: - BannerPalette

private struct BannerPalette {
    let foreground: Color
    let background: Color
    let border: Color
}

// MARK: - Banner

/// 内容 / 控件层的信息表面。用状态语义（`info` / `success` / `warning` / `danger`）
/// 配克制的描边或填充——**不用** Liquid Glass。Banner 面向**页内信息**，不是浮层反馈；
/// 需要浮层反馈请经 `.toastHost(edge:)` 用 `ToastHost`。
public struct Banner<Label: View>: View {
    /// 创建 Banner。
    ///
    /// - Parameters:
    ///   - level: 语义等级，决定图标与配色（见 `StatusLevel`）。
    ///   - label: banner 主体文本视图，通常为 `Text`。
    public init(level: StatusLevel, @ViewBuilder label: () -> Label) {
        self.configuration = .init(label: .init(label()), level: level)
    }

    public var body: some View {
        AnyView(self.style.makeBody(configuration: self.configuration))
    }

    @Environment(\.bannerStyle) var style

    let configuration: BannerStyleConfiguration
}

// MARK: - BannerStyle

/// `Banner` 视觉外观的扩展点，形态对齐 Apple `ButtonStyle` / `ToggleStyle`。
public protocol BannerStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = BannerStyleConfiguration
}

// MARK: - BannerStyleConfiguration

/// 传给 `BannerStyle.makeBody` 的上下文，提供 banner 的语义等级与 label 视图。
public struct BannerStyleConfiguration {
    public typealias Label = AnyView

    public let label: Label
    public let level: StatusLevel
}

// MARK: - Banner shared helpers

private func bannerIcon(for level: StatusLevel) -> Image {
    switch level {
    case .info:
        Image(systemName: "info.circle.fill")
    case .warning:
        Image(systemName: "exclamationmark.triangle.fill")
    case .danger:
        Image(systemName: "exclamationmark.circle.fill")
    case .success:
        Image(systemName: "checkmark.circle.fill")
    }
}

private func bannerPalette(for level: StatusLevel) -> BannerPalette {
    switch level {
    case .info:
        BannerPalette(foreground: .statusAccentForeground, background: .statusAccentSubtle, border: .statusAccentBorder)
    case .warning:
        BannerPalette(foreground: .statusAttentionForeground, background: .statusAttentionSubtle, border: .statusAttentionBorder)
    case .danger:
        BannerPalette(foreground: .statusDangerForeground, background: .statusDangerSubtle, border: .statusDangerBorder)
    case .success:
        BannerPalette(foreground: .statusSuccessForeground, background: .statusSuccessSubtle, border: .statusSuccessBorder)
    }
}

@ViewBuilder
private func bannerBody(configuration: BannerStyleConfiguration, bordered: Bool) -> some View {
    let palette = bannerPalette(for: configuration.level)
    HStack(spacing: CoreSpacing.sm) {
        bannerIcon(for: configuration.level)
            .foregroundStyle(palette.foreground)
            .accessibilityHidden(true)
        configuration.label
    }
    .accessibilityElement(children: .combine)
    .coreFont(.callout)
    .foregroundStyle(palette.foreground)
    .padding(CoreSpacing.md)
    .background {
        if bordered {
            Rectangle().fill(palette.background).bordered(style: palette.border)
        } else {
            Rectangle().fill(palette.background)
        }
    }
}

// MARK: - PlainBannerStyle

/// 默认的 Banner 外观：纯色背景 + 同色系前景，无描边。
public struct PlainBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        bannerBody(configuration: configuration, bordered: false)
    }
}

// MARK: - BorderedBannerStyle

/// 带同色系描边的 Banner 外观：背景 + `CoreBorderWidth.thin` 描边。
public struct BorderedBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        bannerBody(configuration: configuration, bordered: true)
    }
}

extension EnvironmentValues {
    @Entry var bannerStyle: any BannerStyle = PlainBannerStyle()
}

public extension View {
    /// 为子树中的所有 `Banner` 设置外观。
    ///
    /// - Parameter style: 任意符合 `BannerStyle` 协议的实现，通常为内置的
    ///   `PlainBannerStyle` / `BorderedBannerStyle`。
    func bannerStyle(_ style: some BannerStyle) -> some View {
        self.environment(\.bannerStyle, style)
    }
}

#Preview {
    VStack(spacing: 10) {
        Banner(level: .info) {
            Text("A pre-released version is available.")
        }.bannerStyle(BorderedBannerStyle())
        Banner(level: .warning) {
            Text("This version of the document is going to expire after 4 days.")
        }
        Banner(level: .danger) {
            Text("This document was deprecated since Jan 1, 2019.")
        }
        Banner(level: .success) {
            Text("You are viewing the latest version of this document.")
        }
    }
}
