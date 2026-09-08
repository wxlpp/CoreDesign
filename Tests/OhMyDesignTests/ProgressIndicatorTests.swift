import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - ProgressIndicator 文案存储（Issue #172）

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
