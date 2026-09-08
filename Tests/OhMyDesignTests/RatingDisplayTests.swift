import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("RatingDisplay")
@MainActor
struct RatingDisplayTests {
    @Test("value / count 原样保留，count 默认 5")
    func initStoresParameters() {
        let display = RatingDisplay(value: 3.5, count: 7)
        #expect(display.value == 3.5)
        #expect(display.count == 7)
        #expect(RatingDisplay(value: 1).count == 5)
    }

    @Test("count 负数 clamp 到 0（与 Rating 同一条仓内惯例）")
    func negativeCountClampsToZero() {
        #expect(RatingDisplay(value: 0, count: -3).count == 0)
    }

    @Test("accessibilityValue 文案与 Rating 共用同一个位置键，不另起一套")
    func accessibilityValueTextIsSharedWithRating() {
        let value = 2.5
        let count = 5
        #expect(
            RatingDisplay.accessibilityValueText(value: value, count: count)
                == Rating.accessibilityValueText(value: value, count: count)
        )
        #expect(
            RatingDisplay.accessibilityValueText(value: value, count: count)
                == "\(value.formatted()) of \(Double(count).formatted())"
        )
    }
}
