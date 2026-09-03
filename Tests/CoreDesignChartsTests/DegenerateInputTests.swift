import Accessibility
import Foundation
import Testing

@testable import CoreDesignCharts

/// ⚠️ Preview / 测试专用。**必须 `nonisolated`**——本 target 设了
/// `defaultIsolation(MainActor)`，不标就拿不到满足 `Sendable` 的 `Identifiable`
/// conformance。见 `ChartValue` 的文档。
private nonisolated struct Point: ChartValue {
    var id: String = UUID().uuidString
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
        // ⚠️ 第 3 轮终审 S-2：这两条上一版是零断言的冒烟调用，
        // 与第 2 轮判 `RingChart` 那条为不足是同一形态。
        #expect(RadarChart([Point]()).makeChartDescriptor()
            .series.first?.dataPoints.isEmpty == true)
        #expect(RadarChart(points([1])).makeChartDescriptor()
            .series.first?.dataPoints.count == 1)
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
    ///
    /// ⚠️⚠️ **上一版这条测试断言的是「没有截断」**（第 2 轮终审 C-1）：它绕过 `private`
    /// 的 `effectiveNodes` 直接调 `layout(nodes: 全部 200 个)`，然后 `#expect(l.count == n)`
    /// ——测试名与断言方向相反，FR-20 的截断行为**零覆盖**。而这个空洞底下压着一个
    /// 真 bug（`RingChart` 的 descriptor 走未截断集合，见 `RingChartTruncationTests`）。
    /// ⇒ 改成断言**经过组件**的可观测量。
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

    /// ⚠️ 机器无关的**运算量上界**（第 2 轮终审 C-2 方案 3）。计时不进 CI（机器差异会变
    /// 随机红灯），但「上限被上调 / 轮数被放宽」必须有东西挡住——
    /// `#expect(iterations(for: 150) < 90)` 挡不住「上限调到 500、iter=20」这种回归。
    /// ⚠️ **上一版有三个问题**（第 3 轮终审 S-1 / I-5，我自己也怀疑过其中第一个）：
    /// ① `900_000` 是按当前值 810 000 反推的 —— **用现状定义正确**，恒真陷阱的变体；
    /// ② 只在 `n = limit` **一点**检查 —— 若 `iterations(for:)` 被改成非单调曲线、
    ///    峰值不在上限处，就漏掉；
    /// ③ 只算 `n²·iter`，对**边数完全无感** —— 而弹簧回路是 O(E·iter)，
    ///    稠密图（E 可达 n(n-1)/2）的实际工作量约为表中的两倍。
    /// ⇒ 本版：预算**与实测吞吐挂钩**（283 ms / 810 000 ≈ 0.35 µs 每单位 ⇒
    /// 300 ms 预算 ≈ 860 000）、**全区间**检查、**把最坏边数计进去**。
    @Test("全区间的运算量有确定性上界（含最坏边数）")
    func pairwiseWorkIsBounded() {
        // ⚠️⚠️ **上一版的换算用错了单位**（第 4 轮终审 I-4）：810 000 是**旧单位**
        // `n²·iter`（150²×36），而本断言的单位是 `(n²/2 + E)·iter`
        // ——n=150 的实际值是 `(11250 + 600) × 36 = 426 600`。
        // 按同一次 283 ms 实测换算，新单位的吞吐是 `283 ms / 426 600 ≈ 0.66 µs/单位`
        // ⇒ 300 ms 预算在新单位下是 **≈ 450 000**，不是 860 000。
        // 上一版那道闸实际放行 ~570 ms，且把 `recommendedEdgeLimit` 提到 2000 仍然绿。
        // ⚠️ 改这个数须重跑基准并同步 `iterations(for:)` 的文档表格。
        let budget = 450_000
        for n in 1...NetworkGraph<Node>.recommendedNodeLimit {
            let iter = NetworkGraph<Node>.iterations(for: n)
            // ⚠️ 最坏边数与 n **无关**（第 4 轮终审 I-4）：`edges: [Edge]` 允许平行边
            // （本文件的 `edgeLimitTriggersDegradation` 就用 20 个节点造了 700 条），
            // 所以上一版的 `min(n(n-1)/2, limit)` 假设简单图、与 API 契约不符。
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


// MARK: - FR-19 第 5 类 + FR-20：RingChart 的截断与零总和

// ⚠️ 这两条都是上一轮的**残留**（第 2 轮终审 C-1 / I-5）：
// · 零总和此前只落在 `ChartDegeneracy.of([0,0,0])` 上，而 `ChartSupport` 自己写着
//   「目前没有图表消费它，**不得据此声称 RingChart 零总和已覆盖**」——
//   没有一条测试把全零 `values` 喂给 `RingChart`；
// · 截断此前完全无覆盖，而 `RingChart` 的 descriptor 恰好走了未截断的集合。

@Suite("RingChart · 截断与零总和")
struct RingChartTruncationTests {

    private func values(_ n: Int, all zero: Bool = false) -> [Point] {
        (0..<n).map { Point(label: "m\($0)", value: zero ? 0 : Double($0 + 1)) }
    }

    /// ⚠️ **这条测试是为了钉住一个我自己引入的 bug**：渲染走 `effectiveValues`
    /// （最多 6 环），descriptor 曾走 `self.values` ⇒ 喂 20 个指标时
    /// **VoiceOver 播报 20 个、屏幕上只有 6 个环**。
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
        // ⚠️ `AXDataPointValue` 不可直接比较，用其描述判定（全零 ⇒ 每点 y 都是 0）。
        let ys = d.series.first?.dataPoints.map { String(describing: $0.yValue) } ?? []
        #expect(ys.count == 3)
        #expect(ys.allSatisfy { $0.contains("0") && !$0.contains("1") }, "\(ys)")
    }

    @Test("单点：descriptor 有且只有一个数据点")
    func singleValue() {
        let d = RingChart(self.values(1), goal: 100).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == 1)
    }

    /// ⚠️ 终审 I-6：`ForEach(id: \.element.id)` 拿到重复 ID 是 SwiftUI 未定义行为。
    @Test("重复 id 去重（保留首次出现）")
    func duplicateIDs() {
        let dup = [Point(id: "a", label: "first", value: 1),
                   Point(id: "a", label: "second", value: 2),
                   Point(id: "b", label: "B", value: 3)]
        let d = RingChart(dup, goal: 10).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == 2)
    }
}

// MARK: - 本地化通路

/// ⚠️ **没有这条断言，本地化通路就是不可验证的**（第 2 轮终审 I-2）。
/// 查表 miss 时 Foundation **原样返回 key、不报错** ⇒ 现有的
/// `#expect(d.title?.isEmpty == false)` 在 `resources:` 被删、`.lproj` 没拷进 bundle、
/// 或 `.atURL` 写错时**全部保持绿**。CLAUDE.md 已点名「资源缺失是静默失败」。
/// ⇒ 用一个**译文与 key 不同**的哨兵条目，才能区分「命中」与「静默回退」。
@Suite("Bundle.module 本地化通路")
@MainActor
struct LocalizationPathTests {

    @Test("哨兵条目查得到，且不是回退到 key")
    func bundleResolves() {
        let resolved = chartAXString("__localization_probe__")
        #expect(resolved == "resource-bundle-resolved")
        #expect(resolved != "__localization_probe__", "回退到了 key —— 资源没进 bundle")
    }

    /// ⚠️ **上一版只测了 `chartAXString`（`String(localized:bundle:)`），
    /// 而所有用户可见的 chrome 文案走的是另一条机制**
    ///（`LocalizedStringResource(_:bundle: .atURL(...))`，第 3 轮终审 I-3）。
    /// 有人把 `.atURL(...)` 误改成 `.main`、或 `bundleURL` 取错，哨兵抓不到。
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

    /// ⚠️ **两条超限横幅都要断言**（第 5 轮终审 I-1）：`"Showing the first %lld
    /// connections"` 上一版**根本不在 `Localizable.strings` 里**，而英文之所以显示正常
    /// 是因为 Foundation **回退到 key 再套格式参数** ⇒ 翻译者拿不到条目、
    /// 所有非英文 locale 静默显示英文。这正是本 target 为之加了哨兵的那个静默失败面,
    /// 而哨兵只覆盖了 `"No data"` / `"Connections"` / `"Node"`。
    /// ⇒ 判据：查表结果**必须与 key 本身不同**（带格式参数的 key 展开后天然不同，
    /// 故改用「是否含未展开的 `%lld`」判定）。
    @Test("两条超限横幅都在表里（不是回退到 key）")
    func truncationBannersAreRegistered() {
        for key in ["Showing the first %lld nodes", "Showing the first %lld connections"] {
            let resolved = Bundle.module.localizedString(
                forKey: key, value: "@@MISS@@", table: nil
            )
            #expect(resolved != "@@MISS@@", "`\(key)` 不在 Localizable.strings 里")
        }
    }
}


// MARK: - 第 3 轮终审补的覆盖

// ⚠️ 这三条各自钉住一个「同一 bug 类在另一个兄弟组件上原样留着」的实例。

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

    /// ⚠️ 与 `RingChartTruncationTests.descriptorMatchesRendering` 同形——
    /// 第 2 轮修 `RingChart` 时我写「两个兄弟组件走反了」，**那句话少数了一个兄弟**。
    /// ⚠️ **必须注入 UTC 日历**（第 4 轮终审 I-5）：上一版用默认 `.current` 构造组件，
    /// 而数据点落在 UTC 午夜 ⇒ 在 UTC-1/±0 的 DST 时区里会有相邻点落进同一个**本地**日、
    /// 被 `effectiveDays` 去重合并。评审遍历 443 个时区实测：
    /// `America/Scoresbysund` 与 `Atlantic/Azores` 两处得 1825 而非 1830 ⇒ **判红**。
    /// ⚠️ 而 `days(_:)` 里那个 UTC 日历上一版**造了却从没用**（死变量、不触发 warning）。
    @Test("ActivityHeatmap：descriptor 只播报截断后的天数")
    func heatmapDescriptorMatchesRendering() {
        let limit = ActivityHeatmap<Day>.maximumDays
        let d = ActivityHeatmap(self.days(limit + 400), calendar: Self.utc).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == limit)
    }

    /// ⚠️ C-2：descriptor 的度数必须按**截断后**的边算（渲染画 `effectiveEdges`）。
    /// ⚠️ 第 5 轮终审 I-2：同一 bug 类的**第四个轴**（节点截断）。
    @Test("NetworkGraph：度数只算两端都可见的边")
    func graphDegreeSkipsDroppedNodes() {
        let limit = NetworkGraph<Node>.recommendedNodeLimit
        let nodes = (0..<(limit + 50)).map { Node(id: "n\($0)", label: "L") }
        // 边全部集中在**会被丢弃的尾部**节点上。
        let tailEdges = (0..<100).map {
            GraphEdge(from: "n\(limit + ($0 % 50))", to: "n0")
        }
        let d = NetworkGraph(nodes: nodes, edges: tailEdges).makeChartDescriptor()
        let ys = d.series.first?.dataPoints.compactMap {
            Double(String(describing: $0.yValue).filter { "0123456789.".contains($0) })
        } ?? []
        // 所有边都指向被丢弃的节点 ⇒ 可见节点的度数应全为 0。
        #expect(ys.allSatisfy { $0 == 0 },
                "被丢弃节点的度数被算进了可见节点：\(ys.filter { $0 != 0 }.prefix(5))")
    }

    @Test("NetworkGraph：度数按截断后的边算")
    func graphDegreeUsesTruncatedEdges() {
        let nodes = (0..<20).map { Node(id: "n\($0)", label: "L") }
        let many = (0..<(NetworkGraph<Node>.recommendedEdgeLimit + 400))
            .map { GraphEdge(from: "n\($0 % 20)", to: "n\(($0 * 7) % 20)") }
        let d = NetworkGraph(nodes: nodes, edges: many).makeChartDescriptor()
        // ⚠️ `AXDataPointValue` 不可直接解构，用描述里的数字解析。
        let ys = d.series.first?.dataPoints.compactMap {
            Double(String(describing: $0.yValue).filter { "0123456789.".contains($0) })
        } ?? []
        #expect(!ys.isEmpty)
        // 全量 1000 条边 ⇒ 度数总和 2000；截断到 600 ⇒ 1200。
        let total = ys.reduce(0, +)
        #expect(total <= Double(NetworkGraph<Node>.recommendedEdgeLimit) * 2,
                "度数总和 \(total) 超过截断后边数的两倍 —— descriptor 用了全量边")
    }

    /// ⚠️ C-3：颜色分档必须与渲染同源（上一轮只修了 descriptor 与 weeks）。
    @Test("ActivityHeatmap：分档按截断后的窗口算")
    func heatmapBucketsUseEffectiveWindow() {
        // 峰值 500 落在很久以前，最近一段峰值只有 5。
        let old = [Day(date: Date(timeIntervalSinceReferenceDate: 0), count: 500)]
        let recent = (1...10).map {
            Day(date: Date(timeIntervalSinceReferenceDate: Double(ActivityHeatmap<Day>.maximumDays + $0) * 86400),
                count: 5)
        }
        // ⚠️ **走组件自己的路径**（`renderInputs`），不是直接喂已收敛的数据
        // ——后者会绕过被测的那一步，把源码退回 `self.days` 也照样绿。
        let buckets = ActivityHeatmap<Day>.renderInputs(old + recent, calendar: Self.utc).buckets
        #expect(buckets.last == 5, "分档上界是 \(String(describing: buckets.last)) —— 用了窗口外的峰值 500")
    }

    /// ⚠️ I-1：`isTruncated` 必须比**去重后**的数量。
    @Test("重复 id 不触发假截断")
    func duplicateIDsDoNotFakeTruncation() {
        let dup = (0..<200).map { _ in Node(id: "same", label: "L") }
        let g = NetworkGraph(nodes: dup, edges: [])
        #expect(g.layoutKey(for: .init(width: 300, height: 300)).iterations > 0,
                "3 个不同 id 的图被误判为超限、力导向被关掉")
    }

    /// ⚠️ I-2：`buckets` 对 `Int.max` 不得 trap。
    @Test("buckets 对 Int.max 不 trap")
    func bucketsSurviveIntMax() {
        let b = ActivityHeatmap<Day>.buckets(for: [Day(date: Date(), count: .max)])
        #expect(b.count == 4)
        #expect(b.last == Int.max)
    }

    /// ⚠️ S-2：舍入语义是定案，钉住取值表。
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

    /// ⚠️ 第 3 轮终审 C-2：去重此前只在 `layout` 内部，而 `ForEach` 与 descriptor
    /// 拿的是**未去重**的 `effectiveNodes` ⇒ SwiftUI 重复 ID + 多播报一个类目。
    /// 而原来的 `duplicateIDs` 直接调 `layout`、**绕过了那一层**，bug 在时它是绿的。
    @Test("NetworkGraph：重复 id 在组件层就去重（不只在 layout 内部）")
    func graphDedupesAtComponentLevel() {
        let dup = [Node(id: "a", label: "first"), Node(id: "a", label: "second"),
                   Node(id: "b", label: "B")]
        let d = NetworkGraph(nodes: dup, edges: []).makeChartDescriptor()
        #expect(d.series.first?.dataPoints.count == 2)
        let category = d.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(category?.categoryOrder.count == 2)
    }

    /// ⚠️ 第 3 轮终审 I-4：C-4 修的「截断 ⇒ iterations 归零」此前零覆盖。
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
        // C-4 的原始论证：150 → 200 时 key 必须变（否则命中过期布局）。
        #expect(under.layoutKey(for: size) != over.layoutKey(for: size))
    }

    /// ⚠️ 第 3 轮终审 I-5：边数此前完全无上限，而弹簧回路是 O(E·iter)。
    @Test("边数超限也触发降级")
    func edgeLimitTriggersDegradation() {
        let nodes = (0..<20).map { Node(id: "n\($0)", label: "L") }
        let many = (0..<(NetworkGraph<Node>.recommendedEdgeLimit + 100))
            .map { GraphEdge(from: "n\($0 % 20)", to: "n\(($0 * 7) % 20)") }
        let g = NetworkGraph(nodes: nodes, edges: many)
        #expect(g.layoutKey(for: .init(width: 300, height: 300)).iterations == 0)
    }
}
