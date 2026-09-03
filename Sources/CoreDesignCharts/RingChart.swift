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
    private let title: LocalizedStringKey

    /// - Parameters:
    ///   - goal: 满环对应的值。⚠️ **不从数据里推**——活动环的语义是"完成度"，
    ///     目标是外部设定的，用数据最大值当目标会让"全部未达标"看起来像"有人满环"。
    public init(
        _ values: [Value],
        goal: Double,
        title: LocalizedStringKey = "活动环",
        tint: Color = .accent
    ) {
        self.values = values
        self.goal = goal
        self.title = title
        self.tint = tint
    }

    public var body: some View {
        if self.values.isEmpty {
            ChartEmptyState(message: "暂无数据")
        } else if self.goal <= 0 {
            // ⚠️ `goal == 0` 会让每个环的完成度除零。这是**调用方的输入错误**，
            // 但库不该 crash（FR-20 的同款原则）——给出可操作的提示。
            ChartEmptyState(message: "目标值需大于 0")
        } else {
            self.rings
        }
    }

    private var rings: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outer = side / 2 * 0.92
            let width = max(outer / Double(max(self.values.count, 1)) * 0.52, 4)

            ZStack {
                ForEach(Array(self.values.enumerated()), id: \.element.id) { index, value in
                    let radius = outer - Double(index) * width * 1.5
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
        .accessibilityLabel(self.title)
        .accessibilityChartDescriptor(self)
    }
}

extension RingChart: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor {
        let category = AXCategoricalDataAxisDescriptor(
            title: "指标", categoryOrder: self.values.map(\.label)
        )
        let axis = AXNumericDataAxisDescriptor(
            title: "完成度", range: 0...max(self.goal, 1), gridlinePositions: []
        ) { "\($0.formatted(.percent.scale(100 / max(self.goal, 1))))" }
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: self.values.map { AXDataPoint(x: $0.label, y: $0.value) }
        )
        return AXChartDescriptor(
            title: nil, summary: nil,
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
