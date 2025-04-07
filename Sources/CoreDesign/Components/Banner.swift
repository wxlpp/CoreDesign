//
//  Banner.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/2.
//

import SwiftUI

public enum MessageLevel {
    case info
    case warning
    case danger
    case success
}

public struct Banner<Label: View>: View {
    let configuration: BannerStyleConfiguration

    @Environment(\.bannerStyle) var style

    public init(level: MessageLevel, @ViewBuilder label: () -> Label) {
        self.configuration = .init(label: .init(label()), level: level)
    }

    public var body: some View {
        Button {} label: {}

        AnyView(self.style.makeBody(configuration: self.configuration))
    }
}

public protocol BannerStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = BannerStyleConfiguration
}

public struct BannerStyleConfiguration {
    public let label: Label
    public let level: MessageLevel

    public typealias Label = AnyView
}

public struct PlainBannerStyle: BannerStyle {
    public init() {}

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

    func getTintColor(configuration: Configuration) -> Color {
        switch configuration.level {
        case .info:
            .primary
        case .warning:
            .warning
        case .danger:
            .danger
        case .success:
            .success
        }
    }

    public func makeBody(configuration: Configuration) -> some View {
        let icon = self.makeIcon(configuration: configuration)
        let tintColor = self.getTintColor(configuration: configuration)
        HStack(content: {
            icon.foregroundStyle(tintColor)
            configuration.label
        })
        .foregroundStyle(Color.white)
        .padding()
        .background {
            Rectangle().fill(tintColor.opacity(0.4))
        }
    }
}

public struct BorderedBannerStyle: BannerStyle {
    public init() {}

    func getTintColor(configuration: Configuration) -> Color {
        switch configuration.level {
        case .info:
            .primary
        case .warning:
            .warning
        case .danger:
            .danger
        case .success:
            .success
        }
    }

    public func makeBody(configuration: Configuration) -> some View {
        let tintColor = self.getTintColor(configuration: configuration)
        HStack(content: {
            configuration.label
        })
        .foregroundStyle(Color.white)
        .padding()
        .background {
            Rectangle().fill(tintColor.opacity(0.4)).bordered(color: tintColor)
        }
    }
}

extension EnvironmentValues {
    @Entry var bannerStyle: any BannerStyle = PlainBannerStyle()
}

extension View {
    public func bannerStyle(_ style: some BannerStyle) -> some View {
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
