# ActivityHeatmap

按周分列、按星期几分行的贡献热力图（GitHub 那种日格）/ A GitHub-style contribution heatmap.

`ActivityHeatmap(days)`（`CoreDesignCharts/ActivityHeatmap.swift`，Issue #255）。**泛型视图**——
数据类型由调用方提供，本库**不发货**具体的数据 struct。

```swift
import CoreDesignCharts
```

⚠️ 本 target **有意不 `import Charts`**。Swift Charts 的 `RectangleMark` 能画格子，但
**按周分列 + 按星期几分行 + 日期对齐**是一套布局、不是一个 mark；且它没有"缺失日期留空"的概念
（`ActivityHeatmap.swift` 头注释）。

## API

```swift
public struct ActivityHeatmap<Day: HeatmapDay>: View {

    /// - Parameter calendar: ⚠️ 显式接受而不是取 `.current`——一周从周日还是周一开始
    ///   **是 locale 决定的**，写死会让非美国用户看到错位的行。默认取 `.current`
    ///   是为了默认正确，但可注入才可测。
    public init(
        _ days: [Day],
        title: LocalizedStringResource? = nil,
        tint: Color = .accent,
        calendar: Calendar = .current
    )

    /// 单张热力图渲染的天数上限（≈ 5 年）。超出即**截断最旧的一段**（FR-20：截断不断言）。
    public nonisolated static var maximumDays: Int { 1830 }
}
```

数据契约（`ChartSupport.swift`）：

```swift
public protocol HeatmapDay: Identifiable, Sendable {
    /// 该格对应的日期。⚠️ 归一化到哪一天由图表按注入的 `Calendar` 决定，调用方不必对齐。
    var date: Date { get }
    /// 该天的计数。
    var count: Int { get }
}
```

## AD-F 退化输入契约

⚠️ **本图表不调用 `ChartDegeneracy`**——`count` 是 `Int`，天然有限，没有 `NaN` / `±∞` / 除零
这类数值退化面；它的退化面在**日期**与**分档**上。下表全部来自源码与
`DegenerateInputTests.swift`。

| 退化输入 | 判据位置 | 定义好的行为 |
|---|---|---|
| 空数组 `[]` | `body` 的 `days.isEmpty` | 渲染空态，文案 `"No data"`。`weeks(for: [])` 返回**零列**（不是崩，也不是一列空格）。测试：`heatmap()` |
| 单天 | `weeks(ofEffective:)` 取两端相同 | 正好 **1 列**。测试：`heatmap()`（`weeks(for: one).count == 1`） |
| 区间内**缺失的日期** | `weeks` 的 `column[weekday] = byDate[cursor]`（可能为 `nil`） | 画**空槽**（`Color.tertiaryFill`）**而不是跳过**——跳过会让格子错位，而热力图的信息量全在"位置对应日期"上。测试：`gapsBecomeEmptySlots` |
| **同一天两条记录** | `effectiveDays` 反向去重 + `weeks` 的 `byDate[startOfDay] = d` | **后者胜**，且是有意的：**不相加**——相加会让"重复"这个输入错误看起来像正常数据 |
| **所有 `count` 为 0** | `buckets(for:)` 的 `guard peak > 0` | 返回**空分档数组**，`color(for:buckets:)` 据此把每格画成空槽——**不拿 `max == 0` 当除数**。测试：`allZeroBuckets` |
| `count == Int.max` | `buckets` 改为**纯整数运算**（`peak / 4 * $0 + (peak % 4) * $0 / 4`） | 不 trap（上一版 `Int(Double(peak))` 在 `peak ≥ Int.max - 1024` 时 SIGTRAP）。测试：`bucketsSurviveIntMax` |
| **跨百年的区间**（如 1990 → 2090） | `effectiveDays` 把起点前移到 `end - (maximumDays - 1)`，`weeks` 内另有 `guardCounter > maximumDays + 14` 兜底 | 截断到最近 `maximumDays` 天，**不无限循环、不断言**。测试：`rangeIsCapped` |
| **午夜被跳过的 DST 转换**（智利 / 古巴 / 伊朗…） | `weeks` 游标每步 `cursor = calendar.startOfDay(for: next)` | 不丢格。⚠️ 少这一层时实测 `America/Santiago` + 2026-09-06 转换 + 14 天连续数据只落格 **6/14**，其余 8 天**静默消失**。测试：`dstDoesNotDropDays` 及其 UTC 对照组 `utcControlGroup` |

⚠️ **分档舍入语义是定案**：`buckets` 分 4 档、单调递增，峰值总能到满色（更接近 GitHub 的观感）。
`bucketsPinsRounding` 钉住了具体取值表；`bucketsAreMonotonic` 钉住档数与单调性。
颜色为 `tint.opacity(0.25 + level * 0.25)`。

## 规模上限（FR-20）

**`ActivityHeatmap.maximumDays == 1830`（≈ 5 年）**（`public nonisolated static var`）。

**超限行为固定为「截断 + 降级 + 文档」，绝不 `precondition` / `fatalError`**
（`ChartSupport.swift` 硬约束 3）。本图表的具体表现：

- 超过 1830 天 ⇒ **截断掉最旧的一段，保留最近的一段**。方向是有意的：贡献热力图的默认阅读方向
  是「最近」；上一版从最旧一天起步 + 到上限就 `break`，导致有 10 年数据的用户看到的是
  **最早那五年**、最近的活动全部不显示。测试：`heatmapKeepsRecent`。
- **截断对用户静默、不显示提示横幅**——这是三个会截断的图表里**显式定案**的分工：
  只有 `NetworkGraph` 提示，因为它的截断会**改变布局算法**（力导向 → 静态环形）；
  热力图与活动环的截断是**同质的**（少几天 / 少几环）且发生在序列一端，读图时可自明
  ⇒ **由调用方按场景自行提示**（照录自 `maximumDays` 的文档注释）。
- **截断窗口是渲染、分档与 descriptor 的共同源**：`renderInputs(_:calendar:)` 一次算齐
  `(shown, buckets, weeks)`。曾经的 bug 是「10 年数据、峰值 50 出现在 8 年前 ⇒ 可见窗口内每格
  都落最低档、整张图变成均匀最浅色」，现由 `heatmapBucketsUseEffectiveWindow`（断言
  `buckets.last == 5` 而不是窗口外的 500）与 `heatmapDescriptorMatchesRendering` 钉住。

⚠️ **`nonisolated` 在这个常量上是承重的**：AD-F 的「超限固定为截断 + 降级 + 文档」契约要求
调用方**在自己的数据层**按这个数先行分页 / 抽样，而那是后台线程上的活。不标它，下游从
nonisolated 上下文读会拿到
`warning: main actor-isolated static property ... can not be referenced from a nonisolated context`，
而库自身四条验证命令全绿——判据在 `scripts/downstream-probe` 的 `readChartScaleLimits()`。

⚠️ 写成**计算属性**是因为泛型类型不支持 static **存储**属性；读法是
`ActivityHeatmap<MyDay>.maximumDays`（泛型参数必须显式给出）。

### 性能：布局在主线程算，成本**不封顶**

⚠️ 与 `NetworkGraph` 不同，本图表的 `weeks` / `buckets` **每次 body 求值重算，且在主线程上**。
源码里记了实测（best-of-8）：

| 输入 N | `effectiveDays`（sort + 2N 次 `startOfDay`） | `weeks`（恒 1830） | 合计 |
|---|---|---|---|
| 1830 | 10.1 ms | 12.3 ms | 22.5 ms |
| 3653 | 20.2 ms | 12.4 ms | 32.4 ms |
| 20000 | 274.5 ms | 12.3 ms | 287.5 ms |

⇒ **封顶的只有 `weeks` 一项**（`O(maximumDays)`，12–38 ms，随日期年代波动——2001–2006 区间
38.5 ms、2011 年后 12.4 ms，应为 ICU 的 2007 年 DST 规则切换）；`effectiveDays` 的
**2N 次 `startOfDay`** 严格线性于**输入 N**（≈6 µs/条）⇒ **总成本不封顶**。
不做缓存的理由挂在**前提**上：典型用法 N ≤ `maximumDays`，此时约 22 ms。
**若调用方喂 10 年以上（N ≥ 3653），这个前提就不成立** ⇒ 应在自己的数据层先截断。

## FR-7 文本边界

- **日期标签是「内容」**：格子对应的日期由调用方的 `date` 提供，图表用
  `Date.FormatStyle(date: .abbreviated, time: .omitted)` 格式化成 `String` 交给 a11y 描述符。
  它**不是** `LocalizedStringResource`——与 `ChartValue.label`、`GraphNode.label` 同一条 FR-7 边界声明。
- **组件自带的 chrome 才本地化**：`title`（缺省 `.chart("Activity heatmap")`）与空态文案
  `"No data"` 是 `LocalizedStringResource`，译文在
  `Sources/CoreDesignCharts/Resources/en.lproj/Localizable.strings`。

⚠️ **日期标签跟随注入的 `calendar`**（时区、locale、日历标识），不是设备的：
`label(for:calendar:)` 把 `calendar` / `timeZone` / `locale` 逐项灌进 `FormatStyle`。
少这一层时实测注入 `Pacific/Kiritimati`：**格子画在 12/31、VoiceOver 念 1/1**。

⚠️ `LocalizedStringResource.chart(_:)` 是 **`internal`**：它把 key 绑死在本 target 的
`Bundle.module`，下游传自己的 key 必然查不到，而查不到时 Foundation **原样返回 key、不报错**。

## 无障碍（AXChartDescriptorRepresentable）

```swift
extension ActivityHeatmap: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor
}
```

⚠️ 走 **`Accessibility` 框架**的 `AXChartDescriptor`（`import Accessibility`），**不是 Charts 框架**。

视图侧：`.accessibilityElement()` + `.accessibilityLabel(Text(self.title))` +
`.accessibilityChartDescriptor(self)`，挂在 `grid` 上。

descriptor 暴露：

| 字段 | 取值 |
|---|---|
| `title` | `String(localized: self.title)` |
| `summary` | `nil` |
| `xAxis` | `AXCategoricalDataAxisDescriptor(title: "Date", categoryOrder: shown.map { label(for: $0.date, calendar: self.calendar) })` |
| `yAxis` | `AXNumericDataAxisDescriptor(title: "Count", range: safeRange(0, 截断窗口内的峰值 ?? 1))`，格式化为 `$0.formatted(.number.precision(.fractionLength(0)))` |
| `series` | 一条 `AXDataSeriesDescriptor(name: "", isContinuous: false)`，`AXDataPoint(x: 日期标签, y: Double(count))` |

⚠️ **只算 `effectiveDays`，不走 `renderInputs`**：后者会连带算 `buckets` 与 `weeks`，而
descriptor 一个都不用 ⇒ VoiceOver 拉一次描述符的成本从 ~10 ms 变成 ~22 ms。

⚠️ **格式化闭包不得写成 `"\(Int($0))"`**：`Accessibility` 框架在构造描述符时会拿
**非有限的探针值**调用它，`Int(非有限)` 直接 trap（源码记录：本 target 的空数据 descriptor 测试
**当场崩过**——`Fatal error: Double value cannot be converted to Int because it is either
infinite or NaN`）。走 `formatted` 既不 trap 也不会在大数上溢出。
空数据下不 trap 由 `emptyDescriptorsAreSafe` 钉住。

轴标题 `"Date"` / `"Count"` 走 `chartAXString(_:)`（a11y 描述符要 `String`）。

## 并发：数据类型必须 `nonisolated`

⚠️ **下游模块如果设了 `defaultIsolation(MainActor)`（Xcode 26 工程模板默认就写
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`），遵从 `HeatmapDay` 的类型必须标 `nonisolated`。**

不标会拿到 MainActor 隔离的 `Identifiable` conformance，满足不了 `Sendable`，报：

```
main actor-isolated conformance ... cannot satisfy conformance requirement
for a 'Sendable' type parameter
```

⚠️ **把类型提到文件作用域不够**——该设置作用于**整个 target**，解法是给该类型标 `nonisolated`。

⚠️ **为什么仍然要 `Sendable`**：图表的数据入参是调用方在自己模型层构造的值类型，
若被 `MainActor` 隔离，下游在后台线程准备数据时就用不了。这条约束是**有意的**。
（以上照录自 `ChartSupport.swift` 上 `ChartValue` 的文档注释；`HeatmapDay` 的注释明写
「与 `ChartValue` 同理，`nonisolated` 不可省」。）

## 使用示例 / Usage

```swift
import CoreDesignCharts
import SwiftUI

// ⚠️ 调用方定义自己的模型 —— 本库**不发货**具体数据 struct。
// ⚠️ `nonisolated` 不可省，理由见上一节。
nonisolated struct ContributionDay: HeatmapDay {
    let id = UUID()
    let date: Date         // 归一化到哪一天由图表按注入的 Calendar 决定
    let count: Int
}

struct ContributionsCard: View {
    let days: [ContributionDay]

    var body: some View {
        ActivityHeatmap(
            days,
            title: "Contributions",    // chrome ⇒ LocalizedStringResource
            tint: .green,
            // 显式注入才可测；不传则取 .current（默认正确）
            calendar: .current
        )
        .frame(height: 110)
    }
}

#Preview {
    let cal = Calendar.current
    let start = cal.date(byAdding: .day, value: -120, to: .now)!
    return ContributionsCard(days: (0..<120).map { offset in
        ContributionDay(
            date: cal.date(byAdding: .day, value: offset, to: start)!,
            count: [0, 0, 1, 2, 3, 5, 8][offset % 7]
        )
    })
    .padding()
}
```

## 相关

- [`network-graph.md`](network-graph.md) —— 力导向网络图，四个图表里唯一**会提示截断**的那个
- [`ring-chart.md`](ring-chart.md) —— 活动环，与本图表同为「截断但不提示」的一侧
- [`radar-chart.md`](radar-chart.md) —— 雷达图；它**没有**公开的规模上限

## ⚠️ 登记（`#270`）

`public struct ActivityHeatmap` 由 `PublicTypeCollector` 采到，已按公约判定法登记进
`docs/component-registry.json` 的 `components`：
`kind: prescriptive` / `decidedBy: pendingStep2` / `needsExtensionPoint: false`。
⚠️ **`decidedBy` 不是 `tiebreaker`**（PR #297 终审 I-1，本节已改写）：`#270` 初版填的是
`tiebreaker`，而公约步骤 3 门槛的兜底句**以「重跑发生过」为前置**、步骤 2 的停止规则又写着
「枚举视为未完成 ⇒ **不得据以走任一出口**」——本条的候选枚举与来源核验**一次都没做**。
⇒ 改记 `pendingStep2`：**如实说「还没判」**，条目缓办在**可逆的那一侧**
（规定性 / 不给扩展点），落点留给承接 issue **`#299`**。
⚠️ 公约明令**不得预判**重判结论 —— 补足枚举后可能落**任一**出口，含 `semantic`（要开扩展点）。
候选（日历月视图 / 折线时间序列）属排布差异、本该计入 ≥2，与另外三个图表同因。
`calendar:` 是可注入的行为依赖不是外观面。
文本参数 `title`（`LocalizedStringResource?`、无裸串孪生重载）登记为 **by-type**。
逐字理由见该条目的 `notes`；扫描根由单根扩成 `GuardScanRoots.allRoots` 的经过见 issue #270。

### ⚠️ `#299` 重判：`pendingStep2` → `step2`（出口 1，语义组件）（本节只增不改，上文保留为成因记录）

⚠️ **上一段是 `#270` / PR #297 当时的记录，不改写。现状**：`#299` 已按公约补做步骤 2 的
候选枚举与来源核验并重判，本条登记表字段现为
`kind: semantic` / `decidedBy: step2` / `needsExtensionPoint: true`。

**本轮走停止规则的「至少 3 个具名业界候选」这一支**，逐条给可核验来源（完整逐字理由与
URL 见 `docs/component-registry.json` 本条的 `notes`，此处只列骨架）：

1. **日历月视图** —— 产品 + 场景：Apple 自家 Activity / Fitness App 的 History 页把
   **每日活动读数**排成月历（三个活动圆环取代传统的日历事件）。三分法：现状是
   「按周成列 × 按星期成行」的连续长条网格，候选按月分块、每块 7 列 ⇒ 日格**彼此之间**
   的空间关系改变 ⇒ **排布**。
2. **月轨图（month track graph）** —— 产品 + 场景：Obsidian 社区插件 Contribution Graph，
   作者自陈可生成 GitHub 式贡献图 / 月轨图 / 日历轨图三种。⚠️ 这条来源的分量在于它是
   **同一个组件给出三种排布**，不是三个不同组件。⇒ **排布**。
3. **折线 / 柱状时间序列** —— GitLab Pajamas 的 Charts 页把 line / column chart 列为
   「按时间推移」的取值形态。三分法：网格 → 线性，命中排布定义逐字点名的「网格↔线性」
   ⇒ **排布**。

**作用域条款**：最接近的 `Timeline` 承担的是纵向事件流（节点列 + 连线 + 内容），不是按
日历格排布的密度图 ⇒ 条件 ③ 落空。⇒ 三个候选均未被排除。


⇒ **非皮肤且未被作用域排除的候选数 = 3 ≥ 2** ⇒ (A) 不成立、成因② ⇒ 按步骤 3 门槛
「(A) 不成立 ⇒ 重跑步骤 2」重跑一次 ⇒ 落**出口 1**：语义组件、需要扩展点。

⚠️ **扩展点尚未落地**：按 `Toast` 与 #59 的同款成法登记进
`ComponentExtensionPointGuard.knownMissingExtensionPoints`，实现移交 **`#312`**。
这不是「塞回红名单让判据闭嘴」—— 该集合的成文语义就是「**有承接 issue 的**已知缺口」。

⚠️ **公约缺口 `D-299-1`（Swift Charts 不在登记表里、作用域条款援引不了）同样适用于本条。**
