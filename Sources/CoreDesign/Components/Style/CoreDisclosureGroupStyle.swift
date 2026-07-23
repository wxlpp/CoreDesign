//
//  CoreDisclosureGroupStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CoreDisclosureGroupStyle

/// 系统 `DisclosureGroup` 的 CoreDesign 视觉外观——**不重新实现控件本身**，只重排
/// `makeBody(configuration:)` 交出的 `label` / `content`，展开状态仍由系统
/// 通过 `configuration.$isExpanded`（`Binding<Bool>`）驱动。`DisclosureGroupStyle.makeBody`
/// 是公开 API，`.tint` 接入无障碍。
///
/// 外观：`label` + 一个随展开状态旋转 90° 的 chevron，二者放在可点击的
/// `Button`（`.plain` 样式，避免系统按钮外观）里；展开后的 `content` 套一层
/// `.surface(.content)`（背景 + 描边 + 圆角，经 `CoreShape`，非裸
/// `RoundedRectangle`）。chevron 走 `.tint` 取色，不写死 `Color.accent`
/// （FR-12 / ADR-3）——外加 `.tint(.red)` 会让 chevron 真的变红。
///
/// 展开/收起沿用系统 `DisclosureGroup` 的状态绑定（`configuration.isExpanded`
/// 直接读写会驱动同一个 `$isExpanded` binding），VoiceOver 仍可通过按钮的
/// expanded/collapsed 状态与 `.isHeader`/toggle 语义感知，不因换皮而丢失。
public struct CoreDisclosureGroupStyle: DisclosureGroupStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Button {
                withAnimation(.snappy) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack {
                    configuration.label
                    Spacer()
                    Image(systemName: "chevron.right")
                        // `.tint`（`TintShapeStyle`）——反映当前环境 tint，
                        // 而非固定写死的 `Color.accent`（FR-12 / ADR-3）。
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
                    .padding(CoreSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surface(.content)
            }
        }
    }
}

// MARK: - DisclosureGroupStyle extension

public extension DisclosureGroupStyle where Self == CoreDisclosureGroupStyle {
    /// CoreDesign 的默认 `DisclosureGroup` 外观：chevron 走 `.tint`，展开内容套
    /// `.surface(.content)`。
    ///
    /// ```swift
    /// DisclosureGroup("Details") {
    ///     Text("...")
    /// }
    /// .disclosureGroupStyle(.core)
    /// .tint(.red) // chevron 随之变红，不恒取 Color.accent
    /// ```
    static var core: CoreDisclosureGroupStyle { CoreDisclosureGroupStyle() }
}

#Preview("CoreDisclosureGroupStyle — Light") {
    CoreDisclosureGroupStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("CoreDisclosureGroupStyle — Dark") {
    CoreDisclosureGroupStylePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CoreDisclosureGroupStylePreviewGallery: View {
    @State private var expandedA = true
    @State private var expandedB = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("默认 tint（继承 accent）").coreFont(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("Details", isExpanded: self.$expandedA) {
                    Text("Additional information goes here.")
                }
                .disclosureGroupStyle(.core)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(".tint(.red) 覆盖").coreFont(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("Details", isExpanded: self.$expandedB) {
                    Text("Additional information goes here.")
                }
                .disclosureGroupStyle(.core)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
