import SwiftUI
import Testing
@testable import CoreDesign

@Suite("FloatingGlassModifier")
struct FloatingGlassModifierTests {
    @MainActor
    @Test("floating glass modifier constructs")
    func floatingGlassModifierConstructs() {
        let view = Text("Floating").floatingGlass()
        #expect(String(describing: type(of: view)).isEmpty == false)
    }

    @MainActor
    @Test("interactive floating glass modifier compile-smoke constructs")
    func interactiveFloatingGlassModifierCompileSmokeConstructs() {
        let view = Text("Floating").floatingGlass(isInteractive: true)
        #expect(String(describing: type(of: view)).isEmpty == false)
    }
}
