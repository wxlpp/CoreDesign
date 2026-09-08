import Accessibility
import OhMyDesign
import SwiftUI

/// 活动环。多个同心进度环，每环一个指标的完成度。
public struct RingChart<Value: ChartValue>: View {
    private let values: [Value]
    private let goal: Double
    private let tint: Color
    private let colors: [Color]
    private let title: LocalizedStringResource

    /// - Parameters:
    ///   - goal: 满环对应的值。⚠️ **不从数据里推**——活动环的语义是"完成度"，
    ///     目标是外部设定的，用数据最大值当目标会让"全部未达标"看起来像"有人满环"。
    /// - Parameter colors: **逐环**取色，按下标轮转。默认空数组 ⇒ 退回 `tint` 的
    ///   透明度阶梯（每内一环降 0.18）。
    public init(
        _ values: [Value],
        goal: Double,
        title: LocalizedStringResource? = nil,
        tint: Color = .dataAccent,
        colors: [Color] = []
    ) {
        self.values = values
        self.goal = goal
        self.title = title ?? .chart("Activity rings")
        self.tint = tint
        self.colors = colors
    }

    nonisolated func ringBaseColor(at index: Int) -> Color {
        self.colors.isEmpty ? self.tint : self.colors[index % self.colors.count]
    }

    nonisolated func trackColor(at index: Int) -> Color {
        self.ringBaseColor(at: index).opacity(0.18)
    }

    nonisolated func ringColor(at index: Int) -> Color {
        guard !self.colors.isEmpty else {
            return self.tint.opacity(max(1.0 - Double(index) * 0.18, 0.1))
        }
        return self.ringBaseColor(at: index)
    }

    public var body: some View {
        if self.values.isEmpty {
            ChartEmptyState(message: .chart("No data"))
        } else if !self.goal.isFinite || self.goal <= 0 {
            ChartEmptyState(message: .chart("The goal must be greater than 0"))
        } else {
            self.rings
        }
    }

    /// 同心环的建议上限。**超出即截断**，与 `NetworkGraph` 同一条 FR-20 原则。
    public nonisolated static var recommendedRingLimit: Int { 6 }

    private var effectiveValues: [Value] {
        var seen = Set<Value.ID>()
        var kept: [Value] = []
        kept.reserveCapacity(min(self.values.count, Self.recommendedRingLimit))
        for value in self.values where seen.insert(value.id).inserted {
            kept.append(value)
            if kept.count >= Self.recommendedRingLimit { break }
        }
        return kept
    }

    private static func drawnValue(_ value: Double, goal: Double) -> Double {
        guard value.isFinite else { return value > 0 ? goal : 0 }
        return min(max(value, 0), goal)
    }

    private var rings: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outer = side / 2 * 0.92
            let shown = self.effectiveValues
            let width = max(outer / Double(max(shown.count, 1)) * 0.52, 4)

            ZStack {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, value in
                    let radius = max(outer - Double(index) * width * 1.5, 1)
                    let progress = max(0, min(value.value / self.goal, 1))

                    ZStack {
                        Circle()
                            .stroke(self.trackColor(at: index), lineWidth: width)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                self.ringColor(at: index),
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
            title: chartAXString("Metric"), categoryOrder: self.effectiveValues.map(\.label)
        )
        let denominator = self.goal.isFinite && self.goal > 0 ? self.goal : 1
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Completion"),
            range: safeRange(0, denominator), gridlinePositions: []
        ) { "\($0.formatted(.percent.scale(100 / denominator)))" }
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: self.effectiveValues.map {
                AXDataPoint(x: $0.label, y: Self.drawnValue($0.value, goal: denominator))
            }
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

        RingChart([Ring(label: "x", value: 1)], goal: 0).frame(height: 60)
    }
    .padding()
}
