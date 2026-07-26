import SwiftUI
import Testing
@testable import CoreDesign

// Steps（Issue #163）——`currentIndex` → 进行态派生是 private-by-convention（`Steps.
// StepsProgress` 刻意不标 `public`，也不标 `private`，理由见 `Steps.swift` 类型声明处
// 注释），经 `@testable import` 直接对 `Steps.progress(for:currentIndex:)` 与
// `Steps.StepsProgress` 断言。accessibility 文案拼装（位置键 / 错误态 / 组合）与
// `StepItem` 构造参数保留同样走静态纯函数 / 直接字段断言，与 `RatingTests` 同一套路。
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
        // 不硬编码 locale 相关字面量——直接拿同一套 formatted() 结果重建期望值。
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
}
