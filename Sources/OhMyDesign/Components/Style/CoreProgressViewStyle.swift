import SwiftUI

// MARK: - CoreProgressViewStyle

/// 系统 `ProgressView` 的 OhMyDesign 视觉外观——只重绘 `makeBody(configuration:)`
/// 交出的内容，强调色经 `ShapeStyle.tint` 取值，所以 `.tint(_:)` 对它生效。
public struct CoreProgressViewStyle: ProgressViewStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        if let fractionCompleted = configuration.fractionCompleted {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                if let label = configuration.label {
                    label
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        CoreShape.rounded(CoreRadius.small)
                            .fill(Color.surfaceCanvasInset)
                        CoreShape.rounded(CoreRadius.small)
                            .fill(.tint)
                            .frame(width: geometry.size.width * CGFloat(fractionCompleted))
                    }
                }
                .frame(height: CoreSpacing.xs)

                if let currentValueLabel = configuration.currentValueLabel {
                    currentValueLabel
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(fractionCompleted, format: .percent))
        } else {
            VStack(spacing: CoreSpacing.xs) {
                if let label = configuration.label {
                    label
                }
                ProgressView()
                    .progressViewStyle(.circular)
                if let currentValueLabel = configuration.currentValueLabel {
                    currentValueLabel
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - ProgressViewStyle extension

public extension ProgressViewStyle where Self == CoreProgressViewStyle {
    /// OhMyDesign 的默认 `ProgressView` 外观。
    static var core: CoreProgressViewStyle { CoreProgressViewStyle() }
}

#Preview("CoreProgressViewStyle — Light") {
    CoreProgressViewStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("CoreProgressViewStyle — Dark") {
    CoreProgressViewStylePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CoreProgressViewStylePreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("默认 tint（继承 accent）").coreFont(.footnote).foregroundStyle(.secondary)
                ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
                    .progressViewStyle(.core)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(".tint(.red) 覆盖").coreFont(.footnote).foregroundStyle(.secondary)
                ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
                    .progressViewStyle(.core)
                    .tint(.red)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("不确定态 + .tint(.red)").coreFont(.footnote).foregroundStyle(.secondary)
                ProgressView()
                    .progressViewStyle(.core)
                    .tint(.red)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
