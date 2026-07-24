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
        // 第一条是**可执行的公式文档**（复述实现表达式，永不失败）——说明 inset 由这三
        // 个 token 组成，而非某个魔数。真正的回归守卫是下面的 `== 58` 钉值：任一 token
        // 改动都会让钉值失败、提醒同步分隔线预期。
        let expected =
            SettingsRowMetrics.horizontalPadding
            + SettingsRowMetrics.iconSquareSize
            + SettingsRowMetrics.iconTitleGap
        #expect(SettingsRowMetrics.iconAlignedDividerInset == expected)
        #expect(SettingsRowMetrics.iconAlignedDividerInset == 58) // 16 + 30 + 12
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

    // 编译级守卫（0.5.0 文本入参统一）：运行期字符串必须能经 StringProtocol 重载
    // 传入 SettingsRow / InsetGroupedSection。若哪天误删泛型重载、只留 LocalizedStringKey，
    // 这个 @MainActor 测试会**编译失败**（String 变量无法隐式转 LocalizedStringKey）。
    // 字面量→LocalizedStringKey 的解析靠 @_disfavoredOverload 保证（见组件源码），
    // 其本地化行为需带 strings 表的渲染断言才能测，此处只锁「泛型路径存在且可用」。
    @Test("运行期字符串经 StringProtocol 重载可构造（编译级守卫）")
    @MainActor func runtimeStringOverloadsCompile() {
        let title = String("Wi-Fi")
        let sub: String = "HomeNetwork"
        let header: Substring = "General".prefix(7)

        _ = SettingsRow(title: title, subtitle: sub) { EmptyView() }
        _ = SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: title)
        _ = InsetGroupedSection(header: header) { EmptyView() }
        #expect(Bool(true)) // 走到这里即证明上面三处泛型重载解析成功
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
