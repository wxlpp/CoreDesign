import SwiftUI
import Testing
@testable import OhMyDesignCharts

@Suite("RingChart 逐环配色")
struct RingChartColorsGuard {
    private struct Metric: ChartValue {
        let id: Int
        let label: String
        let value: Double
    }

    private static func chart(colors: [Color], tint: Color = .accentColor) -> RingChart<Metric> {
        RingChart(
            (0..<7).map { Metric(id: $0, label: "m\($0)", value: Double($0) * 40) },
            goal: 500, tint: tint, colors: colors
        )
    }

    private static func alpha(_ color: Color) -> Double {
        Double(color.resolve(in: EnvironmentValues()).opacity)
    }

    @Test("colors 为空时轨道透明度恒为 0.18，不随环序衰减")
    func emptyColorsKeepsTrackOpacityConstant() {
        let chart = Self.chart(colors: [])
        for index in 0..<6 {
            let track = Self.alpha(chart.trackColor(at: index))
            #expect(abs(track - 0.18) < 0.001, "第 \(index) 环轨道 α = \(track)，应恒为 0.18")
        }
    }

    @Test("colors 为空时环体仍是 tint 的透明度阶梯，且带 0.1 地板")
    func emptyColorsKeepsBodyRamp() {
        let chart = Self.chart(colors: [])
        for index in 0..<6 {
            let expected = max(1.0 - Double(index) * 0.18, 0.1)
            #expect(abs(Self.alpha(chart.ringColor(at: index)) - expected) < 0.001)
        }
    }

    @Test("colors 非空时逐环轮转，且 tint 完全不生效（已登记的正交性代价）")
    func nonEmptyColorsRotateAndIgnoreTint() {
        let a = Color.white.opacity(0.9)
        let b = Color.white.opacity(0.3)
        let chart = Self.chart(colors: [a, b], tint: .white.opacity(0.5))
        let seq = (0..<6).map { Self.alpha(chart.ringBaseColor(at: $0)) }
        #expect(abs(seq[0] - 0.9) < 0.01)
        #expect(abs(seq[1] - 0.3) < 0.01)
        #expect(abs(seq[2] - 0.9) < 0.01, "index 2 应轮转回 colors[0]")
        #expect(!seq.contains { abs($0 - 0.5) < 0.01 }, "colors 非空时 tint 不得生效")
    }
}
