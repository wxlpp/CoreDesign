import SwiftUI
import Testing
@testable import CoreDesign

@Suite("FlowLayout")
@MainActor
struct FlowLayoutTests {
    @Test("init with default spacing uses CoreSpacing.xs")
    func defaultSpacing() {
        let layout = FlowLayout()
        #expect(layout.spacing == CoreSpacing.xs)
    }

    @Test("init with custom spacing stores value")
    func customSpacing() {
        let layout = FlowLayout(spacing: 8)
        #expect(layout.spacing == 8)
    }
}
