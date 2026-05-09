//
//  Banner.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/2.
//

import SwiftUI

// MARK: - BannerPalette

private struct BannerPalette {
    let foreground: Color
    let background: Color
    let border: Color
}

// MARK: - MessageLevel

public enum MessageLevel {
    case info
    case warning
    case danger
    case success
}

// MARK: - Banner

public struct Banner<Label: View>: View {
    public init(level: MessageLevel, @ViewBuilder label: () -> Label) {
        self.configuration = .init(label: .init(label()), level: level)
    }

    public var body: some View {
        Button {} label: {}

        AnyView(self.style.makeBody(configuration: self.configuration))
    }

    @Environment(\.bannerStyle) var style

    let configuration: BannerStyleConfiguration
}

// MARK: - BannerStyle

public protocol BannerStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = BannerStyleConfiguration
}

// MARK: - BannerStyleConfiguration

public struct BannerStyleConfiguration {
    public typealias Label = AnyView

    public let label: Label
    public let level: MessageLevel
}

// MARK: - PlainBannerStyle

public struct PlainBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let icon = self.makeIcon(configuration: configuration)
        let palette = self.palette(configuration: configuration)
        HStack(content: {
            icon.foregroundStyle(palette.foreground)
            configuration.label
        })
        .foregroundStyle(palette.foreground)
        .padding()
        .background {
            Rectangle().fill(palette.background)
        }
    }

    func makeIcon(configuration: Configuration) -> Image {
        switch configuration.level {
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

    private func palette(configuration: Configuration) -> BannerPalette {
        switch configuration.level {
        case .info:
            BannerPalette(foreground: .infoForeground, background: .infoBackground, border: .infoBorder)
        case .warning:
            BannerPalette(foreground: .warningForeground, background: .warningBackground, border: .warningBorder)
        case .danger:
            BannerPalette(foreground: .dangerForeground, background: .dangerBackground, border: .dangerBorder)
        case .success:
            BannerPalette(foreground: .successForeground, background: .successBackground, border: .successBorder)
        }
    }
}

// MARK: - BorderedBannerStyle

public struct BorderedBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let palette = self.palette(configuration: configuration)
        HStack(content: {
            configuration.label
        })
        .foregroundStyle(palette.foreground)
        .padding()
        .background {
            Rectangle().fill(palette.background).bordered(style: palette.border)
        }
    }

    private func palette(configuration: Configuration) -> BannerPalette {
        switch configuration.level {
        case .info:
            BannerPalette(foreground: .infoForeground, background: .infoBackground, border: .infoBorder)
        case .warning:
            BannerPalette(foreground: .warningForeground, background: .warningBackground, border: .warningBorder)
        case .danger:
            BannerPalette(foreground: .dangerForeground, background: .dangerBackground, border: .dangerBorder)
        case .success:
            BannerPalette(foreground: .successForeground, background: .successBackground, border: .successBorder)
        }
    }
}

extension EnvironmentValues {
    @Entry var bannerStyle: any BannerStyle = PlainBannerStyle()
}

public extension View {
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
