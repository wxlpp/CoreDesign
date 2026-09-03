//
//  CoreDesignCharts.swift
//  CoreDesignCharts
//
//  模块标识与命名空间 / Module identity and namespace.
//
//  ⚠️ 本文件是 target 骨架，**不是组件**。四个图表（RadarChart / RingChart /
//  ActivityHeatmap / NetworkGraph）由 `shipswift-effects` 的 #255 落地。
//
//  ⚠️ 本 target **有意不依赖 Swift Charts**：它只收容 Swift Charts 原生画不出来的
//  四类图表（雷达图 / 活动环 / 贡献热力图 / 力导向网络图）。line / bar / area /
//  point / sector 原生已支持，CoreDesign 不重造它们的换皮。
//

/// `CoreDesignCharts` 的命名空间与模块标识。
///
/// ⚠️ `nonisolated` 的理由同 `CoreDesignEffects`——见该类型的文档注释。
public enum CoreDesignCharts {

    /// 模块名。供宿主 App 的组件画廊分组与调试输出使用。
    nonisolated public static let moduleName = "CoreDesignCharts"
}
