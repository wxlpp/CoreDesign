import SwiftUI
import Testing
@testable import OhMyDesign

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

    @Test("steppedValue：step=1.0 按 ceiling——点第 k 颗星得 k 分")
    func steppedValueWholeStep() {
        #expect(Rating.steppedValue(atRelativeX: 0, totalWidth: 100, count: 5, step: 1.0) == 0)
        #expect(Rating.steppedValue(atRelativeX: 10, totalWidth: 100, count: 5, step: 1.0) == 1)
        #expect(Rating.steppedValue(atRelativeX: 20, totalWidth: 100, count: 5, step: 1.0) == 1)
        #expect(Rating.steppedValue(atRelativeX: 22, totalWidth: 100, count: 5, step: 1.0) == 2)
        #expect(Rating.steppedValue(atRelativeX: 100, totalWidth: 100, count: 5, step: 1.0) == 5)
    }

    @Test("steppedValue：step=0.5 按 ceiling——星 k 左半 → k−0.5、右半 → k")
    func steppedValueHalfStep() {
        #expect(Rating.steppedValue(atRelativeX: 5, totalWidth: 100, count: 5, step: 0.5) == 0.5)
        #expect(Rating.steppedValue(atRelativeX: 44, totalWidth: 100, count: 5, step: 0.5) == 2.5)
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 5, step: 0.5) == 2.5)
        #expect(Rating.steppedValue(atRelativeX: 56, totalWidth: 100, count: 5, step: 0.5) == 3.0)
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

    // MARK: - 交互开关（#41 裁决 4b：isReadOnly 已删除）

    // MARK: - 构造参数保留

    @Test("count / step 原样保留")
    func initStoresParameters() {
        let rating = Rating(value: .constant(1), count: 7, step: 0.5)
        #expect(rating.count == 7)
        #expect(rating.step == 0.5)
    }

    @Test("count 默认 5，step 默认 1.0（整星）")
    func initDefaults() {
        let rating = Rating(value: .constant(1))
        #expect(rating.count == 5)
        #expect(rating.step == 1.0)
    }

    // MARK: - step 入参校验（#41 裁决 4a）

    @Test("step 非正值 clamp 回 1.0——挡住「静默恒 0」，不是挡除零")
    func stepClampsNonPositiveToWholeStar() {
        #expect(Rating(value: .constant(1), step: 0).step == 1.0)
        #expect(Rating(value: .constant(1), step: -0.5).step == 1.0)
        #expect(Rating.steppedValue(atRelativeX: 10, totalWidth: 100, count: 5,
                                    step: Rating(value: .constant(1), step: 0).step) == 1)
    }

    @Test("step 不设上界——count == 0 是合法入参，任何 step ≤ count 的上界都会恒不可满足")
    func stepHasNoUpperBoundBecauseZeroCountIsLegal() {
        let zeroCount = Rating(value: .constant(0), count: 0, step: 2)
        #expect(zeroCount.count == 0)
        #expect(zeroCount.step == 2)
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 3, step: 10) == 3)
    }

    @Test("step: .infinity clamp 回 1.0——挡住 steppedValue 产出 NaN（#41 收尾修复）")
    func stepClampsInfinityToWholeStar() {
        let rating = Rating(value: .constant(1), step: .infinity)
        #expect(rating.step == 1.0)
        #expect(!Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 5, step: rating.step).isNaN)
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 5, step: rating.step) == 3)
    }
}
