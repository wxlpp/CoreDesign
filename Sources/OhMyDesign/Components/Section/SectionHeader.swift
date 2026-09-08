import SwiftUI

// MARK: - SectionHeader

/// 分组页眉，复刻 iOS `.insetGrouped` 的分组标题：大写、`contentSecondary` 灰、`.footnote` 字号。
public struct SectionHeader: View {
    private let title: Text

    /// LocalizedStringKey——字面量在 **`Bundle.main`** 本地化（与直接写 `Text(key)` 行为
    /// 一致；对 App 调用方即其自身 bundle）。
    public init(_ titleKey: LocalizedStringKey) {
        self.title = Text(titleKey)
    }

    /// 运行期字符串（数据来的分类名等），verbatim 显示、不走本地化查表。
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S) {
        self.title = Text(title)
    }

    public var body: some View {
        self.title
            .coreFont(.footnote)
            .textCase(.uppercase)
            .foregroundStyle(Color.contentSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
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
