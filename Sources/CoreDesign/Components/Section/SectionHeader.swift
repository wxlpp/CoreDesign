//
//  SectionHeader.swift
//  CoreDesign
//

import SwiftUI

// MARK: - SectionHeader

/// 分组的页眉——复刻 iOS `.insetGrouped` 列表的分组标题惯例:**大写**、
/// `contentSecondary`（`secondaryLabel`）灰、字号走 **`.footnote` 一族的
/// Dynamic Type text style**（随辅助功能字号缩放，**不是** `Font.system(size:)`
/// 固定 pt）。
///
/// 刻意用 `.insetGrouped` 惯例（大写）而非 `.sidebar` 风格（非大写）——Phase 1
/// 视觉终审发现 demo 误用 `.sidebar` list style 导致 header 非大写，这里对齐的是
/// 系统分组设置页。
///
/// 本组件只负责**文本样式**，不带分组外边距——外边距由承载它的
/// `InsetGroupedSection`（#142）按分组惯例提供，避免与调用方叠加。
///
/// ```swift
/// SectionHeader("General")   // 渲染为 "GENERAL"，footnote 灰
/// ```
public struct SectionHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(self.title)
            .coreFont(.footnote)
            .textCase(.uppercase)
            .foregroundStyle(Color.contentSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("SectionHeader — Light") {
    SectionHeaderPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("SectionHeader — Dark") {
    SectionHeaderPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SectionHeaderPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            SectionHeader("General")
            SectionHeader("Notifications & Sounds")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
