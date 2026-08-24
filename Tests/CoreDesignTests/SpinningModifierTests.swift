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

    // MARK: - SpinningPresentation（`#60` 形态 D2）

    @Test("SpinningModifier：presentation 默认 .overlay —— 现有调用方零影响")
    func spinningPresentationDefaultsToOverlay() {
        // ⚠️ 破坏性变更的防线：新参数带默认值（源码兼容）+ 默认值 == 现状（行为兼容）。
        let modifier = SpinningModifier(isActive: true)
        #expect(modifier.presentation == .overlay)
    }

    @Test("SpinningModifier：presentation 原样保留")
    func spinningStoresPresentation() {
        for presentation in [SpinningPresentation.overlay, .topBar, .inline] {
            let modifier = SpinningModifier(isActive: true, presentation: presentation)
            #expect(modifier.presentation == presentation)
        }
    }

    @Test("SpinningPresentation：三个 case 互不相等（Equatable 不是恒真）")
    func spinningPresentationEquatableIsNotDegenerate() {
        let all: [SpinningPresentation] = [.overlay, .topBar, .inline]
        for (i, lhs) in all.enumerated() {
            for (j, rhs) in all.enumerated() where i != j {
                #expect(lhs != rhs, "\(lhs) 与 \(rhs) 不应相等")
            }
        }
    }

    @Test("SpinningModifier：.topBar 下 text 仍被原样保留（不生效 ≠ 被改写）")
    func spinningTopBarPreservesText() {
        // ⚠️ 正交性约定：.topBar 无文案位 ⇒ text 不生效，但存储层仍保留它。
        let modifier = SpinningModifier(isActive: true, text: "Loading", presentation: .topBar)
        #expect(modifier.text != nil, ".topBar 下 text 仍应原样保留")
        #expect(modifier.presentation == .topBar)
    }

    @Test("SpinningModifier：三种形态 × isActive 都能构造")
    func spinningAllPresentationsConstruct() {
        // ⚠️ 只证「能构造」。**不求值 body** —— `ViewModifier.Content` 是不透明类型，
        // 造不出实例；`EmptyView() as! Content` 能编译但运行时必崩（曾写成那样，已改）。
        // ⚠️ 因此本条**不证渲染正确**，更**不证非阻塞语义**——`allowsHitTesting` /
        // `accessibilityHidden` 是渲染树属性，本仓无 ViewInspector 类工具，测不到。
        // 那条语义靠源码注释 + 人工评审守，见 `topBarBody` / `inlineBody` 的注释。
        // ⚠️ 别把这条读成「三种形态都对」。
        for presentation in [SpinningPresentation.overlay, .topBar, .inline] {
            for isActive in [true, false] {
                let modifier = SpinningModifier(
                    isActive: isActive, text: "L", presentation: presentation
                )
                #expect(modifier.isActive == isActive)
                #expect(modifier.presentation == presentation)
            }
        }
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
