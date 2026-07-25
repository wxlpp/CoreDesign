import SwiftUI
import Testing
@testable import CoreDesign

// PinCode（Issue #166）——真实键盘输入 / 焦点跳转无法在 Swift Testing 里直接模拟，
// 因此覆盖面全部落在 `PinCode` 内部暴露的静态纯函数上：`sanitizedValue` /
// `isComplete` / `character(at:in:)` / `displayText(for:isSecure:)` /
// `focusedIndex` / `positionText`。真实渲染与键盘交互留给 iOS Simulator 视觉评审
// （见 CLAUDE.md 验证边界章节）。
@Suite("PinCode")
@MainActor
struct PinCodeTests {
    // MARK: - 构造参数

    @Test("length 通过 init 原样保留（合法正数）")
    func lengthRoundTrips() {
        let pinCode = PinCode(value: .constant(""), length: 6)
        #expect(pinCode.length == 6)
    }

    @Test("length 非正数 clamp 到 1，不产生 0 或负数格数")
    func nonPositiveLengthClampsToOne() {
        #expect(PinCode(value: .constant(""), length: 0).length == 1)
        #expect(PinCode(value: .constant(""), length: -3).length == 1)
    }

    @Test("isSecure 默认关闭（明文展示）")
    func isSecureDefaultsToFalse() {
        let pinCode = PinCode(value: .constant(""), length: 4)
        #expect(pinCode.isSecure == false)
    }

    @Test("value 通过 Binding 双向绑定，构造时原样保留")
    func valueBindingRoundTrips() {
        var stored = "12"
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let pinCode = PinCode(value: binding, length: 6)
        pinCode.value = "123"
        #expect(stored == "123")
    }

    // MARK: - sanitizedValue：非数字字符过滤 + 长度截断

    @Test("sanitizedValue：过滤非数字字符（字母 / 符号 / 空格）")
    func sanitizedValueFiltersNonDigits() {
        #expect(PinCode.sanitizedValue(from: "1a2b3c", length: 6) == "123")
        #expect(PinCode.sanitizedValue(from: "1 2-3", length: 6) == "123")
        #expect(PinCode.sanitizedValue(from: "abc", length: 6) == "")
    }

    @Test("sanitizedValue：超出 length 的多余数字被截断")
    func sanitizedValueClampsLength() {
        #expect(PinCode.sanitizedValue(from: "123456789", length: 6) == "123456")
        #expect(PinCode.sanitizedValue(from: "12", length: 6) == "12")
    }

    @Test("sanitizedValue：粘贴场景——非数字与超长同时出现")
    func sanitizedValueHandlesPasteWithNoiseAndOverflow() {
        #expect(PinCode.sanitizedValue(from: "1a2b3c4d5e6f7g8h", length: 4) == "1234")
    }

    @Test("sanitizedValue：空字符串保持为空")
    func sanitizedValueEmptyStaysEmpty() {
        #expect(PinCode.sanitizedValue(from: "", length: 6) == "")
    }

    // MARK: - isComplete

    @Test("isComplete：字符数等于 length 时为真")
    func isCompleteWhenLengthMatches() {
        #expect(PinCode.isComplete(value: "123456", length: 6) == true)
    }

    @Test("isComplete：字符数不足 length 时为假")
    func isCompleteWhenUnderLength() {
        #expect(PinCode.isComplete(value: "123", length: 6) == false)
        #expect(PinCode.isComplete(value: "", length: 6) == false)
    }

    // MARK: - character(at:in:)

    @Test("character(at:in:)：下标在范围内返回对应字符")
    func characterReturnsExpectedDigit() {
        #expect(PinCode.character(at: 0, in: "123") == "1")
        #expect(PinCode.character(at: 2, in: "123") == "3")
    }

    @Test("character(at:in:)：下标超出当前长度返回 nil（空格）")
    func characterReturnsNilWhenOutOfRange() {
        #expect(PinCode.character(at: 3, in: "123") == nil)
        #expect(PinCode.character(at: 0, in: "") == nil)
    }

    @Test("character(at:in:)：负数下标返回 nil，不崩溃")
    func characterReturnsNilForNegativeIndex() {
        #expect(PinCode.character(at: -1, in: "123") == nil)
    }

    // MARK: - displayText(for:isSecure:)

    @Test("displayText：isSecure 为 false 时明文展示字符本身")
    func displayTextShowsPlainCharacterWhenNotSecure() {
        #expect(PinCode.displayText(for: "7", isSecure: false) == "7")
    }

    @Test("displayText：isSecure 为 true 时以圆点替代实际字符")
    func displayTextMasksCharacterWhenSecure() {
        #expect(PinCode.displayText(for: "7", isSecure: true) == "\u{2022}")
        // 掩码文案与具体数字无关——任意数字都得到同一个圆点。
        #expect(PinCode.displayText(for: "7", isSecure: true) == PinCode.displayText(for: "1", isSecure: true))
    }

    @Test("displayText：字符为 nil（空格）时始终返回空字符串，不论 isSecure")
    func displayTextEmptyWhenCharacterIsNil() {
        #expect(PinCode.displayText(for: nil, isSecure: false) == "")
        #expect(PinCode.displayText(for: nil, isSecure: true) == "")
    }

    // MARK: - focusedIndex：当前应高亮的格位

    @Test("focusedIndex：未填满时指向下一个空格")
    func focusedIndexPointsToNextEmptySlot() {
        #expect(PinCode.focusedIndex(valueCount: 0, length: 6) == 0)
        #expect(PinCode.focusedIndex(valueCount: 3, length: 6) == 3)
    }

    @Test("focusedIndex：填满时 clamp 在最后一格，不越界")
    func focusedIndexClampsToLastSlotWhenFull() {
        #expect(PinCode.focusedIndex(valueCount: 6, length: 6) == 5)
    }

    // MARK: - positionText：Phase 0 位置键 "%@ of %@"

    @Test("positionText：按 Phase 0 位置键组装，两端为 formatted() 结果")
    func positionTextComposesPositionalKey() {
        let text = PinCode.positionText(index: 3, count: 6)
        // 不硬编码 locale 相关字面量——直接拿同一套 formatted() 结果重建期望值，
        // 避免 CI 运行环境 locale 不同导致假红（与 RatingTests 同一手法）。
        #expect(text == "\(3.formatted()) of \(6.formatted())")
    }

    // MARK: - 处理流水线：sanitizedValue + isComplete 组合行为（onChange 背后的受控逻辑）

    @Test("处理流水线：填满 length 格时 isComplete 为真，可驱动 onComplete 触发")
    func pipelineSignalsCompleteWhenFilled() {
        let raw = "123456"
        let sanitized = PinCode.sanitizedValue(from: raw, length: 6)
        #expect(sanitized == "123456")
        #expect(PinCode.isComplete(value: sanitized, length: 6) == true)
    }

    @Test("处理流水线：未填满时不触发 onComplete 语义")
    func pipelineDoesNotSignalCompleteWhenPartial() {
        let raw = "123"
        let sanitized = PinCode.sanitizedValue(from: raw, length: 6)
        #expect(PinCode.isComplete(value: sanitized, length: 6) == false)
    }

    @Test("处理流水线：粘贴超长噪声输入后仍能正确判定填满")
    func pipelineSignalsCompleteAfterClampingNoisyPaste() {
        let raw = "1a2b3c4d5e6f7g8h9i"
        let sanitized = PinCode.sanitizedValue(from: raw, length: 6)
        #expect(sanitized == "123456")
        #expect(PinCode.isComplete(value: sanitized, length: 6) == true)
    }

    // MARK: - onComplete 转变沿（模拟真实 onChange：binding 已被 TextField 写成新值）
    //
    // 关键形态：真实 `onChange(of: value)` 触发时 `self.value` 已 == 新值，故组件用 onChange
    // 提供的**击键前旧值**穿透。下列测试统一模拟这一形态——先把 `stored` 置为 raw（TextField
    // 已写），再以真旧值调两参 `processInput(raw, previousValue: old)`。单参/binding 未预写的
    // 旧测试形态是运行时不存在的上下文（会假绿），已全部废弃。

    @Test("shouldFireComplete：新值满 且 旧值(规整后)未满 才为真（含写回第二轮）")
    func shouldFireCompleteTruthTable() {
        #expect(PinCode.shouldFireComplete(previousValue: "123", newSanitized: "1234", length: 4))    // 补满 → fire
        #expect(!PinCode.shouldFireComplete(previousValue: "1234", newSanitized: "1234", length: 4))  // 满→满
        // 写回第二轮：旧值超长(count 5≠4) 但规整后 "1234" 已满 → 不 fire（严格 == 会误判未满）
        #expect(!PinCode.shouldFireComplete(previousValue: "12345", newSanitized: "1234", length: 4))
        #expect(!PinCode.shouldFireComplete(previousValue: "12", newSanitized: "123", length: 4))     // 未满→未满
    }

    @Test("onComplete：正常补满最后一位触发一次，参数为最终值（主路径回归守卫）")
    func onCompleteFiresOnFill() {
        var captured: String?
        var count = 0
        var stored = "1234"   // TextField 已把新值写进 binding
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let pin = PinCode(value: binding, length: 4, onComplete: { captured = $0; count += 1 })
        pin.processInput("1234", previousValue: "123")   // 击键前旧值 "123"
        #expect(captured == "1234")
        #expect(count == 1)
        #expect(stored == "1234")
    }

    @Test("onComplete：未填满不触发")
    func onCompleteDoesNotFireWhenIncomplete() {
        var count = 0
        var stored = "12"
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let pin = PinCode(value: binding, length: 4, onComplete: { _ in count += 1 })
        pin.processInput("12", previousValue: "1")
        #expect(count == 0)
        #expect(stored == "12")
    }

    @Test("onComplete：满态多敲一位——两轮 onChange 均不重复触发")
    func onCompleteDoesNotRefireOnOverType() {
        var count = 0
        var stored = "12345"   // TextField 已写入超长
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let pin = PinCode(value: binding, length: 4, onComplete: { _ in count += 1 })
        pin.processInput("12345", previousValue: "1234")   // 第一轮：旧 "1234" 已满 → 不 fire；写回 "1234"
        pin.processInput("1234", previousValue: "12345")   // 写回引发第二轮：旧 "12345" 规整后满 → 不 fire
        #expect(count == 0)
        #expect(stored == "1234")
    }

    @Test("onComplete：onAppear 已满初值不触发（firesOnComplete:false，防 NavigationStack 重放循环）")
    func onCompleteNotFiredOnAppear() {
        var count = 0
        var stored = "1234"
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let pin = PinCode(value: binding, length: 4, onComplete: { _ in count += 1 })
        pin.processInput("1234", previousValue: "1234", firesOnComplete: false)
        #expect(count == 0)
    }

    @Test("onComplete：删一位再补回最后一位应再次触发（转变沿复位）")
    func onCompleteRefiresAfterDropAndRefill() {
        var count = 0
        var stored = ""
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let pin = PinCode(value: binding, length: 4, onComplete: { _ in count += 1 })
        stored = "1234"; pin.processInput("1234", previousValue: "123")   // 未满→满：触发 1
        stored = "123";  pin.processInput("123", previousValue: "1234")   // 删一位：不触发
        stored = "1234"; pin.processInput("1234", previousValue: "123")   // 未满→满：再触发
        #expect(count == 2)
    }

    @Test("onComplete：为 nil 时填满也不崩溃")
    func onCompleteNilDoesNotCrashWhenFilled() {
        var stored = "1234"
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let pin = PinCode(value: binding, length: 4)
        pin.processInput("1234", previousValue: "123")
        #expect(stored == "1234")
    }

    @Test("processInput：粘贴超长噪声输入被截断且清洗后写回 Binding")
    func processInputSanitizesAndClampsBoundValue() {
        var stored = "1a2b3c4d5e"
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let pin = PinCode(value: binding, length: 4)
        pin.processInput("1a2b3c4d5e", previousValue: "")
        #expect(stored == "1234")
    }

    // MARK: - accessibility value（非掩码补数字）

    @Test("accessibilityValueText：非掩码且已填时把数字附在位置后")
    func accessibilityValueAppendsDigitWhenVisible() {
        #expect(PinCode.accessibilityValueText(index: 3, count: 6, character: "7", isSecure: false) == "3 of 6, 7")
    }

    @Test("accessibilityValueText：掩码态 / 空格只播位置，不泄露不臆造")
    func accessibilityValueHidesDigitWhenSecureOrEmpty() {
        #expect(PinCode.accessibilityValueText(index: 3, count: 6, character: "7", isSecure: true) == "3 of 6")
        #expect(PinCode.accessibilityValueText(index: 4, count: 6, character: nil, isSecure: false) == "4 of 6")
    }
}
