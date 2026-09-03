//
//  RadarChart.swift
//  CoreDesignCharts
//

import Accessibility
import CoreDesign
import SwiftUI

/// 雷达图（蛛网图）。多维评分的形状对比。
///
/// ⚠️ Swift Charts 画不出来：它没有极坐标多轴的 mark。
public struct RadarChart<Value: ChartValue>: View {

    private let values: [Value]
    private let tint: Color
    private let title: LocalizedStringKey

    /// 轴数下限。⚠️ **少于 3 轴不成其为雷达图**（两轴退化成一条线段）。
    static var minimumAxes: Int { 3 }

    /// - Parameters:
    ///   - values: 各维度。`label` 作轴名、`value` 作长度。
    ///   - title: 图表标题。⚠️ **组件自带的 chrome 文案**，走 `LocalizedStringKey`（FR-7）；
    ///     而 `values` 里的 `label` 是**调用方的内容**，是 `String`。
    public init(
        _ values: [Value],
        title: LocalizedStringKey = "雷达图",
        tint: Color = .accent
    ) {
        self.values = values
        self.title = title
        self.tint = tint
    }

    public var body: some View {
        let raw = self.values.map(\.value)

        switch ChartDegeneracy.of(raw, minimumCount: Self.minimumAxes) {
        case .empty:
            ChartEmptyState(message: "暂无数据")
        case .singlePoint:
            // ⚠️ 不是错误，是"轴不够"。给出可操作的提示而非空白。
            ChartEmptyState(message: "雷达图至少需要 3 个维度")
        default:
            self.web(normalized: raw.normalizedSafely())
        }
    }

    // MARK: - Private

    @ViewBuilder
    private func web(normalized: [Double]) -> some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2 * 0.78
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let count = normalized.count

            ZStack {
                // 网格：4 圈同心多边形。⚠️ 用 `Color.dividerDefault` 而非硬编码灰。
                ForEach(1...4, id: \.self) { ring in
                    Self.polygon(
                        center: center, radius: radius * Double(ring) / 4, count: count
                    )
                    .stroke(Color.dividerDefault, lineWidth: CoreBorderWidth.hairline)
                }

                // 数据多边形。
                // ⚠️ `normalizedSafely` 在全等时返回 0.5 而不是 NaN——所有维度同分是常见输入。
                Self.polygon(
                    center: center, radius: radius, count: count, scales: normalized
                )
                .fill(self.tint.opacity(0.28))

                Self.polygon(
                    center: center, radius: radius, count: count, scales: normalized
                )
                .stroke(self.tint, lineWidth: CoreBorderWidth.thin)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(self.title)
        .accessibilityChartDescriptor(self)
    }

    /// 正多边形路径。`scales` 非空时逐顶点缩放（画数据形状）。
    private static func polygon(
        center: CGPoint, radius: Double, count: Int, scales: [Double]? = nil
    ) -> Path {
        Path { path in
            guard count >= minimumAxes else { return }
            for i in 0..<count {
                // 从正上方起，顺时针均分。
                let angle = -Double.pi / 2 + 2 * .pi * Double(i) / Double(count)
                let r = radius * (scales.map { $0[i] * 0.85 + 0.15 } ?? 1)
                let point = CGPoint(
                    x: center.x + cos(angle) * r,
                    y: center.y + sin(angle) * r
                )
                i == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Accessibility

extension RadarChart: AXChartDescriptorRepresentable {

    /// ⚠️ 走 `Accessibility` 框架的 `AXChartDescriptor`，**不需要 `import Charts`**
    /// （本 target 的硬约束之一；落地前已一次性验证，见 epic 的 A-3 checkpoint）。
    public func makeChartDescriptor() -> AXChartDescriptor {
        let raw = self.values.map(\.value)
        let low = raw.min() ?? 0
        let high = raw.max() ?? 1

        let axis = AXNumericDataAxisDescriptor(
            title: "维度",
            range: low...(high > low ? high : low + 1),
            gridlinePositions: []
        ) { "\($0.formatted())" }

        let category = AXCategoricalDataAxisDescriptor(
            title: "维度",
            categoryOrder: self.values.map(\.label)
        )

        let series = AXDataSeriesDescriptor(
            name: "",
            isContinuous: false,
            dataPoints: self.values.map {
                AXDataPoint(x: $0.label, y: $0.value)
            }
        )

        return AXChartDescriptor(
            title: nil,
            summary: nil,
            xAxis: category,
            yAxis: axis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - Preview

/// ⚠️ Preview 专用的最小实现。放在这里而不是测试里——`#Preview` 是本仓组件的
/// 主要视觉冒烟方式（CLAUDE.md）。
///
/// ⚠️ **必须 `nonisolated`** —— 本 target 设了 `defaultIsolation(MainActor)`，
/// 不标就拿不到满足 `Sendable` 的 `Identifiable` conformance。见 `ChartValue` 的文档。
private nonisolated struct Metric: ChartValue {
    let id = UUID()
    let label: String
    let value: Double
}

#Preview("RadarChart") {
    VStack(spacing: 24) {
        RadarChart([
            Metric(label: "速度", value: 82),
            Metric(label: "力量", value: 61),
            Metric(label: "耐力", value: 94),
            Metric(label: "技巧", value: 47),
            Metric(label: "智力", value: 73),
        ])
        .frame(height: 220)

        // 退化：全等值 —— 应画出正多边形而非 NaN
        RadarChart([
            Metric(label: "A", value: 50),
            Metric(label: "B", value: 50),
            Metric(label: "C", value: 50),
        ])
        .frame(height: 160)

        // 退化：轴不够
        RadarChart([Metric(label: "只有一个", value: 10)])
            .frame(height: 60)
    }
    .padding()
}
