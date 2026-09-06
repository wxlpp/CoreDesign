import SwiftUI

// MARK: - ExtendedFloatButtonStyle

/// 胶囊形悬浮按钮样式（icon + 文字的 extended FAB 形态）。
public struct ExtendedFloatButtonStyle: ButtonStyle {
    /// 尺寸档位，走 `CoreControlMetrics.height(for:)`；默认 `.large`（50pt）。
    public let size: ControlSize

    public init(size: ControlSize = .large) {
        self.size = size
    }

    @Environment(\.isEnabled) private var isEnabled

    private var resolvedHeight: CGFloat {
        CoreControlMetrics.height(for: self.size)
    }

    private var resolvedHorizontalPadding: CGFloat {
        CoreControlMetrics.horizontalPadding(for: self.size)
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: self.resolvedHeight)
            .padding(.horizontal, self.resolvedHorizontalPadding)
            .contentShape(Capsule(style: .continuous))
            .floatingGlass(in: Capsule(style: .continuous), isInteractive: true)
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
                Button {} label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.extendedFloat)
                .foregroundStyle(.white)

                Button {} label: {
                    Label("生成", systemImage: "wand.and.sparkles")
                }
                .buttonStyle(.extendedFloat(size: .regular))
                .foregroundStyle(.white)

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
