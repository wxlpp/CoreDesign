import Testing
import SwiftUI
@testable import CoreDesign

// macOS 无 Dynamic Type：ScaledMetric 恒返回 wrappedValue（NSFont.preferredFont(.body)
// 恒 13pt）。故整套断言 #if os(iOS)，只在第 5 条 xcodebuild iOS Simulator 命令下执行；
// 四条 SwiftPM 命令下本 suite 为空，不构成假绿——凡改本文件覆盖的组件都须跑第 5 条命令。
#if os(iOS)
@Suite("Dynamic Type 布局")
@MainActor
struct DynamicTypeLayoutTests {
    /// 在给定 Dynamic Type 尺寸下渲染并量高度。
    /// 用 ImageRenderer（不依赖颜色——asset 色在测试下解析为透明，本处只读尺寸）。
    private func renderedHeight<V: View>(
        _ view: V,
        at size: DynamicTypeSize
    ) -> CGFloat {
        let renderer = ImageRenderer(
            content: view
                .environment(\.dynamicTypeSize, size)
                .frame(width: 320)   // 固定宽度，让高度反映字号/换行
        )
        renderer.scale = 1
        return renderer.uiImage?.size.height ?? 0
    }

    // Task 1 Step 4 的 spike，保留作机制回归锚点（改用 renderedHeight）。
    @Test("spike：ImageRenderer 尊重注入的 dynamicTypeSize")
    func imageRendererRespectsDynamicType() {
        let text = Text("Ag").coreFont(.body)
        #expect(self.renderedHeight(text, at: .accessibility5) > self.renderedHeight(text, at: .large),
                "ImageRenderer 未按注入档缩放——Task 5 的整套断言不成立")
    }

    @Test("Sidebar 四种 row 的高度随 Dynamic Type 单调不减")
    func sidebarRowsGrowWithDynamicType() {
        // 注意：本断言的高度增长依赖 `SidebarRow` 的 **title** 字号缩放（Task 3 已把
        // SidebarRow 的 title 迁到 coreFont）。若 title 仍是固定 Font，此断言不通电。
        let row = SidebarNavigationRow(systemImage: "star", title: "Long enough title to wrap at accessibility sizes", isSelected: false) {}

        let small = self.renderedHeight(row, at: .large)          // 默认档
        let xxxl  = self.renderedHeight(row, at: .xxxLarge)
        let ax5   = self.renderedHeight(row, at: .accessibility5)

        #expect(small > 0, "渲染失败（uiImage nil）——下面的比较会以 0 假通过")
        // 主断言用**最大跨度** large vs accessibility5——`row` 有 `minHeight` 地板，
        // 相邻/近档可能都被夹到地板值。最大跨度才必然突破地板。
        #expect(ax5 > small, "accessibility5 未比 large 高——字号没缩放或被固定高度裁切")
        #expect(xxxl >= small, "xxxLarge 应 ≥ large")
        #expect(ax5 >= xxxl, "accessibility5 应 ≥ xxxLarge")
    }

    @Test("Sidebar 单行钳制 row（Document）在放大档同样撑高不裁切")
    func sidebarSingleLineRowGrows() {
        // Document row 传 titleLineLimit: 1（与 Navigation 的 nil 换行行为不同），
        // 单独覆盖单行钳制路径——AC 是「四种 row 不裁切」。
        let row = SidebarDocumentRow(systemImage: "doc", title: "Document title", detail: "3 days ago") {}
        let small = self.renderedHeight(row, at: .large)
        let ax5   = self.renderedHeight(row, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "Document row 在 accessibility5 未撑高——单行钳制下字号没缩放或被裁")
    }

    @Test("coreFont 的字号在 iOS 下确实随 Dynamic Type 变化")
    func coreFontActuallyScales() {
        let text = Text("Ag").coreFont(.body)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "coreFont 未缩放——ScaledMetric 或 textStyle 基准错了")
    }

    // Issue #119 之前：`captionSmall` 是故意不缩放的固定 9pt chrome 字号
    // （旧 `Spec.scales == false`）。Issue #119 之后：`captionSmall` 只是
    // `caption2`（`@available(*, deprecated, renamed: "caption2")`）的弃用别名，
    // 语义完全由 `caption2`（系统 `.caption2` 文本样式）决定，会随 Dynamic Type 缩放。
    // 本测试断言方向相对旧版本**故意翻转**——这是 119.md AC 明确要求的行为变化，
    // 不是回归；保留旧名 `captionSmallDoesNotScale` 会误导读者，故一并更名。
    @Test("captionSmall 现在是 caption2 的别名，随 Dynamic Type 缩放")
    func captionSmallNowScalesViaCaption2Alias() {
        let text = Text("9").coreFont(.caption2)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "captionSmall（→ caption2）未随 Dynamic Type 缩放——别名映射或 caption2 的 textStyle 错了")
    }

    // MARK: - 全部 12 档 token 覆盖（Issue #123）
    //
    // 上面几个既有测试只抽样验证了 `.body` / `.caption2` 两档——`CoreTypography.Token`
    // 重铸后一一对应 12 个系统 `Font.TextStyle`（Task #119），"重铸带来的可访问性
    // 承诺"须对全部 12 档兑现，不能只信抽样。用 `Token.allCases` 参数化，每档独立
    // 断言 large → accessibility5 单调增长——任何一档的 `textStyle` 映射写错（比如
    // 误连到不随 Dynamic Type 缩放的 `.system(size:)` 定值写法）都会在这里单独现形，
    // 而不是被抽样掩盖。
    @Test(
        "CoreTypography 全部 12 档 token 在 iOS 下均随 Dynamic Type 缩放",
        arguments: CoreTypography.Token.allCases
    )
    func everyTypographyTokenScalesWithDynamicType(_ token: CoreTypography.Token) {
        let text = Text("Ag").coreFont(token)
        let small = self.renderedHeight(text, at: .large)
        let ax5 = self.renderedHeight(text, at: .accessibility5)
        #expect(small > 0, "\(token)：渲染失败（uiImage nil）")
        #expect(ax5 > small, "\(token) 未随 Dynamic Type 缩放（large=\(small)pt, accessibility5=\(ax5)pt）")
    }

    // MARK: - 复合布局在最大辅助功能字号下不裁切、不重叠（Issue #123）
    //
    // 上面的 Sidebar 断言只覆盖 Sidebar 一族；`ListRow` 是另一个高频复合布局
    // （leading icon + 两行 label + trailing），且 label 的标题/副标题两个
    // `coreFont` 档位不同（`.callout` / `.footnote`，参见 `ListRow.swift` 预览）。
    // 用同一「large → accessibility5 高度不减」判据验证：若两行文字在放大档
    // 被固定高度裁掉，或 leading icon 与文字重叠导致渲染高度反而不变/更小，
    // 这里会失败。
    @Test("ListRow 两行 label 在 accessibility5 下随 Dynamic Type 撑高、不裁切")
    func listRowGrowsWithDynamicTypeWithoutClipping() {
        let row = ListRow(
            leading: {
                Image(systemName: "doc.text")
            },
            label: {
                VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                    Text("A sufficiently long title to wrap at accessibility sizes")
                        .coreFont(.callout)
                    Text("Updated 2 hours ago")
                        .coreFont(.footnote)
                }
            },
            trailing: {
                Image(systemName: "chevron.right")
            }
        )
        let small = self.renderedHeight(row, at: .large)
        let ax5 = self.renderedHeight(row, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "ListRow 在 accessibility5 未撑高——两行 label 没缩放或被裁切/重叠")
    }
}
#endif
