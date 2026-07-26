import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - ProgressIndicator 文案存储（Issue #172）
//
// 三个 init 的行为差异只在“存不存文案、存的是不是 verbatim”，覆盖这条逻辑即可——
// 渲染正确性（spinner 尺寸、tint、无障碍标签）交给 `#Preview` + 视觉终审。

@Suite("ProgressIndicator 文案存储")
@MainActor
struct ProgressIndicatorTests {
    @Test("init() 无破坏：不带文案（NFR-6）")
    func defaultInitHasNoText() {
        let indicator = ProgressIndicator()
        #expect(indicator.text == nil)
    }

    @Test("init(text: LocalizedStringKey) 存入本地化文案")
    func localizedTextStored() {
        let indicator = ProgressIndicator(text: "Loading…")
        #expect(indicator.text == Text("Loading…"))
    }

    @Test("init(text: StringProtocol) 存入 verbatim 文案")
    func verbatimTextStored() {
        let status: String = "3 of 10 uploaded"
        let indicator = ProgressIndicator(text: status)
        #expect(indicator.text == Text(status))
    }

    @Test("非 String 的 StringProtocol（Substring）同样可构造，@_disfavoredOverload 不影响非字面量调用")
    func substringOverloadResolves() {
        let full = "status: syncing"
        let substring: Substring = full.dropFirst("status: ".count)
        let indicator = ProgressIndicator(text: substring)
        #expect(indicator.text == Text(substring))
    }
}
