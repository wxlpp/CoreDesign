import SwiftUI
import Testing
@testable import OhMyDesignEffects

@MainActor struct MaskRevealInterpolationTests {
    @Test func dissolveClipInterpolatesItsPath() {
        let rect = CGRect(x: 0, y: 0, width: 360, height: 260)
        var clip = MaskRevealShape(plan: MaskReveal.plan(kind: .dissolve(cellSize: 10), progress: 1, isReduced: false))
        let full = clip.path(in: rect)
        clip.animatableData = 0.5
        let middle = clip.path(in: rect)
        #expect(middle != full)
        #expect(!middle.isEmpty)
        clip.animatableData = 0
        #expect(clip.path(in: rect).isEmpty)
    }
}
