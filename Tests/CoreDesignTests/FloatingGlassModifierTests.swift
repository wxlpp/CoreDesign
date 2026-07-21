import SwiftUI
import Testing
@testable import CoreDesign

// FloatingGlassModifier 的公开 API 契约断言（C2）。
//
// 旧版用「描述字符串非空」做恒真占位（编译通过即必过，零信息量）。
// modifier 暴露 public `shape` / `isInteractive`，可断言 init 的**默认值**与**存储契约**：
// - `defaultsNonInteractive` 有真价值：捕获默认参数从 false 被误翻为 true。
// - `interactiveFlagPassedThrough` 较弱：只验 init 存下了入参，仅在 init 被写成
//   `= !isInteractive` 这类反常实现时才红。**真正的行为——`isInteractive` 在 body 里
//   选择 `Glass.regular.interactive()`（FloatingGlassModifier.swift:20）——在 Tests/ 内
//   不可断言**（需渲染 / ViewInspector，属 Out of Scope），此处不覆盖。
@Suite("FloatingGlassModifier")
@MainActor
struct FloatingGlassModifierTests {
    @Test("init 默认非交互")
    func defaultsNonInteractive() {
        let modifier = FloatingGlassModifier(shape: Capsule())
        #expect(modifier.isInteractive == false)
    }

    @Test("isInteractive 透传到 modifier")
    func interactiveFlagPassedThrough() {
        let modifier = FloatingGlassModifier(shape: Capsule(), isInteractive: true)
        #expect(modifier.isInteractive == true)
    }
}
