# RingChart

多个同心进度环，每环一个指标的完成度 / Concentric activity rings, one per metric.

`RingChart(values, goal:)`（`CoreDesignCharts/RingChart.swift`，Issue #255）。**泛型视图**——
数据类型由调用方提供，本库**不发货**具体的数据 struct。

```swift
import CoreDesignCharts
```

⚠️ 本 target **有意不 `import Charts`**。Swift Charts 的 `SectorMark` 是饼图/环形图
（按占比切分**一个**环），活动环是**多个独立环各自表示完成度**——不是同一个概念
（`RingChart.swift` 头注释）。

## API

```swift
public struct RingChart<Value: ChartValue>: View {

    /// - Parameters:
    ///   - goal: 满环对应的值。⚠️ **不从数据里推**——活动环的语义是"完成度"，
    ///     目标是外部设定的，用数据最大值当目标会让"全部未达标"看起来像"有人满环"。
    public init(
        _ values: [Value],
        goal: Double,
        title: LocalizedStringResource? = nil,
        tint: Color = .accent
    )

    /// 同心环的建议上限。**超出即截断**，与 `NetworkGraph` 同一条 FR-20 原则。
    public nonisolated static var recommendedRingLimit: Int { 6 }
}
```

数据契约（`ChartSupport.swift`）：

```swift
public protocol ChartValue: Identifiable, Sendable {
    var label: String { get }
    var value: Double { get }
}
```

## AD-F 退化输入契约

⚠️⚠️ **RingChart 从不调用 `ChartDegeneracy`**——它走的是自己的 `goal` 守卫。
`ChartSupport.swift` 在 `.zeroTotal` 上明写：「**目前没有图表消费它**……保留本 case 是因为
`of()` 是通用判定器，**但不得据此声称『RingChart 零总和已覆盖』**——那是本轮评审抓到的
一处虚假信心。」本文档照此办理：下表里没有一行是 `ChartDegeneracy` 判出来的。

| 退化输入 | 判据位置 | 定义好的行为 |
|---|---|---|
| 空数组 `[]` | `body` 的 `values.isEmpty` | 渲染空态，文案 `"No data"` |
| `goal == 0` / `goal < 0` | `body` 的 `self.goal <= 0` | 渲染空态，文案 `"The goal must be greater than 0"`——调用方的输入错误，但库**不 crash** |
| `goal` 为 `NaN` / `±∞` | `body` 的 `!self.goal.isFinite`（**这半句不可省**：`NaN <= 0` 为**假**，`goal <= 0` 拦不住） | 同上，走同一条空态 |
| **所有 value 全为 0（零总和）** | 无专用分支——`progress = max(0, min(0 / goal, 1)) == 0` | **照常画环**，每环进度为 0（空环底轨仍在）。⚠️ 这是**除法自然收敛**，不是 `ChartDegeneracy.zeroTotal` 覆盖的。测试：`zeroTotalValues`（3 个数据点、y 全为 0，不 trap） |
| `value > goal`（超额完成） | 渲染 `max(0, min(value / goal, 1))` | 环**画满即止**，不多绕圈 |
| `value < 0` | 同上 | 当 0 处理，**不反向画** |
| `value == +∞` | `drawnValue(_:goal:)` 的 `guard value.isFinite` | 画**满环**；descriptor 报 `goal` |
| `value == -∞` / `NaN` | 同上（渲染那侧走 `Comparable` 版 `min`/`max`，对 `NaN` 的短路结果是 **0**） | 画**空环**；descriptor 报 `0`。测试：`descriptorClampsNonFiniteValues` 断言 `ys == [goal, 0, 0]` |
| 重复 `id` | `effectiveValues` 的 `seen.insert(...).inserted` | **去重，保留首次出现**（`ForEach(id: \.element.id)` 拿到重复 ID 是 SwiftUI 未定义行为）。测试：`duplicateIDs` |
| 单点 | 无特殊分支 | 正常画 1 个环。测试：`singleValue` |

⚠️ **去重在截断之前**，且**收够 6 个唯一值即停**（不扫完全表）。顺序语义由
`dedupeThenTruncateKeepsOrder` 逐字钉住：保留首次出现、保持原数组顺序、截断后取的是**前 6 个唯一值**。

⚠️ 源码另记了一条不能改的写法：**不能**写成 `values.lazy.filter { … }.prefix(6)`——
`[Value]` 是 `Collection`，`prefix` 会让带副作用的谓词**求值两次**，实测直接 trap
（`Range requires lowerBound <= upperBound`）。显式循环才保证每个元素恰好求值一次。

## 规模上限（FR-20）

**`RingChart.recommendedRingLimit == 6`**（`public nonisolated static var`）。

**超限行为固定为「截断 + 降级 + 文档」，绝不 `precondition` / `fatalError`**——
「库代码对数据规模 `precondition` 就是让宿主 App crash」（`ChartSupport.swift` 硬约束 3）。
本图表的具体表现：

- 超过 6 个唯一指标 ⇒ **静默截断**，只画前 6 个（去重后）。
- **不显示提示横幅**——这是本 target 里**显式定案**的三种行为之一：只有 `NetworkGraph` 提示，
  因为它的截断会**改变布局算法**（力导向 → 静态环形），用户看到的是一张"不一样的图"；
  热力图与活动环的截断是**同质的**（少几天 / 少几环），读图时可自明 ⇒
  **由调用方按场景自行提示**（照录自 `ActivityHeatmap.maximumDays` 的文档注释）。
- descriptor **走同一批** `effectiveValues`。这曾经是一个真 bug（渲染 6 环、VoiceOver 播报 20 个），
  现由 `descriptorMatchesRendering` 钉住。

⚠️ **6 这个数不是拍脑袋**：环宽有个 `max(…, 4)` 地板，环数一多
`radius = outer - index * width * 1.5` 会变**负**（实测 side=200、20 个指标 ⇒ index 19 时
radius = -22 ⇒ `.frame(width: -44)`）。6 是取「最内环仍有正半径」反推的。
另有两道地板兜住极端容器：半径夹到 `≥ 1`、环色透明度夹到 `≥ 0.1`。

⚠️ **`nonisolated` 在这个常量上是承重的**：AD-F 的「超限固定为截断 + 降级 + 文档」契约
要求调用方**在自己的数据层**按这个数先行分页 / 抽样，而那是后台线程上的活。
不标它，下游从 nonisolated 上下文读会拿到
`warning: main actor-isolated static property ... can not be referenced from a nonisolated context`，
而库自身四条验证命令全绿——判据在 `scripts/downstream-probe` 的 `readChartScaleLimits()`。

⚠️ 写成**计算属性**是因为泛型类型不支持 static **存储**属性；读法仍是
`RingChart<MyMetric>.recommendedRingLimit`（泛型参数必须显式给出）。

## FR-7 文本边界

- **调用方给的 `label`（指标名）是「内容」不是「UI 文案」** ⇒ 普通 `String`，
  **有意不强制 `LocalizedStringResource`**（`ChartValue` 的文档注释明写这是 FR-7 的边界声明）。
- **组件自带的 chrome 才本地化**：`title`（缺省 `.chart("Activity rings")`）与两条空态文案
  （`"No data"` / `"The goal must be greater than 0"`）都是 `LocalizedStringResource`，
  译文在 `Sources/CoreDesignCharts/Resources/en.lproj/Localizable.strings`。

⚠️ `LocalizedStringResource.chart(_:)` 是 **`internal`**：它把 key 绑死在本 target 的
`Bundle.module`，下游传自己的 key 必然查不到，而查不到时 Foundation **原样返回 key、不报错**。
要换标题就直接传自己的 `LocalizedStringResource`。

## 无障碍（AXChartDescriptorRepresentable）

```swift
extension RingChart: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor
}
```

⚠️ 走 **`Accessibility` 框架**的 `AXChartDescriptor`（`import Accessibility`），**不是 Charts 框架**。

视图侧：`.accessibilityElement()` + `.accessibilityLabel(Text(self.title))` +
`.accessibilityChartDescriptor(self)`，挂在 `rings` 上。

descriptor 暴露：

| 字段 | 取值 |
|---|---|
| `title` | `String(localized: self.title)` |
| `summary` | `nil` |
| `xAxis` | `AXCategoricalDataAxisDescriptor(title: "Metric", categoryOrder: effectiveValues.map(\.label))`——**截断后的那批** |
| `yAxis` | `AXNumericDataAxisDescriptor(title: "Completion", range: safeRange(0, denominator))`，其中 `denominator = goal.isFinite && goal > 0 ? goal : 1` |
| `series` | 一条 `AXDataSeriesDescriptor(name: "", isContinuous: false)`，`AXDataPoint(x: label, y: drawnValue(value, goal: denominator))` |

⚠️ **数值轴把 `goal` 读成 `100%`**：格式化闭包是
`"\($0.formatted(.percent.scale(100 / denominator)))"`。这里的 `scale` 是 **`100 / goal`
而不是 `1 / goal`**——`.scale(_:)` **替换**掉 `Percent` 那个隐式的 ×100，而不是与它相乘
（`(2.0).formatted(.percent) == "200%"`，但 `(2.0).formatted(.percent.scale(1)) == "2%"`）。
该语义由测试 `ringAxisReadsPercent` 钉住。

⚠️ **y 与画面走同一道夹取**：`drawnValue` 与渲染的 `max(0, min(value / goal, 1))` 同区间，
否则「喂 750（goal = 500）时屏幕是满环、VoiceOver 念 150%」。由 `descriptorClampsToGoal`
（`ys == [goal, 0, goal, 123]`）与 `descriptorClampsNonFiniteValues` 钉住。

⚠️ **`goal` 退化时 descriptor 仍不 trap**：`denominator` 兜底 1、`safeRange` 保证区间合法。
测试 `ringGoalIsSafe` 遍历 `0 / -5 / .nan / .infinity`。

轴标题 `"Metric"` / `"Completion"` 走 `chartAXString(_:)`（a11y 描述符要 `String` 而不是
`LocalizedStringResource`）。

## 并发：数据类型必须 `nonisolated`

⚠️ **下游模块如果设了 `defaultIsolation(MainActor)`（Xcode 26 工程模板默认就写
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`），遵从 `ChartValue` 的类型必须标 `nonisolated`。**

不标会拿到 MainActor 隔离的 `Identifiable` conformance，满足不了 `Sendable`，报：

```
main actor-isolated conformance ... cannot satisfy conformance requirement
for a 'Sendable' type parameter
```

⚠️ **把类型提到文件作用域不够**——该设置作用于**整个 target**，解法是给该类型标 `nonisolated`。

⚠️ **为什么仍然要 `Sendable`**：图表的数据入参是调用方在自己模型层构造的值类型，
若被 `MainActor` 隔离，下游在后台线程准备数据时就用不了。这条约束是**有意的**
（照录自 `ChartSupport.swift` 上 `ChartValue` 的文档注释）。

## 使用示例 / Usage

```swift
import CoreDesignCharts
import SwiftUI

// ⚠️ 调用方定义自己的模型 —— 本库**不发货**具体数据 struct。
// ⚠️ `nonisolated` 不可省，理由见上一节。
nonisolated struct Ring: ChartValue {
    let id = UUID()
    let label: String      // 指标名是「内容」⇒ String
    let value: Double
}

struct MoveSummary: View {
    let rings: [Ring]

    var body: some View {
        RingChart(
            // ⚠️ 超过 6 个指标会被静默截断且**没有横幅** ⇒ 在自己的数据层先收敛。
            Array(rings.prefix(RingChart<Ring>.recommendedRingLimit)),
            goal: 500,                 // 目标外部设定，不从数据里推
            title: "Today",            // chrome ⇒ LocalizedStringResource
            tint: .pink
        )
        .frame(height: 200)
    }
}

#Preview {
    MoveSummary(rings: [
        Ring(label: "活动", value: 420),
        Ring(label: "锻炼", value: 28),
        Ring(label: "站立", value: 9),
    ])
    .padding()
}
```

## 相关

- [`radar-chart.md`](radar-chart.md) —— 雷达图，共用 `ChartValue`；它**没有**公开的规模上限
- [`activity-heatmap.md`](activity-heatmap.md) —— 贡献热力图，同样是「截断但不提示」的一侧
- [`network-graph.md`](network-graph.md) —— 力导向网络图，四个图表里唯一**会提示截断**的那个

## ⚠️ 登记（`#270`）

`public struct RingChart` 由 `PublicTypeCollector` 采到，已按公约判定法登记进
`docs/component-registry.json` 的 `components`：
`kind: prescriptive` / `decidedBy: tiebreaker` / `needsExtensionPoint: false`。
落 tiebreaker 的理由同 `RadarChart`：候选（堆叠条 / 并排进度条）属排布差异，
但候选来源核验未做 ⇒ 枚举未完成 ⇒ 落步骤 4。
文本参数 `title`（`LocalizedStringResource?`、无裸串孪生重载）登记为 **by-type**。
逐字理由见该条目的 `notes`；扫描根由单根扩成 `GuardScanRoots.allRoots` 的经过见 issue #270。
