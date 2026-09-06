import SwiftUI

// MARK: - CoreLabelStyle

/// 系统 `Label` 的 CoreDesign 视觉外观——只重排 `makeBody(configuration:)` 交出的 `icon` / `title`。
public struct CoreLabelStyle: LabelStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: CoreSpacing.sm) {
            configuration.icon
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            configuration.title
        }
    }
}

// MARK: - LabelStyle extension

public extension LabelStyle where Self == CoreLabelStyle {
    /// CoreDesign 的默认 `Label` 外观：icon 走 `.tint`、title 走默认前景色。
    static var core: CoreLabelStyle { CoreLabelStyle() }
}

#Preview("CoreLabelStyle — Light") {
    CoreLabelStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("CoreLabelStyle — Dark") {
    CoreLabelStylePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CoreLabelStylePreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("默认 tint（继承 accent）").coreFont(.footnote).foregroundStyle(.secondary)
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(.core)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(".tint(.red) 覆盖").coreFont(.footnote).foregroundStyle(.secondary)
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(.core)
                    .tint(.red)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
