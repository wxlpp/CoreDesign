//
//  ActivityHeatmap.swift
//  CoreDesignCharts
//

import Accessibility
import CoreDesign
import SwiftUI

/// 贡献热力图（GitHub 那种按周排列的日格）。
///
/// ⚠️ Swift Charts 画不出来：`RectangleMark` 能画格子，但**按周分列 + 按星期几分行 +
/// 日期对齐**是一套布局，不是一个 mark；且它没有"缺失日期留空"的概念。
public struct ActivityHeatmap: View {

    /// 一天的数据。
    ///
    /// ⚠️ `nonisolated` 的理由见 `ChartValue` 的文档（本 target 设了 `defaultIsolation`）。
    public nonisolated struct Day: Identifiable, Sendable {
        public let id: Date
        public let date: Date
        public let count: Int

        public init(date: Date, count: Int) {
            self.id = date
            self.date = date
            self.count = count
        }
    }

    private let days: [Day]
    private let tint: Color
    private let title: LocalizedStringKey
    private let calendar: Calendar

    /// - Parameter calendar: ⚠️ 显式接受而不是取 `.current`——一周从周日还是周一开始
    ///   **是 locale 决定的**，写死会让非美国用户看到错位的行。默认取 `.current`
    ///   是为了默认正确，但可注入才可测。
    public init(
        _ days: [Day],
        title: LocalizedStringKey = "活动热力图",
        tint: Color = .accent,
        calendar: Calendar = .current
    ) {
        self.days = days
        self.title = title
        self.tint = tint
        self.calendar = calendar
    }

    public var body: some View {
        if self.days.isEmpty {
            ChartEmptyState(message: "暂无数据")
        } else {
            self.grid
        }
    }

    // MARK: - Private

    private var grid: some View {
        let buckets = Self.buckets(for: self.days)
        let weeks = self.weeks

        return HStack(spacing: 3) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { weekday in
                        // ⚠️ 缺失的日期画**空槽**而不是跳过——跳过会让格子错位，
                        // 而热力图的信息量全在"位置对应日期"上。
                        let day = week[weekday]
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(self.color(for: day, buckets: buckets))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(self.title)
        .accessibilityChartDescriptor(self)
    }

    /// 按 ISO 周切成列，每列 7 个槽（缺失为 `nil`）。
    private var weeks: [[Day?]] {
        let sorted = self.days.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return [] }

        var result: [[Day?]] = []
        var column = [Day?](repeating: nil, count: 7)
        var cursor = self.calendar.startOfDay(for: first.date)
        let end = self.calendar.startOfDay(for: last.date)
        var byDate = [Date: Day]()
        for d in sorted { byDate[self.calendar.startOfDay(for: d.date)] = d }

        while cursor <= end {
            // `weekday` 是 1...7，减 1 归零；`firstWeekday` 让一周起点跟随 locale。
            let weekday = (self.calendar.component(.weekday, from: cursor)
                           - self.calendar.firstWeekday + 7) % 7
            column[weekday] = byDate[cursor]
            if weekday == 6 {
                result.append(column)
                column = [Day?](repeating: nil, count: 7)
            }
            guard let next = self.calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        if column.contains(where: { $0 != nil }) { result.append(column) }
        return result
    }

    /// 分档阈值。
    ///
    /// ⚠️ **全零时返回空数组**，`color(for:)` 据此把所有格子画成空槽——
    /// 而不是让 `max == 0` 去做除数（FR-19 的 `zeroTotal` 形态）。
    private static func buckets(for days: [Day]) -> [Int] {
        let peak = days.map(\.count).max() ?? 0
        guard peak > 0 else { return [] }
        return (1...4).map { Int((Double(peak) * Double($0) / 4).rounded(.up)) }
    }

    private func color(for day: Day?, buckets: [Int]) -> Color {
        guard let day, day.count > 0, !buckets.isEmpty else {
            return Color.tertiaryFill
        }
        let level = buckets.firstIndex { day.count <= $0 } ?? buckets.count - 1
        return self.tint.opacity(0.25 + Double(level) * 0.25)
    }
}

extension ActivityHeatmap: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor {
        let counts = self.days.map { Double($0.count) }
        let peak = counts.max() ?? 1
        let axis = AXNumericDataAxisDescriptor(
            title: "次数", range: 0...max(peak, 1), gridlinePositions: []
        ) { "\(Int($0))" }
        let dates = AXCategoricalDataAxisDescriptor(
            title: "日期",
            categoryOrder: self.days.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        )
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: self.days.map {
                AXDataPoint(
                    x: $0.date.formatted(date: .abbreviated, time: .omitted),
                    y: Double($0.count)
                )
            }
        )
        return AXChartDescriptor(
            title: nil, summary: nil,
            xAxis: dates, yAxis: axis, additionalAxes: [], series: [series]
        )
    }
}

#Preview("ActivityHeatmap") {
    let start = Calendar.current.date(byAdding: .day, value: -120, to: .now)!
    let days = (0..<120).map { offset in
        ActivityHeatmap.Day(
            date: Calendar.current.date(byAdding: .day, value: offset, to: start)!,
            count: [0, 0, 1, 2, 3, 5, 8][offset % 7]
        )
    }
    return VStack(spacing: 24) {
        ActivityHeatmap(days).frame(height: 110)
        // 退化：全零 —— 应全部画成空槽，不 NaN
        ActivityHeatmap(days.map { .init(date: $0.date, count: 0) }).frame(height: 110)
    }
    .padding()
}
