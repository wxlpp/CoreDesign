import CoreDesignCharts

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
