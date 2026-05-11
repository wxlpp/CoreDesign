import Testing
@testable import CoreDesign
import CoreGraphics

@Suite("CoreButtonMetrics")
struct CoreButtonMetricsTests {
    @Test("glassInset is 2pt")
    func glassInset() {
        #expect(CoreButtonMetrics.glassInset == 2.0)
    }

    @Test("glassBorderOpacity is 0.2")
    func glassBorderOpacity() {
        #expect(CoreButtonMetrics.glassBorderOpacity == 0.2)
    }

    @Test("pressedScale is 0.94")
    func pressedScale() {
        #expect(CoreButtonMetrics.pressedScale == 0.94)
    }

    @Test("all values are positive and non-zero")
    func allPositive() {
        #expect(CoreButtonMetrics.glassInset > 0)
        #expect(CoreButtonMetrics.glassBorderOpacity > 0)
        #expect(CoreButtonMetrics.pressedScale > 0 && CoreButtonMetrics.pressedScale < 1)
    }
}
