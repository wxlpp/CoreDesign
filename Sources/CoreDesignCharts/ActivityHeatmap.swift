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
        tint: Color = .accent,
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

    // ⚠️ **`weeks` / `buckets` 每次 body 求值重算，这是有意的**（第 2 轮终审 I-3）。
    // `NetworkGraph` 的布局挪去了后台，这里没有，理由是量级差两个数量级——
    // ⚠️ **上一版的实测口径已被第 3 轮的截断修复作废**（第 4 轮终审 I-6）：
    // `effectiveDays` 要对**调用方传入的全量**做一次 `sorted` + 两次 `startOfDay`
    // 全表扫描 ⇒ 成本随**输入天数**增长，而不是随 `maximumDays` 封顶。
    // 旧数「1830 天 = 8 ms」描述的不再是当前代码。
    // ⇒ 现口径：**输入 N 条时 O(N log N)**，`maximumDays` 只封住渲染侧的列数。
    // 喂 10 年（3653 条）时排序成本约为 1830 条的 2.2 倍。
    // ⇒ 8 ms 不值得为它引入 `@State` + 失效键的复杂度；**但这个数字必须在这里**，
    // 否则下一个人只能在「重算」与「缓存」之间凭感觉选。
    private var grid: some View {
        // ⚠️⚠️ **上一轮的 C-1 只修了一半**（第 4 轮终审 C-3）：descriptor 与 `weeks`
        // 都改走了 `effectiveDays`，**只有决定每个格子颜色的 `buckets` 留在原地**
        // ⇒ 10 年数据、峰值 50 出现在 8 年前时，可见窗口内每格都落最低档、
        // 整张图变成均匀最浅色、信息量归零，而 descriptor 的量程是 0...5
        // ⇒ 屏幕与播报又一次不同源。
        // ⇒ 算**一次**传给两边，顺带消掉 `weeks` 内的重复 sort。
        let inputs = Self.renderInputs(self.days, calendar: self.calendar)
        let buckets = inputs.buckets
        let weeks = inputs.weeks

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
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }

    /// 按周切成列，每列 7 个槽（缺失为 `nil`）。
    ///
    /// ⚠️ **提成 `static` 纯函数是为了可测**（终审 C-3）：初版它是 `private` 计算属性，
    /// 测试 target 即使 `@testable` 也够不到 ⇒ 整个分列逻辑零覆盖，
    /// 而下面那个 DST bug 就藏在里面。
    /// 渲染真正消费的三样东西，**一次算齐**。
    ///
    /// ⚠️ **抽出来是为了让测试能走组件自己的路径**（第 4 轮终审 C-3 的教训）：
    /// 上一版测试直接调 `buckets(for: 已收敛的数据)` ⇒ **绕过了组件**，
    /// 把源码退回 `self.days` 它照样绿——正是本 PR 反复被判的假绿形态。
    static func renderInputs(_ days: [Day], calendar: Calendar)
        -> (shown: [Day], buckets: [Int], weeks: [[Day?]]) {
        let shown = Self.effectiveDays(days, calendar: calendar)
        return (shown, Self.buckets(for: shown), Self.weeks(ofEffective: shown, calendar: calendar))
    }

    /// 渲染与 descriptor **共用**的有效数据：排序 → 去重（后者胜）→ 截断最近一段。
    ///
    /// ⚠️⚠️ **第 3 轮终审 C-1：这是第二轮 `RingChart` 那个 bug 的同形复发。**
    /// 上一轮我把 descriptor 从 `self.values` 改成 `effectiveValues` 时记账写的是
    /// 「`NetworkGraph` 在同一件事上是对的，两个兄弟组件走反了」——**那句话少数了
    /// 一个兄弟**。四个图表里有三个会截断，我只核对了两个。
    /// 后果一致：10 年数据时屏幕画 1830 天、**VoiceOver 播报 3653 个点**。
    static func effectiveDays(_ days: [Day], calendar: Calendar) -> [Day] {
        let sorted = days.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return [] }
        var seen = Set<Date>()
        // 后者胜：与 `weeks` 内 `byDate[...] = d` 的语义一致 ⇒ 反向去重再翻回来。
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

    /// 已经过 `effectiveDays` 收敛的数据 → 列。⚠️ 分成两个入口是为了让调用方
    /// **只算一次** `effectiveDays`（第 4 轮终审 C-3）。
    static func weeks(ofEffective sorted: [Day], calendar: Calendar) -> [[Day?]] {
        guard let first = sorted.first, let last = sorted.last else { return [] }

        var result: [[Day?]] = []
        var column = [Day?](repeating: nil, count: 7)
        // ⚠️ **截断保留最近的一段，不是最旧的**（第 2 轮终审 I-7）：贡献热力图的
        // 默认阅读方向是「最近」，上一版从最旧一天起步 + 到上限就 break ⇒ 有 10 年
        // 数据的用户看到的是**最早那五年**，最近的活动全部不显示。
        // 起点/终点已由 `effectiveDays` 收敛过，这里直接取两端。
        let end = calendar.startOfDay(for: last.date)
        var cursor = calendar.startOfDay(for: first.date)
        // ⚠️ **重复日期后者胜**，且这是有意的（终审 S-8）：调用方给同一天两条记录时
        // 静默取后一条，而不是相加——相加会让"重复"这个输入错误看起来像正常数据。
        var byDate = [Date: Day]()
        for d in sorted { byDate[calendar.startOfDay(for: d.date)] = d }

        var guardCounter = 0
        while cursor <= end {
            // ⚠️ **上限**（终审 S-7）：区间无上限时，两个相距百年的 `Day` 会产生
            // ~36500 次 `Calendar` 运算 + 5000 列视图，且**每次 body 求值重算一遍**。
            // 与 `NetworkGraph` 同一条 FR-20 原则：截断，不断言。
            guardCounter += 1
            // 起点已按上限前移，这里只是最后一道防线（日历异常导致游标不前进等）。
            if guardCounter > Self.maximumDays + 14 { break }

            // `weekday` 是 1...7，减 1 归零；`firstWeekday` 让一周起点跟随 locale。
            let weekday = (calendar.component(.weekday, from: cursor)
                           - calendar.firstWeekday + 7) % 7
            column[weekday] = byDate[cursor]
            if weekday == 6 {
                result.append(column)
                column = [Day?](repeating: nil, count: 7)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            // ⚠️⚠️ **`startOfDay` 这一层不能省**（终审 C-1，已实测复现）：
            // `byDate` 的键是 `startOfDay`，而 `date(byAdding: .day)` 在**午夜被跳过**
            // 的 DST 转换（智利 / 古巴 / 伊朗…）上会把 cursor 推到 01:00 并**永久漂移**，
            // 此后每次 `byDate[cursor]` 全部 miss。
            // 实测 `America/Santiago` + 2026-09-06 转换 + 14 天连续数据：
            // 落格 **6/14**，其余 8 天在网格里**静默消失**、无任何报错。
            cursor = calendar.startOfDay(for: next)
        }
        if column.contains(where: { $0 != nil }) { result.append(column) }
        return result
    }

    /// 单张热力图渲染的天数上限（≈ 5 年）。超出即**截断最旧的一段**（FR-20：截断不断言）。
    /// ⚠️ **截断对用户静默**。⚠️ 上一版这里写「与 `NetworkGraph` 一致」——
    /// 那句在同一个 commit 里就已失真（`NetworkGraph` 已加可见提示，第 3 轮终审 I-6）。
    /// 三个会截断的图表现在是三种行为，本轮**显式定案**：
    /// 只有 `NetworkGraph` 提示，因为它的截断会**改变布局算法**（力导向 → 静态环形），
    /// 用户看到的是一张"不一样的图"而不只是"少了几个"；
    /// 热力图与活动环的截断是**同质的**（少几天 / 少几环），且都发生在时间/指标序列的
    /// 一端，读图时可自明 ⇒ 由调用方按场景自行提示。
    /// ⚠️ 泛型类型不支持 static **存储**属性。
    public static var maximumDays: Int { 1830 }

    /// 分档阈值。
    ///
    /// ⚠️ **全零时返回空数组**，`color(for:)` 据此把所有格子画成空槽——
    /// 而不是让 `max == 0` 去做除数。
    /// ⚠️ 与 `weeks(for:calendar:)` 同理提为 `internal`，否则零覆盖。
    static func buckets(for days: [Day]) -> [Int] {
        let peak = days.map(\.count).max() ?? 0
        guard peak > 0 else { return [] }
        // ⚠️ 舍入语义**已从 `.up` 变为等价的整数下取整**（第 4 轮终审 S-2 指出
        // 上一版的 `.up → .down` 是一次没说明也没测试的视觉语义变更）：
        // 低计数格子整体深一档、`peak == 1` 时任何非零天从最浅变满色。
        // **这是定案**——新分档让峰值总能到满色，更接近 GitHub 的观感。
        // 下面 `bucketsPinsRounding` 钉住了具体取值表。
        // ⚠️⚠️ **上一版的 `min` 加在 `Int(_:)` 之后 ⇒ 越界 trap 照旧发生**
        //（第 4 轮终审 I-2 实测：`peak = Int.max - 1024` 起 SIGTRAP）。
        // `$0 == 4` 时 `Double(peak)` 舍入到 2⁶³ > `Int.max`。
        // ⇒ 改**纯整数运算**：无浮点、无 trap，且顺带定死舍入语义。
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
        // `count` 是 `Int`，天然有限；这里仍走 `safeRange` 是为了与另外三个图表同形。
        // ⚠️ 与渲染同源（第 3 轮终审 C-1）。
        let shown = Self.renderInputs(self.days, calendar: self.calendar).shown
        let peak = Double(shown.map(\.count).max() ?? 1)
        // ⚠️⚠️ **不要写成 `"\(Int($0))"`**——`Accessibility` 框架在构造描述符时会拿
        // **非有限的探针值**调用这个闭包，`Int(非有限)` 直接 trap。
        // 这不是理论：本 target 的空数据 descriptor 测试**当场崩给我看**
        // （`Fatal error: Double value cannot be converted to Int because it is
        // either infinite or NaN`），而在补这批 a11y 断言之前它一直是绿的。
        // ⇒ 走 `formatted`，既不 trap 也不会在大数上溢出。
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Count"), range: safeRange(0, peak), gridlinePositions: []
        ) { $0.formatted(.number.precision(.fractionLength(0))) }
        let dates = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Date"),
            categoryOrder: shown.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        )
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: shown.map {
                AXDataPoint(
                    x: $0.date.formatted(date: .abbreviated, time: .omitted),
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
    // ⚠️ Preview 自己造一个遵从 `HeatmapDay` 的类型——这正是泛型化后调用方的用法。
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
        // 退化：全零 —— 应全部画成空槽，不 NaN
        ActivityHeatmap(days.map { Day(date: $0.date, count: 0) }).frame(height: 110)
    }
    .padding()
}
