import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - SpinningModifier（Issue #172）
//
// 两类断言：
//   1. `SpinningModifier` 自身的存储契约（isActive / text 透传），与
//      `FloatingGlassModifierTests` 同款、跨平台可跑。
//   2. `isActive` 切换不改变底层内容渲染尺寸——遮罩是 overlay，不应影响 frame。
//      仿照 `BasicContainerTests.CardVisibilityTests` 的 ImageRenderer 量测手法，
//      只在 iOS 腿跑（macOS 无 WindowServer 会塌缩系统色/材质）。

@Suite("SpinningModifier 存储契约")
@MainActor
struct SpinningModifierStorageTests {
    @Test("isActive / text 透传存储")
    func storesParameters() {
        let active = SpinningModifier(isActive: true, text: "Refreshing…")
        #expect(active.isActive == true)
        #expect(active.text == "Refreshing…")

        let inactive = SpinningModifier(isActive: false)
        #expect(inactive.isActive == false)
        #expect(inactive.text == nil)
    }
}

#if os(iOS)
import UIKit

@Suite("SpinningModifier 尺寸稳定性（iOS 腿）")
@MainActor
struct SpinningModifierSizeTests {
    /// 渲染 `view` 并返回其 intrinsic 尺寸（`ImageRenderer` 的 CGImage 像素尺寸）。
    private func renderedSize(_ view: some View) -> CGSize? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        return CGSize(width: cg.width, height: cg.height)
    }

    @Test("isActive 开关不改变内容尺寸（遮罩不影响 frame）")
    func maskDoesNotChangeLayoutSize() {
        let content = Text("Content")
            .padding()
            .frame(width: 200, height: 120)

        let plainSize = self.renderedSize(content)
        let maskedOffSize = self.renderedSize(content.spinning(false))
        let maskedOnSize = self.renderedSize(content.spinning(true))
        let maskedOnWithTextSize = self.renderedSize(content.spinning(true, text: "Loading…"))

        #expect(plainSize != nil, "基线内容渲染失败")
        #expect(maskedOffSize == plainSize, "isActive: false 时尺寸应与未套 modifier 时一致")
        #expect(maskedOnSize == plainSize, "isActive: true 时遮罩不应改变内容尺寸")
        #expect(maskedOnWithTextSize == plainSize, "带文案的遮罩同样不应改变内容尺寸")
    }
}
#endif
