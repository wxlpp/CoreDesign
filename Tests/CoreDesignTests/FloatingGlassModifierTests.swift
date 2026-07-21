import SwiftUI
import Testing
@testable import CoreDesign

// FloatingGlassModifier 的公开 API 契约断言（C2）。
//
// 旧版用「描述字符串非空」做恒真占位（编译通过即必过，零信息量）。
// modifier 暴露 public `shape` / `isInteractive`，可直接断言 init 的默认值与透传
// 契约——能捕获「默认参数被误改」「isInteractive 未透传」这类真实回退。
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
