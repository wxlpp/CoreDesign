#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - macOS 分组背景降级守卫（Issue #120）
//
// AppKit 没有 grouped background 系列。Issue #120 之前，`systemGroupedBackground`
// 与 `secondarySystemGroupedBackground` 的 macOS 分支**双双**落到
// `.controlBackgroundColor`——照搬 iOS 映射会让 `surfaceCanvas`（画布）与
// `surfaceRaised`（卡片）同色、raised 层完全隐形。那不是"macOS 观感不打磨"，
// 是功能性退化。现改为 window / control 两分支。
//
// **验证手法的取舍**：本想解析成具体 RGBA 再比明度，但在无 WindowServer 会话的
// 沙箱里两者会塌缩成同一 fallback RGBA——那是解析环境的产物，不是真实的设计塌缩。
// 故改为断言**本库 token 本身**互不相等：SwiftUI `Color` 对 `Color(nsColor:)` 的
// 相等性基于其承载的 NSColor，一旦有人把某个分支改回 `.controlBackgroundColor`，
// 两个 token 就会判等，本测试立刻变红。
//
// > 早先版本这里比较的是 `NSColor.windowBackgroundColor != NSColor.controlBackgroundColor`
// > ——那是 AppKit 自身常量的性质，与 CoreDesign 无关，无论本库怎么改都恒真。
// > 被测对象必须是本库代码。

@Suite("macOS 分组背景降级")
struct SystemBackgroundColorsMacOSTests {

    @Test("canvas 与 raised 的底层 token 不同色")
    func groupedBackgroundsDiffer() {
        #expect(
            Color.systemGroupedBackground != Color.secondarySystemGroupedBackground,
            "macOS 上 canvas 与 raised 塌缩成同色——raised 层将完全隐形"
        )
    }

    @Test("语义层 surfaceCanvas 与 surfaceRaised 不同色")
    func semanticSurfacesDiffer() {
        #expect(
            Color.surfaceCanvas != Color.surfaceRaised,
            "surfaceCanvas 与 surfaceRaised 同色——卡片在画布上不可辨"
        )
    }

    @Test("三档分组背景：canvas 独立，secondary 与 tertiary 已知塌缩")
    func groupedFamilyDistinctness() {
        // canvas 与其余两档必须分开——这是 Issue #120 修的那一层。
        #expect(Color.systemGroupedBackground != Color.secondarySystemGroupedBackground)
        #expect(Color.systemGroupedBackground != Color.tertiarySystemGroupedBackground)

        // secondary 与 tertiary 在 macOS 上仍然同色：AppKit 没有第三级 grouped 背景，
        // 两者都落 `.controlBackgroundColor`。硬塞一个别的系统色（`underPageBackgroundColor`
        // / `textBackgroundColor`）风险大于收益——这两个 token 当前在组件层零消费点，
        // 猜错色比诚实塌缩更糟。
        //
        // 用 `withKnownIssue` 而不是删掉断言：一旦将来有人给 tertiary 找到合适的
        // AppKit 对应物，这里会因"预期失败却通过了"而提醒更新，不会静默失效。
        withKnownIssue("AppKit 无第三级 grouped 背景，secondary 与 tertiary 同落 controlBackgroundColor") {
            #expect(Color.secondarySystemGroupedBackground != Color.tertiarySystemGroupedBackground)
        }
    }
}
#endif
