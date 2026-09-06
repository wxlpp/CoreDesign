import SwiftUI
import Testing
@testable import CoreDesignCharts

/// `RingChart` 逐环配色（`colors:`）的判据。
///
/// ⚠️ **`tint` 一律用系统语义色，不得用 `ColorGrade` / `StatusColors` / `FunctionalColor`**：
/// 那 198 个走 asset catalog 的常量在 macOS `swift test` 腿上全部解析为 `(0,0,0,0)`，
/// α 断言会**向绿失效**（见 `CLAUDE.md`《验证边界与常见坑》）。
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

    /// ⚠️ **本条网的是 `trackColor(at:)` 的定义**，不是「C-1 不会复发」这么宽的东西。
    /// C-1 的病灶在**调用点**（`rings` 里那一行写成了 `ringColor(at:).opacity(0.18)`，
    /// 二次相乘、第 6 环轨道 α 从 0.18 掉到 0.018）。`rings` 是 `private` + 返回
    /// `some View`，结构上测不到 ⇒ 上一版判据自己重拼一遍表达式，**抓的是它自己写的那行**：
    /// 实测把调用点改回病灶形态，三条判据**全绿 `EXIT=0`**。
    /// ⇒ 现在轨道表达式收进具名的 `trackColor(at:)`，本条断言**它的定义**。
    /// ⚠️ **这没有把缺口补上，只是消除了重复**：实测在加了 `trackColor(at:)` 之后，
    /// 把 `rings` 里的调用改回病灶形态，三条**仍然全绿**。调用点结构上无网。
    /// ⇒ 别把本条读成「C-1 不会复发」。
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
        // 用两个 α 互异的色，靠 α 就能分辨轮转，无需比 RGB。
        // ⚠️ **基色取 `.white` 而不是 `.primary`**：`Color.primary` 在 macOS 上
        // 自带 α = 0.8471（iOS 是 1.0），`.opacity(0.9)` 实测得 0.762 而不是 0.9
        // ⇒ 断言会因平台而异。`.white` 两端都是 α = 1。
        let a = Color.white.opacity(0.9)
        let b = Color.white.opacity(0.3)
        let chart = Self.chart(colors: [a, b], tint: .white.opacity(0.5))
        let seq = (0..<6).map { Self.alpha(chart.ringBaseColor(at: $0)) }
        #expect(abs(seq[0] - 0.9) < 0.01)
        #expect(abs(seq[1] - 0.3) < 0.01)
        #expect(abs(seq[2] - 0.9) < 0.01, "index 2 应轮转回 colors[0]")
        // tint 的 0.5 一次都不该出现
        #expect(!seq.contains { abs($0 - 0.5) < 0.01 }, "colors 非空时 tint 不得生效")
    }
}
