import SwiftUI

// MARK: - CoreLabeledContentStyle

/// 系统 `LabeledContent` 的 CoreDesign 视觉外观——**不重新实现控件本身**，只重排
/// `makeBody(configuration:)` 交出的 `label` / `content`。`LabeledContentStyleConfiguration`
/// 的 `makeBody` 是公开 API，与 `CoreLabelStyle` / `CoreProgressViewStyle` 同一形态。
public struct CoreLabeledContentStyle: LabeledContentStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.sm) {
            configuration.label
                .foregroundStyle(Color.contentSecondary)
            Spacer(minLength: CoreSpacing.sm)
            configuration.content
                .foregroundStyle(Color.contentPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - LabeledContentStyle extension

public extension LabeledContentStyle where Self == CoreLabeledContentStyle {
    /// CoreDesign 的默认 `LabeledContent` 外观：label 走 `contentSecondary`，
    /// content 走 `contentPrimary`（描述列表惯例：字段名弱化、值强化）。
    static var core: CoreLabeledContentStyle { CoreLabeledContentStyle() }
}

#Preview("CoreLabeledContentStyle — Light") {
    CoreLabeledContentStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("CoreLabeledContentStyle — Dark") {
    CoreLabeledContentStylePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CoreLabeledContentStylePreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("label 弱化 / content 强化").coreFont(.footnote).foregroundStyle(.secondary)
                LabeledContent("Status") {
                    Text("Active")
                }
                .labeledContentStyle(.core)
            }
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("多值 content").coreFont(.footnote).foregroundStyle(.secondary)
                LabeledContent("Owner") {
                    Text("Jane Appleseed")
                }
                .labeledContentStyle(.core)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
