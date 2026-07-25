import SwiftUI
import Testing
@testable import CoreDesign

// Rating（Issue #165）——手势 / accessibility adjust action 背后的受控逻辑无法在 Swift
// Testing 里直接模拟真实触摸，因此覆盖面全部落在 `Rating` 内部暴露的静态纯函数上：
// `fillFraction` / `steppedValue` / `isInteractive`。真实渲染与手势交互留给 iOS Simulator
// 视觉评审（见 CLAUDE.md 验证边界章节）。
@Suite("Rating")
@MainActor
struct RatingTests {
    // MARK: - 受控值：Binding 驱动 + 每颗星填充比例

    @Test("value 通过 Binding 双向绑定，构造时原样保留（不额外 clamp）")
    func valueBindingRoundTrips() {
        var stored = 3.0
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let rating = Rating(value: binding, count: 5)
        rating.value = 4.0
        #expect(stored == 4.0)
    }

    @Test("fillFraction：整星为 1，未达到的星为 0")
    func fillFractionWholeStars() {
        #expect(Rating.fillFraction(value: 3, starIndex: 0) == 1)
        #expect(Rating.fillFraction(value: 3, starIndex: 2) == 1)
        #expect(Rating.fillFraction(value: 3, starIndex: 3) == 0)
        #expect(Rating.fillFraction(value: 3, starIndex: 4) == 0)
    }

    @Test("fillFraction：半星在过渡星上给出 0.5")
    func fillFractionHalfStar() {
        #expect(Rating.fillFraction(value: 2.5, starIndex: 1) == 1)
        #expect(Rating.fillFraction(value: 2.5, starIndex: 2) == 0.5)
        #expect(Rating.fillFraction(value: 2.5, starIndex: 3) == 0)
    }

    @Test("fillFraction：value 为 0 时全部星为空")
    func fillFractionZeroValue() {
        for index in 0..<5 {
            #expect(Rating.fillFraction(value: 0, starIndex: index) == 0)
        }
    }

    // MARK: - 半星步进取整

    @Test("steppedValue：allowsHalfStar 关闭（step=1.0）按整数取整")
    func steppedValueWholeStep() {
        // 5 颗星，总宽 100pt：每颗星占 20pt
        #expect(Rating.steppedValue(atRelativeX: 0, totalWidth: 100, count: 5, step: 1.0) == 0)
        #expect(Rating.steppedValue(atRelativeX: 22, totalWidth: 100, count: 5, step: 1.0) == 1)
        #expect(Rating.steppedValue(atRelativeX: 48, totalWidth: 100, count: 5, step: 1.0) == 2)
        #expect(Rating.steppedValue(atRelativeX: 100, totalWidth: 100, count: 5, step: 1.0) == 5)
    }

    @Test("steppedValue：allowsHalfStar 开启（step=0.5）按半星取整")
    func steppedValueHalfStep() {
        // 2.5 颗星对应的 x = 2.5/5 * 100 = 50
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 5, step: 0.5) == 2.5)
        // 2.2 颗星（x=44）应就近取整到 2.0（非 0.5 的整数倍差 <0.25 时向下）
        #expect(Rating.steppedValue(atRelativeX: 44, totalWidth: 100, count: 5, step: 0.5) == 2.0)
        // 2.3 颗星（x=46）应就近取整到 2.5
        #expect(Rating.steppedValue(atRelativeX: 46, totalWidth: 100, count: 5, step: 0.5) == 2.5)
    }

    // MARK: - 边界值

    @Test("steppedValue：relativeX 为负数 clamp 到 0 分")
    func steppedValueClampsBelowZero() {
        #expect(Rating.steppedValue(atRelativeX: -50, totalWidth: 100, count: 5, step: 0.5) == 0)
    }

    @Test("steppedValue：relativeX 超出总宽 clamp 到最大星数")
    func steppedValueClampsAboveMax() {
        #expect(Rating.steppedValue(atRelativeX: 500, totalWidth: 100, count: 5, step: 1.0) == 5)
        #expect(Rating.steppedValue(atRelativeX: 500, totalWidth: 100, count: 3, step: 0.5) == 3)
    }

    @Test("steppedValue：totalWidth / count / step 非法输入归零，不崩溃")
    func steppedValueDegenerateInputs() {
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 0, count: 5, step: 1.0) == 0)
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 0, step: 1.0) == 0)
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 5, step: 0) == 0)
    }

    @Test("Rating(count:) 拒绝负数星数，落到 0")
    func negativeCountClampsToZero() {
        let rating = Rating(value: .constant(0), count: -3)
        #expect(rating.count == 0)
    }

    // MARK: - accessibilityValue 文案组装

    @Test("accessibilityValueText：按 Phase 0 位置键 \"%@ of %@\" 组装，两端为 formatted() 结果")
    func accessibilityValueTextComposesPositionalKey() {
        let value = 2.5
        let count = 5
        let text = Rating.accessibilityValueText(value: value, count: count)
        // 不硬编码 locale 相关的字面量（如 "2.5 of 5"）——直接拿同一套 formatted()
        // 结果重建期望值，避免 CI 运行环境 locale 不同导致假红。
        #expect(text == "\(value.formatted()) of \(Double(count).formatted())")
    }

    @Test("accessibilityValueText：半星精确播报，不取整（与整星取整后的文案不同）")
    func accessibilityValueTextDoesNotRoundHalfStar() {
        let halfStarText = Rating.accessibilityValueText(value: 2.5, count: 5)
        let roundedDownText = Rating.accessibilityValueText(value: 2.0, count: 5)
        let roundedUpText = Rating.accessibilityValueText(value: 3.0, count: 5)
        #expect(halfStarText != roundedDownText)
        #expect(halfStarText != roundedUpText)
        #expect(halfStarText.contains(2.5.formatted()))
    }

    // MARK: - 只读模式下手势 / accessibility adjust action 不生效

    @Test("isInteractive：只读时关闭，不论 isEnabled")
    func isInteractiveReadOnly() {
        #expect(Rating.isInteractive(isReadOnly: true, isEnabled: true) == false)
        #expect(Rating.isInteractive(isReadOnly: true, isEnabled: false) == false)
    }

    @Test("isInteractive：非只读且 enabled 时开启")
    func isInteractiveEnabled() {
        #expect(Rating.isInteractive(isReadOnly: false, isEnabled: true) == true)
    }

    @Test("isInteractive：非只读但外层 .disabled(true) 时仍关闭")
    func isInteractiveDisabledEnvironment() {
        #expect(Rating.isInteractive(isReadOnly: false, isEnabled: false) == false)
    }

    // MARK: - 构造参数保留

    @Test("count / allowsHalfStar / isReadOnly 原样保留")
    func initStoresParameters() {
        let rating = Rating(value: .constant(1), count: 7, allowsHalfStar: true, isReadOnly: true)
        #expect(rating.count == 7)
        #expect(rating.allowsHalfStar == true)
        #expect(rating.isReadOnly == true)
    }

    @Test("count 默认 5，allowsHalfStar / isReadOnly 默认 false")
    func initDefaults() {
        let rating = Rating(value: .constant(1))
        #expect(rating.count == 5)
        #expect(rating.allowsHalfStar == false)
        #expect(rating.isReadOnly == false)
    }
}
