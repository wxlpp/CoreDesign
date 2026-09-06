import SwiftUI
import Testing
@testable import CoreDesign

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
