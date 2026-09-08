import Accessibility
import OhMyDesign
import SwiftUI

/// 贡献热力图（GitHub 那种按周排列的日格）。
public struct ActivityHeatmap<Day: HeatmapDay>: View {
    private let days: [Day]
    private let tint: Color
    private let title: LocalizedStringResource
    private let calendar: Calendar

    /// - Parameter calendar: ⚠️ 显式接受而不是取 `.current`——一周从周日还是周一开始
    ///   **是 locale 决定的**，写死会让非美国用户看到错位的行。默认取 `.current`
    ///   是为了默认正确，但可注入才可测。
    public init(
        _ days: [Day],
        title: LocalizedStringResource? = nil,
        tint: Color = .dataAccent,
        calendar: Calendar = .current
    ) {
        self.days = days
        self.title = title ?? .chart("Activity heatmap")
        self.tint = tint
        self.calendar = calendar
    }

    public var body: some View {
        if self.days.isEmpty {
            ChartEmptyState(message: .chart("No data"))
        } else {
            self.grid
        }
    }

    // MARK: - Private

    private var grid: some View {
        let inputs = Self.renderInputs(self.days, calendar: self.calendar)
        let buckets = inputs.buckets
        let weeks = inputs.weeks

        return HStack(spacing: 3) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = week[weekday]
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(self.color(for: day, buckets: buckets))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }

    static func renderInputs(_ days: [Day], calendar: Calendar)
        -> (shown: [Day], buckets: [Int], weeks: [[Day?]]) {
        let shown = Self.effectiveDays(days, calendar: calendar)
        return (shown, Self.buckets(for: shown), Self.weeks(ofEffective: shown, calendar: calendar))
    }

    static func label(for date: Date, calendar: Calendar) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        if let locale = calendar.locale { style.locale = locale }
        return date.formatted(style)
    }

    static func effectiveDays(_ days: [Day], calendar: Calendar) -> [Day] {
        let sorted = days.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return [] }
        var seen = Set<Date>()
        let deduped = sorted.reversed()
            .filter { seen.insert(calendar.startOfDay(for: $0.date)).inserted }
            .reversed()
        let end = calendar.startOfDay(for: last.date)
        guard let floorDate = calendar.date(byAdding: .day, value: -(Self.maximumDays - 1), to: end)
        else { return Array(deduped) }
        return deduped.filter { calendar.startOfDay(for: $0.date) >= floorDate }
    }

    static func weeks(for days: [Day], calendar: Calendar) -> [[Day?]] {
        Self.weeks(ofEffective: Self.effectiveDays(days, calendar: calendar), calendar: calendar)
    }

    static func weeks(ofEffective sorted: [Day], calendar: Calendar) -> [[Day?]] {
        guard let first = sorted.first, let last = sorted.last else { return [] }

        var result: [[Day?]] = []
        var column = [Day?](repeating: nil, count: 7)
        let end = calendar.startOfDay(for: last.date)
        var cursor = calendar.startOfDay(for: first.date)
        var byDate = [Date: Day]()
        for d in sorted { byDate[calendar.startOfDay(for: d.date)] = d }

        var guardCounter = 0
        while cursor <= end {
            guardCounter += 1
            if guardCounter > Self.maximumDays + 14 { break }

            let weekday = (calendar.component(.weekday, from: cursor)
                           - calendar.firstWeekday + 7) % 7
            column[weekday] = byDate[cursor]
            if weekday == 6 {
                result.append(column)
                column = [Day?](repeating: nil, count: 7)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: next)
        }
        if column.contains(where: { $0 != nil }) { result.append(column) }
        return result
    }

    /// 单张热力图渲染的天数上限（≈ 5 年）；超出即静默截断最旧的一段，不提示调用方。
    public nonisolated static var maximumDays: Int { 1830 }

    static func buckets(for days: [Day]) -> [Int] {
        let peak = days.map(\.count).max() ?? 0
        guard peak > 0 else { return [] }
        return (1...4).map { peak / 4 * $0 + (peak % 4) * $0 / 4 }
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
        let shown = Self.effectiveDays(self.days, calendar: self.calendar)
        let peak = Double(shown.map(\.count).max() ?? 1)
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Count"), range: safeRange(0, peak), gridlinePositions: []
        ) { $0.formatted(.number.precision(.fractionLength(0))) }
        let dates = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Date"),
            categoryOrder: shown.map { Self.label(for: $0.date, calendar: self.calendar) }
        )
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: shown.map {
                AXDataPoint(
                    x: Self.label(for: $0.date, calendar: self.calendar),
                    y: Double($0.count)
                )
            }
        )
        return AXChartDescriptor(
            title: String(localized: self.title), summary: nil,
            xAxis: dates, yAxis: axis, additionalAxes: [], series: [series]
        )
    }
}

#Preview("ActivityHeatmap") {
    nonisolated struct Day: HeatmapDay {
        let id = UUID()
        let date: Date
        let count: Int
    }
    let start = Calendar.current.date(byAdding: .day, value: -120, to: .now)!
    let days = (0..<120).map { offset in
        Day(
            date: Calendar.current.date(byAdding: .day, value: offset, to: start)!,
            count: [0, 0, 1, 2, 3, 5, 8][offset % 7]
        )
    }
    return VStack(spacing: 24) {
        ActivityHeatmap(days).frame(height: 110)
        ActivityHeatmap(days.map { Day(date: $0.date, count: 0) }).frame(height: 110)
    }
    .padding()
}
