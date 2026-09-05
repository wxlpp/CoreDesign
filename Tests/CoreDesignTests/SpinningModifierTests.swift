import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - SpinningModifier（Issue #172）
//
// 两类断言：
//   1. `SpinningModifier` 自身的存储契约（isActive / text 透传），与
//      `FloatingGlassModifierTests` 同款、跨平台可跑。
//   2. `isActive` 切换不改变底层内容渲染尺寸——遮罩是 overlay，不应影响 frame。
//      仿照 `CardVisibilityTests`（`BasicContainerTests.swift`）的 ImageRenderer 量测手法，
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


    @Test("TopBarIndicator.offset：相位覆盖整条轨道，首尾衔接不跳变")
    func topBarIndicatorSweepCoversTrack() {
        // ⚠️ PR #206 第 3 轮：上一版顶条**静态快照里完全不可见** —— 初始
        // `offset(x: -barWidth)` 把条推到视口外，再被 `.clipped()` 裁掉，而动画依赖
        // `@State` + `.onAppear` + `.repeatForever` 的时序。现在按时钟求相位，可断言。
        let track: CGFloat = 200
        let bar = track * TopBarIndicator.barWidthRatio
        let epoch = Date(timeIntervalSinceReferenceDate: 0)

        // 相位 0：条完全在左侧视口外（贴着左边缘外侧）。
        #expect(TopBarIndicator.offset(at: epoch, trackWidth: track) == -bar)

        // 相位 1（下一周期起点）：与相位 0 逐字相同 ⇒ 循环无跳变。
        let nextPeriod = Date(timeIntervalSinceReferenceDate: TopBarIndicator.period)
        #expect(TopBarIndicator.offset(at: nextPeriod, trackWidth: track)
                == TopBarIndicator.offset(at: epoch, trackWidth: track))

        // 相位 0.5：条已进入轨道中段 ⇒ 可见。这条是「顶条真的会动且会出现」的承重断言。
        let mid = Date(timeIntervalSinceReferenceDate: TopBarIndicator.period / 2)
        let midOffset = TopBarIndicator.offset(at: mid, trackWidth: track)
        #expect(midOffset > 0 && midOffset < track, "相位 0.5 时亮条必须落在轨道内，实际 \(midOffset)")

        // 单调推进：**一个周期内**相位越大位移越大（不回退、不抖动）。
        // ⚠️ 上界取开区间：`step == 10` 时 `t == period`，`truncatingRemainder` 归零、相位
        // 回绕到起点 —— 那是正确行为（由上面「首尾衔接」那条断言覆盖），不是单调性违例。
        var previous = -CGFloat.infinity
        for step in 0..<10 {
            let t = TopBarIndicator.period * Double(step) / 10
            let offset = TopBarIndicator.offset(at: Date(timeIntervalSinceReferenceDate: t), trackWidth: track)
            #expect(offset >= previous)
            previous = offset
        }
    }

    @Test("TopBarIndicator：轨道常驻 ⇒ 任意相位下顶条都占据可见高度")
    func topBarIndicatorHasVisibleTrack() {
        // ⚠️ 「顶条存在」不能取决于亮条此刻扫到哪 —— 相位落在两端时亮条整个在视口外。
        // 高度是常量且为正 ⇒ 轨道恒占位；2pt 曾细到在高分屏上几乎看不见，现取 4pt。
        #expect(TopBarIndicator.height == CoreSpacing.xs)
        #expect(TopBarIndicator.height > 0)
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
