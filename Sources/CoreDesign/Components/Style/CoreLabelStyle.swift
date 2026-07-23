//
//  CoreLabelStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CoreLabelStyle

/// 系统 `Label` 的 CoreDesign 视觉外观——**不重新实现控件本身**，只重排
/// `makeBody(configuration:)` 交出的 `icon` / `title`。`LabelStyleConfiguration`
/// 的 `makeBody` 是公开 API，`.tint` 接入无障碍。
///
/// icon 走 `.tint`（`ShapeStyle.tint`，反映当前环境 tint）取色，不写死
/// `Color.accent`（FR-12 / ADR-3）——对 `Label` 外加 `.tint(.red)` 会让 icon
/// 真的变红。title 保持系统默认前景色（`.primary`），只有 icon 承担强调色，
/// 与 `Label` 原生"icon 装饰、title 承载语义"的分工一致。
///
/// icon 显式 `.accessibilityHidden(true)`——保留系统默认 `Label` 的可访问性
/// 语义：VoiceOver 只播报 title，icon 是纯装饰，不产生冗余播报。
public struct CoreLabelStyle: LabelStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: CoreSpacing.sm) {
            configuration.icon
                // `.tint`（`TintShapeStyle`）——反映当前环境 tint，
                // 而非固定写死的 `Color.accent`（FR-12 / ADR-3）。
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            configuration.title
        }
    }
}

// MARK: - LabelStyle extension

public extension LabelStyle where Self == CoreLabelStyle {
    /// CoreDesign 的默认 `Label` 外观：icon 走 `.tint`、title 走默认前景色。
    ///
    /// ```swift
    /// Label("Sync", systemImage: "arrow.triangle.2.circlepath")
    ///     .labelStyle(.core)
    ///     .tint(.red) // icon 随之变红，不恒取 Color.accent
    /// ```
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
