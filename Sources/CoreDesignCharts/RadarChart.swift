import Accessibility
import CoreDesign
import SwiftUI

/// 雷达图（蛛网图）。多维评分的形状对比。
public struct RadarChart<Value: ChartValue>: View {
    private let values: [Value]
    private let tint: Color
    private let title: LocalizedStringResource

    static var minimumAxes: Int { 3 }

    /// - Parameters:
    ///   - values: 各维度。`label` 作轴名、`value` 作长度。
    ///   - title: 图表标题。⚠️ **组件自带的 chrome 文案**，走 `LocalizedStringResource`（公约 §4 A 类 / #43-1）；
    ///     而 `values` 里的 `label` 是**调用方的内容**，是 `String`。
    public init(
        _ values: [Value],
        title: LocalizedStringResource? = nil,
        tint: Color = .accent
    ) {
        self.values = values
        self.title = title ?? .chart("Radar chart")
        self.tint = tint
    }

    public var body: some View {
        let raw = self.values.map(\.value)

        switch ChartDegeneracy.of(raw, minimumCount: Self.minimumAxes) {
        case .empty:
            ChartEmptyState(message: .chart("No data"))
        case .insufficientPoints:
            ChartEmptyState(message: .chart("A radar chart needs at least 3 dimensions"))
        case .nonFinite:
            ChartEmptyState(message: .chart("Data contains values that are not finite"))
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
                ForEach(1...4, id: \.self) { ring in
                    Self.polygon(
                        center: center, radius: radius * Double(ring) / 4, count: count
                    )
                    .stroke(Color.dividerDefault, lineWidth: CoreBorderWidth.hairline)
                }

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
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }

    private static func polygon(
        center: CGPoint, radius: Double, count: Int, scales: [Double]? = nil
    ) -> Path {
        Path { path in
            guard count >= minimumAxes else { return }
            for i in 0..<count {
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
    /// 交出 VoiceOver 的图表描述符——走 `Accessibility` 框架，不需要 `import Charts`。
    public func makeChartDescriptor() -> AXChartDescriptor {
        let raw = self.values.map(\.value).filter(\.isFinite)
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Value"),
            range: safeRange(raw.min() ?? 0, raw.max() ?? 1),
            gridlinePositions: []
        ) { "\($0.formatted())" }

        let category = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Dimension"),
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
            title: String(localized: self.title),
            summary: nil,
            xAxis: category,
            yAxis: axis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - Preview

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

        RadarChart([
            Metric(label: "A", value: 50),
            Metric(label: "B", value: 50),
            Metric(label: "C", value: 50),
        ])
        .frame(height: 160)

        RadarChart([Metric(label: "只有一个", value: 10)])
            .frame(height: 60)
    }
    .padding()
}
