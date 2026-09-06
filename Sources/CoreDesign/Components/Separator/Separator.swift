import SwiftUI

// MARK: - Separator

/// 可控 inset 的分隔线，默认 hairline 宽度、颜色走 `Color.dividerDefault`。
public struct Separator: View {
    /// 分隔线的 leading 缩进方式。
    public enum Inset: Equatable, Sendable {
        /// 无缩进，分隔线贯穿父容器整宽；⚠️ 不叫 `none` 是有意的——调用方持有 `Inset?`
        /// 时写 `.none` 会静默解析成 `Optional.none`，不要改名。
        case edgeToEdge
        /// 从 leading 缩进指定量（pt）。
        case leading(CGFloat)

        var leadingAmount: CGFloat {
            switch self {
            case .edgeToEdge: 0
            case let .leading(amount): max(0, amount)
            }
        }
    }

    @Environment(\.displayScale) private var displayScale

    private let inset: Inset

    public init(inset: Inset = .edgeToEdge) {
        self.inset = inset
    }

    public var body: some View {
        Rectangle()
            .fill(Color.dividerDefault)
            .frame(height: 1.0 / self.displayScale)
            .frame(maxWidth: .infinity)
            .padding(.leading, self.inset.leadingAmount)
    }
}

#Preview("Separator — Light") {
    SeparatorPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Separator — Dark") {
    SeparatorPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SeparatorPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("贯穿").coreFont(.footnote).foregroundStyle(.secondary)
                Separator()
            }
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("leading 缩进（xl = 24pt）").coreFont(.footnote).foregroundStyle(.secondary)
                Separator(inset: .leading(CoreSpacing.xl))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
