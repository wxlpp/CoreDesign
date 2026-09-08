import Accessibility
import Foundation
import Testing

@testable import OhMyDesignCharts

private nonisolated struct Point: ChartValue {
    var id: String = UUID().uuidString
    let label: String
    let value: Double
}

private nonisolated struct Day: HeatmapDay {
    let id = UUID()
    let date: Date
    let count: Int
}

private nonisolated struct Node: GraphNode {
    let id: String
    let label: String
}

private func points(_ values: [Double]) -> [Point] {
    values.enumerated().map { Point(label: "m\($0.offset)", value: $0.element) }
}

// MARK: - FR-19 第 1、2 类：四个图表各自的空数组与点数不足

@Suite("四个图表 · 空数组与点数不足")
struct PerChartDegenerateTests {
    @Test("RadarChart：空 / 1 点 / 2 点都不崩，且不画网")
    func radar() {
        #expect(ChartDegeneracy.of([], minimumCount: 3) == .empty)
        #expect(ChartDegeneracy.of([1], minimumCount: 3) == .insufficientPoints(needed: 3))
        #expect(ChartDegeneracy.of([1, 2], minimumCount: 3) == .insufficientPoints(needed: 3))
        #expect(RadarChart([Point]()).makeChartDescriptor()
            .series.first?.dataPoints.isEmpty == true)
        #expect(RadarChart(points([1])).makeChartDescriptor()
            .series.first?.dataPoints.count == 1)
    }

    @Test("RingChart：空数组走空态、描述符不崩")
    func ring() {
        #expect(RingChart([Point](), goal: 100).makeChartDescriptor()
            .series.first?.dataPoints.isEmpty == true)
        #expect(RingChart(points([1]), goal: 100).makeChartDescriptor()
            .series.first?.dataPoints.count == 1)
    }

    @Test("ActivityHeatmap：空数组 → 零列（不是崩，也不是一列空格）")
    func heatmap() {
        #expect(ActivityHeatmap<Day>.weeks(for: [], calendar: .current).isEmpty)
        let one = [Day(date: Date(), count: 3)]
        #expect(ActivityHeatmap<Day>.weeks(for: one, calendar: .current).count == 1)
        _ = ActivityHeatmap<Day>([]).makeChartDescriptor()
    }

    @Test("NetworkGraph：空 / 单节点")
    func graph() {
        #expect(NetworkGraph<Node>.layout(
            nodes: [], edges: [], size: .init(width: 100, height: 100), iterations: 30
        ).isEmpty)
        let one = NetworkGraph<Node>.layout(
            nodes: [Node(id: "a", label: "A")], edges: [],
            size: .init(width: 100, height: 100), iterations: 30
        )
        #expect(one.count == 1)
        #expect(one["a"]?.x.isFinite == true && one["a"]?.y.isFinite == true)
        _ = NetworkGraph<Node>(nodes: [], edges: []).makeChartDescriptor()
    }
}

// MARK: - FR-19 第 3–5 类：全等值 / 轴数不足 / 目标值退化

@Suite("退化数值：全等 / 零总和 / 非有限")
struct DegenerateValueTests {
    @Test("全等非零 → .flat；总和为 0 → .zeroTotal")
    func flatAndZero() {
        #expect(ChartDegeneracy.of([5, 5, 5]) == .flat)
        #expect(ChartDegeneracy.of([0, 0, 0]) == .zeroTotal)
    }

    @Test("非有限值单独成一类，不混进 .flat")
    func nonFinite() {
        #expect(ChartDegeneracy.of([1, .nan, 3]) == .nonFinite)
        #expect(ChartDegeneracy.of([1, .infinity]) == .nonFinite)
        #expect(ChartDegeneracy.of([-.infinity]) == .nonFinite)
    }

    @Test("RadarChart 全等轴值 / 非有限轴值：描述符不 trap")
    func radarRangeIsSafe() {
        _ = RadarChart(points([7, 7, 7])).makeChartDescriptor()
        _ = RadarChart(points([.nan, 1, 2])).makeChartDescriptor()
        _ = RadarChart(points([.infinity, .nan])).makeChartDescriptor()
    }

    @Test("RingChart goal 为 0 / 负 / NaN / ∞：描述符不 trap")
    func ringGoalIsSafe() {
        for goal in [0.0, -5, .nan, .infinity] {
            _ = RingChart(points([1, 2]), goal: goal).makeChartDescriptor()
        }
    }

    @Test("safeRange 永远产出合法区间")
    func safeRangeAlwaysValid() {
        for (lo, hi) in [(0.0, 0.0), (5.0, 1.0), (.nan, 1.0), (0.0, .nan), (.infinity, .nan)] {
            let r = safeRange(lo, hi)
            #expect(r.lowerBound.isFinite && r.upperBound.isFinite)
            #expect(r.lowerBound < r.upperBound)
        }
    }

    @Test("safeRange 在大量级上仍严格递增（+1 被舍入吃掉）")
    func safeRangeStillIncreasesAtLargeMagnitudes() {
        let twoPow53 = 9_007_199_254_740_992.0
        #expect(twoPow53 + 1 == twoPow53, "前提失效：该量级上 +1 应当被舍掉")
        let cases: [(Double, Double)] = [
            (twoPow53, .nan), (twoPow53, twoPow53), (twoPow53, .infinity),
            (-twoPow53, .nan), (1e300, .nan),
            (.greatestFiniteMagnitude, .nan),
            (.greatestFiniteMagnitude, .greatestFiniteMagnitude),
            (.greatestFiniteMagnitude, -.infinity)
        ]
        for (lo, hi) in cases {
            let r = safeRange(lo, hi)
            #expect(r.lowerBound.isFinite && r.upperBound.isFinite,
                    "端点非有限：\(r) —— 输入 (\(lo), \(hi))")
            #expect(r.lowerBound < r.upperBound,
                    "零宽区间：\(r) —— 输入 (\(lo), \(hi))")
        }
    }

    @Test("safeRange 常规量级取值不变")
    func safeRangeKeepsOrdinarySpans() {
        #expect(safeRange(0, .nan) == 0...1)
        #expect(safeRange(5, 1) == 5...6)
        #expect(safeRange(.nan, 1) == 0...1)
        #expect(safeRange(2, 9) == 2...9)
    }
}

// MARK: - 安全归一化

@Suite("安全归一化 —— 输出恒为 [0,1] 内的有限值")
struct NormalizationTests {
    @Test("全等值返回 0.5 而不是 NaN")
    func flatIsNotNaN() {
        #expect([7.0, 7.0, 7.0].normalizedSafely() == [0.5, 0.5, 0.5])
    }

    @Test("空数组返回空")
    func emptyIsEmpty() { #expect([Double]().normalizedSafely().isEmpty) }

    @Test("正常区间映射到端点")
    func spansFullRange() {
        let out = [10.0, 20.0, 30.0].normalizedSafely()
        #expect(out.first == 0 && out.last == 1)
    }

    @Test("非有限输入不产生 NaN，且不参与跨度计算")
    func nonFiniteIsClamped() {
        for input in [[1.0, .infinity], [1.0, .nan, 3.0], [-.infinity, 0.0, .infinity],
                      [.nan, .nan], [-5.0, .nan, 5.0]] {
            let out = input.normalizedSafely()
            #expect(out.count == input.count)
            #expect(out.allSatisfy { $0.isFinite && (0...1).contains($0) },
                    "输入 \(input) 产出 \(out)")
        }
        #expect([-.infinity, 0.0, .infinity].normalizedSafely() == [0, 0.5, 1])
    }
}

// MARK: - FR-19 第 6、7 类：热力图的日期退化

@Suite("ActivityHeatmap · 日期与分档")
struct HeatmapTests {
    private func day(_ iso: String, _ count: Int, _ cal: Calendar) -> Day {
        var c = DateComponents()
        let p = iso.split(separator: "-").map { Int($0)! }
        (c.year, c.month, c.day, c.hour) = (p[0], p[1], p[2], 12)
        return .init(date: cal.date(from: c)!, count: count)
    }

    private func calendar(_ tz: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    @Test("跨 DST（America/Santiago，午夜被跳过）不丢任何一天")
    func dstDoesNotDropDays() {
        let cal = self.calendar("America/Santiago")
        let days = (1...14).map { self.day("2026-09-\($0)", $0, cal) }
        let placed = ActivityHeatmap<Day>.weeks(for: days, calendar: cal)
            .flatMap { $0 }.compactMap { $0 }.count
        #expect(placed == days.count, "跨 DST 丢了 \(days.count - placed) 天")
    }

    @Test("UTC 下同样不丢（对照组，证明上面那条测的是 DST 不是别的）")
    func utcControlGroup() {
        let cal = self.calendar("UTC")
        let days = (1...14).map { self.day("2026-09-\($0)", $0, cal) }
        let placed = ActivityHeatmap<Day>.weeks(for: days, calendar: cal)
            .flatMap { $0 }.compactMap { $0 }.count
        #expect(placed == days.count)
    }

    @Test("缺失日期渲染空槽而不是错位")
    func gapsBecomeEmptySlots() {
        let cal = self.calendar("UTC")
        let days = [self.day("2026-03-01", 1, cal), self.day("2026-03-10", 2, cal)]
        let weeks = ActivityHeatmap<Day>.weeks(for: days, calendar: cal)
        #expect(weeks.flatMap { $0 }.compactMap { $0 }.count == 2)
        #expect(weeks.count >= 2)
    }

    @Test("全零值 → 空分档（不拿 max == 0 当除数）")
    func allZeroBuckets() {
        let cal = self.calendar("UTC")
        let days = (1...5).map { self.day("2026-03-0\($0)", 0, cal) }
        #expect(ActivityHeatmap<Day>.buckets(for: days).isEmpty)
        #expect(ActivityHeatmap<Day>.buckets(for: []).isEmpty)
    }

    @Test("正常数据分 4 档，单调递增")
    func bucketsAreMonotonic() {
        let cal = self.calendar("UTC")
        let days = (1...4).map { self.day("2026-03-0\($0)", $0 * 3, cal) }
        let b = ActivityHeatmap<Day>.buckets(for: days)
        #expect(b.count == 4)
        #expect(b == b.sorted())
    }

    @Test("超长区间截断到 maximumDays，不无限循环")
    func rangeIsCapped() {
        let cal = self.calendar("UTC")
        let days = [self.day("1990-01-01", 1, cal), self.day("2090-01-01", 2, cal)]
        let weeks = ActivityHeatmap<Day>.weeks(for: days, calendar: cal)
        #expect(weeks.count <= ActivityHeatmap<Day>.maximumDays / 7 + 2)
    }
}

// MARK: - FR-19 第 8、9 类 + FR-20：力导向布局

@Suite("NetworkGraph 力导向布局")
struct NetworkGraphLayoutTests {
    private func nodes(_ n: Int) -> [Node] {
        (0..<n).map { .init(id: "n\($0)", label: "L\($0)") }
    }

    @Test("零边 + 多节点：坐标全部有限")
    func zeroEdges() {
        let l = NetworkGraph<Node>.layout(
            nodes: self.nodes(12), edges: [], size: .init(width: 300, height: 300), iterations: 60
        )
        #expect(l.count == 12)
        #expect(l.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("极小容器（钳位坍缩）—— 曾让所有节点落到容器外的同一点")
    func tinyContainerDoesNotCollapseOutside() {
        for side in [0.0, 1, 4, 7.9] {
            let size = CGSize(width: side, height: side)
            let l = NetworkGraph<Node>.layout(
                nodes: self.nodes(4), edges: [], size: size, iterations: 20
            )
            #expect(l.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            let w = max(size.width, 1), h = max(size.height, 1)
            #expect(l.values.allSatisfy { (0...w).contains($0.x) && (0...h).contains($0.y) },
                    "side=\(side) 时节点落到容器外：\(l.values.map { ($0.x, $0.y) })")
        }
    }

    @Test("size 含 NaN / ∞ 不产生 NaN 坐标")
    func nonFiniteSize() {
        let inf = Double.infinity, nan = Double.nan
        for size in [CGSize(width: nan, height: 100), CGSize(width: inf, height: inf),
                     CGSize(width: 100, height: nan)] {
            let l = NetworkGraph<Node>.layout(
                nodes: self.nodes(4), edges: [], size: size, iterations: 20
            )
            #expect(l.values.allSatisfy { $0.x.isFinite && $0.y.isFinite }, "size=\(size)")
        }
    }

    @Test("重复 node id 去重（保留首次出现），不静默丢节点")
    func duplicateIDs() {
        let dup: [Node] = [
            Node(id: "a", label: "first"), Node(id: "a", label: "second"),
            Node(id: "b", label: "B"),
        ]
        let l = NetworkGraph<Node>.layout(
            nodes: dup, edges: [], size: .init(width: 200, height: 200), iterations: 20
        )
        #expect(l.count == 2)
        #expect(l["a"] != nil && l["b"] != nil)
    }

    @Test("自环 / 悬空边不产生 NaN")
    func degenerateEdges() {
        for edges: [GraphEdge<String>] in [[.init(from: "n0", to: "n0")],
                                           [.init(from: "n0", to: "missing")]] {
            let l = NetworkGraph<Node>.layout(
                nodes: self.nodes(3), edges: edges,
                size: .init(width: 200, height: 200), iterations: 40
            )
            #expect(l.count == 3)
            #expect(l.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        }
    }

    @Test("坐标留在容器内")
    func staysInBounds() {
        let size = CGSize(width: 200, height: 140)
        let l = NetworkGraph<Node>.layout(
            nodes: self.nodes(20),
            edges: (0..<25).map { .init(from: "n\($0 % 20)", to: "n\(($0 * 7 + 1) % 20)") },
            size: size, iterations: 80
        )
        #expect(l.values.allSatisfy {
            (0...size.width).contains($0.x) && (0...size.height).contains($0.y)
        })
    }

    @Test("超限：descriptor 只播报截断后的节点数")
    func overLimitTruncates() {
        let n = NetworkGraph<Node>.recommendedNodeLimit + 50
        let d = NetworkGraph(nodes: self.nodes(n), edges: []).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == NetworkGraph<Node>.recommendedNodeLimit)
        let category = d.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(category?.categoryOrder.count == NetworkGraph<Node>.recommendedNodeLimit)
    }

    @Test("未超限时 layout 全量返回（与上一条互为对照）")
    func underLimitKeepsAll() {
        let l = NetworkGraph<Node>.layout(
            nodes: self.nodes(20), edges: [], size: .init(width: 300, height: 300), iterations: 0
        )
        #expect(l.count == 20)
        #expect(l.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("全区间的运算量有确定性上界（含最坏边数）")
    func pairwiseWorkIsBounded() {
        let budget = 450_000
        for n in 1...NetworkGraph<Node>.recommendedNodeLimit {
            let iter = NetworkGraph<Node>.iterations(for: n)
            let worstEdges = NetworkGraph<Node>.recommendedEdgeLimit
            let work = (n * n / 2 + worstEdges) * iter
            #expect(work <= budget, "n=\(n) 的运算量 \(work) 超出预算 \(budget)")
        }
    }

    @Test("布局确定性：同输入两次结果相同")
    func deterministic() {
        let n = self.nodes(8)
        let e = (0..<10).map { GraphEdge(from: "n\($0 % 8)", to: "n\(($0 * 3) % 8)") }
        let size = CGSize(width: 250, height: 250)
        let a = NetworkGraph<Node>.layout(nodes: n, edges: e, size: size, iterations: 40)
        let b = NetworkGraph<Node>.layout(nodes: n, edges: e, size: size, iterations: 40)
        #expect(a.keys.allSatisfy { a[$0] == b[$0] })
    }
}

// MARK: - US-4：四个图表的 accessibility 表示

@Suite("US-4 · 四个图表的 AXChartDescriptor 内容")
struct AccessibilityDescriptorTests {
    @Test("RadarChart：类目轴与数据点对得上标签")
    func radar() {
        let values = points([3, 1, 4, 1, 5])
        let d = RadarChart(values).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == values.count)
        let category = d.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(category?.categoryOrder == values.map(\.label))
        #expect(d.title?.isEmpty == false)
    }

    @Test("RingChart：数据点数 = 环数")
    func ring() {
        let values = points([420, 28, 9])
        let d = RingChart(values, goal: 500).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == values.count)
        #expect(d.title?.isEmpty == false)
    }

    @Test("RingChart：数值轴把 goal 读成 100%（既不是 1% 也不是 10000%）")
    func ringAxisReadsPercent() throws {
        let goal = 500.0
        let d = RingChart(points([420]), goal: goal).makeChartDescriptor()
        let describe = try #require(d.yAxis).valueDescriptionProvider
        #expect(describe(goal) == (1.0).formatted(.percent))
        #expect(describe(goal / 2) == (0.5).formatted(.percent))
        #expect(describe(0) == (0.0).formatted(.percent))
    }

    @Test("ActivityHeatmap：每天一个数据点")
    func heatmap() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let days = (1...9).map {
            Day(
                date: cal.date(from: DateComponents(year: 2026, month: 3, day: $0, hour: 12))!,
                count: $0
            )
        }
        let d = ActivityHeatmap(days).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == days.count)
        #expect(d.title?.isEmpty == false)
    }

    @Test("NetworkGraph：每个节点一个数据点，超限后按截断后的数量")
    func graph() {
        let nodes = (0..<5).map { Node(id: "n\($0)", label: "L\($0)") }
        let d = NetworkGraph(nodes: nodes, edges: [.init(from: "n0", to: "n1")])
            .makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == nodes.count)
        #expect(d.title?.isEmpty == false)
    }

    @Test("空数据下四个描述符都不 trap，且数据点为 0")
    func emptyDescriptorsAreSafe() {
        #expect(RadarChart([Point]()).makeChartDescriptor()
            .series.first?.dataPoints.isEmpty == true)
        #expect(RingChart([Point](), goal: 1).makeChartDescriptor()
            .series.first?.dataPoints.isEmpty == true)
        #expect(ActivityHeatmap<Day>([]).makeChartDescriptor()
            .series.first?.dataPoints.isEmpty == true)
        #expect(NetworkGraph<Node>(nodes: [], edges: []).makeChartDescriptor()
            .series.first?.dataPoints.isEmpty == true)
    }
}

// MARK: - FR-19 第 5 类 + FR-20：RingChart 的截断与零总和

@Suite("RingChart · 截断与零总和")
struct RingChartTruncationTests {
    private func values(_ n: Int, all zero: Bool = false) -> [Point] {
        (0..<n).map { Point(label: "m\($0)", value: zero ? 0 : Double($0 + 1)) }
    }

    @Test("超限：descriptor 与渲染看到的是同一批指标")
    func descriptorMatchesRendering() {
        let limit = RingChart<Point>.recommendedRingLimit
        let d = RingChart(self.values(20), goal: 100).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == limit)
        let category = d.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(category?.categoryOrder.count == limit)
    }

    @Test("全零 values（零总和）：不 trap，进度全为 0")
    func zeroTotalValues() {
        let d = RingChart(self.values(3, all: true), goal: 100).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == 3)
        let ys = d.series.first?.dataPoints.map { String(describing: $0.yValue) } ?? []
        #expect(ys.count == 3)
        #expect(ys.allSatisfy { $0.contains("0") && !$0.contains("1") }, "\(ys)")
    }

    @Test("单点：descriptor 有且只有一个数据点")
    func singleValue() {
        let d = RingChart(self.values(1), goal: 100).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == 1)
    }

    @Test("重复 id 去重（保留首次出现）")
    func duplicateIDs() {
        let dup = [Point(id: "a", label: "first", value: 1),
                   Point(id: "a", label: "second", value: 2),
                   Point(id: "b", label: "B", value: 3)]
        let d = RingChart(dup, goal: 10).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == 2)
    }

    @Test("超额 / 负值：descriptor 的 y 夹在 0...goal（与画面一致）")
    func descriptorClampsToGoal() throws {
        let goal = 500.0
        let d = RingChart([Point(label: "over", value: 750),
                           Point(label: "under", value: -100),
                           Point(label: "exact", value: goal),
                           Point(label: "inside", value: 123)], goal: goal)
            .makeChartDescriptor()
        let ys = try #require(d.series.first?.dataPoints).map { $0.yValue?.__number }
        #expect(ys == [goal, 0, goal, 123], "descriptor 播报的是未夹取的原始值：\(ys)")
    }

    @Test("非有限值：+∞ 读满环，-∞ 与 NaN 读 0（与渲染的短路一致）")
    func descriptorClampsNonFiniteValues() throws {
        let goal = 500.0
        let d = RingChart([Point(label: "inf", value: .infinity),
                           Point(label: "-inf", value: -.infinity),
                           Point(label: "nan", value: .nan)], goal: goal)
            .makeChartDescriptor()
        let ys = try #require(d.series.first?.dataPoints).map { $0.yValue?.__number }
        #expect(ys == [goal, 0, 0], "非有限值透进了 descriptor：\(ys)")
    }

    @Test("去重 + 截断的取值与顺序（重复项插在中间，超限）")
    func dedupeThenTruncateKeepsOrder() {
        let limit = RingChart<Point>.recommendedRingLimit
        let dup = (0..<20).flatMap { i in
            [Point(id: "m\(i)", label: "m\(i)-first", value: Double(i)),
             Point(id: "m\(i)", label: "m\(i)-second", value: Double(i))]
        }
        let d = RingChart(dup, goal: 100).makeChartDescriptor()
        let category = d.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(category?.categoryOrder == (0..<limit).map { "m\($0)-first" })
    }
}

// MARK: - 本地化通路

@Suite("Bundle.module 本地化通路")
@MainActor
struct LocalizationPathTests {
    @Test("哨兵条目查得到，且不是回退到 key")
    func bundleResolves() {
        let resolved = chartAXString("__localization_probe__")
        #expect(resolved == "resource-bundle-resolved")
        #expect(resolved != "__localization_probe__", "回退到了 key —— 资源没进 bundle")
    }

    @Test("chrome 文案走的 .atURL 通路同样命中")
    func localizedStringResourcePathResolves() {
        #expect(String(localized: .chart("__localization_probe__")) == "resource-bundle-resolved")
        #expect(String(localized: .chart("No data")) == "No data")
    }

    @Test("真实文案也走同一条通路")
    func realStringsResolve() {
        #expect(chartAXString("Connections") == "Connections")
        #expect(!chartAXString("Node").isEmpty)
    }

    @Test("两条超限横幅都在表里（哨兵 value 判定命中），且译文保留 %lld 占位符")
    func truncationBannersAreRegistered() {
        for key in ["Showing the first %lld nodes", "Showing the first %lld connections"] {
            let resolved = Bundle.module.localizedString(
                forKey: key, value: "@@MISS@@", table: nil
            )
            #expect(resolved != "@@MISS@@", "`\(key)` 不在 Localizable.strings 里")
            #expect(resolved.contains("%lld"), "`\(key)` 的译文丢了 %lld —— 数字显示不出来")
        }
    }
}

// MARK: - 第 3 轮终审补的覆盖

@Suite("NetworkGraph 度数（正向）")
struct GraphDegreeTests {
    @Test("度数确实被算出来，且是无向计数")
    func degreeIsComputed() {
        let nodes = ["n0", "n1", "n2"].map { Node(id: $0, label: "L") }
        let d = NetworkGraph(nodes: nodes,
                             edges: [GraphEdge(from: "n0", to: "n1"),
                                     GraphEdge(from: "n0", to: "n2")]).makeChartDescriptor()
        let ys = d.series.first?.dataPoints.compactMap {
            Double(String(describing: $0.yValue).filter { "0123456789.".contains($0) })
        } ?? []
        #expect(ys == [2, 1, 1], "度数算错或根本没算：\(ys)")
    }

    @Test("重复边与反向边只计一次")
    func duplicateAndReverseEdgesCountOnce() {
        let nodes = ["a", "b"].map { Node(id: $0, label: "L") }
        let many = Array(repeating: GraphEdge(from: "a", to: "b"), count: 30)
            + [GraphEdge(from: "b", to: "a")]
        let d = NetworkGraph(nodes: nodes, edges: many).makeChartDescriptor()
        let ys = d.series.first?.dataPoints.compactMap {
            Double(String(describing: $0.yValue).filter { "0123456789.".contains($0) })
        } ?? []
        #expect(ys == [1, 1], "31 条重合边被算成了 \(ys)——屏幕上只画得出 1 条")
    }

    @Test("重复边不触发假截断")
    func duplicateEdgesDoNotFakeTruncation() {
        let nodes = ["a", "b"].map { Node(id: $0, label: "L") }
        let many = Array(repeating: GraphEdge(from: "a", to: "b"),
                         count: NetworkGraph<Node>.recommendedEdgeLimit + 1)
        let g = NetworkGraph(nodes: nodes, edges: many)
        #expect(g.layoutKey(for: .init(width: 300, height: 300)).iterations > 0,
                "唯一边只有 1 条，却被判为超限、力导向被关掉")
    }
}

@Suite("截断在三个组件间一致（渲染 == descriptor）")
struct TruncationConsistencyTests {
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    private func days(_ n: Int) -> [Day] {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        return (0..<n).map { Day(date: start.addingTimeInterval(Double($0) * 86400), count: $0 % 9) }
    }

    @Test("ActivityHeatmap：descriptor 只播报截断后的天数")
    func heatmapDescriptorMatchesRendering() {
        let limit = ActivityHeatmap<Day>.maximumDays
        let d = ActivityHeatmap(self.days(limit + 400), calendar: Self.utc).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == limit)
    }

    @Test("NetworkGraph：度数只算两端都可见的边")
    func graphDegreeSkipsDroppedNodes() {
        let limit = NetworkGraph<Node>.recommendedNodeLimit
        let nodes = (0..<(limit + 50)).map { Node(id: "n\($0)", label: "L") }
        let tailEdges = (0..<100).map {
            GraphEdge(from: "n\(limit + ($0 % 50))", to: "n0")
        }
        let d = NetworkGraph(nodes: nodes, edges: tailEdges).makeChartDescriptor()
        let ys = d.series.first?.dataPoints.compactMap {
            Double(String(describing: $0.yValue).filter { "0123456789.".contains($0) })
        } ?? []
        #expect(ys.count == limit, "数据点数不是截断后的节点数")
        #expect(ys.allSatisfy { $0 == 0 },
                "被丢弃节点的度数被算进了可见节点：\(ys.filter { $0 != 0 }.prefix(5))")
    }

    @Test("NetworkGraph：度数按截断后的边算")
    func graphDegreeUsesTruncatedEdges() {
        let nodes = (0..<20).map { Node(id: "n\($0)", label: "L") }
        let many = (0..<(NetworkGraph<Node>.recommendedEdgeLimit + 400))
            .map { GraphEdge(from: "n\($0 % 20)", to: "n\(($0 * 7) % 20)") }
        let d = NetworkGraph(nodes: nodes, edges: many).makeChartDescriptor()
        let ys = d.series.first?.dataPoints.compactMap {
            Double(String(describing: $0.yValue).filter { "0123456789.".contains($0) })
        } ?? []
        #expect(!ys.isEmpty)
        let total = ys.reduce(0, +)
        #expect(total <= Double(NetworkGraph<Node>.recommendedEdgeLimit) * 2,
                "度数总和 \(total) 超过截断后边数的两倍 —— descriptor 用了全量边")
    }

    @Test("ActivityHeatmap：分档按截断后的窗口算")
    func heatmapBucketsUseEffectiveWindow() {
        let old = [Day(date: Date(timeIntervalSinceReferenceDate: 0), count: 500)]
        let recent = (1...10).map {
            Day(date: Date(timeIntervalSinceReferenceDate: Double(ActivityHeatmap<Day>.maximumDays + $0) * 86400),
                count: 5)
        }
        let buckets = ActivityHeatmap<Day>.renderInputs(old + recent, calendar: Self.utc).buckets
        #expect(buckets.last == 5, "分档上界是 \(String(describing: buckets.last)) —— 用了窗口外的峰值 500")
    }

    @Test("重复 id 不触发假截断")
    func duplicateIDsDoNotFakeTruncation() {
        let dup = (0..<200).map { _ in Node(id: "same", label: "L") }
        let g = NetworkGraph(nodes: dup, edges: [])
        #expect(g.layoutKey(for: .init(width: 300, height: 300)).iterations > 0,
                "200 个节点但只有 1 个不同 id 的图被误判为超限、力导向被关掉")
    }

    @Test("buckets 对 Int.max 不 trap")
    func bucketsSurviveIntMax() {
        let b = ActivityHeatmap<Day>.buckets(for: [Day(date: Date(), count: .max)])
        #expect(b.count == 4)
        #expect(b.last == Int.max)
    }

    @Test("分档取值表（舍入语义已定案）")
    func bucketsPinsRounding() {
        func b(_ peak: Int) -> [Int] {
            ActivityHeatmap<Day>.buckets(for: [Day(date: Date(), count: peak)])
        }
        #expect(b(1) == [0, 0, 0, 1])
        #expect(b(2) == [0, 1, 1, 2])
        #expect(b(3) == [0, 1, 2, 3])
        #expect(b(10) == [2, 5, 7, 10])
    }

    @Test("ActivityHeatmap：截断保留的是**最近**一段")
    func heatmapKeepsRecent() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let all = self.days(ActivityHeatmap<Day>.maximumDays + 100)
        let kept = ActivityHeatmap<Day>.effectiveDays(all, calendar: cal)
        #expect(kept.last?.date == all.last?.date, "丢掉的是最近的一段")
        #expect(kept.first?.date != all.first?.date, "没有截断")
    }

    @Test("NetworkGraph：重复 id 在组件层就去重（不只在 layout 内部）")
    func graphDedupesAtComponentLevel() {
        let dup = [Node(id: "a", label: "first"), Node(id: "a", label: "second"),
                   Node(id: "b", label: "B")]
        let d = NetworkGraph(nodes: dup, edges: []).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == 2)
        let category = d.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(category?.categoryOrder.count == 2)
    }

    @Test("FR-20 降级：超限时 iterations 归零，且 key 随节点数变化")
    func truncationDegradesToStaticLayout() {
        let size = CGSize(width: 300, height: 300)
        let under = NetworkGraph(nodes: (0..<20).map { Node(id: "n\($0)", label: "L") }, edges: [])
        let over = NetworkGraph(
            nodes: (0..<(NetworkGraph<Node>.recommendedNodeLimit + 50))
                .map { Node(id: "n\($0)", label: "L") },
            edges: []
        )
        #expect(under.layoutKey(for: size).iterations > 0)
        #expect(over.layoutKey(for: size).iterations == 0, "超限没有降级为静态布局")
        #expect(under.layoutKey(for: size) != over.layoutKey(for: size))
    }

    @Test("边数超限也触发降级（用真正互异的边）")
    func edgeLimitTriggersDegradation() {
        let n = 40
        let nodes = (0..<n).map { Node(id: "n\($0)", label: "L") }
        var edges: [GraphEdge<String>] = []
        outer: for i in 0..<n {
            for j in (i + 1)..<n {
                edges.append(GraphEdge(from: "n\(i)", to: "n\(j)"))
                if edges.count > NetworkGraph<Node>.recommendedEdgeLimit { break outer }
            }
        }
        #expect(edges.count == NetworkGraph<Node>.recommendedEdgeLimit + 1)
        let g = NetworkGraph(nodes: nodes, edges: edges)
        #expect(g.layoutKey(for: .init(width: 300, height: 300)).iterations == 0)
    }
}

// MARK: - 截断路径的行为锁（PR #263 Copilot 第 4 轮 S-1 ~ S-5）

@Suite("截断路径：去重 + 截断的取值、顺序与边界")
struct TruncationPathTests {
    private static let size = CGSize(width: 300, height: 300)

    @Test("节点：保留首次出现的前 N 个唯一 id，顺序不变")
    func nodesKeepFirstUniqueInOrder() {
        let limit = NetworkGraph<Node>.recommendedNodeLimit
        let dup = (0..<(limit + 50)).flatMap {
            [Node(id: "n\($0)", label: "first"), Node(id: "n\($0)", label: "second")]
        }
        let ids = NetworkGraph(nodes: dup, edges: []).layoutKey(for: Self.size).ids
        #expect(ids == (0..<limit).map { "n\($0)" })
    }

    @Test("节点：恰好 N 个唯一 id 不触发截断，N + 1 触发")
    func nodeLimitBoundary() {
        let limit = NetworkGraph<Node>.recommendedNodeLimit
        func graph(_ n: Int) -> NetworkGraph<Node> {
            NetworkGraph(nodes: (0..<n).map { Node(id: "n\($0)", label: "L") }, edges: [])
        }
        #expect(graph(limit).layoutKey(for: Self.size).iterations > 0, "恰好 N 被误判为超限")
        #expect(graph(limit + 1).layoutKey(for: Self.size).iterations == 0)
    }

    @Test("边：保留首次出现的前 N 条唯一无向边，顺序不变")
    func edgesKeepFirstUniqueInOrder() {
        let limit = NetworkGraph<Node>.recommendedEdgeLimit
        let unique = Self.distinctEdges(count: limit + 20)
        let dup = unique.flatMap { [$0, GraphEdge(from: $0.to, to: $0.from)] }
        let nodes = Set(unique.flatMap { [$0.from, $0.to] }).sorted().map { Node(id: $0, label: "L") }
        let kept = NetworkGraph(nodes: nodes, edges: dup).layoutKey(for: Self.size).edges
        #expect(kept == Array(unique.prefix(limit)))
    }

    @Test("边：恰好 N 条唯一边不触发截断，N + 1 触发")
    func edgeLimitBoundary() {
        let limit = NetworkGraph<Node>.recommendedEdgeLimit
        func graph(_ n: Int) -> NetworkGraph<Node> {
            let edges = Self.distinctEdges(count: n)
            let ids = Set(edges.flatMap { [$0.from, $0.to] }).sorted()
            return NetworkGraph(nodes: ids.map { Node(id: $0, label: "L") }, edges: edges)
        }
        #expect(graph(limit).layoutKey(for: Self.size).iterations > 0, "恰好 N 被误判为超限")
        #expect(graph(limit + 1).layoutKey(for: Self.size).iterations == 0)
    }

    private static func distinctEdges(count: Int) -> [GraphEdge<String>] {
        var edges: [GraphEdge<String>] = []
        outer: for i in 0..<40 {
            for j in (i + 1)..<40 {
                edges.append(GraphEdge(from: "n\(i)", to: "n\(j)"))
                if edges.count == count { break outer }
            }
        }
        return edges
    }
}

// MARK: - 边的口径：只算两端都可见的边（PR #263 Copilot 第 5 轮）

@Suite("边只算两端都可见的（渲染 / 截断 / 度数同口径）")
struct VisibleEdgeScopeTests {
    private static let size = CGSize(width: 300, height: 300)

    @Test("指向缺失节点的边不触发假截断")
    func edgesToMissingNodesDoNotFakeTruncation() {
        let nodes = ["a", "b"].map { Node(id: $0, label: "L") }
        let real = GraphEdge(from: "a", to: "b")
        let ghosts = (0..<(NetworkGraph<Node>.recommendedEdgeLimit + 50)).map {
            GraphEdge(from: "ghost\($0)", to: "ghost\($0 + 1)")
        }
        let key = NetworkGraph(nodes: nodes, edges: [real] + ghosts).layoutKey(for: Self.size)
        #expect(key.iterations > 0,
                "可见边只有 1 条，却被判为超限、力导向被关掉（横幅还会说截断了连接）")
        #expect(key.edges == [real], "缺失节点的边进了 effectiveEdges：\(key.edges.count) 条")
    }

    @Test("指向被截断节点的边不占边额度")
    func edgesToTruncatedNodesDoNotConsumeEdgeBudget() {
        let limit = NetworkGraph<Node>.recommendedNodeLimit
        let nodes = (0..<(limit + 50)).map { Node(id: "n\($0)", label: "L") }
        let tailEdges = (0..<(NetworkGraph<Node>.recommendedEdgeLimit + 50)).map {
            GraphEdge(from: "n\(limit + ($0 % 50))", to: "n\($0 % limit)")
        }
        let key = NetworkGraph(nodes: nodes, edges: tailEdges).layoutKey(for: Self.size)
        #expect(key.edges.isEmpty,
                "两端不全可见的边进了 effectiveEdges：\(key.edges.count) 条")
    }

    @Test("effectiveEdges 的两端恒在 effectiveNodes 内")
    func everyEffectiveEdgeHasVisibleEndpoints() {
        let limit = NetworkGraph<Node>.recommendedNodeLimit
        let nodes = (0..<(limit + 30)).map { Node(id: "n\($0)", label: "L") }
        let mixed = (0..<800).map { i -> GraphEdge<String> in
            switch i % 3 {
            case 0: GraphEdge(from: "n\(i % limit)", to: "n\((i * 7) % limit)")
            case 1: GraphEdge(from: "n\(limit + (i % 30))", to: "n0")
            default: GraphEdge(from: "ghost\(i)", to: "n1")
            }
        }
        let key = NetworkGraph(nodes: nodes, edges: mixed).layoutKey(for: Self.size)
        let visible = Set(key.ids)
        #expect(!key.edges.isEmpty, "输入里有合法边，结果却是空的")
        #expect(key.edges.allSatisfy { visible.contains($0.from) && visible.contains($0.to) },
                "有边的端点不在 effectiveNodes 内 —— 渲染画不出来，却占了额度")
    }

    @Test("真的边超限仍然截断（本轮口径统一没有把上限关掉）")
    func genuineEdgeOverflowStillTruncates() {
        let limit = NetworkGraph<Node>.recommendedEdgeLimit
        var edges: [GraphEdge<String>] = []
        outer: for i in 0..<40 {
            for j in (i + 1)..<40 {
                edges.append(GraphEdge(from: "n\(i)", to: "n\(j)"))
                if edges.count == limit + 1 { break outer }
            }
        }
        let ghosts = (0..<200).map { GraphEdge(from: "ghost\($0)", to: "n0") }
        let nodes = (0..<40).map { Node(id: "n\($0)", label: "L") }
        let key = NetworkGraph(nodes: nodes, edges: edges + ghosts).layoutKey(for: Self.size)
        #expect(key.iterations == 0, "601 条真实可见边没有触发降级")
        #expect(key.edges.count == limit)
    }
}

// MARK: - 无向边归一化（PR #263 Copilot 第 2 轮）

private nonisolated struct CollidingID: Hashable, Sendable {
    let raw: String
    func hash(into hasher: inout Hasher) { hasher.combine(0) }
}

private nonisolated struct CollidingNode: GraphNode {
    let id: CollidingID
    let label: String
}

@Suite("无向边归一化对 hashValue 碰撞免疫")
struct UndirectedKeyCollisionTests {
    @Test("前提成立：hashValue 相同但不相等")
    func premiseHolds() {
        let a = CollidingID(raw: "a")
        let b = CollidingID(raw: "b")
        #expect(a != b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("hashValue 碰撞时 a→b 与 b→a 仍算同一条边（度数）")
    func reverseEdgeDedupesUnderHashCollision() {
        let a = CollidingID(raw: "a")
        let b = CollidingID(raw: "b")
        let nodes = [CollidingNode(id: a, label: "A"), CollidingNode(id: b, label: "B")]
        let d = NetworkGraph(nodes: nodes,
                             edges: [GraphEdge(from: a, to: b),
                                     GraphEdge(from: b, to: a)]).makeChartDescriptor()
        let ys = d.series.first?.dataPoints.compactMap {
            Double(String(describing: $0.yValue).filter { "0123456789.".contains($0) })
        } ?? []
        #expect(ys == [1, 1], "反向边在哈希碰撞下没被去重，度数成了 \(ys)——屏幕上只画得出 1 条")
    }

    @Test("hashValue 碰撞时 effectiveEdges 只留一条")
    func effectiveEdgesDedupesUnderHashCollision() {
        let a = CollidingID(raw: "a")
        let b = CollidingID(raw: "b")
        let nodes = [CollidingNode(id: a, label: "A"), CollidingNode(id: b, label: "B")]
        let g = NetworkGraph(nodes: nodes,
                            edges: [GraphEdge(from: a, to: b),
                                    GraphEdge(from: b, to: a)])
        #expect(g.layoutKey(for: .init(width: 300, height: 300)).edges.count == 1,
                "a→b 与 b→a 在哈希碰撞下被当成了两条边")
    }
}
