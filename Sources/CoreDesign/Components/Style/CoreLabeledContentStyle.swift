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
/// `Color.contentSecondary`，`content` 走 `Color.contentPrimary`。沿用「label leading、
/// content trailing」的语义排布，但几何由本 style 自建：`HStack(alignment: .firstTextBaseline)`
/// + `CoreSpacing.sm` 间距 + `Spacer(minLength:)` + 值侧 `.multilineTextAlignment(.trailing)`
/// （系统默认为 center 对齐——重排 alignment 是本 style 的有意设计，属 style 协议正当用途，
/// 不是「重造控件」）。
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
