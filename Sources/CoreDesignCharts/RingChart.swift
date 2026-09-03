//
//  RingChart.swift
//  CoreDesignCharts
//

import Accessibility
import CoreDesign
import SwiftUI

/// 活动环。多个同心进度环，每环一个指标的完成度。
///
/// ⚠️ Swift Charts 画不出来：`SectorMark` 是饼图/环形图（按占比切分**一个**环），
/// 活动环是**多个独立环各自表示完成度**——不是同一个概念。
public struct RingChart<Value: ChartValue>: View {

    private let values: [Value]
    private let goal: Double
    private let tint: Color
    private let title: LocalizedStringResource

    /// - Parameters:
    ///   - goal: 满环对应的值。⚠️ **不从数据里推**——活动环的语义是"完成度"，
    ///     目标是外部设定的，用数据最大值当目标会让"全部未达标"看起来像"有人满环"。
    public init(
        _ values: [Value],
        goal: Double,
        title: LocalizedStringResource = .chart("Activity rings"),
        tint: Color = .accent
    ) {
        self.values = values
        self.goal = goal
        self.title = title
        self.tint = tint
    }

    public var body: some View {
        if self.values.isEmpty {
            ChartEmptyState(message: .chart("No data"))
        } else if !self.goal.isFinite || self.goal <= 0 {
            // ⚠️ `goal == 0` 会让每个环的完成度除零。这是**调用方的输入错误**，
            // 但库不该 crash（FR-20 的同款原则）——给出可操作的提示。
            // ⚠️ `isFinite` 这半句是终审 C-4 补的：`NaN <= 0` 为**假**，
            // 原来的守卫放 `goal = .nan` 过关，然后在 `0...max(goal, 1)` 处
            // 让宿主 App trap（`max(NaN, 1) == NaN`）。
            ChartEmptyState(message: .chart("The goal must be greater than 0"))
        } else {
            self.rings
        }
    }

    /// 同心环的建议上限。**超出即截断**，与 `NetworkGraph` 同一条 FR-20 原则。
    ///
    /// ⚠️ **终审 I-6 抓到的**：初版一个上限都没有，而环宽有个 `max(…, 4)` 地板
    /// ⇒ 环数一多，`radius = outer - index * width * 1.5` 会变**负**
    ///（实测 side=200、20 个指标 ⇒ index 19 时 radius = -22 ⇒ `.frame(width: -44)`）。
    /// 6 是取「最内环仍有正半径」反推：`outer - 5 * width * 1.5 > 0` 在 `width`
    /// 走公式（非地板）时恒成立。
    /// ⚠️ 泛型类型不支持 static **存储**属性，故写成计算属性。
    public static var recommendedRingLimit: Int { 6 }

    private var effectiveValues: [Value] {
        Array(self.values.prefix(Self.recommendedRingLimit))
    }

    private var rings: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outer = side / 2 * 0.92
            let shown = self.effectiveValues
            let width = max(outer / Double(max(shown.count, 1)) * 0.52, 4)

            ZStack {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, value in
                    // ⚠️ 半径夹到 ≥ 1：`max(…, 4)` 那道宽度地板在极小容器里仍能把
                    // 半径推负，而负 frame 是 SwiftUI 运行期告警（终审 I-6）。
                    let radius = max(outer - Double(index) * width * 1.5, 1)
                    // ⚠️ 完成度可以 > 1（超额完成），环画满即止；但**不夹到 0 以下**，
                    // 负值当 0 处理而不是反向画。
                    let progress = max(0, min(value.value / self.goal, 1))

                    ZStack {
                        Circle()
                            .stroke(self.tint.opacity(0.18), lineWidth: width)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                self.tint.opacity(1.0 - Double(index) * 0.18),
                                style: StrokeStyle(lineWidth: width, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: radius * 2, height: radius * 2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }
}

extension RingChart: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor {
        let category = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Metric"), categoryOrder: self.values.map(\.label)
        )
        // ⚠️ `safeRange` 与 `denominator` 都是终审 C-4 的产物：descriptor 是
        // VoiceOver 主动拉取的，**渲染没崩不代表这里不崩**。
        let denominator = self.goal.isFinite && self.goal > 0 ? self.goal : 1
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Completion"),
            range: safeRange(0, denominator), gridlinePositions: []
        ) { "\($0.formatted(.percent.scale(100 / denominator)))" }
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: self.values.map { AXDataPoint(x: $0.label, y: $0.value) }
        )
        return AXChartDescriptor(
            title: String(localized: self.title), summary: nil,
            xAxis: category, yAxis: axis, additionalAxes: [], series: [series]
        )
    }
}

private nonisolated struct Ring: ChartValue {
    let id = UUID()
    let label: String
    let value: Double
}

#Preview("RingChart") {
    VStack(spacing: 24) {
        RingChart([
            Ring(label: "活动", value: 420),
            Ring(label: "锻炼", value: 28),
            Ring(label: "站立", value: 9),
        ], goal: 500)
        .frame(height: 200)

        // 退化：目标为 0
        RingChart([Ring(label: "x", value: 1)], goal: 0).frame(height: 60)
    }
    .padding()
}
