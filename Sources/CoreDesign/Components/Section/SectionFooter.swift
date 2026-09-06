import SwiftUI

// MARK: - SectionFooter

/// 分组页脚，即跟在分组下方的说明文字：`.footnote` 字号、`contentSecondary` 灰、不大写。
public struct SectionFooter: View {
    private let content: Text

    /// LocalizedStringKey——字面量在 **`Bundle.main`** 本地化（与直接写 `Text(key)` 行为
    /// 一致；对 App 调用方即其自身 bundle）。
    public init(_ textKey: LocalizedStringKey) {
        self.content = Text(textKey)
    }

    /// 运行期字符串，verbatim 显示、不走本地化查表。
    @_disfavoredOverload
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
