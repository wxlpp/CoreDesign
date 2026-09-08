import SwiftUI
import Testing
@testable import CoreDesign

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
        let v = ProgressBar.percentValue(0.5, locale: Locale(identifier: "en_US"))
        #expect(v == "50% complete", "取到的不是 catalog 值：\(v)")
        #expect(!v.contains("%%"), "渲染结果含字面量 %%：\(v)")
        #expect(v.contains("%"), "百分号丢失：\(v)")
    }

    @Test("两个新 key 确实注册进 catalog——而不是靠 key 回退看起来对")
    func newKeysExistInCatalog() {
        // "Clear %@" 已随 SearchField 改用原生控件移除——清除按钮的可访问名由系统提供。
        for key in ["%@ complete", "Search"] {
            let resolved = Bundle.module.localizedString(forKey: key, value: "__MISSING__", table: nil)
            #expect(resolved != "__MISSING__", "键 \(key) 未注册进 Localizable.strings")
        }
    }

    @Test("边界值：0% 与 100%")
    func percentValueBoundaries() {
        let en = Locale(identifier: "en_US")
        #expect(ProgressBar.percentValue(0, locale: en) == "0% complete")
        #expect(ProgressBar.percentValue(1, locale: en) == "100% complete")
    }

    @Test("百分号相对数字的位置由 locale 决定，不再写死在 Swift 侧（#235）")
    func percentSignPositionFollowsLocale() {
        func pct(_ id: String) -> String {
            let full = ProgressBar.percentValue(0.5, locale: Locale(identifier: id))
            #expect(full.hasSuffix(" complete"),
                    "文案没落到 en 的 catalog 值 \(full)——查 Bundle.module.preferredLocalizations，不是 String(localized:locale:)")
            return String(full.dropLast(" complete".count))
        }

        #expect(pct("en_US") == "50%")
        #expect(pct("tr_TR") == "%50", "土耳其语百分号须前置")

        for id in ["fr_FR", "de_DE"] {
            let s = pct(id)
            #expect(s.hasPrefix("50") && s.hasSuffix("%") && s.count == 4
                        && s.dropFirst(2).first?.isWhitespace == true,
                    "\(id) 的数字与百分号之间须恰有一个空白字符，实为 \(s.debugDescription)")
        }
    }

    @Test("取整方向仍是向零截断，不取默认的四舍五入（#235）")
    func percentValueTruncatesTowardZero() {
        let en = Locale(identifier: "en_US")
        #expect(ProgressBar.percentValue(0.999, locale: en) == "99% complete")
        #expect(ProgressBar.percentValue(0.005, locale: en) == "0% complete")
        #expect(ProgressBar.percentValue(0.29, locale: en) == "29% complete",
                "十进制截断被换回二进制截断了：旧的 Int(0.29 * 100) 因浮点误差给 28")
    }
}
