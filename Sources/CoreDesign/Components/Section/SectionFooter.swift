//
//  SectionFooter.swift
//  CoreDesign
//

import SwiftUI

// MARK: - SectionFooter

/// 分组的页脚——iOS 分组设置页里跟在分组下方的说明文字:`.footnote` 一族的
/// Dynamic Type text style（**非固定 pt**）、`contentSecondary`（`secondaryLabel`）灰、
/// **不大写**（与 `SectionHeader` 的大写标题相对）。
///
/// 与 `SectionHeader` 一样只负责文本样式，分组外边距交由 `InsetGroupedSection`
/// （#142）提供。
///
/// ```swift
/// SectionFooter("Turning this off stops all notifications from this app.")
/// ```
public struct SectionFooter: View {
    private let content: Text

    /// LocalizedStringKey——字面量会在**调用方 bundle** 本地化（与 SwiftUI `Text` 一致）。
    public init(_ textKey: LocalizedStringKey) {
        self.content = Text(textKey)
    }

    /// 运行期字符串，verbatim 显示、不走本地化查表。
    public init<S: StringProtocol>(_ text: S) {
        self.content = Text(text)
    }

    public var body: some View {
        self.content
            .coreFont(.footnote)
            .foregroundStyle(Color.contentSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("SectionFooter — Light") {
    SectionFooterPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("SectionFooter — Dark") {
    SectionFooterPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SectionFooterPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            SectionFooter("Turning this off stops all notifications from this app.")
            SectionFooter("多行说明文字会按 footnote 字号自然换行，并随辅助功能字号缩放。")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
