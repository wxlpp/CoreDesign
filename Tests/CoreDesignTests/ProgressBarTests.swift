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

// MARK: - a11y 值的本地化（Issue #222）

@Suite("ProgressBar a11y 本地化")
struct ProgressBarL10nTests {
    @Test("百分比值走 catalog，且渲染结果不含字面量 %%")
    func percentValueGoesThroughCatalog() {
        let v = ProgressBar.percentValue(0.5)
        #expect(v == "50% complete", "取到的不是 catalog 值：\(v)")
        // ⚠️ 百分号转义写错的典型失败形态是渲染出字面量 `%%`——那不会让编译红、
        // 也不会让上面那条断言以外的任何东西红。显式钉住。
        #expect(!v.contains("%%"), "渲染结果含字面量 %%：\(v)")
        #expect(v.contains("%"), "百分号丢失：\(v)")
    }

    @Test("四个新 key 确实注册进 catalog——而不是靠 key 回退看起来对")
    func newKeysExistInCatalog() {
        // ⚠️ **这条是 I-5 的修复**。上面那些断言的期望值（"50% complete" / "Clear search"）
        // 与 **key 本身的回退渲染逐字相同**（en 值 == key）——把 Localizable.strings 里
        // 四条新 key 全删、或 bundle 接错走了回退，那些断言**照样全绿**。
        // 「断言取到的是 catalog 值」在字面上满足、在实质上没有覆盖。
        //
        // 用一个不可能出现在 catalog 里的 sentinel 作 value：取到 sentinel 说明键不存在。
        // ⚠️ 只列**本 issue 新增**的四个键。"iMessage" 是 #221 分支新增的
        // （BottomInputBar 的 B 类兜底），不属本分支——首版误列进来，
        // 断言立刻判红并抓到了这个跨分支混淆。
        for key in ["%@ complete", "Clear %@", "Search", "search"] {
            let resolved = Bundle.module.localizedString(forKey: key, value: "__MISSING__", table: nil)
            #expect(resolved != "__MISSING__", "键 \(key) 未注册进 Localizable.strings")
        }
    }

    @Test("边界值：0% 与 100%")
    func percentValueBoundaries() {
        #expect(ProgressBar.percentValue(0) == "0% complete")
        #expect(ProgressBar.percentValue(1) == "100% complete")
    }
}
