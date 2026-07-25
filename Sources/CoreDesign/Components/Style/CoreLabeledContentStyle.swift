//
//  CoreLabeledContentStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CoreLabeledContentStyle

/// 系统 `LabeledContent` 的 CoreDesign 视觉外观——**不重新实现控件本身**，只重排
/// `makeBody(configuration:)` 交出的 `label` / `content`。`LabeledContentStyleConfiguration`
/// 的 `makeBody` 是公开 API，与 `CoreLabelStyle` / `CoreProgressViewStyle` 同一形态。
///
/// 描述列表惯例：字段名（`label`）弱化、值（`content`）强化——`label` 走
/// `Color.contentSecondary`，`content` 走 `Color.contentPrimary`。布局沿用系统
/// `LabeledContent` 默认的「label leading、content trailing」排布（`HStack` +
/// `Spacer`），本 style 只重新着色，不改变几何。
///
/// `Descriptions` 分组容器内的每一行都套用本 style；也可独立套用在任意
/// `LabeledContent` 上（见下方 `#Preview`）。
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
    ///
    /// ```swift
    /// LabeledContent("Status") { Text("Active") }
    ///     .labeledContentStyle(.core)
    /// ```
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
