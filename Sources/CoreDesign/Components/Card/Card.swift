//
//  Card.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Card

/// `.surface(.content)` 的**具名封装** + 默认内边距——iOS 分组卡片/内容容器的最薄外壳。
///
/// Card **不引入平行的容器体系**：它就是 `content` → `.padding(默认值)` →
/// `.surface(.content)`（背景 + 描边 + 圆角均由 `SurfaceModifier` 提供，不重新实现）。
/// 需要更细控制（自定义 kind / 边距 / 形状）的场景，直接用 `View.surface(_:)`。
///
/// 背景来自 `.surface(.content)`，Issue #140 后指向 `surfaceRaised`
/// （`secondarySystemGroupedBackground`）——**浮于画布之上**，深浅双模式下都与
/// `Color.surfaceCanvas` 拉开、不再塌缩隐形。
///
/// ```swift
/// Card {
///     VStack(alignment: .leading, spacing: CoreSpacing.sm) {
///         Text("Title").coreFont(.headline)
///         Text("Body").coreFont(.subheadline).foregroundStyle(.secondary)
///     }
/// }
/// ```
public struct Card<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    /// - Parameters:
    ///   - padding: 内容四周内边距，默认 `CoreSpacing.lg`（16pt，对齐 iOS 分组卡片惯例）。
    ///   - content: 卡片内容。
    public init(
        padding: CGFloat = CoreSpacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        self.content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(.content)
    }
}

#Preview("Card — Light") {
    CardPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Card — Dark") {
    CardPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CardPreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            Card {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Card 标题").coreFont(.headline)
                    Text("卡片浮于画布之上，深浅双模式都与背景拉开。")
                        .coreFont(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Card(padding: CoreSpacing.md) {
                Text("紧凑内边距（md）").coreFont(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
