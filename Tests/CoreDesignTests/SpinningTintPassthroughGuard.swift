import SwiftUI
import Testing
@testable import CoreDesign

/// `.spinning(..., tint:)` 与 `ProgressIndicator(tint:)` 的**存储与透传**判据。
///
/// ⚠️ **只证存储与透传，不证「spinner 真的变绿」**：本仓没有 ViewInspector，
/// 渲染取色测不到。别把这几条读成渲染证据（`spinningAllPresentationsConstruct`
/// 的注释已经警告过同一种越界声称）。
@Suite("spinning / ProgressIndicator 的 tint 透传")
struct SpinningTintPassthroughGuard {

    @Test("ProgressIndicator 三个 init 都存下 tint，默认为 accent")
    func progressIndicatorStoresTint() {
        #expect(ProgressIndicator().tint == Color.accent)
        #expect(ProgressIndicator(tint: .red).tint == Color.red)
        #expect(ProgressIndicator(text: "x", tint: .red).tint == Color.red)
        #expect(ProgressIndicator(text: "x" as String, tint: .red).tint == Color.red)
    }

    /// ⚠️ 三个形态**都**要存下 tint：`.topBar` 曾经不透传（终审 C-2），
    /// 失效形态是「传了不报错也不变色」，而另两个形态吃这个参数
    /// ⇒ 同一 API 三形态取色分裂。
    @Test("SpinningModifier 三个形态都存下 tint")
    func spinningModifierStoresTintForEveryPresentation() {
        for presentation in [SpinningPresentation.overlay, .topBar, .inline] {
            let modifier = SpinningModifier(isActive: true, presentation: presentation, tint: .green)
            #expect(modifier.tint == Color.green, "\(presentation) 未存下 tint")
        }
    }

    @Test("TopBarIndicator 收 tint 而不是只从环境取")
    func topBarIndicatorTakesTintAsStoredProperty() {
        #expect(TopBarIndicator(tint: .green).tint == Color.green)
    }
}
