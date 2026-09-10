import OhMyDesign
import SwiftUI
import Testing
@testable import OhMyDesignEffects

@Suite("流光形状与显式停用")
@MainActor
struct GlowSweepShapeTests {
    private func pixels<S: InsettableShape>(_ shape: S, active: Bool = true) -> Data? {
        MicroInteractionAPITests.stablePixels(
            GlowSweep(in: shape, isActive: active) {
                Color.black.frame(width: 180, height: 60)
            }
            .tint(.white)
            .environment(\.scenePhaseOverride, .active)
            .environment(\.lowPowerModeOverride, true)
        )
    }

    @Test func customShapesAffectBorder() {
        expectBitmapsDiffer(pixels(Capsule()), pixels(Rectangle()), "胶囊不能仍绘制矩形边框")
        expectBitmapsDiffer(pixels(Circle()), pixels(Capsule()), "圆形必须服从自身路径")
    }

    @Test func inactiveDoesNotDrawOverlay() {
        let baseline = MicroInteractionAPITests.stablePixels(Color.black.frame(width: 180, height: 60))
        expectBitmapsEqual(pixels(Capsule(), active: false), baseline, "停用后应只剩内容")
        expectBitmapsDiffer(pixels(Capsule()), baseline, "启用应绘制边框")
    }
}
