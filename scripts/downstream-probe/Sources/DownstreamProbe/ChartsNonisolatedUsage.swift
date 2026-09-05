import CoreDesignCharts
import Foundation

// `CoreDesignCharts` 的 nonisolated 消费面（#247 建结构）。
//
// ⚠️ 同 `EffectsNonisolatedUsage.swift`：本文件目前只有模块标识这一条，
// 四个图表（RadarChart / RingChart / ActivityHeatmap / NetworkGraph）落地后
// 由 `shipswift-effects` 的 A-7 补齐调用点。
//
// ⚠️ 图表的**数据入参类型**（节点、数据点、日期桶等）是最需要在这里覆盖的——
// 它们是调用方要在自己的模型层构造的值类型，若被 `MainActor` 隔离，
// 下游在后台线程准备数据时就用不了，而这**只有本 probe 看得见**。
// ⚠️ 而四个图表**本身**（`View` struct）落 `PublicVisibility.swift`——理由见
// `EffectsNonisolatedUsage.swift` 里的分流表（#260 终审 Important-2）。

nonisolated func readChartsModuleName() -> String {
    CoreDesignCharts.moduleName
}

// MARK: - #255 的四个图表：数据契约与规模上限（`shipswift-effects` A-7 补齐）

// MARK: 数据入参：三个协议 + 一个 struct
//
// ⚠️⚠️ **这一节是本 probe 在整个 `CoreDesignCharts` 上唯一看得见、而库自身四条验证
// 命令结构上看不见的东西**：本 target 开了 `.defaultIsolation(MainActor.self)`，
// 而 `ChartValue` / `HeatmapDay` / `GraphNode` 三个协议都要求 `Sendable`
// ——`ChartSupport.swift` 的类型文档逐字写着「**解法是给该类型标 `nonisolated`**」，
// 并且点名「下游多半和这里一样（Xcode 26 模板默认 `SWIFT_DEFAULT_ACTOR_ISOLATION
// = MainActor`）」。⇒ 下游是否**真的能**在 nonisolated 上下文里构造并持有这些模型，
// 只有跨模块的 `nonisolated func` 证得了。
//
// ⚠️ 下面三个模型类型**故意不标 `nonisolated`**：本 probe target 没设
// `defaultIsolation`，它们天然就是 nonisolated 的 —— 这正是「下游的普通值类型」
// 那一档。若哪天 `ChartValue` 的 `Sendable` 要求被拿掉，这里不会红（那是放宽），
// 而若三个协议本身或 `GraphEdge` 丢了 `public`，这里当场编译红。

struct ChartsProbeMetric: ChartValue {
    let id: Int
    let label: String
    let value: Double
}

struct ChartsProbeDay: HeatmapDay {
    let id: Int
    let date: Date
    let count: Int
}

struct ChartsProbeNode: GraphNode {
    let id: String
    let label: String
}

/// 从 nonisolated 上下文构造全部四类数据入参。
///
/// ⚠️ `GraphEdge` 是四者里唯一由**库**提供的具体类型（`public nonisolated struct`），
/// 其 `init(from:to:)` 与两个 `let` 都是公开面 —— 三个协议由下游实现，
/// 它由下游**构造**，两种失效方向不同，都要覆盖。
nonisolated func buildChartInputs() -> (Int, Int, Int, Int) {
    let metrics = [
        ChartsProbeMetric(id: 0, label: "速度", value: 82),
        ChartsProbeMetric(id: 1, label: "力量", value: 61),
        ChartsProbeMetric(id: 2, label: "耐力", value: 94),
    ]
    let days = (0..<7).map {
        ChartsProbeDay(id: $0, date: Date(timeIntervalSince1970: Double($0) * 86_400), count: $0)
    }
    let nodes = (0..<4).map { ChartsProbeNode(id: "n\($0)", label: "节点 \($0)") }
    let edges = [GraphEdge(from: "n0", to: "n1"), GraphEdge(from: "n1", to: "n2")]
    // 读 `GraphEdge` 的两个存储属性：只构造不读时，它们各自漏 `public` 仍然编译得过。
    let endpoints = edges.map { "\($0.from)->\($0.to)" }
    return (metrics.count, days.count, nodes.count, endpoints.count)
}

// MARK: 规模上限：四个 `public static var`
//
// ⚠️ 它们是 AD-F「超限固定为截断 + 降级 + 文档标注」那条契约的**对外面**：
// 调用方要在自己的数据层按这几个数**先行分页 / 抽样**，那正是后台线程上的活
// ⇒ 被 `MainActor` 隔离就用不了，而这只有本 probe 看得见。
//
// ⚠️⚠️ **本函数是观测点，不是判据 —— 实测过，别写成「有它守着」。**
// 把 `RingChart.recommendedRingLimit` 的 `nonisolated` 删掉再跑
// `cd scripts/downstream-probe && swift build`：
//
//     ChartsNonisolatedUsage.swift:91:38: warning: main actor-isolated static property
//         'recommendedRingLimit' can not be referenced from a nonisolated context
//     Build complete!            ← 退出码 0
//
// CI 的 `downstream-probe` job 跑的正是这条不带 `-Xswiftc -warnings-as-errors` 的
// `swift build`（全仓 `ci.yml` 里一处都没有）⇒ **新增 warning 不会让它变红**。
// 最直接的反证：本包**今天就带着 5 条既存 warning 而 CI 是绿的**（#290）。
// ⇒ 这四个常量的 `nonisolated` 今天只能靠人读 build 输出 + PR 评审。
// 把它做实的动作是给那一步加 `-warnings-as-errors`，而那要先清掉 #290 的 5 条
// ⇒ **那是 #290 的收尾判据**，不在 `#256` 射程内。
//
// ⚠️ 对照：本文件 `buildChartInputs()` 与 `PublicVisibility.swift` 的
// `consumeCharts()` 那两侧是**真判据** —— 实测把 `GraphEdge.from` 的 `public`
// 拿掉，库的 `swift build` 退出码 0、probe **硬 error**
// （`'from' is inaccessible due to 'internal' protection level`）。
//
// ⚠️ **`recommendedNodeLimit` / `recommendedEdgeLimit` 定义在泛型类型上**
// （`NetworkGraph<Node>`），读它们必须写出一个具体的 `Node` ⇒ 这里用上面的
// `ChartsProbeNode`。若哪天它们被挪到一个非泛型的命名空间上，这行会红，
// 那是**预期的**（形态变了要重新过一遍下游写法）。
//
// ⚠️ **`RadarChart` 有意不在这张表里**：它的 `minimumAxes` 是 `internal`
// （只给退化判定用，不是给调用方分页用的上限）⇒ 登记它会编译红，
// 而那是**正确**的——本函数只收公开面。
nonisolated func readChartScaleLimits() -> [Int] {
    [
        RingChart<ChartsProbeMetric>.recommendedRingLimit,
        ActivityHeatmap<ChartsProbeDay>.maximumDays,
        NetworkGraph<ChartsProbeNode>.recommendedNodeLimit,
        NetworkGraph<ChartsProbeNode>.recommendedEdgeLimit,
    ]
}
