import SwiftUI

// MARK: - RatingDisplay

/// **材质层**: 内容. **表面角色**: 内容.
public struct RatingDisplay: View {
    let value: Double
    let count: Int

    @Environment(\.ratingStyle) private var style

    /// - Parameters:
    ///   - value: 要展示的评分（可含小数——半星由小数部分表达）。
    ///   - count: 档位总数，默认 5。负数 clamp 到 0（与 `Rating` 同一条仓内惯例）。
    public init(value: Double, count: Int = 5) {
        self.value = value
        self.count = max(0, count)
    }

    public var body: some View {
        AnyView(self.style.makeBody(
            configuration: RatingStyleConfiguration(value: self.value, count: self.count)
        ))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rating", bundle: .module))
        .accessibilityValue(
            Text(verbatim: Self.accessibilityValueText(value: self.value, count: self.count))
        )
    }

    // MARK: - Pure logic (unit-testable via `@testable import`)

    static func accessibilityValueText(value: Double, count: Int) -> String {
        Rating.accessibilityValueText(value: value, count: count)
    }
}

// MARK: - Preview

#Preview("RatingDisplay — Light") {
    RatingDisplayPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("RatingDisplay — Dark") {
    RatingDisplayPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct RatingDisplayPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("整星").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 4)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("半星").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 3.5)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("十档（count: 10）").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 7, count: 10)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text(".tint(.orange) 覆盖").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 4.5)
                    .tint(.orange)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
