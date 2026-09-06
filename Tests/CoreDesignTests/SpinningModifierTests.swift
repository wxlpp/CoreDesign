import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - SpinningModifier（Issue #172）

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
        let modifier = SpinningModifier(isActive: true, text: "Loading", presentation: .topBar)
        #expect(modifier.text != nil, ".topBar 下 text 仍应原样保留")
        #expect(modifier.presentation == .topBar)
    }

    @Test("SpinningModifier：三种形态 × isActive 都能构造")
    func spinningAllPresentationsConstruct() {
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
        let track: CGFloat = 200
        let bar = track * TopBarIndicator.barWidthRatio
        let epoch = Date(timeIntervalSinceReferenceDate: 0)

        #expect(TopBarIndicator.offset(at: epoch, trackWidth: track) == -bar)

        let nextPeriod = Date(timeIntervalSinceReferenceDate: TopBarIndicator.period)
        #expect(TopBarIndicator.offset(at: nextPeriod, trackWidth: track)
                == TopBarIndicator.offset(at: epoch, trackWidth: track))

        let mid = Date(timeIntervalSinceReferenceDate: TopBarIndicator.period / 2)
        let midOffset = TopBarIndicator.offset(at: mid, trackWidth: track)
        #expect(midOffset > 0 && midOffset < track, "相位 0.5 时亮条必须落在轨道内，实际 \(midOffset)")

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
        #expect(TopBarIndicator.height == CoreSpacing.xs)
        #expect(TopBarIndicator.height > 0)
    }
}

#if os(iOS)
import UIKit

@Suite("SpinningModifier 尺寸稳定性（iOS 腿）")
@MainActor
struct SpinningModifierSizeTests {
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
