import SwiftUI
import Testing
@testable import OhMyDesignEffects

@MainActor struct MaskRevealInterpolationTests {
    @Test func controlledDissolveHasVisibleIntermediateFrame() throws {
        let full = try #require(MicroInteractionAPITests.stablePixels(Color.white.frame(width: 120, height: 80).dissolve(progress: 1)))
        let middle = try #require(MicroInteractionAPITests.stablePixels(Color.white.frame(width: 120, height: 80).dissolve(progress: 0.5)))
        let empty = try #require(MicroInteractionAPITests.stablePixels(Color.white.frame(width: 120, height: 80).dissolve(progress: 0)))
        #expect(middle != full && middle != empty)
    }
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
