import SwiftUI
import Testing
@testable import CoreDesign

// RatingDisplay（Issue #41 裁决 4b）——`Rating` 的只读展示态被拆成独立的 indicator。
//
// ⚠️ **为什么拆而不是归并**：归并方案（删 isReadOnly、统一走 .disabled(true)）会让所有
// 展示态评分走 SwiftUI 原生 disabled 视觉（变灰 + 降低对比度），而展示态不是「不能用」、
// 是「本来就不是控件」——那是语义错配导致的视觉回归。拆分后「控制展示态」只剩一条路径：
// 选哪个类型。
//
// 真实渲染与手势留给 iOS Simulator 视觉评审（见 CLAUDE.md 验证边界章节）。
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
        // ⚠️ 这条挡的是「拆组件时顺手复制一份文案组装逻辑」——两份实现必然漂移，
        // 而 `bundle: .module` 漏传 / 插值形状跑偏都是静默 fallback（英文环境下输出
        // 恰好不变，直到非英文本地化才暴露）。RatingDisplay 直接复用
        // `Rating.accessibilityValueText(value:count:)`，本断言把这条复用钉死。
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
