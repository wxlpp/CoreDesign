import SwiftUI
import Testing
@testable import CoreDesign

// ProgressBar 自 0.6.0 起弃用（导向 .core ProgressView），但在移除前仍保留其
// value 钳制 / 非有限输入归零等行为守卫。测试内会产生 deprecation 警告——这是
// 有意的（@Suite 宏不兼容 @available(deprecated)，无法在此处静默），移除 ProgressBar
// 时本文件一并删。
@Suite("ProgressBar（弃用守卫）")
@MainActor
struct ProgressBarTests {
    @Test("init with value stores clamped value")
    func initValue() {
        let bar = ProgressBar(value: 0.6)
        #expect(bar.value == 0.6)
    }

    @Test("value clamped to 0...1")
    func valueClamping() {
        let low = ProgressBar(value: -0.5)
        #expect(low.value == 0.0)
        let high = ProgressBar(value: 1.5)
        #expect(high.value == 1.0)
    }

    @Test("optional tint and label stored")
    func optionalParams() {
        let bar = ProgressBar(value: 0.3, tint: .green, label: "3 of 10")
        #expect(bar.value == 0.3)
        #expect(bar.tint == .green)
        #expect(bar.label == "3 of 10")
    }

    @Test("non-finite value sanitized to 0")
    func nonFiniteValue() {
        #expect(ProgressBar(value: .nan).value == 0)
        #expect(ProgressBar(value: .infinity).value == 0)
        #expect(ProgressBar(value: -.infinity).value == 0)
    }
}
