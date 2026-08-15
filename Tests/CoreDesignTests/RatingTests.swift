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

    @Test("steppedValue：step=1.0 按 ceiling——点第 k 颗星得 k 分")
    func steppedValueWholeStep() {
        // 5 颗星，总宽 100pt：每颗星占 20pt（星 k 覆盖 rawValue ∈ (k−1, k]，x ∈ ((k−1)*20, k*20]）
        #expect(Rating.steppedValue(atRelativeX: 0, totalWidth: 100, count: 5, step: 1.0) == 0)   // 最左缘 → 清空
        #expect(Rating.steppedValue(atRelativeX: 10, totalWidth: 100, count: 5, step: 1.0) == 1)  // 星 1 内 → 1（关键：不再回落 0）
        #expect(Rating.steppedValue(atRelativeX: 20, totalWidth: 100, count: 5, step: 1.0) == 1)  // 星 1 右边界 → 仍 1
        #expect(Rating.steppedValue(atRelativeX: 22, totalWidth: 100, count: 5, step: 1.0) == 2)  // 进入星 2 → 2
        #expect(Rating.steppedValue(atRelativeX: 100, totalWidth: 100, count: 5, step: 1.0) == 5)
    }

    @Test("steppedValue：step=0.5 按 ceiling——星 k 左半 → k−0.5、右半 → k")
    func steppedValueHalfStep() {
        // 星 3 覆盖 x ∈ (40, 60]：左半 (40,50] → 2.5、右半 (50,60] → 3.0
        #expect(Rating.steppedValue(atRelativeX: 5, totalWidth: 100, count: 5, step: 0.5) == 0.5)  // 星 1 左半 → 0.5
        #expect(Rating.steppedValue(atRelativeX: 44, totalWidth: 100, count: 5, step: 0.5) == 2.5) // 星 3 左半 → 2.5
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 5, step: 0.5) == 2.5) // 星 3 左/右半分界 → 2.5
        #expect(Rating.steppedValue(atRelativeX: 56, totalWidth: 100, count: 5, step: 0.5) == 3.0) // 星 3 右半 → 3.0
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

    // MARK: - 交互开关（#41 裁决 4b：isReadOnly 已删除）
    //
    // ⚠️ 原先这里有三条 `@Test` 盯着 `Rating.isInteractive(isReadOnly:isEnabled:)`
    // （4 组断言）。#41 把展示态拆成了独立的 `RatingDisplay`（indicator），
    // `Rating` 只剩 control 语义 ⇒ 该函数退化为「`isEnabled` 恒等」，随之删除，
    // 两处调用点直接读 `@Environment(\.isEnabled)`。
    //
    // **行为没有丢失，是被类型二分吸收了**：
    // · 「只读 ⇒ 不可交互」现在由「用 `RatingDisplay` 这个类型」表达（它根本没有手势
    //   与 adjust action，见 `RatingDisplayTests`）；
    // · 「`.disabled(true)` ⇒ 不可交互」由 SwiftUI 原生 `\.isEnabled` 表达，本就不需要
    //   本仓再写一个纯函数去转述。
    // 留一个恒真的 `isInteractive(isEnabled:) == isEnabled` 的壳只会让覆盖率好看，
    // 不增加任何信息。

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
        // ⚠️ 失效形态不是崩溃：`steppedValue` 的 `guard ... step > 0 else { return 0 }`
        // 会让 step <= 0 的 Rating **恒返回 0 分**，比崩溃难发现得多。
        // 走 clamp 而不是 precondition，与仓内惯例一致（Rating.count 的 max(0,count)、
        // AvatarGroup.max 的 Swift.max(0,max)、Separator.Inset.leading 的 max(0,amount)），
        // 且 clamp 可单测——precondition 触发 trap，Swift Testing 抓不住。
        #expect(Rating(value: .constant(1), step: 0).step == 1.0)
        #expect(Rating(value: .constant(1), step: -0.5).step == 1.0)
        // clamp 之后组件真的能用：整星步进给出非 0 分。
        #expect(Rating.steppedValue(atRelativeX: 10, totalWidth: 100, count: 5,
                                    step: Rating(value: .constant(1), step: 0).step) == 1)
    }

    @Test("step 不设上界——count == 0 是合法入参，任何 step ≤ count 的上界都会恒不可满足")
    func stepHasNoUpperBoundBecauseZeroCountIsLegal() {
        // ⚠️ `Rating(count:)` 的 init 有 `max(0, count)`，`negativeCountClampsToZero`
        // 已把「count == 0 合法」钉成判据 ⇒ 若给 step 加上界 `step <= Double(count)`，
        // count == 0 时它与 `step > 0` 联立无解，会把一个既有合法调用打成非法。
        let zeroCount = Rating(value: .constant(0), count: 0, step: 2)
        #expect(zeroCount.count == 0)
        #expect(zeroCount.step == 2)
        // step > count 也不是失效形态：steppedValue 把结果 clamp 回 0...count。
        #expect(Rating.steppedValue(atRelativeX: 50, totalWidth: 100, count: 3, step: 10) == 3)
    }
}
