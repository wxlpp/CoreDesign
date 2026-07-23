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
/// **布局行为**：Card **默认撑满父容器宽度**（`maxWidth: .infinity`，对齐 iOS 分组
/// 卡片贯穿页宽的惯例），内容按 `alignment` 对齐（默认 `.leading`）。需要「卡片 hug
/// 自身内容尺寸」这类非撑满场景时，直接用 `View.surface(.content)` 而非 Card——
/// Card 刻意只服务最常见的撑满分组卡片。
///
/// ```swift
/// Card {
///     VStack(alignment: .leading, spacing: CoreSpacing.sm) {
///         Text("Title").coreFont(.headline)
///         Text("Body").coreFont(.subheadline).foregroundStyle(.secondary)
///     }
/// }
///
/// Card(alignment: .center) { EmptyStateView() }  // 居中内容的空态卡片
/// ```
public struct Card<Content: View>: View {
    private let padding: CGFloat
    private let alignment: Alignment
    private let content: Content

    /// - Parameters:
    ///   - padding: 内容四周内边距，默认 `CoreSpacing.lg`（16pt，对齐 iOS 分组卡片惯例）。
    ///   - alignment: 撑满宽度内的内容对齐，默认 `.leading`。
    ///   - content: 卡片内容。
    public init(
        padding: CGFloat = CoreSpacing.lg,
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.alignment = alignment
        self.content = content()
    }

    public var body: some View {
        self.content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: self.alignment)
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
