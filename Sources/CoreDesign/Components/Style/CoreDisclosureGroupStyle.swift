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
/// `Button`（`.plain` 样式，避免系统按钮外观）里；展开后的 `content` 只作
/// leading 缩进对齐（贴近原生 `DisclosureGroup`，不加卡片、不消费 surface）。
/// chevron 走 `.tint` 取色，不写死 `Color.accent`
/// （FR-12 / ADR-3）——外加 `.tint(.red)` 会让 chevron 真的变红。
///
/// 展开/收起沿用系统 `DisclosureGroup` 的状态绑定（`configuration.isExpanded`
/// 直接读写会驱动同一个 `$isExpanded` binding）。**但换皮后系统不再自动为这个
/// 自绘 `Button` 播报展开态**——原生 `DisclosureGroup` 会告诉 VoiceOver
/// 「展开/收起」，普通 `Button` 只会播「按钮」。故在 header 上显式补回
/// `.accessibilityValue`（可本地化的 `Text`），使 VoiceOver 用户仍能感知
/// 当前是展开还是收起。
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
                    Image(systemName: "chevron.forward")
                        // `.tint`（`TintShapeStyle`）——反映当前环境 tint，
                        // 而非固定写死的 `Color.accent`（FR-12 / ADR-3）。
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // 自绘 Button 不会像原生 DisclosureGroup 那样自动播报展开态——
            // 显式补回。字符串走 `bundle: .module` 在库自带的 Localizable.strings
            // 查键（与库内其余 a11y 文案一致，如 ProgressIndicator 的 "Loading"），
            // 保证库侧可本地化、不依赖宿主 App 提供这两个键。
            .accessibilityValue(
                configuration.isExpanded
                    ? Text("Expanded", bundle: .module)
                    : Text("Collapsed", bundle: .module)
            )

            if configuration.isExpanded {
                // 原生 iOS `DisclosureGroup` 展开后只把内容缩进对齐、不加卡片。
                // 这里照做——不套 `.surface(.content)`：既贴近系统观感，也让本 style
                // 不消费 surface 层（与 #140 表面色改动解耦，观感不依赖其 token 值）。
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, CoreSpacing.md)
            }
        }
    }
}

// MARK: - DisclosureGroupStyle extension

public extension DisclosureGroupStyle where Self == CoreDisclosureGroupStyle {
    /// CoreDesign 的默认 `DisclosureGroup` 外观：chevron 走 `.tint`，展开内容
    /// 作 leading 缩进（贴近原生，不加卡片）。
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
