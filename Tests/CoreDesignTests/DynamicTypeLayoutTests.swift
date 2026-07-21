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
}
#endif
