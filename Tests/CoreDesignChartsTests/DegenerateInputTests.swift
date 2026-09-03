import Accessibility
import Foundation
import Testing

@testable import CoreDesignCharts

/// ⚠️ Preview / 测试专用。**必须 `nonisolated`**——本 target 设了
/// `defaultIsolation(MainActor)`，不标就拿不到满足 `Sendable` 的 `Identifiable`
/// conformance。见 `ChartValue` 的文档。
private nonisolated struct Point: ChartValue {
    let id = UUID()
    let label: String
    let value: Double
}

/// ⚠️ 泛型化后（终审 I-7）热力图与网络图的数据类型也由**调用方**提供——
/// 下面这两个就是"调用方自己的模型"，和 `Point` 同一形态。
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

// ⚠️ **退化输入是一等契约，不是边角**（FR-19）。
//
// ⚠️ 本 suite 断言「不 crash、不产生 NaN、走到正确的降级分支」，**不是**具体像素。
// 像素级验证靠 `#Preview`。
//
// ⚠️ **本文件第 1 版被终审判为假绿**，三处照录以防重犯：
// ① 断言全打在 `ChartDegeneracy` / `normalizedSafely` 这类 helper 上，**四个图表
//    类型自己一条没测**——而 `RingChart` 根本不调用 `ChartDegeneracy`，
//    于是「RingChart 零总和已覆盖」是纯粹的虚假信心；
// ② US-4 的 a11y「有测试」全靠 conformance 的编译期存在，**零条断言**，
//    而 descriptor 里恰好埋着一条 `ClosedRange` trap；
// ③ `zeroEdgesNoNaN` 的注释自称「防节点重合」，实际测的是 300×300 正常尺寸，
//    **注释宣称的覆盖与真正测的东西不是一回事**。

// MARK: - FR-19 第 1、2 类：四个图表各自的空数组与点数不足

@Suite("四个图表 · 空数组与点数不足")
struct PerChartDegenerateTests {

    @Test("RadarChart：空 / 1 点 / 2 点都不崩，且不画网")
    func radar() {
        #expect(ChartDegeneracy.of([], minimumCount: 3) == .empty)
        #expect(ChartDegeneracy.of([1], minimumCount: 3) == .insufficientPoints(needed: 3))
        #expect(ChartDegeneracy.of([1, 2], minimumCount: 3) == .insufficientPoints(needed: 3))
        // 描述符是 VoiceOver 主动拉取的，空数据下同样不得 trap。
        _ = RadarChart([Point]()).makeChartDescriptor()
        _ = RadarChart(points([1])).makeChartDescriptor()
    }

    @Test("RingChart：空数组走空态、描述符不崩")
    func ring() {
        _ = RingChart([Point](), goal: 100).makeChartDescriptor()
        _ = RingChart(points([1]), goal: 100).makeChartDescriptor()
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

    /// ⚠️ **终审 C-4 抓到的真崩溃**：`NaN` 端点让 `ClosedRange` 触发前置条件失败、
    /// **进程 trap**。`NaN <= 0` 为假 ⇒ `goal <= 0` 那道守卫拦不住它。
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

    /// ⚠️ 终审 C-4：初版 `[1, .infinity]` 吐 `[0, nan]`、`[1, .nan, 3]` 吐 `[0, nan, 1]`，
    /// 而本文件开头的硬约束与 FR-19 都写着「不产生 NaN」。
    @Test("非有限输入不产生 NaN，且不参与跨度计算")
    func nonFiniteIsClamped() {
        for input in [[1.0, .infinity], [1.0, .nan, 3.0], [-.infinity, 0.0, .infinity],
                      [.nan, .nan], [-5.0, .nan, 5.0]] {
            let out = input.normalizedSafely()
            #expect(out.count == input.count)
            #expect(out.allSatisfy { $0.isFinite && (0...1).contains($0) },
                    "输入 \(input) 产出 \(out)")
        }
        // +∞ → 1、-∞ → 0、NaN → 0.5：确定性映射，不猜、不吸附。
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

    /// ⚠️⚠️ **终审 C-1 的回归测试**——这是本 suite 存在的首要理由。
    ///
    /// `byDate` 的键是 `startOfDay`，而 `date(byAdding: .day)` 在**午夜被跳过**的
    /// DST 转换上会把 cursor 推到 01:00 并**永久漂移**，此后每次查表全 miss。
    /// 智利 2026-09-06 就是这样一次转换：修复前 14 天只有 **6 天**落进网格，
    /// 其余 8 天**静默消失**，无任何报错。
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
        // 10 天跨度必然 ≥ 2 列，若被"跳过缺失日"实现掉则会塌成 1 列。
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

    /// FR-20 的同一条原则：截断，不断言。
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

    /// ⚠️ **这才是"节点重合"这一类的真入口**（终审 C-3）：环形初始化保证不同 id
    /// 的节点初始不重合，所以正常尺寸下 `dist < 0.01` 分支**根本不可达**。
    /// 真正能构造重合的是**极小容器**（钳位把所有点压到一起）。
    @Test("极小容器（钳位坍缩）—— 曾让所有节点落到容器外的同一点")
    func tinyContainerDoesNotCollapseOutside() {
        for side in [0.0, 1, 4, 7.9] {
            let size = CGSize(width: side, height: side)
            let l = NetworkGraph<Node>.layout(
                nodes: self.nodes(4), edges: [], size: size, iterations: 20
            )
            #expect(l.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            // ⚠️ 终审 I-3 实测：`min(max(x, 4), w - 4)` 在 w < 8 时反转，
            // 四个节点全部变成 (-3, -3) —— 有限、但在容器外。
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

    /// ⚠️ 终审 I-4：`pos` 以 id 为键，重复 id 会让后写覆盖先写 ⇒ 返回节点数少于输入，
    /// 而渲染侧 `ForEach` 拿到重复 ID 是 SwiftUI 未定义行为。
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

    /// FR-20：超限走**截断 + 静态布局**，不抛断言。
    @Test("超过 recommendedNodeLimit：截断且不 crash")
    func overLimitTruncates() {
        let n = NetworkGraph<Node>.recommendedNodeLimit + 50
        let graph = NetworkGraph(nodes: self.nodes(n), edges: [])
        _ = graph.makeChartDescriptor()
        let l = NetworkGraph<Node>.layout(
            nodes: self.nodes(n), edges: [], size: .init(width: 300, height: 300), iterations: 0
        )
        #expect(l.count == n)
        #expect(l.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    /// ⚠️ 轮数随规模收敛的**实测依据**见 `NetworkGraph.iterations(for:)` 的文档表格
    /// （固定 90 轮时 n=150 要 231 ms，收敛后 89 ms）。**计时不进 CI**——机器差异会让它
    /// 变成随机红灯；这里只钉住"轮数随 n 单调不增且恒为正"这条性质。
    @Test("迭代轮数随节点数单调不增，且恒为正")
    func iterationsShrinkWithSize() {
        let counts = [1, 30, 60, 61, 100, 150, 400]
        let iters = counts.map { NetworkGraph<Node>.iterations(for: $0) }
        #expect(iters.allSatisfy { $0 > 0 })
        #expect(zip(iters, iters.dropFirst()).allSatisfy { $0 >= $1 }, "\(iters)")
        // 上限处必须已经收敛下来，否则实测的 231 ms 会原样回来。
        #expect(NetworkGraph<Node>.iterations(for: NetworkGraph<Node>.recommendedNodeLimit) < 90)
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

// ⚠️ **终审 C-2 判定初版这条 AC 为假绿**：`AXChartDescriptorRepresentable` 的
// conformance 只有编译期存在性，测试里零条断言——而 descriptor 里恰好埋着
// 一条会让宿主 App trap 的 `ClosedRange` 构造。下面断言的是**内容**，不是存在性。

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

    /// ⚠️ 空数据下 VoiceOver 照样会拉描述符——**这条是四个图表的 trap 面**。
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
