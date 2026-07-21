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
        let text = Text("Ag").coreFont(.bodyLarge)
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
        #expect(ax5 > small, "Document row 在 accessibility5 未撑高——单行钳制下字号没缩放或被裁")
    }

    @Test("coreFont 的字号在 iOS 下确实随 Dynamic Type 变化")
    func coreFontActuallyScales() {
        let text = Text("Ag").coreFont(.bodyLarge)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        #expect(ax5 > small, "coreFont 未缩放——ScaledMetric 或 textStyle 基准错了")
    }

    @Test("captionSmall 明确不缩放")
    func captionSmallDoesNotScale() {
        let text = Text("9").coreFont(.captionSmall)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）——本断言的 <= 会被 0<=1 假放过")
        // captionSmall 固定档：ax5 不应比 small 显著高（渲染有 ±1px 抖动，留容差）。
        #expect(ax5 <= small + 1, "captionSmall 缩放了——违反其固定设计约束")
    }
}
#endif
