# NetworkGraph

力导向关系网络图（斥力 + 弹簧 + 向心力迭代解出节点位置）/ A force-directed relationship graph.

`NetworkGraph(nodes:edges:)`（`CoreDesignCharts/NetworkGraph.swift`，Issue #255）。**泛型视图**——
数据类型由调用方提供，本库**不发货**具体的数据 struct。

```swift
import CoreDesignCharts
```

⚠️ 本 target **有意不 `import Charts`**。Swift Charts 没有图布局的概念——节点位置要由
**斥力 + 弹簧 + 向心力**迭代解出，不是把数据映射到坐标轴（`NetworkGraph.swift` 头注释）。

⚠️ 向心力是 `#295` 补的：没有它时斥力（每对节点都有）压倒弹簧（只沿边），节点全被推到
容器边框并被钳位焊死，画出来是一圈矩形轮廓而不是力导向结果。
前后对照见 [`docs/issues/295-network-graph-before-after.png`](../issues/295-network-graph-before-after.png)。
代价是节点更密、不相连的簇被拉近；调参入口是 `NetworkGraph.centeringStrength`。

## API

```swift
public struct NetworkGraph<Node: GraphNode>: View {

    /// 本图表的边类型 —— 以调用方节点的 `ID` 相连。
    public typealias Edge = GraphEdge<Node.ID>

    /// 建议的节点上限。
    /// ⚠️ **力导向布局是每帧 O(n²)**。超过此数走"截断 + 关掉力导向"——**不抛断言**。
    /// ⚠️ 「退化为静态**环形**」只对 `.force` 成立；其余形态本就不跑迭代，截断后保持各自形态。
    public nonisolated static var recommendedNodeLimit: Int { 150 }

    /// 建议的**边数**上限。
    public nonisolated static var recommendedEdgeLimit: Int { 600 }

    public init(
        nodes: [Node],
        edges: [Edge],
        title: LocalizedStringResource? = nil,
        tint: Color = .accent,
        layout: NetworkGraphLayout = .force
    )
}
```

数据契约（`ChartSupport.swift`）：

```swift
public protocol GraphNode: Identifiable, Sendable where ID: Hashable & Sendable {
    /// 节点的显示名。
    var label: String { get }
}

/// 网络图的一条边。**以节点 `ID` 相连**，不持有节点本身。
///
/// ⚠️ 指向不存在节点的边会被**静默忽略**（不是错误：调用方常常先删节点后删边）。
public nonisolated struct GraphEdge<ID: Hashable & Sendable>: Sendable, Hashable {
    public let from: ID
    public let to: ID
    public init(from: ID, to: ID)
}
```

⚠️ **`GraphEdge` 本身已经是 `nonisolated` 的具体 struct**（本库唯一发货的数据类型）——
它不需要调用方遵从协议，直接 `GraphEdge(from:to:)` 构造即可。需要标 `nonisolated` 的
是调用方自己的 **`GraphNode`** 类型，见下方并发一节。

⚠️ **`Node.ID` 只要求 `Hashable`，不要求 `Comparable`**——组件内部的无向边归一化因此
不能靠排序，走的是「顺序无关的相等性 + 交换律哈希」。

## 布局形态扩展点（`#312` · 形态 D2）

```swift
public nonisolated enum NetworkGraphLayout: Sendable, Equatable, CaseIterable {
    case force      // 默认：环形播种 + 力导向迭代（现状形态）
    case circular   // 环形，不跑迭代
    case grid       // 按行列铺开（业界来源：AntV G6 的 grid）
    case layered    // 拓扑分层（业界来源：AntV G6 的 dagre）
}

NetworkGraph(nodes: nodes, edges: edges, layout: .layered)
```

⚠️ **只有 `.force` 会跑力导向迭代**，其余三个形态的位置**就是播种结果** ——
迭代会把它们揉回力导向的样子，那正是选那些形态的人不要的。
守这一条的是 `layout()` 里 `guard layout == .force, iterations > 0, …`
与判据 `NetworkGraphLayoutFormTests.onlyForceRunsIterations`。

⚠️ **`.circular` 不是新画法**：超 `recommendedNodeLimit` 时的降级形态本来就是环形
（见上面《规模上限》），本 case 只是把它提成可选项。

⚠️ **`.layered` 的分层规则（三条，各自被一次退化或一次终审换来）**：
1. **层号 = 已放前驱的最大层号 + 1**，没有已放前驱则第 0 层。
   ⚠️ **不是**「循环跑到第几轮」—— 那样互不相连的分量会被**串成一列**
   （50 个互不相连的 3-环、共 150 点，排成 150 层而不是 3 层）。
2. 有环、剥不动时**强制放一个再继续**（取剩余入度最小、并列取 `nodes` 数组里先出现者）。
   ⚠️ **不是**「把剩下的整体放到最后一层」—— 那会把环的**下游**一起卡住。
3. 强制放行**只在「还有未放后继」的节点里挑** —— 放一个纯汇点释放不了任何人，
   只会把指向它的边压成同层。
   ⚠️ 这里**有意不写「实测 N 张随机图，同层边 X → Y」**：那组数完全由随机图生成器的
   点数 / 边数分布决定，换一个生成器方向一致但数值全变 ⇒ **不可复现的数比没有数更坏**。

判据：`NetworkGraphLayoutFormTests` 的 `layeredSeparatesCycleDownstream` /
`layeredHandlesRootCycle`（规则 2）、`disjointCyclesShareLayers` /
`cycleBesideIsolatedNodeStartsAtZero` / `rankTakesDeepestPredecessor` /
`forcedNodeStillHonoursPlacedPredecessors`（规则 1）、
`forcedPickReleasesSomeone`（规则 3）—— 全部走 `layoutKey(for:)`。

⚠️⚠️ **`.layered` 明确不做的三件事（都会在有环的图上看得见）**：
- **不做交叉最小化**：同层的列序就是 `nodes` 数组顺序，两个分量会在同一行里交错。
- **不做边路由**：边是直线段。**回边与正向链共线** ⇒ 一条回边会从视觉上**穿过**
  中间的每一个节点（含另一个分量的节点）。
- **向上边消不掉，而且不止环造成的**：有环时至少有一条回边消不掉（形态本身的代价）；
  ⚠️ 除此之外，规则 2 的 tie-break（入度最小、并列取 `nodes` 顺序）会**先挑到环外的节点**，
  由此**多出**的向上边不是环造成的 —— 换 `nodes` 顺序就能变。
  规则 3 只是不再**平白**制造同层边，不是把向上边清零。
⇒ 复杂的有向图用 `.layered` 只能看出「大致的层次」，看不出连接关系；那种图仍应用 `.force`。

⚠️ **`layout` 必须进 `LayoutKey`**：`.task(id: key)` 靠它重算，漏了换形态不会重新布局。
（这条由**编译期**兜底：`LayoutKey` 少字段时 `layoutKey(for:)` 与调用点都编译不过。）

⚠️ **加 case 是 source-breaking**：`NetworkGraphLayout` 非 `@frozen`，
下游穷举 `switch` 不写 `@unknown default` 就会编译红 ⇒ 加 case 要走 BREAKING-CHANGES 登记。
（这仍比形态 B 的 public 协议可撤 —— 那个发出去就收不回。）

⚠️⚠️ **`.layered` 读边的方向，而本组件的边模型是无向的**：`effectiveEdges` 把互指的一对
**去重、只留先列出的那条**（见上面《无向边归一化》）。⇒ **层向由 `Edge.from → Edge.to` 定，
互指对按先列出者算** —— 同一份数据里 a→b 与 b→a 谁写在前面，会改变分层方向。
⚠️ **同层的列序 = `nodes` 数组顺序**，换节点顺序列位置就变（与 `.circular` 一致）。

⚠️ **超 `recommendedNodeLimit` 时的「退化为静态环形」只对 `.force` 成立**：
截断时 `iterations` 置 0，而 `.grid` / `.layered` 的播种**根本不看 `iterations`**，
截断后保持各自形态。

⚠️ **`.layered` 的宽层与高层都会挤**：一层 149 个点时**列**间距约 2.2 px（点直径 8 px）；
150 层时**行**间距约 1.6 px（画布高 300、上下各 10% 留白 ⇒ 可用 240 px）。
`.circular` 在 150 点时列间距也只有约 5 px（既有问题）；`.grid` 无此问题（约 22–27 px）。
⇒ **`.layered` 只适合层数与每层宽度都不大的图**，两个方向都没有自动缩放。

### 为什么是形态 D2（配置枚举）而不是 public 协议

`#312` 有一条**排序约束**：在 `D-299-1` 的修订回路走完前**不得走形态 B**
—— public 协议受祖父条款约束、**发布后不可撤**，而枚举与槽**可演进**。
逐条见 `docs/contract-defects.md` 的 `D-299-1` 与 `#312`。

## AD-F 退化输入契约

⚠️ **本图表不调用 `ChartDegeneracy`**——它的退化面是几何与拓扑的（重合点会 NaN、悬空边、
自环、退化容器尺寸），不是一维数值的。下表全部来自源码与 `DegenerateInputTests.swift`。

| 退化输入 | 判据位置 | 定义好的行为 |
|---|---|---|
| `nodes` 为空 | `body` 的 `nodes.isEmpty` | 渲染空态，文案 `"No data"`（`edges` 一并被忽略）。`layout(nodes: [], …)` 返回空字典。测试：`graph()` |
| 单节点 | `layout` 的 `guard iterations > 0, nodes.count > 1` | 直接返回环形初始位置；坐标**有限**。测试：`graph()` |
| **所有节点重合** | `layout` 的**环形初始位置**（不是随机、不是同点） | 不产生 NaN。⚠️ 所有节点重合时斥力方向未定义，归一化零向量会产生 **NaN**、整张图消失——环形初始保证任意两点初始就不重合 |
| 迭代中两点**距离 < 0.01** | 斥力回路的 `if dist < 0.01` | 用**确定性**的微小偏移拆开（`(i % 7 + 1) * 0.01` / `(j % 5 + 1) * 0.01`），**不是 `random`**——随机会让同一份数据每次布局不同、测试不可复现。布局确定性由 `deterministic` 一条钉住 |
| **边指向不存在的节点**（悬空边） | 渲染 `guard let a = layout[edge.from], let b = layout[edge.to] else { continue }`；`effectiveEdges` 的 `where visible.contains(...)` | **静默忽略**（`GraphEdge` 的契约明写），不产生 NaN，**也不占边额度、不触发假截断**。测试：`degenerateEdges`、`edgesToMissingNodesDoNotFakeTruncation` |
| **边指向被节点上限截断掉的节点** | 同上（`visible` 取自 `effectiveNodes`） | 同上——画不出来就不占额度。测试：`edgesToTruncatedNodesDoNotConsumeEdgeBudget`、`everyEffectiveEdgeHasVisibleEndpoints` |
| **自环 `a→a`** | 弹簧回路正常走 `dist = max(..., 0.01)` | 不产生 NaN。⚠️ **descriptor 里计度数 2**（图论定义），但它**画不出来**（零长度 stroke）——这条渲染/播报差异在源码里被显式记录并保留。测试：`degenerateEdges` |
| **重复 / 反向边**（`a→b` 与 `b→a`） | `UndirectedKey` 归一化 | 视为**同一条**，只计一次、只画一条。测试：`duplicateAndReverseEdgesCountOnce`、`duplicateEdgesDoNotFakeTruncation` |
| **重复 node id** | `effectiveNodes` 的 `firstUnique`（组件层）+ `layout` 内部再去一次 | **去重，保留首次出现**；不静默丢节点，也不让 `ForEach` 拿到重复 ID（SwiftUI 未定义行为）。测试：`duplicateIDs`、`graphDedupesAtComponentLevel`、`duplicateIDsDoNotFakeTruncation` |
| **容器尺寸为 0 / 极小（< 8pt）** | `loX = min(4, w / 2)`、`hiX = max(w - 4, loX)`（同理 y） | 不坍缩到容器外的同一点。⚠️ 写死 `4` 与 `w - 4` 时实测 `size = .zero` 让四个节点全落在 `(-3, -3)`。测试：`tinyContainerDoesNotCollapseOutside` |
| **尺寸含 `NaN` / `±∞`** | `layout` 的 `size.width.isFinite ? max(size.width, 1) : 1` | 坐标仍全部有限。⚠️ `max(x, 1)` 挡得住 0 与负数，**挡不住 `NaN`**（`max(NaN, 1) == NaN`）也挡不住 `∞`（`cos(θ) * ∞ == NaN`）。测试：`nonFiniteSize` |
| 零边 + 多节点 | 斥力回路照常跑 | 坐标全部有限、留在容器内。测试：`zeroEdges`、`staysInBounds` |

## 规模上限（FR-20）

两个上限，都是 `public nonisolated static var`：

| 常量 | 值 | 触发条件 |
|---|---|---|
| **`NetworkGraph.recommendedNodeLimit`** | `150` | **去重后**的唯一节点数 > 150 |
| **`NetworkGraph.recommendedEdgeLimit`** | `600` | **去重后、且两端都可见**的唯一无向边数 > 600 |

**超限行为固定为「截断 + 降级为静态布局 + 文档」，绝不 `precondition` / `fatalError`**——
「库代码对数据规模 `precondition` 就是让宿主 App crash」（`ChartSupport.swift` 硬约束 3）。
本图表的具体表现（三件事一起发生）：

1. **截断**：`firstUnique` 保留首次出现的前 N 个唯一节点 / 前 600 条唯一无向边，**收够即停**
   （不扫完全表）。顺序由 `TruncationPathTests` 逐条钉住。
2. **降级为静态布局**：`layoutKey(for:)` 把 `iterations` 置 **0** ⇒ `layout` 在
   `guard layout == .force, iterations > 0` 处直接返回播种位置，**力导向解算器整个关掉**。
   由 `truncationDegradesToStaticLayout` 与 `edgeLimitTriggersDegradation` 钉住。
   ⚠️ **「退化为静态*环形*」只对 `.force` 成立**——`.circular` / `.grid` / `.layered`
   本就不跑迭代，截断后保持各自形态（`iterations` 对它们没有作用）。
   ⚠️ 但**边的截断对 `.layered` 有实质影响**：分层完全由边算出，丢边会改变层数与层向。
3. **对用户可见的横幅**：`body` 在截断分支下在 canvas 下方渲染
   `"Showing the first %lld nodes"` 或 `"Showing the first %lld connections"`
   （`.coreFont(.caption2)` + `Color.contentTertiary`），数字写的是**实际渲染数**而非上限。

⚠️ **四个图表里只有本图表提示截断**，这是**显式定案**：它的截断会**改变布局算法**
（`.force` 下：力导向 → 静态环形；`.layered` 下：丢边改变分层），
用户看到的是一张"不一样的图"而不只是"少了几个"；
`ActivityHeatmap` / `RingChart` 的截断是**同质的**（少几天 / 少几环）⇒ 由调用方自行提示。

⚠️ **边超限会把力导向整个关掉，连节点没超限时也关**——理由被要求写明：力导向布局的簇结构
**完全由边决定**，丢掉 1/4 的边之后解出来的布局会把本该相邻的节点摆开、把不相干的摆到一起，
**它不是"精度差一点的图"，是一张会误导读者的图**；静态环形至少不声称任何拓扑关系。
代价如实记录：`n=100 / E=800` 这类**预算足够**的输入也会降级——**这是有意选择"不误导"
而不是"更好看"，不是性能所迫**。

⚠️ **`recommendedEdgeLimit == 600` 未实测**（源码自陈）：它是按节点表的实测配置（E = 2n = 300）
取的**两倍保守值**，与任何一个测得的量都没有推导关系。相邻的 `recommendedNodeLimit`
则有实测支撑（见下）。

⚠️ **`nonisolated` 在这两个常量上是承重的**：AD-F 的「超限固定为截断 + 降级 + 文档」契约要求
调用方**在自己的数据层**按这个数先行分页 / 抽样，而那是后台线程上的活。不标它，下游从
nonisolated 上下文读会拿到
`warning: main actor-isolated static property ... can not be referenced from a nonisolated context`，
而库自身四条验证命令全绿——判据在 `scripts/downstream-probe` 的 `readChartScaleLimits()`。

⚠️ 写成**计算属性**是因为泛型类型不支持 static **存储**属性；读法是
`NetworkGraph<MyNode>.recommendedNodeLimit`（泛型参数必须显式给出）。

### 性能与线程

迭代轮数随节点数收敛（`iterations(for:)`：`count <= 60 ? 90 : max(20, 90 * 60 / count)`）。
源码记的实测（`swift test -c release`，Apple Silicon，390×390，边数 = 2n，best-of-3）：

| n | 固定 90 轮 | 收敛后 |
|---|---|---|
| 50 | 80 ms | 80 ms（iter 90） |
| 100 | 311 ms | 187 ms（iter 54） |
| 150 | 709 ms | **283 ms**（iter 36） |

⚠️ **283 ms ≈ 17 帧** ⇒ 光靠收敛轮数救不了「上限内不掉帧」，所以**布局不在主线程算**：
`.task(id: layoutKey)` + `Task.detached(priority: .userInitiated)`，结果写回 `@State`。
布局是纯函数（`nonisolated`、入参全值类型、无随机），可安全 detach。

⚠️ **取消是协作式的、且必须显式传导**：`Task.detached` 按定义**不继承**父任务的取消
⇒ 外层用 `withTaskCancellationHandler { … } onCancel: { handle.cancel() }`，
**同时** `layout` 每轮开头检查一次 `Task.isCancelled`。少任一半，`GeometryReader` 在
resize / 旋转时逐帧启动的 solve 会全部跑满，把有界的卡顿换成**无界的 CPU 堆积**。

⚠️ 上表标注的是**稀疏图**（E = 2n）。n=150 的稠密图 E 可达 11 175，与斥力回路的配对数同量级
⇒ 实际耗时约为表中的两倍（源码自陈；`pairwiseWorkIsBounded` 只算 `n²·iter`，对 E 无感）。

## FR-7 文本边界

- **调用方给的 `Node.label`（节点名）是「内容」不是「UI 文案」** ⇒ 普通 `String`，
  **有意不强制 `LocalizedStringResource`**（FR-7 的边界声明，
  `GraphNode` 与它同一条约定）。
- **组件自带的 chrome 才本地化**：`title`（缺省 `.chart("Relationship graph")`）、空态文案
  `"No data"`、两条截断横幅 `"Showing the first %lld nodes"` /
  `"Showing the first %lld connections"` 都是 `LocalizedStringResource`，译文在
  `Sources/CoreDesignCharts/Resources/en.lproj/Localizable.strings`。
  两条横幅在表里且**译文保留 `%lld` 占位符**由 `truncationBannersAreRegistered` 钉住。

⚠️ `LocalizedStringResource.chart(_:)` 是 **`internal`**：它把 key 绑死在本 target 的
`Bundle.module`，下游传自己的 key 必然查不到，而查不到时 Foundation **原样返回 key、不报错**。

## 无障碍（AXChartDescriptorRepresentable）

```swift
extension NetworkGraph: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor
}
```

⚠️ 走 **`Accessibility` 框架**的 `AXChartDescriptor`（`import Accessibility`），**不是 Charts 框架**。

视图侧：`.accessibilityElement()` + `.accessibilityLabel(Text(self.title))` +
`.accessibilityChartDescriptor(self)`，挂在 `canvas` 上。

⚠️ **网络图没有数值轴**——用「每个节点的**度数**」作为可播报的量。

descriptor 暴露：

| 字段 | 取值 |
|---|---|
| `title` | `String(localized: self.title)` |
| `summary` | `nil` |
| `xAxis` | `AXCategoricalDataAxisDescriptor(title: "Node", categoryOrder: effectiveNodes.map(\.label))`——**截断后的那批** |
| `yAxis` | `AXNumericDataAxisDescriptor(title: "Connections", range: 0...Double(max(peak, 1)))`，格式化为 `$0.formatted(.number.precision(.fractionLength(0)))` |
| `series` | 一条 `AXDataSeriesDescriptor(name: "", isContinuous: false)`，`AXDataPoint(x: label, y: Double(度数))` |

⚠️ **度数按「截断后的边」且「两端都在 `effectiveNodes` 内」算**——与渲染同口径。
这曾是同一 bug 类的第三、第四个轴（边超限时"屏幕 2 条线、VoiceOver 播报 40 条"；
节点超限时被丢弃节点的度数把 `peak` 抬高、把所有点压向零）。现由
`graphDegreeUsesTruncatedEdges`、`graphDegreeSkipsDroppedNodes`、`overLimitTruncates` 钉住。

⚠️ **格式化闭包不得写成 `"\(Int($0))"`**：`Accessibility` 框架在构造描述符时会拿
**非有限的探针值**调用它，`Int(非有限)` 直接 trap（源码记录：本 target 的空数据 descriptor
测试**当场崩过**）。空数据下不 trap 由 `emptyDescriptorsAreSafe` 钉住。

⚠️ **自环在这里计度数 2**（`degree[from] += 1; degree[to] += 1` 落在同一 id 上）——图论定义如此，
但屏幕上画不出来。这条渲染/播报差异是**已知且有意保留**的。

轴标题 `"Node"` / `"Connections"` 走 `chartAXString(_:)`（a11y 描述符要 `String`）。

## 并发：数据类型必须 `nonisolated`

⚠️ **下游模块如果设了 `defaultIsolation(MainActor)`（Xcode 26 工程模板默认就写
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`），遵从 `GraphNode` 的类型必须标 `nonisolated`。**

不标会拿到 MainActor 隔离的 `Identifiable` conformance，满足不了 `Sendable`，报：

```
main actor-isolated conformance ... cannot satisfy conformance requirement
for a 'Sendable' type parameter
```

⚠️ **把类型提到文件作用域不够**——该设置作用于**整个 target**，解法是给该类型标 `nonisolated`。

⚠️ **为什么仍然要 `Sendable`**：图表的数据入参是调用方在自己模型层构造的值类型，
若被 `MainActor` 隔离，下游在后台线程准备数据时就用不了。这条约束是**有意的**。
（`GraphNode` / `HeatmapDay` 同理，`nonisolated` 不可省。）

⚠️ 本图表对此格外敏感：`layout` 是 `nonisolated` 纯函数、跑在 detached 任务里，
`LayoutKey` 也是 `Sendable`——数据类型不 `Sendable` 这条路就走不通。
（同一道摩擦在本文件里现身到第四次时，连 `CGVector` 的 `+=` / `-=` 运算符扩展都要标
`nonisolated`，否则 `layout` 里调用它会报 `#ActorIsolatedCall`。）

## 使用示例 / Usage

```swift
import CoreDesignCharts
import SwiftUI

// ⚠️ 调用方定义自己的节点模型 —— 本库**不发货**具体节点 struct。
// ⚠️ `nonisolated` 不可省，理由见上一节。
nonisolated struct Person: GraphNode {
    let id: String         // Node.ID 只需 Hashable & Sendable，不必 Comparable
    let label: String      // 节点名是「内容」⇒ String
}

struct TeamGraph: View {
    let people: [Person]
    let links: [(String, String)]

    var body: some View {
        NetworkGraph(
            // ⚠️ 超限会截断 + 关掉力导向 + 弹出横幅 ⇒ 在自己的数据层先收敛更可控。
            nodes: Array(people.prefix(NetworkGraph<Person>.recommendedNodeLimit)),
            // 边只以 ID 相连；指向不存在节点的边被静默忽略。
            edges: links.map { GraphEdge(from: $0.0, to: $0.1) },
            title: "Who works with whom",   // chrome ⇒ LocalizedStringResource
            tint: .blue
        )
        .frame(height: 300)
    }
}

#Preview {
    TeamGraph(
        people: (0..<14).map { Person(id: "n\($0)", label: "节点 \($0)") },
        links: (0..<20).map { ("n\($0 % 14)", "n\(($0 * 5 + 3) % 14)") }
    )
    .padding()
}
```

## 相关

- [`radar-chart.md`](radar-chart.md) —— 雷达图，数据契约是 `ChartValue`；它**没有**公开的规模上限
- [`ring-chart.md`](ring-chart.md) —— 活动环，同样「先去重、后截断」，但**不提示**截断
- [`activity-heatmap.md`](activity-heatmap.md) —— 贡献热力图，同样**不提示**截断；
  它的布局在**主线程**上算，与本图表的 detached 解算相反

## ⚠️ 登记（`#270`）

`public struct NetworkGraph` 由 `PublicTypeCollector` 采到，已按公约判定法登记进
`docs/component-registry.json` 的 `components`：
`kind: prescriptive` / `decidedBy: pendingStep2` / `needsExtensionPoint: false`。
⚠️ **`decidedBy` 不是 `tiebreaker`**（PR #297 终审 I-1，本节已改写）：`#270` 初版填的是
`tiebreaker`，而公约步骤 3 门槛的兜底句**以「重跑发生过」为前置**、步骤 2 的停止规则又写着
「枚举视为未完成 ⇒ **不得据以走任一出口**」——本条的候选枚举与来源核验**一次都没做**。
⇒ 改记 `pendingStep2`：**如实说「还没判」**，条目缓办在**可逆的那一侧**
（规定性 / 不给扩展点），落点留给承接 issue **`#299`**。
⚠️ 公约明令**不得预判**重判结论 —— 补足枚举后可能落**任一**出口，含 `semantic`（要开扩展点）。
候选（邻接矩阵 / 分层树布局）属排布差异、本该计入 ≥2，与另外三个图表同因。
文本参数 `title`（`LocalizedStringResource?`、无裸串孪生重载）登记为 **by-type**。
⚠️ `NetworkGraphRenderProbe` 是 `@_spi(CoreDesignBenchmark)` 的仪器，不是 `View` ⇒ 不进登记表。
逐字理由见该条目的 `notes`；扫描根由单根扩成 `GuardScanRoots.allRoots` 的经过见 issue #270。

### ⚠️ `#299` 重判：`pendingStep2` → `step2`（出口 1，语义组件）（本节只增不改，上文保留为成因记录）

⚠️ **上一段是 `#270` / PR #297 当时的记录，不改写。现状**：`#299` 已按公约补做步骤 2 的
候选枚举与来源核验并重判，本条登记表字段现为
`kind: semantic` / `decidedBy: step2` / `needsExtensionPoint: true`。

**本轮走停止规则的「至少 3 个具名业界候选」这一支**，逐条给可核验来源（完整逐字理由与
URL 见 `docs/component-registry.json` 本条的 `notes`，此处只列骨架）：

本条的来源是这批里最硬的一份：设计体系 Ant Design 的图可视化体系 AntV G6，
**布局总览页把同一份图数据的布局列为可替换项**，共 20 个具名布局，其中：

1. **分层（dagre）布局**、2. **环形布局**、3. **网格布局** —— 三者改变的都是节点
**彼此之间**的落点 ⇒ 按三分法均属**排布**。

⚠️ **本条另有一条源码内自证**：现状代码在节点数超过 `recommendedNodeLimit` 时**已经降级为
静态环形布局**（见上文《超限》一节）⇒ 候选 2 的形态在本组件内**已经实现过**，
「只有一种合理长相」这句在本条上被自己的源码直接证伪。

**查过但来源模板不符、不计入**：邻接矩阵 —— InfoVis 文献把它与 node-link 图并列为
同一份网络的两种表示，形态真实，但学术论文既非设计体系也非产品。

**作用域条款**：`OutlineTree`（storyui）承担的是三层大纲的**缩进列表**，不是 node-link 图的
分层布局 ⇒ 条件 ③ 落空；登记表里没有其它条目承担环形 / 网格布局。⇒ 三个候选均未被排除。


⇒ **非皮肤且未被作用域排除的候选数 = 3 ≥ 2** ⇒ (A) 不成立、成因② ⇒ 按步骤 3 门槛
「(A) 不成立 ⇒ 重跑步骤 2」重跑一次 ⇒ 落**出口 1**：语义组件、需要扩展点。

⚠️ **扩展点已由 `#312` 落地**（形态 D2 配置枚举 `NetworkGraphLayout`，四个 case），
本条已从 `ComponentExtensionPointGuard.knownMissingExtensionPoints` 移出
（曾按 `Toast` 与 #59 的同款成法暂登记在那里）。
⚠️ **有意不发 public 协议**（形态 B）：`D-299-1` 的修订回路未走完前不得发布不可撤的协议，
配置枚举可演进。判据：`NetworkGraphLayoutFormTests`。

⚠️⚠️ **本条不适用 `D-299-1`（`#315` 终审 C-2 更正）**：上一版这里原样抄了给三个图表用的
那句「同样适用于本条」，而它**被本仓自己的源码逐字证伪** —— 本条的三个候选是 **dagre / 环形 /
网格三种图布局**，而 Swift Charts **画不出来**本件：它没有图布局的概念——节点位置要由
**斥力 + 弹簧**迭代解出，不是把数据映射到坐标轴；`CLAUDE.md`
也把本件列为「Swift Charts **原生画不出来**的四类图表」之一；Swift Charts 没有任何 node-link
mark ⇒ **这三个候选没有任何框架级承担者**，`D-299-1` 那条「候选的真实承担者是宿主平台框架」的
前提在本条上根本不成立 ⇒ 本条的落点在这一侧**没有翻转风险**。
⚠️ 成因如实记：那段样板被逐条抄了五遍而没有逐条重判 —— 见 `docs/contract-defects.md` 的
`D-299-1`。
⚠️ **上面这句只管 `D-299-1`，不是全称句**（`#315` 终审 C-1）：同批新开的 `D-299-2` **是**
`OrbitingLogos` 落点的决定性依据，本轮**确实**被用来定了那一条的落点，见
`docs/components/orbiting-logos.md` 与 `docs/contract-defects.md` 的 `D-299-2`。

