import SwiftUI

// MARK: - SectionHeader

/// 分组的页眉——复刻 iOS `.insetGrouped` 列表的分组标题惯例:**大写**、
/// `contentSecondary`（`secondaryLabel`）灰、字号走 **`.footnote` 一族的
/// Dynamic Type text style**（随辅助功能字号缩放，**不是** `Font.system(size:)`
/// 固定 pt）。
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
