import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 分组设置行（Issue #142）
//
// 覆盖两类机械可断言的东西：
//   1. 分隔线 leading inset 的**推导**（本任务最细的活）——必须从图标方块尺寸 + 间距
//      算出，不硬编码；这里把推导公式钉死，图标尺寸一改、这条测试会跟着变，防错位。
//   2. SettingsRow 的命中高度 ≥ 44pt（Apple HIG 最小可点击目标，AC 要求，跑 iOS 腿）。
//   视觉正确性（分隔线是否真对齐、圆角、raised 背景）靠 #Preview 与 #144 视觉终审兜底。

@Suite("分组分隔线 inset 推导")
struct SettingsDividerInsetTests {

    @Test("iconAligned = 横向 padding + 图标方块宽 + 间距（非硬编码）")
    func iconAlignedDerivation() {
        let expected =
            SettingsRowMetrics.horizontalPadding
            + SettingsRowMetrics.iconSquareSize
            + SettingsRowMetrics.iconTitleGap
        #expect(SettingsRowMetrics.iconAlignedDividerInset == expected)
        // 具体值：16 + 30 + 12 = 58（默认 token 档；token 改了这里也该改）。
        #expect(SettingsRowMetrics.iconAlignedDividerInset == 58)
    }

    @Test("textAligned = 横向 padding（无图标列）")
    func textAlignedDerivation() {
        #expect(SettingsRowMetrics.textAlignedDividerInset == SettingsRowMetrics.horizontalPadding)
        #expect(SettingsRowMetrics.textAlignedDividerInset == 16)
    }

    @Test("DividerInset.value 三档映射")
    func dividerInsetValueMapping() {
        typealias Inset = InsetGroupedSection<EmptyView>.DividerInset
        #expect(Inset.iconAligned.value == SettingsRowMetrics.iconAlignedDividerInset)
        #expect(Inset.textAligned.value == SettingsRowMetrics.textAlignedDividerInset)
        #expect(Inset.custom(7).value == 7)
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
        let row = SettingsRow(title: Text("Version")) { EmptyView() }
        let height = self.renderedHeight(row)
        #expect(height != nil)
        #expect((height ?? 0) >= 44, "SettingsRow 命中高度 \(height ?? 0) < 44pt")
    }

    @Test("带图标 + 副标题的行同样 ≥ 44pt")
    func iconSubtitleRowMeetsFloor() {
        let row = SettingsRow(
            icon: .init(systemName: "wifi", background: .blue),
            title: Text("Wi-Fi"),
            subtitle: Text("HomeNetwork")
        ) {
            SettingsRowChevron()
        }
        let height = self.renderedHeight(row)
        #expect(height != nil)
        #expect((height ?? 0) >= 44, "带图标副标题行高度 \(height ?? 0) < 44pt")
    }
}
#endif
