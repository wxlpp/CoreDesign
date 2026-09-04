# RadarChart

多维评分的形状对比（蛛网图）/ A radar (spider) chart comparing multi-dimensional scores.

`RadarChart(values)`（`CoreDesignCharts/RadarChart.swift`，Issue #255）。**泛型视图**——
数据类型由调用方提供，本库**不发货**具体的数据 struct。

```swift
import CoreDesignCharts
```

⚠️ 本 target **有意不 `import Charts`**：它只收容 Swift Charts 原生画不出来的四类图表。
雷达图属于这一类——Swift Charts 没有极坐标多轴的 mark（`RadarChart.swift` 头注释）。

## API

```swift
public struct RadarChart<Value: ChartValue>: View {

    /// - Parameters:
    ///   - values: 各维度。`label` 作轴名、`value` 作长度。
    ///   - title: 图表标题。
    public init(
        _ values: [Value],
        title: LocalizedStringResource? = nil,
        tint: Color = .accent
    )
}
```

数据契约（`ChartSupport.swift`）：

```swift
public protocol ChartValue: Identifiable, Sendable {
    /// 该点在图表上的显示名。由调用方的模型提供。
    var label: String { get }
    /// 该点的数值。
    var value: Double { get }
}
```

⚠️ **`minimumAxes`（值为 `3`）是 `internal`，不在公开 API 表面上**——源码里写的是
`static var minimumAxes: Int { 3 }`（无 `public`）。它只是内部判据，调用方**读不到**，
与另外三个图表的 `recommendedRingLimit` / `maximumDays` / `recommendedNodeLimit` 不同。
「至少 3 轴」这条约束只能通过下面那条空态文案观察到。

## AD-F 退化输入契约

`body` 把 `values.map(\.value)` 交给 `ChartDegeneracy.of(_:minimumCount: 3)`，
**判定顺序在 `ChartDegeneracy.of` 里写死**：空 > 非有限 > 点数不足 > 零总和 > 全等。

| 退化输入 | `ChartDegeneracy` | 定义好的行为 |
|---|---|---|
| 空数组 `[]` | `.empty` | 渲染空态，文案 `"No data"` |
| 含 `NaN` / `+∞` / `-∞`（**任意一个**） | `.nonFinite` | 渲染空态，文案 `"Data contains values that are not finite"` |
| 1 个或 2 个点 | `.insufficientPoints(needed: 3)` | 渲染空态，文案 `"A radar chart needs at least 3 dimensions"`——**不是错误，是"轴不够"** |
| 全 0（零总和） | `.zeroTotal` | 落 `default` 分支 ⇒ **照常画网**：`normalizedSafely()` 在跨度为 0 时返回全 `0.5` ⇒ 一个正多边形 |
| 全等非零（各维同分） | `.flat` | 同上——落 `default` 分支，画出正多边形，**不 NaN、不除零** |
| 3 个及以上互异有限值 | `.usable` | 正常绘制 |

⚠️ **`.nonFinite` 这一类是「防 trap」不是「防脏数据」**：`ClosedRange` 端点为 `NaN` 时
会触发前置条件失败、**进程 trap**，而 `NaN <= 0` 为假 ⇒ 普通的 `<= 0` 守卫拦不住它
（`ChartSupport.swift` 对 `.nonFinite` / `safeRange` 的说明）。

⚠️ **归一化的确定性映射**（`Collection.normalizedSafely()`）：非有限值被**逐个夹到确定值**
（`+∞ → 1`、`-∞ → 0`、`NaN → 0.5`）且**不参与跨度计算**——否则一个 `∞` 会把其余所有点压成 0。
返回值保证「每个元素都是有限值且落在 `[0, 1]`」。测试：`normalizedSafely` 一组
（`DegenerateInputTests.swift` 的「安全归一化」suite）。

⚠️ **descriptor 与画面在退化输入下并不同源**（源码事实，如实记录）：`makeChartDescriptor()`
的 `dataPoints` 走的是**全量 `self.values`**，不过 `ChartDegeneracy`。所以
`RadarChart(points([1]))` 屏幕上是空态、descriptor 却有 **1 个数据点**——这一点由
`PerChartDegenerateTests.radar()` 直接钉住（`#expect(… dataPoints.count == 1)`）。
另外三个图表里有截断的那三个都做了「descriptor 用截断后的集合」的对齐，雷达图**没有截断**，
故这里只是分支差异，不是数量分叉。

## 规模上限（FR-20）

⚠️ **本图表没有声明任何公开的规模上限**——四个图表里唯一一个。`RingChart.recommendedRingLimit` /
`ActivityHeatmap.maximumDays` / `NetworkGraph.recommendedNodeLimit` / `.recommendedEdgeLimit`
都是 `public nonisolated static var`，而雷达图**没有对应物**；`minimumAxes` 是**下限**且是
`internal`，方向与用途都不同。

FR-20 的原则本身仍然成立并被本 target 全线遵守：**超限行为固定为「截断 + 降级为静态布局 + 文档」，
绝不 `precondition` / `fatalError`**——「库代码对数据规模 `precondition` 就是让宿主 App crash」
（`ChartSupport.swift` 开头的硬约束 3）。

⚠️ **我无法从源码或测试中确认「雷达图轴数很多时会发生什么」有任何定义好的行为**：
既没有上限常量、也没有截断路径，`polygon(...)` 会按 `count` 均分整圈。这是一处**未覆盖**，
不是「无上限即安全」的保证。

## FR-7 文本边界

- **调用方给的 `label`（轴名）是「内容」不是「UI 文案」** ⇒ 它是普通 `String`，
  **有意不强制 `LocalizedStringResource`**（`ChartValue` 的文档注释明写这是 FR-7 的边界声明）。
- **组件自带的 chrome 才本地化**：`title` 是 `LocalizedStringResource`，缺省值走
  `.chart("Radar chart")`；三条空态文案（`"No data"` / `"A radar chart needs at least 3 dimensions"` /
  `"Data contains values that are not finite"`）同样是 `LocalizedStringResource`，
  译文在 `Sources/CoreDesignCharts/Resources/en.lproj/Localizable.strings`。

⚠️ `LocalizedStringResource.chart(_:)` 是 **`internal`**，下游拿不到、也不该拿——它把 key 绑死在
本 target 的 `Bundle.module`，下游传自己的 key 必然查不到，而查不到时 Foundation
**原样返回 key、不报错**（静默丢本地化）。要换标题就直接传自己的 `LocalizedStringResource`。

## 无障碍（AXChartDescriptorRepresentable）

```swift
extension RadarChart: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor
}
```

⚠️ 走 **`Accessibility` 框架**的 `AXChartDescriptor`（`import Accessibility`），
**不是 Charts 框架**——本 target 的硬约束之一就是不依赖 Swift Charts。

视图侧：`.accessibilityElement()` + `.accessibilityLabel(Text(self.title))` +
`.accessibilityChartDescriptor(self)`，挂在 `web(normalized:)` 上（即**只有真正画出网时**才挂；
空态分支走 `ChartEmptyState`，它自带 `accessibilityLabel`）。

descriptor 暴露：

| 字段 | 取值 |
|---|---|
| `title` | `String(localized: self.title)`——**不是 `nil`** |
| `summary` | `nil` |
| `xAxis` | `AXCategoricalDataAxisDescriptor(title: "Dimension", categoryOrder: values.map(\.label))` |
| `yAxis` | `AXNumericDataAxisDescriptor(title: "Value", range: safeRange(有限值的 min ?? 0, 有限值的 max ?? 1))`，值格式化为 `"\($0.formatted())"` |
| `series` | 一条 `AXDataSeriesDescriptor(name: "", isContinuous: false)`，每个 `AXDataPoint(x: label, y: value)` |

⚠️ **量程只取有限值**：`self.values.map(\.value).filter(\.isFinite)`——`min()` / `max()` 遇 `NaN`
会把 `NaN` 传出来（NaN 的比较恒 false ⇒ 保留 seed），`NaN...NaN` 直接 trap。
外面再包一层 `safeRange` 兜底。测试 `radarRangeIsSafe` 覆盖 `[7,7,7]` / `[.nan,1,2]` / `[.infinity,.nan]`。

⚠️ 轴标题 `"Dimension"` / `"Value"` 走 `chartAXString(_:)`（`String(localized:bundle: .module)`），
因为 a11y 描述符要的是 `String` 而不是 `LocalizedStringResource`。

## 并发：数据类型必须 `nonisolated`

⚠️ **下游模块如果设了 `defaultIsolation(MainActor)`（Xcode 26 工程模板默认就写
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`），遵从 `ChartValue` 的类型必须标 `nonisolated`。**

不标会拿到 MainActor 隔离的 `Identifiable` conformance，满足不了 `Sendable`，报：

```
main actor-isolated conformance ... cannot satisfy conformance requirement
for a 'Sendable' type parameter
```

⚠️ **把类型提到文件作用域不够**——该设置作用于**整个 target**，解法就是给该类型标 `nonisolated`。

⚠️ **为什么 `ChartValue` 仍然要求 `Sendable`**：图表的数据入参是调用方在自己模型层构造的值类型，
若被 `MainActor` 隔离，下游在后台线程准备数据时就用不了。这条约束是**有意的**
（以上全部照录自 `ChartSupport.swift` 上 `ChartValue` 的文档注释）。

## 使用示例 / Usage

```swift
import CoreDesignCharts
import SwiftUI

// ⚠️ 调用方定义自己的模型 —— 本库**不发货**具体数据 struct，四个图表都是泛型的。
// ⚠️ `nonisolated` 不可省，理由见上一节。
nonisolated struct Metric: ChartValue {
    let id = UUID()
    let label: String      // 轴名是「内容」⇒ String，不是 LocalizedStringResource
    let value: Double
}

struct PlayerCard: View {
    let metrics: [Metric]

    var body: some View {
        RadarChart(
            metrics,
            title: "Attributes",       // chrome ⇒ LocalizedStringResource
            tint: .green
        )
        .frame(height: 220)
    }
}

#Preview {
    PlayerCard(metrics: [
        Metric(label: "速度", value: 82),
        Metric(label: "力量", value: 61),
        Metric(label: "耐力", value: 94),
        Metric(label: "技巧", value: 47),
        Metric(label: "智力", value: 73),
    ])
    .padding()
}
```

## 相关

- [`ring-chart.md`](ring-chart.md) —— 活动环：多个独立环各表示一个指标的**完成度**，共用 `ChartValue`
- [`activity-heatmap.md`](activity-heatmap.md) —— 贡献热力图，数据契约是 `HeatmapDay`
- [`network-graph.md`](network-graph.md) —— 力导向网络图，数据契约是 `GraphNode` / `GraphEdge`
