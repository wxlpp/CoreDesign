import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 分组设置行（Issue #142）

@Suite("分组分隔线 inset 推导")
struct SettingsDividerInsetTests {
    @Test("iconAligned = 横向 padding + 图标方块宽 + 间距（非硬编码）")
    func iconAlignedDerivation() {
        let expected =
            SettingsRowMetrics.horizontalPadding
            + SettingsRowMetrics.iconSquareSize
            + SettingsRowMetrics.iconTitleGap
        #expect(SettingsRowMetrics.iconAlignedDividerInset == expected)
        #expect(SettingsRowMetrics.iconAlignedDividerInset == 58)
    }

    @Test("textAligned = 横向 padding（无图标列）")
    func textAlignedDerivation() {
        #expect(SettingsRowMetrics.textAlignedDividerInset == SettingsRowMetrics.horizontalPadding)
        #expect(SettingsRowMetrics.textAlignedDividerInset == 16)
    }

    @Test("SettingsDividerInset.value 三档映射（顶层类型，非泛型嵌套）")
    func dividerInsetValueMapping() {
        #expect(SettingsDividerInset.iconAligned.value == SettingsRowMetrics.iconAlignedDividerInset)
        #expect(SettingsDividerInset.textAligned.value == SettingsRowMetrics.textAlignedDividerInset)
        #expect(SettingsDividerInset.custom(7).value == 7)
    }

    @Test("运行期字符串经 StringProtocol 重载可构造（编译级守卫）")
    @MainActor func runtimeStringOverloadsCompile() {
        let title = String("Wi-Fi")
        let sub: String = "HomeNetwork"
        let header: Substring = "General".prefix(7)

        _ = SettingsRow(title: title, subtitle: sub) { EmptyView() }
        _ = SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: title)
        _ = InsetGroupedSection(header: header) { EmptyView() }
        #expect(Bool(true))
    }
}

#if os(iOS)
import UIKit

@Suite("SettingsRow 命中高度 ≥ 44pt")
@MainActor
struct SettingsRowHeightTests {
    private func renderedHeight(_ view: some View) -> CGFloat? {
        let renderer = ImageRenderer(content: view.frame(width: 320))
        renderer.scale = 1
        return renderer.uiImage?.size.height
    }

    @Test("最简行（仅标题）渲染高度 ≥ 44pt")
    func minimalRowMeetsFloor() {
        let row = SettingsRow(title: "Version") { EmptyView() }
        let height = self.renderedHeight(row)
        #expect(height != nil)
        #expect((height ?? 0) >= 44, "SettingsRow 命中高度 \(height ?? 0) < 44pt")
    }

    @Test("带图标 + 副标题的行同样 ≥ 44pt")
    func iconSubtitleRowMeetsFloor() {
        let row = SettingsRow(
            icon: .init(systemName: "wifi", background: .blue),
            title: "Wi-Fi",
            subtitle: "HomeNetwork"
        ) {
            SettingsRowChevron()
        }
        let height = self.renderedHeight(row)
        #expect(height != nil)
        #expect((height ?? 0) >= 44, "带图标副标题行高度 \(height ?? 0) < 44pt")
    }
}
#endif
