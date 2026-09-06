import SwiftUI
import Testing
@testable import CoreDesign

@Suite("spinning / ProgressIndicator 的 tint 透传")
struct SpinningTintPassthroughGuard {
    @Test("ProgressIndicator 三个 init 都存下 tint，默认为 accent")
    func progressIndicatorStoresTint() {
        #expect(ProgressIndicator().tint == Color.accent)
        #expect(ProgressIndicator(tint: .red).tint == Color.red)
        #expect(ProgressIndicator(text: "x", tint: .red).tint == Color.red)
        #expect(ProgressIndicator(text: "x" as String, tint: .red).tint == Color.red)
    }

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
