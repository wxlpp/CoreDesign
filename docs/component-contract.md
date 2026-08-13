# 组件 API 公约 / Component API Contract

本文件是 CoreDesign 与 StoryUI 的**组件 API 地基**——回答「这个组件该长什么样的 API」。

> 视觉地基（token 取值理由）在 [`DESIGN-FOUNDATION.md`](DESIGN-FOUNDATION.md)。
> 两者不同轴：那份管「这个数字为什么是这个数字」，本份管「这个参数为什么是这个形状」。

## 1. 判定法：语义组件 vs 规定性组件

**照着走，不要凭感觉。** 按顺序回答，第一个命中的答案即结论。

> ⚠️ **祖父条款（先于以下步骤判断）**：组件已经**发布了公开的样式协议**
> （如 `SegmentedControlStyle`、`BannerStyle`）⇒ **不再走下面的判定法**，
> 直接登记 `kind: semantic` + `decidedBy: precedent`。判定法只约束**新增**
> 扩展点的决策，不倒过来审判已发布协议——public 协议一旦发布，删它是
> 破坏性变更，判定法不可能推翻既成事实。
>
> ⚠️ **弃用条款（先于以下步骤，也先于上面的祖父条款）**：组件已标记
> `@available(*, deprecated)`（如 `ProgressBar`）⇒ **不分类**，登记表记
> `kind: excluded` 并附一句弃用去向说明。判定法回答的是「这个组件现在该
> 长什么 API」——对一个即将删除的组件问这个问题没有意义。
> ⚠️ **本条优先于祖父条款**：即将删除的组件有没有自有协议都一样，不必再问。
> （现存组件无一同时命中——唯一的弃用件 `ProgressBar` 没有自有协议——但顺序要写死,
> 否则两条都自称「先于以下步骤」，将来撞上就分叉。）

1. **Apple 有对应的原生样式协议吗？**（`ButtonStyle` / `LabelStyle` / `ProgressViewStyle`
   / `DisclosureGroupStyle` / `ToggleStyle` / `MenuStyle` …）
   ⚠️ **操作化判据**：**有** = 能写出一句「本组件可改写为『系统控件 + 该协议的
   自定义 style』且不丢功能」的声明，**且该协议有公开的 `makeBody` 定制点**
   （第三方能实现）。写不出这句声明、或协议无公开定制点 ⇒ **视为「无」，
   继续步骤 2**（例：macOS 的 `.radioGroup` `PickerStyle` 没有公开的
   `makeBody` 定制点，第三方无法实现 ⇒ 对 `Radio` 视为「无」）。
   → **有** ⇒ 语义组件，且**必须实现原生协议**（优先级固定，细则见第 2 节）
2. **调用方会合理地想要一个「看起来完全不同、但含义相同」的版本吗？**
   ⚠️ **操作化门槛**：能**当场举出 ≥2 个业界真实存在的替代形态**才算「会」
   （**替代 = 不含组件当前的形态**）。
   ⚠️ **三个出口，不是两个**：
   · 举得出 ≥2（且非皮肤变体）⇒ **会**，语义组件
   · 举不出，**但能说清「长相即含义」的理由** ⇒ **不会**，进**步骤 3**
   · 举不出**且说不清理由**、或**举得犹豫** ⇒ 视为答不上来，**落步骤 4**
   （第一版只写了后两个出口中的一个，于是「不会 → 步骤 3」这条路在字面上不存在、
   步骤 3 成死代码——而附录 A.2 走了步骤 3、A.4 落了步骤 4，**两个样本对同一门槛
   给出相反走法**。影响的是 `decidedBy` 元数据与「写明两可理由」的义务归属。
   **这不是本条款唯一一次同类翻车**：补上皮肤变体条款后，Issue #38 Task 2 走查
   出第二起——皮肤变体候选与「能说清长相即含义的理由」两个判据同时命中时，
   `AsyncButton`/`Badge`/`Carousel`/`StreamingIndicator` 四个样本再次分裂成两条
   相反走法，见下方皮肤变体条款末尾的裁断。**同一种病（新增判据分支时没有连带
   审视它与既有出口的交叉情形）在同一条款里犯了两次**——补丁式加新句、不回头
   检查旧句是否还能自洽，本身就是本 epic 反复出现的失败模式。）
   ⚠️ **皮肤变体不计入 ≥2**：候选形态如果共享**同一个底层布局结构**，只是把
   结构里的单元换了种画法（例如都是「每位一个独立格子」，格子本身画成方框 /
   圆点 / 下划线），这些算**同一结构的皮肤变体**，不算「长相完全不同」，
   不计入 ≥2——即使能举出三个，只要它们共享同一个布局骨架，就仍算**举得犹豫**。
   ⚠️ **与出口 2 的交叉情形已裁断**：皮肤变体候选之外，若还能额外说清一句
   「长相即含义」的理由，**不要因此改套出口 2（『举不出但能说清理由 ⇒ 步骤 3』）**。
   「不计入 ≥2」不等价于「举不出」——它就是「举得犹豫」本身：本段结论词与出口 3
   逐字同款，是刻意的绑定，不是巧合措辞。「长相即含义」的理由此时只能
   作为 tiebreaker 默认结论的**佐证**写进 notes，不能借它跳过 tiebreaker、直接判
   `decidedBy: step3`。落点固定为**步骤 4，`decidedBy: tiebreaker`**。
   例：评分——当前形态是星（App Store 风格，离散符号计数），**替代枚举不把它算进去**：
   数字条（IMDb，连续条形）/ 表情（NPS 量表，单一图形）⇒ 两者**结构本身不同**、
   且都**不含当前形态**，举得出 ≥2，答「会」。
   例：骨架屏占位 —— `SkeletonCircle`/`SkeletonLine`/`SkeletonRect` 分别用固定几何形状
   （圆形 / 圆角矩形 / 矩形）代表头像 / 文本行 / 图片卡片将来会长出的内容形状：圆形换成
   方形，占位对象就从「头像」读成「图片」——形状本身就是它在声明自己占位哪类内容，
   换形状即换语义。举不出替代形态，且**能额外说清「长相即含义」的理由**（不是仅仅
   「只有一种合理长相」这句消极描述），进步骤 3。
   ⚠️ **「只有一种合理长相」这个措辞本身不构成理由**——它只说明「举不出」，而据出口
   2/3 的分野，光「举不出」还落不到步骤 3，必须**额外**说清为什么换了长相就不是这
   东西，否则该往步骤 4 走（对照皮肤变体条款：候选存在但不计入 ≥2 时同样是「举得
   犹豫」而非自动获得步骤 3）。见登记表 `SkeletonCircle`/`SkeletonLine`/`SkeletonRect`
   三条判例——notes 对应的正是「形状 = 占位内容类型的声明」这条积极理由，不是「没有别的
   选择」这句消极描述。（`Skeleton` 本身是容器，notes 理由是「redacted + shimmer 叠加
   固定」，与「形状 = 内容类型」这条推理无关，不计入本处引证。）
   → **会** ⇒ 语义组件，需要扩展点
3. **组件的视觉是它含义的一部分吗？**（换个长相就不是这个东西了）
   → **是** ⇒ 规定性组件，不给扩展点
4. **以上都答不上来** ⇒ **tiebreaker（见下）**

### ⚠️ Tiebreaker：两可时怎么办

**默认判为规定性组件 / 不给扩展点**，并在登记表里记
`kind: prescriptive` + `decidedBy: tiebreaker` + **写明两可的理由**。

> **登记表** = `docs/component-registry.json`（随 #38 落地）。`kind` 字段取值
> `semantic` / `prescriptive` / `excluded`（已弃用组件，见上方弃用条款）；
> `decidedBy` 字段记录这次判定是由判定法的哪一步产出的结论
> （**`step1`** / `step2` / `step3` / `tiebreaker`），或 `precedent`（见上方祖父条款,
> 不经判定法、直接沿用已发布协议的先例结论），或 `exclusion`（见上方弃用条款，不经判定法，
> `kind: excluded` 组件专用）。
> ⚠️ **`step1` 不能漏** —— 附录 A.0（`CheckBox`）演示的正是「步骤 1 答『有』」
> 直接产出结论的情形。第一版枚举漏了它，而交接文件 `38.md` 的 schema 里有
> —— 两份规范性文档打架，且公约是更权威的那份。
> ⚠️ **这不是第一次**——`exclusion` 同样只在登记表（`ProgressBar` 条目）与守卫代码
> （`Tests/CoreDesignTests/ComponentRegistryGuard.swift` 的 `validDecidedBy`）里出现过，
> `38-plan.md:27-28` 把它记成对 `38.md` AC 的偏离，却从未回写进本公约——于是弃用条款
> 强制生成的 `kind: excluded` 条目，长期没有一个合法的 `decidedBy` 取值能描述它。上面
> 这段警告讲的正是「枚举漏值 ⇒ 两份规范性文档打架 ⇒ 公约是更权威的那份」，而它自己
> 上方 3 行正在重演同一件事——已在此补上 `exclusion`。
> ⚠️ **后来又发生了第三次**（`textParams[].category` 的 `by-type`）。⇒ 三例的完整对照
> 与**通则**（哪一方有义务同步、范围限哪几个字段）见第 4 节末尾的
> **「通则：判定法枚举的三方同步义务」**——**本条款不再逐次追记，以那一处为准**。

**为什么默认这一侧**：少给扩展点是**可逆的**（后续按需补，不破坏 API）；
多给扩展点**不可逆**（public 协议一旦发布，删它是破坏性变更）。

⚠️ **这条 tiebreaker 是必需的，不是保险措施**：没有它，全量分类会在遇到真正的
边界组件时来回改判定法而**永不终止**。判定法的目的是**产出结论**，不是产出真理。

## 2. 样式扩展点：三选一

按第 1 节判定后，扩展点只有三种合法形态：

| 形态 | 何时用 |
|---|---|
| **A. 实现 Apple 原生协议** | **第 1 节判定为「有」时**（⚠️ 终审 M3：不是「只要 Apple 提供了对应协议」这种字面存在性——第 1 节的操作化判据已经排除了「协议无公开 `makeBody` 定制点」的情形，例如 `RadioGroup` 面对的 `.radioGroup` `PickerStyle`；两句对同一组件必须给出同一个答案，此处与第 1 节对齐，不能各判各的） |
| **B. 自定义样式协议** | 语义组件，且 Apple 无对应协议（含第 1 节判定为「无」的情形） |
| **C. 不给扩展点** | 规定性组件 |

### ⚠️ 优先级固定：A 永远优先于 B

**Apple 有原生协议时必须用原生的，不许自造平行体系。**

本仓已有的正确先例（形态 A）：`CoreLabelStyle` / `CoreProgressViewStyle` /
`CoreDisclosureGroupStyle` / `CoreLabeledContentStyle`（均在
`Sources/CoreDesign/Components/Style/`）、以及 `Button` 的各 `ButtonStyle` 实现、
`CheckBoxToggleStyle: ToggleStyle`（`CheckBox` 组件，见附录 A.0）。

⚠️ **「正确先例」仅指「实现原生协议」这一点**：`SolidButtonStyle.swift` /
`LightButtonStyle.swift` 的参数表内至今带 `glass: Bool` public 参数——正是本节
下方引用的 `SegmentedControl.swift` 注释所斥的「布尔 hack」，**不构成整体背书**，
其 `glass: Bool` 仍属第 3 节待处置项。

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

### ⚠️ 例外：Style Configuration 上的状态描述 Bool 不受本节约束

**Style Configuration 类型上向 style 实现者描述状态的 Bool 字段**（对标 Apple 的
`ButtonStyleConfiguration.isPressed` / `ToggleStyleConfiguration.isOn`）**不是
配置开关，不受本节约束**。第 2 节要求的形态 A/B 结构性地必然产生这类 Bool——
`SegmentedControlStyleConfiguration.Segment.isSelected`（`SegmentedControl.swift`）
就是一例：它描述的是「这个 segment 现在是不是选中态」，供 style 实现者据此画出
选中 / 未选中的外观差异。下面四条替代路径对它全部无意义（不是被压扁的取值域、
不是可选内容槽、不独立于组件构造、不作用于一整棵子树），终局条款的 (b)「论证
删掉」也不成立——style 实现者不知道当前状态就画不出正确外观。

### ⚠️ 终局条款：四条都不适用时怎么办

下面四条不保证穷尽——不是要死磕出一条勉强凑数的路径。四条都不适用时，
**按顺序**试两个出口（**不是并列二选一**）：

**先试 (b)：论证这个参数本不该存在，走删除。**
四条选不出往往正说明这个 Bool 从一开始就不该进 public API，不必强行套进某一条。
⚠️ 这是现实中最常见的处置，但只要没写出来，执行者面对「四条都不适用」时就只会
卡住或硬凑，不会想到「也可以直接删掉」。

**(b) 不成立才用 (a)：记入豁免基线** —— 写入 `docs/bool-exemptions.json`（#39 已落地），
理由里**必须包含「为什么删不掉」**，而不只是「为什么四条都不适用」。
守卫会真的查这一点：理由文本必须出现「删除」二字，否则判红
（`Tests/CoreDesignTests/BoolExemptionGuard.swift` 的 `exemptionBaselineIsWellFormed`）。

⚠️ **豁免基线是两份文件，加一条豁免要改两处**（#39 的一/二文件选型裁决）：
`docs/bool-exemptions.json` 是清单本身（每条四字段：`parameter` / `reason` /
`decidedBy`（裁决人）/ `decidedOn`），`docs/bool-exemptions-baseline.json` 只记一个
上限 `maxEntries` 与这次抬高的 `raisedBy` / `raisedOn` / `rationale`。守卫要求
**清单条目数与 `maxEntries` 严格相等**——清单增一条必须同轮抬高上限，缩一条必须同轮
下调（**不留额度**，否则未来的新增可以免审吃掉这段 slack）。
⇒ 这么切的理由是：**内容**（改措辞、补日期，常改且无害）与**容量**（放宽豁免面，
罕改且必须署名）是两根不同的轴。切开之后，`git log -p docs/bool-exemptions-baseline.json`
就是 **`maxEntries` 变更**的完整台账，不会被清单里的无害编辑淹没。
⚠️ **这不是「豁免面被放宽」的完整台账**（Task 8 终审 Important-3 收窄措辞）：
`maxEntries` 只钉住**总量**，至少有两条不经过它、因此不出现在这份 git log 里的通道，
两条都是**已知残余、未拦截**：
- **通道 A（`pendingViolationKeys`）**：`BoolExemptionGuard.swift` 里写死的这个集合
  不受本节棘轮保护、不占 `maxEntries`（见该常量文档），往里加一个键就是一次完整的
  J-1 豁免，只需改那一个文件的一行，不经过这里描述的两文件流程。
- **通道 B（键碰撞）**：扫描命中集 `keys` 是 `Set`，新增一个 public 声明只要键已经
  在清单里就不增加清单条目数——`maxEntries` 与清单条目数都不会变化，这份 git log
  同样看不出来。`hits.count`（源码位置数，含键碰撞）此前未被任何断言钉住；
  Task 8 终审已在 `docs/bool-exemptions-baseline.json` 补 `sourceSites` 字段
  与配套的严格等式断言堵上这条通道（见 `BoolExemptionGuard.swift` 的
  `baselineRatchetHoldsExactly`）。
⚠️ 这句话说的是**豁免面**（`docs/bool-exemptions.json` + 其 `maxEntries`）本身的
台账，不含 `pendingViolationKeys`（`BoolExemptionGuard.swift` 里写死的、按公约 A.3
已裁决为已知违规、刻意不放进豁免清单的那个集合）——它是一条平行通道，不占
`maxEntries`、不受本节棘轮保护，它自己的台账就在 `BoolExemptionGuard.swift` 自身的
`git log` 里，不在这份文件描述的范围内。

⚠️ **两个出口必须有序，不能并列。** 并列时执行者的激励是反的：
(a) 只需写一条 JSON + 理由，(b) 是破坏性变更 + 迁移 —— 文字说「(b) 最常见」，
激励却把所有难例都推向 (a)，**豁免清单会从第一天起就臃肿**，
而 #39 的棘轮只挡新增、不逼删除，臃肿一旦形成就固化了。

### ⚠️ 头号反例：把 Bool 换成两 case enum **不是**替代路径

J-1 的谓词是「**任何 Bool**」，做的是纯符号比对 ⇒
`bordered: Bool` → `border: BorderStyle`（`.bordered` / `.none` 两个 case）
**机器判据完全挡不住**，而它只是换了名字的同一个布尔旋钮。

**这是最廉价的逃逸路径，而公约文档是唯一能封住它的地方。**

**判据**：两 case enum 只有在**存在真实的第三 case 或连续取值域**时才算替代路径。
造不出第三种合理取值，就说明它本来就是布尔旋钮 ⇒ 回去从下面四条里重选。

⚠️ **判据范围限定**：本判据只适用于**「把已存在的 Bool 参数改写成两 case enum」**
这个动作本身，不倒过来审判**本来就是 enum、且与系统类型同构**的既有域——例如
`StepsAxis`（`horizontal` / `vertical`）与 SwiftUI 自己的 `Axis` 同构、同样只有
两个 case，它不是「Bool 换皮」，是复刻系统惯例，**豁免于本判据**。

### 3.1 专用 init / 专用参数

**适用**：布尔背后其实是一个**被压扁的取值域**。

例：`Rating(allowsHalfStar: Bool)` → `Rating(step: Double)`。
`Rating` 的手势注释证明 `step`（`allowsHalfStar ? 0.5 : 1.0`）本来就是内部概念，
Bool 只是它的二值投影。

⚠️ **取值域不限于连续量**：只要满足第 3 节头号反例判据（**存在真实第三 case**）的
enum，同样算被压扁的取值域，归入本条——`step: Double` 只是其中一种形状，判据在于
「域」本身，不在于类型是不是数字。合格的离散 enum 域走这条，不是无路可归。

**反例**：`Badge(outlined: Bool)` 换成 `Badge(borderWidth: CGFloat)` —— **错**。
描边与否是**外观变体**，不是数值刻度；它该走样式（第 2 节），不是换个参数类型。

### 3.2 子视图槽（`@ViewBuilder`）

**适用**：布尔控制的是**要不要渲染一块调用方能提供的内容**，尤其当它配着回调时。

例：`Tag(removable: Bool, onRemove: (() -> Void)?)` → 尾随 `@ViewBuilder` 槽。
一并消除 `Tag.init(onRemove:)` 参数文档记录的自相矛盾状态：「`onRemove == nil`
时按钮仍可见但 `.disabled(true)`」。

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
——`Rating` 的手势注释写明「`isReadOnly` 或外层 `.disabled(true)` 时手势整体不挂载」,
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
| **B. 调用方传入的可本地化文案** | 调用方传，但内容是**界面文案**（标题、说明、占位符） | **新增用 `LocalizedStringKey`；存量迁移见下** |
| **C. 用户数据** | 调用方传，内容是**用户自己产生的**（设定名、章节标题） | `String`，**不得改** |

⚠️ **B 类是 CoreDesign 文本 API 的大头，不是 A 类。** `SectionHeader` /
`InsetGroupedSection(header:footer:)` / `ProgressIndicator(text:)` / `SettingsRow` 都是 B。

⚠️ **裁决：新增 B 类参数用 `LocalizedStringKey`**，与本仓既有 `SectionHeader` 一致、
`Bundle.main` 解析语义不变，**不是** `LocalizedStringResource`。

⚠️ **B 类改造有隐藏破坏性**：现有 B 类 API 有成文的 `Bundle.main` 解析语义
（`SectionHeader.swift`）。把**存量**改成 `LocalizedStringResource` 会**改变 bundle
解析行为**——属破坏性变更，必须进 `docs/BREAKING-CHANGES.md`，节奏归 #42；
**新增**参数不受此限，直接用 `LocalizedStringKey`，不必等 #42。

**本仓现状**：`Package.swift` 已有 `defaultLocalization: "en"`，`en.lproj/Localizable.strings`
里 chrome 已本地化。⇒ **CoreDesign 侧不需要新增本地化基建**；
缺 `defaultLocalization` 的是 **StoryUI**（归 #43）。

### 登记表的第四个 `category` 取值：`by-type`

三分法管的是**需要人工判别**的参数。登记表（`docs/component-registry.json`）的
`textParams[].category` 因此有**第四个取值** `by-type`：参数类型**已经是**
`LocalizedStringKey` / `LocalizedStringResource`、且**无接受裸字符串的孪生重载**
（`String` **或** `StringProtocol`）时，分类由类型直接判定，**不落 A/B/C 的人工三分**。
出处 `oh-my-story` 仓的 `.claude/epics/component-contract/38.md` 的 Acceptance Criteria 里 `textParams` 那条 bullet；守卫侧见
`Tests/CoreDesignTests/ComponentRegistryGuard.swift` 的 `validCategories`。
现状 2 条在用（`Descriptions.header`、`SpinningModifier.text`），**均在 CoreDesign 侧**；
StoryUI 侧现无 LSK/LSR 参数，该判据在那边恒不触发。

⚠️ **「无孪生重载」是本节的实际筛子**：第 4 节点名的四件
（`SectionHeader` / `InsetGroupedSection(header:footer:)` / `ProgressIndicator(text:)` /
`SettingsRow`）**全部带 `init<S: StringProtocol>` 重载**，因此仍是 **B 类**，不受本节影响。
措辞必须同时写 `String` 与 `StringProtocol`——只写前者，严格读者可主张
「这些类型上并没有 `String` 重载」而把 6 条 B 误判成 `by-type`（终审 M5 核实：
`SectionHeader.title` 1 条 + `InsetGroupedSection.header/footer` 2 条 +
`ProgressIndicator.text` 1 条 + `SettingsRow.title/subtitle` 2 条 = 6，此前的
「8」对不上这四件登记表的实际 `textParams` 总数，本次改正）。

⚠️ **A 类按定义不会出现在 `textParams[]` 里**：A 的定义是「文案写在组件源码里，
调用方看不见也改不了」，而 `textParams[]` 收的是 **public 参数**——参数按定义对调用方
可见。⇒ 实测 `textParams[]` 中 A 计数恒为 **0**（现状 33 条：B 22 / C 9 / by-type 2，
不写裸分母是为了不再重蹈本节前一版「31」的覆辙——分母每次改登记表都会变，写死的数字
会立刻变成化石），这是预期，不是覆盖缺口。三方仍各自保留 A 取值（它是三分法本身的一
部分，只是不经由参数这条路进登记表）。

---

#### 通则：判定法枚举的三方同步义务

⚠️ **这是同一种病的第三例**。三例都是「取值在一处合法且在用，另一处零提及」：

| 例 | 引入方 | 漏的一方 |
|---|---|---|
| `step1` | `38.md` 的 schema | **本公约**（第一版枚举漏） |
| `exclusion` | 守卫 `validDecidedBy` + 登记表 | **本公约**（`kind` 同步了 `excluded`，`decidedBy` 没同步） |
| `by-type` | `38.md` 的 `textParams` bullet + 守卫 `validCategories` | **本公约**（第 4 节标题就叫「三分法」） |

⇒ **任何一方**（本公约 / 守卫的 `validXxx` 域 / 任务书 schema / 登记表实际取值）
**新增判定法枚举字段的取值**时——即 `kind`、`decidedBy`、`textParams[].category`
这三个字段——**必须回头核对四方是否同向，而不是只在引入它的那一侧记一笔偏离。**

⚠️ **义务人是「新增取值的那一方」，不是本公约**：三例的引入方**没有一次是本公约**，
若把主语写成「本文件新增取值时」，这条规矩对三个致病者**一个都约束不到**。

⚠️ **范围仅限上列三个字段**：`repo` / `nativeProtocol` / `needsExtensionPoint` 等
不是判定法产出的枚举，本公约从未也不必镜像它们。

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

**现状交叉核对**：`Rating` 已通过 `@Environment` 读取 `controlSize` / `isEnabled` /
`layoutDirection`——本清单与它不矛盾，是对它的推广。

## 附录 A：判定法的实测走查

用 PRD 点名的**两可样本**验证判定法能产出确定结论。
⚠️ 出现「卡住、无法判定」即判定法失败——必须回去改，不许在这里打圆场。

### A.0 `CheckBox` —— 步骤 1 真正走「有」这条分支的样本

补上终审指出的缺口：下面 A.1 / A.4 两个样本走步骤 1 都答「无」，判定法「有」
这条分支从未被演练过。`CheckBoxToggleStyle: ToggleStyle`（`CheckBox` 组件）是
现成样本——它没有叫 `CheckBoxStyle` 的自造协议，对应的是 Apple 原生 `ToggleStyle`。

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ✅ **有**——CheckBox 可改写为「`Toggle` + 自定义 `ToggleStyle`」且不丢功能；`ToggleStyle` 有公开的 `makeBody` 定制点（第三方能实现，`CheckBoxToggleStyle` 本身就是证明） |
| — | ⇒ **语义组件，且必须实现原生协议** |

⇒ 结论：**语义组件，必须实现原生协议**。与现状一致（`CheckBoxToggleStyle` 已经
这么做）。**未卡住，且这次真的走到了步骤 1 的「有」分支。**

### A.1 `Rating(allowsHalfStar:)`

PRD 原文：「控制**手势步进粒度**（0.5 vs 1.0），同时影响渲染 ⇒ 外观还是行为？」

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ❌ 无 `RatingStyle` 之类 |
| 2. 想要「长相不同、含义相同」的版本吗？ | ✅ **想要**——替代枚举：数字条 / 表情（当前形态「星」不计入替代枚举） |
| — | ⇒ **语义组件，需要扩展点** |

⇒ 结论：**语义组件，需要扩展点**。**未卡住。**

### A.2 `Tag(removable:)`

PRD 原文：「与 `onRemove` 闭包耦合 ⇒ 既是外观也是行为」。
`Tag.init(onRemove:)` 参数文档实证：「`onRemove == nil` 时按钮仍可见但 `.disabled(true)`」
——一个参数控制了「画不画按钮」与「按钮能不能点」两件事。

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ❌ 无 |
| 2. 想要「长相不同、含义相同」的版本吗？ | ❌ chip 的长相就是它的含义 |
| 3. 视觉是含义的一部分吗？ | ✅ 是 |
| — | ⇒ **规定性组件，不给扩展点** |

⇒ 结论：**规定性组件，不给扩展点**。**未卡住。**

### A.1 续：`allowsHalfStar` 这个参数改成什么形状

`Rating` 的手势注释写明它算出 `step`（`allowsHalfStar ? 0.5 : 1.0`）供手势
取整用 ⇒ 按 **3.1**，它是**被压成布尔的连续量**，替代路径是**专用参数**（`step`）。

⚠️ **不塞进样式协议** —— 手势粒度是行为，违反第 2 节的「样式不得携带行为」。

### A.2 续：`removable` 这个参数改成什么形状

Bool + 配套闭包 ⇒ 按 **3.2** 走**子视图槽**，一并消除 `Tag.init(onRemove:)` 参数
文档记录的自相矛盾状态：「`onRemove == nil` 时按钮仍可见但 `.disabled(true)`」。

### A.3 `surface(_ kind:, bordered: Bool = true)`（modifier 形态）

这不是组件，是 **View extension 上的 public modifier** —— 用来验证 **3.3** 的 modifier 条款。

`SurfaceModifier.swift` 的文档注释：「`bordered` 是否画描边，默认 `true`。
置 `false` 只保留背景 + 圆角、去描边」。

| 第 3 节判据 | 结论 |
|---|---|
| modifier 表达**语义选择**？ | `.surface(.content)` 的 `kind` 是 ✅ |
| modifier 承载**布尔旋钮**？ | `bordered` 是 ❌ **不合规** |

⇒ 结论：**不合规**。最终处置（豁免或改造）**留给 #41 试点**，本任务只给判据。
⚠️ **它不进豁免清单**：`View.surface#bordered` 不在 `docs/bool-exemptions.json` 里，
因此**不占** `maxEntries` 的格子、**不受**棘轮保护——它不是「被接受的 API」，
而是一条**已知的、未解决的违规**。
⚠️ **落法是 `withKnownIssue` 而不是让 CI 字面红**（#39 的裁决，AC 偏离已登记）：
J-1 主判据 `BoolExemptionGuard.j1NoUnexemptedBoolParameters` 用 Swift Testing 的
`withKnownIssue` 只包住「未豁免违规集合为空」这一条断言，其余（过期条目、棘轮、
宿主台账、新违规）照常判红。理由：epic / main 分支**都没有分支保护**，字面红拦不住
任何合并、只是信号；而它会让 `.github/workflows/ci.yml` 里「仅已知 flake 才重跑」的
保护恒走「直接判红」分支，等于在整个 epic 期间关掉那道保护。
⚠️ **到期是机器强制的，不靠任何人记账**：#41 一旦删掉/改造 `bordered`，
`withKnownIssue` 块内不再记录到 issue ⇒ Swift Testing 判「Known issue was not recorded」
⇒ 主判据**自己红**。第二道闸是 `j1ViolationSetIsExactlyTheContractPending`：
它断言「未豁免违规集合**恰好**等于 `View.surface#bordered` 这一条」，
既在 known issue **之外**抓新出现的未豁免 Bool，也在 `bordered` 消失时判红。

#### AD-2 裁决：「这不是组件」的范围——ViewModifier 是否进登记表

上面 A.3 那句「这不是组件」容易被误读成「`ViewModifier` 这一整类不进
`docs/component-registry.json`」——实测不是这么回事，必须在这里把范围钉死：

- `SurfaceModifier`（A.3 的样本）**本身不是 `public` 类型**——`struct SurfaceModifier:
  ViewModifier` 无 `public` 修饰符，只经 `public extension View { func surface(...) }`
  这一层暴露。它没有可被扫描器采集、可被判定法审查的 public 类型，「这不是组件」说的
  是**这一种写法**（内部 struct + public View extension 方法）没有公开的类型级 API 形状
  需要判定法回答，不是在说「凡是 `ViewModifier` 都不算组件」。
- `SpinningModifier` / `FloatingGlassModifier` / `TelegramGlassButtonModifier`
  三个是 **`public struct ... : ViewModifier`**——它们本身就是公开类型，有自己的
  init 参数表，一样有「这个参数该长什么形状」的问题，且扫描器（`PublicTypeCollector`,
  `Tests/CoreDesignTests/ComponentRegistryGuard.swift`）设计上就把 `View` 与
  `ViewModifier` 归为同一类「组件」一并采集。

⇒ **裁决**：登记单位是「有 public 类型的 API 表面」，不是「是不是 `ViewModifier`」。
public 的 `ViewModifier` 类型**照常登记进 `component-registry.json`，判定法同样适用**
（`nativeProtocol`/`customStyleProtocol`/`needsExtensionPoint` 对它们同样有意义——
样式扩展点判据不关心宿主类型是 `View` 还是 `ViewModifier`）；A.3 的「这不是组件」
限定为「像 `SurfaceModifier` 这样连 public 类型都没有的 modifier 写法，没有可登记的
对象」。Task 2 填表遇到 `SpinningModifier` 等三个公开 `ViewModifier` 时，按此裁决
正常走判定法，不必现场发明。

⚠️ **终审 C1 实测命中第二例，点名写死**：`BottomInputBar`（`docs/README.md:23` 索引）
与 `SurfaceModifier` 是**同一种写法**——`struct BottomInputBar: View` 没有 `public`
修饰符，唯一暴露的 public 表面是 `public extension View { func bottomInputBar(...) }`
（`BottomInputBar.swift:19` / `:458`）。它没有可被 `PublicTypeCollector` 采集、可被
判定法审查的 public 类型 ⇒ 按本裁决**排除**出登记表，不因为「README 索引过」或
「参数很多」就破例登记。它的 6 个 public Bool 与 `placeholder: String` 参数仍是真实的
public API 面，需要治理——已移交 `oh-my-story` 的 `39.md`（J-1/FR-4），只是不经登记表
这条路径。

⚠️ **`Toast` 是反例，同样点名写死，以示裁决边界不是含糊的**：`Toast`（`docs/README.md:78`
索引）表面上也是「class + struct 组合」，但它**确实有 public 类型**——`ToastHost`
（public class）、`ToastItem`（public struct）、`ToastDefaults`（public enum）三个都是
public——只是都不是 `View`/`ViewModifier`。

⚠️ **终审 I4 收窄：「有 public 类型的 API 表面」单独不是充分条件。** 若照字面直接当
充分条件用，会得到两个坏结论：(1) **超发**——`Sidebar.swift` 的 `SidebarTextStyle` /
`StatusLevel` / `ButtonRoleStyleRole` / `CoreSpacing` 同样「有 public 类型的 API
表面」，但都未登记，字面读法会推出它们「都应当登记」，与现状矛盾；(2) **给不出
`Toast` 这个条目名**——机械套用会得到 `ToastHost` / `ToastItem` / `ToastDefaults`
三条按类型各自登记，而不是一条名为 `Toast` 的聚合条目。真正生效的是**复合条件**：
「有 public 类型的 API 表面 **且被 `docs/README.md` 组件索引收录**（未弃用）」⇒
**以该 README 行名登记为一条聚合条目**——`Toast` 满足（`docs/README.md:78`），
已在终审 C1 补录（`component-registry.json`，`kind: semantic` / `decidedBy: step2`，
条目名沿用 README 行名 `Toast`，不拆成三条按类型登记）；`Sidebar` 的四个辅助类型不满足
（README 没有以它们为行名的索引条目），因此不登记，不受本裁决牵连。

⚠️ **本复合条件的作用域必须限定，否则它只是换了一个过宽的条件**（终审第 3 轮 I-1）：
**它仅适用于「该 README 行名下没有任何 `public struct: View/ViewModifier` 类型」
——即扫描器结构上看不见它——的情形**，`Toast` 属此类。行名下**存在**可被扫描器采集的
类型时，仍按**类型逐条登记，条目名用类型名**，不合并成聚合条目。

反例（若不加这条限定，按字面会推出与登记表现状相反的结论）：

| README 行 | 无限定时按字面 | 登记表实际 |
|---|---|---|
| `Skeleton（SkeletonLine / SkeletonRect / SkeletonCircle）` | 1 条聚合条目 | **4 条** |
| `Sidebar` | 1 条聚合条目 `Sidebar` | **6 条**，且**没有**叫 `Sidebar` 的条目 |
| `LabelIcon / ChevronRightIcon / DangerIcon` | 1 条 | 3 条 |
| `SectionHeader / SectionFooter` | 1 条 | 2 条 |

⚠️ **复合条件也不是必要条件**：45 条 coredesign 条目里有 **14 条**根本不是任何 README
行名（`AsyncButton` / `FloatingGlassModifier` / `TelegramGlassButtonModifier` /
`SettingsRowChevron` 等）。它们由扫描器的双向差集**强制要求登记**——把复合条件当必要
条件读，会推出这 14 条「不该登记」，与判据直接冲突。⇒ **复合条件只是「扫描器看不见的
东西如何进表」这一条补充通路，不是登记单位的总定义。**

`PublicTypeCollector` 结构上仍看不到 `Toast` 名下的三个类型（它只认
`public struct: View/ViewModifier`），因此 `Toast` 条目额外加入了
`ComponentRegistryGuard.knownOffScannerComponents` 白名单，避免被完整性判据的双向
差集误判为幽灵条目——白名单是**已知盲区的临时豁免**，不是对本裁决的修改。

⚠️ **本裁决拍的是「现状 public 面」，不是背书它们永久 public。** 另一条出路是把这三个
modifier **internal 化**（只经 `public extension View` 暴露，即 `SurfaceModifier` 的范式）
—— 那是**破坏性变更**，节奏归 #42，**属于被搁置而非被否决的选项**。
将来收窄 API 面时不要把本条读成反对意见。

#### AD-3 裁决：AC #49 点名的三个 style（`CoreLabelStyle`/`CoreProgressViewStyle`/`CoreDisclosureGroupStyle`）在新登记单位下无对应物

`38.md` 的 AC「标出对应协议名」一条点名这三个类型，但按 D1 它们是 **Style 实现**，不是登记表
条目（登记单位是「组件」，见本文件第 1 节判定法与 `ComponentRegistryGuard.swift` 的
`ScanResult.styleImpls` 分类）。Task 2 实测核对（`grep -rn
".progressViewStyle(.core)\|.labelStyle(.core)\|.disclosureGroupStyle(.core)"`）：
三者均被直接施加在**裸系统控件**上（`ProgressView().progressViewStyle(.core)` /
`Label { } icon: { }.labelStyle(.core)` / `DisclosureGroup().disclosureGroupStyle(.core)`），
调用方既包括本仓 Preview，也包括 StoryUI 的 `WritingStatusBar` / `ChapterCard`
（`.progressViewStyle(.core)`）与 `DelegationTimeline` / `AgentMessageList` /
`ToolCallRow`（`.disclosureGroupStyle(.core)`）——**没有一个登记表条目通过这三个 style
提供扩展点**。`ProgressIndicator` 是本仓唯一 `nativeProtocol: ProgressViewStyle` 的组件，
但它走的是自己的固定 `.circular` + `Color.accent`（FR-3a 例外），不消费 `.core`。

⇒ **裁决：选二选一里的第 2 条——登记为 AC 偏离**。`38.md` 那句「标出对应协议名」的 AC 在「登记单位 = 组件」
下无对应物，不是漏做，是 AC 原文与登记单位定义之间的张力（同 D1 的既有说明）。三个
style 的存在性、协议采纳、`.core` 静态工厂已通过 Task 1 的 `scannerFindsCoreDesignTypes`
（`styleImpls` 打印清单）与 J-3 判据（#40，读取 `nativeProtocol` 交叉核对源码）覆盖，
不需要在登记表里额外造三条不对应任何真实组件的幽灵条目——那会立即被
`registryCoversCoreDesignTypes` 的双向差集判红（`registered.subtracting(scanned)`
非空，因为它们在 `styleImpls` 而非 `components` 集合里）。

### A.4 `PinCode` —— 一个真的落到 tiebreaker 的样本

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ❌ 无 |
| 2. 能举出 ≥2 个业界真实替代形态吗？ | 分格框 / 锁屏圆点 / **逐位**下划线 —— 三者共享同一个「每位一格」布局骨架，只是格子的画法不同 ⇒ 按步骤 2 的**皮肤变体判据，不计入 ≥2**，**举得犹豫** |
| — | ⇒ 视为答不上来，**落步骤 4** |
| 4. tiebreaker | ⇒ **规定性组件 / 不给扩展点**，`decidedBy: tiebreaker` |

⇒ 结论：**未卡住**，且这次真的走到了 tiebreaker。

⚠️ 这一条的价值不在结论，而在**证明 tiebreaker 这条路径真的通**。
没有它，tiebreaker 就是一段从未被执行过的代码。
