import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("Steps")
@MainActor
struct StepsTests {
    // MARK: - progress(for:currentIndex:) 边界值

    @Test("progress：index 小于 currentIndex → done")
    func progressBeforeCurrentIsDone() {
        #expect(Steps.progress(for: 0, currentIndex: 2) == .done)
        #expect(Steps.progress(for: 1, currentIndex: 2) == .done)
    }

    @Test("progress：index 等于 currentIndex → current")
    func progressAtCurrentIsCurrent() {
        #expect(Steps.progress(for: 2, currentIndex: 2) == .current)
    }

    @Test("progress：index 大于 currentIndex → pending")
    func progressAfterCurrentIsPending() {
        #expect(Steps.progress(for: 3, currentIndex: 2) == .pending)
        #expect(Steps.progress(for: 4, currentIndex: 2) == .pending)
    }

    @Test("progress：首索引（0）在 currentIndex 为 0 时为 current，为负数时为 pending")
    func progressFirstIndexBoundary() {
        #expect(Steps.progress(for: 0, currentIndex: 0) == .current)
        #expect(Steps.progress(for: 0, currentIndex: -1) == .pending)
    }

    @Test("progress：尾索引在 currentIndex 越界到 items.count 时为 done（全部完成场景）")
    func progressLastIndexAllDone() {
        let count = 4
        for index in 0..<count {
            #expect(Steps.progress(for: index, currentIndex: count) == .done)
        }
    }

    @Test("progress：currentIndex 为 0 且只有一步时该步为 current")
    func progressSingleStepCurrent() {
        #expect(Steps.progress(for: 0, currentIndex: 0) == .current)
    }

    // MARK: - accessibilityLabelText

    @Test("accessibilityLabelText：无 description 时只用 title")
    func accessibilityLabelTextTitleOnly() {
        #expect(Steps.accessibilityLabelText(title: "Shipping", description: nil) == "Shipping")
    }

    @Test("accessibilityLabelText：非空 description 时拼接为 \"title: description\"")
    func accessibilityLabelTextWithDescription() {
        #expect(
            Steps.accessibilityLabelText(title: "Shipping", description: "Add address")
                == "Shipping: Add address"
        )
    }

    @Test("accessibilityLabelText：空字符串 description 视同缺省，不拼接")
    func accessibilityLabelTextEmptyDescriptionIgnored() {
        #expect(Steps.accessibilityLabelText(title: "Shipping", description: "") == "Shipping")
    }

    // MARK: - accessibilityValueText（位置键 + 错误态）

    @Test("accessibilityValueText：当前步骤按 Phase 0 位置键 \"%@ of %@\" 组装（1-based）")
    func accessibilityValueTextCurrentStepUsesPositionalKey() {
        let text = Steps.accessibilityValueText(index: 1, currentIndex: 1, total: 4, isError: false)
        #expect(text == "\(2.formatted()) of \(4.formatted())")
    }

    @Test("accessibilityValueText：非当前步骤且非错误态返回 nil")
    func accessibilityValueTextNonCurrentNonErrorReturnsNil() {
        #expect(Steps.accessibilityValueText(index: 0, currentIndex: 2, total: 4, isError: false) == nil)
    }

    @Test("accessibilityValueText：错误态非当前步骤只播报 \"Error\"")
    func accessibilityValueTextErrorOnlyStep() {
        #expect(Steps.accessibilityValueText(index: 0, currentIndex: 2, total: 4, isError: true) == "Error")
    }

    @Test("accessibilityValueText：当前步骤同时是错误态——位置 + Error 以 \", \" 拼接")
    func accessibilityValueTextCurrentAndErrorCombine() {
        let text = Steps.accessibilityValueText(index: 2, currentIndex: 2, total: 4, isError: true)
        #expect(text == "\(3.formatted()) of \(4.formatted()), Error")
    }

    @Test("positionText：两端为 Int.formatted() 结果")
    func positionTextComposesFormattedInts() {
        #expect(Steps.positionText(current: 2, total: 4) == "\(2.formatted()) of \(4.formatted())")
    }

    // MARK: - StepItem 构造参数保留

    @Test("StepItem：title 必填，description / isError 默认值")
    func stepItemDefaults() {
        let item = StepItem(title: "Cart")
        #expect(item.title == "Cart")
        #expect(item.description == nil)
        #expect(item.isError == false)
    }

    @Test("StepItem：description / isError 原样保留")
    func stepItemStoresParameters() {
        let item = StepItem(title: "Payment", description: "Card declined", isError: true)
        #expect(item.title == "Payment")
        #expect(item.description == "Card declined")
        #expect(item.isError == true)
    }

    @Test("StepItem：显式传入 id 时原样保留，不覆盖为新 UUID")
    func stepItemPreservesExplicitID() {
        let id = UUID()
        let item = StepItem(title: "Cart", id: id)
        #expect(item.id == id)
    }

    // MARK: - Steps 构造参数保留

    @Test("Steps：items / currentIndex / axis / indicatorStyle 原样保留")
    func stepsStoresParameters() {
        let items = [StepItem(title: "A"), StepItem(title: "B")]
        let steps = Steps(items: items, currentIndex: 1, axis: .vertical, indicatorStyle: .numbered)
        #expect(steps.items == items)
        #expect(steps.currentIndex == 1)
        #expect(steps.axis == .vertical)
        #expect(steps.indicatorStyle == .numbered)
    }

    @Test("Steps：axis 默认 .horizontal，indicatorStyle 默认 .dot")
    func stepsDefaults() {
        let steps = Steps(items: [StepItem(title: "A")], currentIndex: 0)
        #expect(steps.axis == .horizontal)
        #expect(steps.indicatorStyle == .dot)
    }

    // MARK: - StepsPresentation（`#60` 形态 D2）

    @Test("Steps：presentation 默认 .steps —— 现有调用方零影响")
    func stepsPresentationDefaultsToSteps() {
        let steps = Steps(items: [StepItem(title: "A")], currentIndex: 0)
        #expect(steps.presentation == .steps)
    }

    @Test("Steps：presentation 原样保留")
    func stepsStoresPresentation() {
        for presentation in [StepsPresentation.steps, .segmentedBar, .navigation, .text] {
            let steps = Steps(
                items: [StepItem(title: "A")], currentIndex: 0, presentation: presentation
            )
            #expect(steps.presentation == presentation)
        }
    }

    @Test("StepsPresentation：四个 case 互不相等（Equatable 不是恒真）")
    func stepsPresentationEquatableIsNotDegenerate() {
        let all: [StepsPresentation] = [.steps, .segmentedBar, .navigation, .text]
        for (i, lhs) in all.enumerated() {
            for (j, rhs) in all.enumerated() where i != j {
                #expect(lhs != rhs, "\(lhs) 与 \(rhs) 不应相等")
            }
        }
    }

    @Test("Steps：indicatorStyle 与 presentation 正交 —— 两者独立保留，互不改写")
    func stepsIndicatorStyleAndPresentationAreOrthogonal() {
        let steps = Steps(
            items: [StepItem(title: "A")], currentIndex: 0,
            indicatorStyle: .numbered, presentation: .text
        )
        #expect(steps.indicatorStyle == .numbered, "非 .steps 呈现下 indicatorStyle 仍应原样保留")
        #expect(steps.presentation == .text)
    }

    @Test("Steps：四种呈现都能构造且 body 可求值（不 crash）")
    func stepsAllPresentationsRender() {
        let items = [StepItem(title: "A"), StepItem(title: "B", isError: true), StepItem(title: "C")]
        for presentation in [StepsPresentation.steps, .segmentedBar, .navigation, .text] {
            for axis in [StepsAxis.horizontal, .vertical] {
                let steps = Steps(items: items, currentIndex: 1, axis: axis, presentation: presentation)
                _ = steps.body
            }
        }
    }

    @Test("Steps：.text 呈现只消费 items.count 与 currentIndex —— 逐条内容不参与")
    func stepsTextPresentationCollapsesItems() {
        let a = [StepItem(title: "Cart"), StepItem(title: "Shipping")]
        let b = [StepItem(title: "完全不同"), StepItem(title: "的标题")]
        let summaryA = Steps.progressSummary(currentIndex: 0, total: a.count)
        let summaryB = Steps.progressSummary(currentIndex: 0, total: b.count)
        #expect(summaryA == summaryB, "逐条标题不同但条数相同 ⇒ .text 产出必须逐字一致")
        #expect(summaryA == Steps.positionText(current: 1, total: 2),
                "实际产出 \(summaryA) —— .text 的文案必须复用已登记键 \"%@ of %@\"")

        #expect(Steps.progressSummary(currentIndex: 0, total: a.count)
                != Steps.progressSummary(currentIndex: 1, total: a.count))
    }

    @Test("Steps.progressSummary：越界 currentIndex 被夹进 1...total，且不溢出")
    func stepsProgressSummaryClampsOutOfRangeIndex() {
        #expect(Steps.progressSummary(currentIndex: -4, total: 3) == Steps.positionText(current: 1, total: 3))
        #expect(Steps.progressSummary(currentIndex: 0, total: 3) == Steps.positionText(current: 1, total: 3))
        #expect(Steps.progressSummary(currentIndex: 2, total: 3) == Steps.positionText(current: 3, total: 3))
        #expect(Steps.progressSummary(currentIndex: 3, total: 3) == Steps.positionText(current: 3, total: 3))
        #expect(Steps.progressSummary(currentIndex: .max, total: 3) == Steps.positionText(current: 3, total: 3))
        #expect(Steps.progressSummary(currentIndex: .min, total: 3) == Steps.positionText(current: 1, total: 3))
        #expect(Steps.progressSummary(currentIndex: 0, total: 0) == Steps.positionText(current: 0, total: 0))
    }

    @Test("Steps：.segmentedBar / .text 塌成单 element 后，错误态仍经 accessibilityValue 播报")
    func stepsCollapsedPresentationsKeepErrorSemantics() {
        #expect(Steps.collapsedValueText(hasError: false) == nil,
                "无错误步 ⇒ 不挂 accessibilityValue，避免播报空值")
        #expect(Steps.collapsedValueText(hasError: true) == String(localized: "Error", bundle: .module))
        #expect(Steps.collapsedValueText(hasError: true)
                == Steps.accessibilityValueText(index: 0, currentIndex: 1, total: 3, isError: true))
    }

    @Test("Steps：.segmentedBar 的每段对应它自己那一步，不跟着前一步走")
    func stepsSegmentedBarSegmentTracksItsOwnStep() {
        #expect(Steps.segmentState(index: 0, currentIndex: 1, isError: false) == .filled)
        #expect(Steps.segmentState(index: 1, currentIndex: 1, isError: false) == .empty,
                "第 1 段对应当前步（未完成），不能因第 0 步已完成而被填充 —— 这正是原错位形态")
        #expect(Steps.segmentState(index: 2, currentIndex: 1, isError: false) == .empty)

        #expect(Steps.segmentState(index: 0, currentIndex: 0, isError: false) == .empty)
        #expect(Steps.segmentState(index: 2, currentIndex: 3, isError: false) == .filled)

        #expect(Steps.segmentState(index: 0, currentIndex: 5, isError: true) == .error)
        #expect(Steps.segmentState(index: 9, currentIndex: 0, isError: true) == .error)
    }
}
