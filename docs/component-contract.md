# 组件 API 公约 / Component API Contract

本文件是 CoreDesign 与 StoryUI 的**组件 API 地基**——回答「这个组件该长什么样的 API」。

> 视觉地基（token 取值理由）在 [`DESIGN-FOUNDATION.md`](DESIGN-FOUNDATION.md)。
> 两者不同轴：那份管「这个数字为什么是这个数字」，本份管「这个参数为什么是这个形状」。

## 1. 判定法：语义组件 vs 规定性组件

**照着走，不要凭感觉。** 按顺序回答，第一个命中的答案即结论。

1. **Apple 有对应的原生样式协议吗？**（`ButtonStyle` / `LabelStyle` / `ProgressViewStyle`
   / `DisclosureGroupStyle` / `ToggleStyle` / `MenuStyle` …）
   → **有** ⇒ 语义组件，且**必须实现原生协议**（优先级固定，细则见第 2 节）
2. **调用方会合理地想要一个「看起来完全不同、但含义相同」的版本吗？**
   ⚠️ **操作化门槛**：能**当场举出 ≥2 个业界真实存在的替代形态**才算「会」。
   举不出、或举得犹豫 ⇒ **视为答不上来，落步骤 4**。
   例：评分 —— 星（App Store）/ 数字条（IMDb）/ 表情（NPS 量表）⇒ 举得出，答「会」。
   例：骨架屏占位 —— 只有一种合理长相 ⇒ 举不出，落步骤 4。
   → **会** ⇒ 语义组件，需要扩展点
3. **组件的视觉是它含义的一部分吗？**（换个长相就不是这个东西了）
   → **是** ⇒ 规定性组件，不给扩展点
4. **以上都答不上来** ⇒ **tiebreaker（见下）**

### ⚠️ Tiebreaker：两可时怎么办

**默认判为规定性组件 / 不给扩展点，并在登记表里标 `undecided` + 写明两可的理由。**

**为什么默认这一侧**：少给扩展点是**可逆的**（后续按需补，不破坏 API）；
多给扩展点**不可逆**（public 协议一旦发布，删它是破坏性变更）。

⚠️ **这条 tiebreaker 是必需的，不是保险措施**：没有它，全量分类会在遇到真正的
边界组件时来回改判定法而**永不终止**。判定法的目的是**产出结论**，不是产出真理。

## 2. 样式扩展点：三选一

按第 1 节判定后，扩展点只有三种合法形态：

| 形态 | 何时用 |
|---|---|
| **A. 实现 Apple 原生协议** | 只要 Apple 提供了对应协议 |
| **B. 自定义样式协议** | 语义组件，且 Apple 无对应协议 |
| **C. 不给扩展点** | 规定性组件 |

### ⚠️ 优先级固定：A 永远优先于 B

**Apple 有原生协议时必须用原生的，不许自造平行体系。**

本仓已有的正确先例（形态 A）：`CoreLabelStyle` / `CoreProgressViewStyle` /
`CoreDisclosureGroupStyle` / `CoreLabeledContentStyle`（均在
`Sources/CoreDesign/Components/Style/`）、以及 `Button` 的各 `ButtonStyle` 实现。

本仓已有的形态 B 先例，**公约认可**：`SegmentedControlStyle`、`BannerStyle`
——Apple 对这两类控件确无原生协议。

> ⚠️ `SegmentedControl.swift` 的注释里有一句值得抄给每个组件作者看：
> 「此前的 `glass: Bool` **布尔 hack** 升级为本协议。」
> **这个库自己已经做过一次「布尔开关 → 样式协议」的升级并称前者为 hack**,
> 本公约只是把它变成通行规矩。

### 边界条款：样式不得携带行为

样式协议只描述**长什么样**。手势粒度、校验规则、是否可交互 —— 都不进样式协议。
理由：同一个组件换个样式不该改变它**做什么**，否则调用方无法预期。

⇒ 形态 A/B 都受这条约束。行为类参数走第 3 节。

## 3. 配置开关的四条替代路径

**规则**：public API 里不要出现 Bool 参数。想加一个时，从下面四条里选。

### ⚠️ 头号反例：把 Bool 换成两 case enum **不是**替代路径

J-1 的谓词是「**任何 Bool**」，做的是纯符号比对 ⇒
`bordered: Bool` → `border: BorderStyle`（`.bordered` / `.none` 两个 case）
**机器判据完全挡不住**，而它只是换了名字的同一个布尔旋钮。

**这是最廉价的逃逸路径，而公约文档是唯一能封住它的地方。**

**判据**：两 case enum 只有在**存在真实的第三 case 或连续取值域**时才算替代路径。
造不出第三种合理取值，就说明它本来就是布尔旋钮 ⇒ 回去从下面四条里重选。

### 3.1 专用 init / 专用参数

**适用**：布尔背后其实是一个**被压扁的取值域**。

例：`Rating(allowsHalfStar: Bool)` → `Rating(step: Double)`。
`Rating.swift:19` 证明 `step` 本来就是内部概念，Bool 只是它的二值投影。

**反例**：`Badge(outlined: Bool)` 换成 `Badge(borderWidth: CGFloat)` —— **错**。
描边与否是**外观变体**，不是数值刻度；它该走样式（第 2 节），不是换个参数类型。

### 3.2 子视图槽（`@ViewBuilder`）

**适用**：布尔控制的是**要不要渲染一块调用方能提供的内容**，尤其当它配着回调时。

例：`Tag(removable: Bool, onRemove: (() -> Void)?)` → 尾随 `@ViewBuilder` 槽。
一并消除 `Tag.swift:83` 记录的自相矛盾状态：「`onRemove == nil` 时按钮仍可见但
`.disabled(true)`」。

**反例**：把 `Skeleton(isLoading: Bool)` 变成槽 —— **错**。它控制的是
**组件自身处于哪个状态**，不是「渲染谁提供的内容」。那种情况见 3.4。

### 3.3 Modifier

**适用**：这个选择**独立于组件的构造**，且**表达一个语义选择**。

⚠️ **modifier 携带 Bool 不自动合规。** 判据：

| | 合规 | 不合规 |
|---|---|---|
| 形态 | modifier 表达**语义选择** | modifier 承载**布尔旋钮** |
| 例 | `.surface(.content)` —— `kind` 选表面语义 | `.surface(bordered: false)` |

**反例**：把 `Card(bordered: Bool)` 挪成 `.card(bordered: false)` —— **错**。
换了个位置的同一个布尔旋钮，不是替代路径。

### 3.4 环境值

**适用**：这个选择**作用于一整棵子树**，或**已有系统环境值表达同一件事**。

⚠️ **优先复用系统环境值，不要自造平行开关**。
例：`Rating(isReadOnly: Bool)` 与 `@Environment(\.isEnabled)` 语义重叠
——`Rating.swift:20` 写明「`isReadOnly` 或外层 `.disabled(true)` 时手势整体不挂载」,
**两条路径做同一件事**。

**反例（重要）**：直接把 `isReadOnly` 删掉、让调用方用 `.disabled(true)` —— **不够**。
`disabled` 会连带**禁用态的灰色外观**，而只读评分的典型用途是「显示平均分」,
需要**正常外观**。⇒ 这类「行为重叠但视觉诉求不同」的情形，
正确解法可能是**拆成两个语义组件**（交互 `Rating` vs 展示 `RatingDisplay`,
类比 `Slider` vs `Gauge`）。**取舍留给 #41，但不许默认归并。**

## 4. 文案类型三分法

| 类别 | 判别特征 | 类型 |
|---|---|---|
| **A. 组件自带 chrome** | 文案**写在组件源码里**，调用方看不见也改不了 | `LocalizedStringResource` |
| **B. 调用方传入的可本地化文案** | 调用方传，但内容是**界面文案**（标题、说明、占位符） | 见下 |
| **C. 用户数据** | 调用方传，内容是**用户自己产生的**（设定名、章节标题） | `String`，**不得改** |

⚠️ **B 类是 CoreDesign 文本 API 的大头，不是 A 类。** `SectionHeader` /
`InsetGroupedSection(header:footer:)` / `ProgressIndicator(text:)` / `SettingsRow` 都是 B。

⚠️ **B 类改造有隐藏破坏性**：现有 B 类 API 有成文的 `Bundle.main` 解析语义
（`SectionHeader.swift`）。改 `LocalizedStringResource` 会**改变 bundle 解析行为**
——属破坏性变更，必须进 `docs/BREAKING-CHANGES.md`（归 #42）。

**本仓现状**：`Package.swift` 已有 `defaultLocalization: "en"`，`en.lproj/Localizable.strings`
里 chrome 已本地化。⇒ **CoreDesign 侧不需要新增本地化基建**；
缺 `defaultLocalization` 的是 **StoryUI**（归 #43）。

## 5. 环境值清单

组件**必须**响应下列环境值。逐条写明「怎么算响应到位」：

| 环境值 | 响应要求 |
|---|---|
| `isEnabled` | 禁用时停止交互**且**呈现禁用外观。⚠️ 不要另造 `isReadOnly` 这类平行开关（见 3.4） |
| `controlSize` | 尺寸随之变化，走 `CoreControlMetrics`，不写死数值 |
| `dynamicTypeSize` | 文字随之缩放；容器**换行而非截断** |
| `layoutDirection` | RTL 下方向性元素（chevron、进度、手势方向）镜像 |
| `tint` | 强调色取自 `tint`，不硬编码色相 |
| `accessibilityReduceMotion` | 开启时去掉装饰性动画（保留必要的状态转场） |

**现状交叉核对**：`Rating` 已读取 `controlSize` / `isEnabled` / `layoutDirection`
（`Rating.swift:36-38`）——本清单与它不矛盾，是对它的推广。

## 附录 A：判定法的实测走查

用 PRD 点名的**两可样本**验证判定法能产出确定结论。
⚠️ 出现「卡住、无法判定」即判定法失败——必须回去改，不许在这里打圆场。

### A.1 `Rating(allowsHalfStar:)`

PRD 原文：「控制**手势步进粒度**（0.5 vs 1.0），同时影响渲染 ⇒ 外观还是行为？」

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ❌ 无 `RatingStyle` 之类 |
| 2. 想要「长相不同、含义相同」的版本吗？ | ✅ **想要**——星 / 数字 / 表情 |
| — | ⇒ **语义组件，需要扩展点** |

⇒ 结论：**语义组件，需要扩展点**。**未卡住。**

### A.2 `Tag(removable:)`

PRD 原文：「与 `onRemove` 闭包耦合 ⇒ 既是外观也是行为」。
`Tag.swift:83` 实证：「`onRemove == nil` 时按钮仍可见但 `.disabled(true)`」
——一个参数控制了「画不画按钮」与「按钮能不能点」两件事。

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ❌ 无 |
| 2. 想要「长相不同、含义相同」的版本吗？ | ❌ chip 的长相就是它的含义 |
| 3. 视觉是含义的一部分吗？ | ✅ 是 |
| — | ⇒ **规定性组件，不给扩展点** |

⇒ 结论：**规定性组件，不给扩展点**。**未卡住。**

### A.1 续：`allowsHalfStar` 这个参数改成什么形状

`Rating.swift:19` 的文档注释写明它算出 `step`（`allowsHalfStar ? 0.5 : 1.0`）供手势
取整用 ⇒ 按 **3.1**，它是**被压成布尔的连续量**，替代路径是**专用参数**（`step`）。

⚠️ **不塞进样式协议** —— 手势粒度是行为，违反第 2 节的「样式不得携带行为」。

### A.2 续：`removable` 这个参数改成什么形状

Bool + 配套闭包 ⇒ 按 **3.2** 走**子视图槽**，一并消除 `Tag.swift:83` 记录的自相矛盾
状态：「`onRemove == nil` 时按钮仍可见但 `.disabled(true)`」。

### A.3 `surface(_ kind:, bordered: Bool = true)`（modifier 形态）

这不是组件，是 **View extension 上的 public modifier** —— 用来验证 **3.3** 的 modifier 条款。

`SurfaceModifier.swift` 的文档注释：「`bordered` 是否画描边，默认 `true`。
置 `false` 只保留背景 + 圆角、去描边」。

| 第 3 节判据 | 结论 |
|---|---|
| modifier 表达**语义选择**？ | `.surface(.content)` 的 `kind` 是 ✅ |
| modifier 承载**布尔旋钮**？ | `bordered` 是 ❌ **不合规** |

⇒ 结论：**不合规**。最终处置（豁免或改造）**留给 #41 试点**，本任务只给判据。
⚠️ 这条会让 J-1 上线后到 #41 完成前保持红——**预期状态**，见 #39 的交付说明。

### A.4 `PinCode` —— 一个真的落到 tiebreaker 的样本

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ❌ 无 |
| 2. 能举出 ≥2 个业界真实替代形态吗？ | 分格框 / 锁屏圆点 / 单条下划线 —— **举得出，但都还是「一格一位」的变体**，是否算「长相完全不同」有真实分歧 ⇒ **举得犹豫** |
| — | ⇒ 视为答不上来，**落步骤 4** |
| 4. tiebreaker | ⇒ **规定性组件 / 不给扩展点**，`decidedBy: tiebreaker` |

⇒ 结论：**未卡住**，且这次真的走到了 tiebreaker。

⚠️ 这一条的价值不在结论，而在**证明 tiebreaker 这条路径真的通**。
没有它，tiebreaker 就是一段从未被执行过的代码。
