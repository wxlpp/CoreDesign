---
issue: 221
started: 2026-09-03
completion: 100%
---

# Issue #221 进度

## 1 · `BottomInputBar` 提为 public

`struct` / `init` / `body` 三处，doc comment 齐备（含「为什么它是 public」一节与
逐参数说明）。这是走**终审 C1 裁决自己给出的第二条出路**——「给它一个可登记的
public 类型表面」。

## 2 · 六个守卫逐个处置（task 预告的「固定集合断言会逐个报出」）

提 public 后 `swift test` 精确报出 6 处，一个都没静默放过：

| 守卫 | 处置 |
|---|---|
| `ComponentRegistryGuard` 覆盖 | 补登记表条目 |
| `ComponentRegistryGuard` README | 从 `knownExcludedReadmeRows` 移除 |
| `ComponentRegistryGuard` 计数 | 46 → 47 |
| `ComponentTextParamGuard` FR-4 | `BottomInputBar.init#placeholder` 补分类 |
| `ComponentTextParamGuard` 计数 | textParams 30→31、covered 29→30、carrying 8→9 |
| `BoolExemptionGuard` J-1 + 棘轮 | 5 条 struct 侧豁免；基线 27→32 / 30→35 |

### 判定法走查（真做了一遍，未照抄同族）

- 弃用条款 / 祖父条款：均不适用
- **步骤 1**：无。`TextFieldStyle` 覆盖不了「浮层容器 + 多个行内按钮 + suggestions
  列表 + 运行态切换」这套复合行为——属任务书点名的 `SearchField` 一类 wrapper 陷阱
- **步骤 2**（⚠️ **初版未过停止规则，已重做**）：初版只枚举 2 个候选、其中一个无具名
  来源，也没写穷尽声明——按公约「停止规则是走任一出口的前置」，当时**连 tiebreaker
  这个出口都还不能走**。重做后枚举 **4 个具名候选** + 查过的名单：
  - (a) 当前形态：浮起胶囊，按钮与输入框并排（Telegram iOS AI 输入条、Apple Messages iOS 26）
  - (b) 全宽贴底工具栏（Slack iOS、Ant Design Mobile）——⚠️ **改判为「排布」而非「装饰」**：
    初判只引了补充规则 1（背景/描边/阴影属纯装饰层），漏了**补充规则 3**「组件与周围内容
    的空间关系改变也算排布」，而「浮起（四周有边距）↔ 贴边全宽（零间距）」正是这种改变
    ⇒ **计入**
  - (c) 双层形态（Telegram 附件面板展开态、Discord 移动端）⇒ 排布，计入
  - (d) 内联展开式（Notion AI 行内输入）⇒ 排布，计入
  - 查过：Apple HIG / Material 3 / Fluent / Ant Design Mobile + Telegram/Slack/Discord/Notion
  - ⇒ 举得出 ≥2 个骨架差异，但按**候选形态的作用域条款**，(b)(c)(d) 改的都是「输入条与
    页面的锚定关系」或「输入与动作的分层」，属**宿主布局决策**而非组件内部可换皮的表面
    ——换任一形态都要换掉组件本身而非换一个 style ⇒ 落作用域排除项、**举证归零**
    ⇒ **步骤 4 / tiebreaker**
- 落点与同族 `SearchField` / `TagInput` 一致（三者都是包 TextField 的 wrapper）

### `placeholder` 分类：**B 类**（初版判 C，被评审证伪后改判）

⚠️ **初版的两条依据都站不住，这里如实记录**：

1. 我写「无 LSK/StringProtocol 孪生重载 ⇒ 不满足 B 类类型判据」——**错用条款**。
   「无孪生重载」是 `by-type` 小节区分「LSK/LSR 类型参数落 by-type 还是留 B」的筛子，
   **不是裸 String 参数的 B 类资格判据**。
2. 我引「本仓另有形态相同但登记为 C 类的兜底（SearchField / TagInput）」作先例——
   **选择性引用**。公约紧接的下一句就是「它们的分类要不要一并改……**已记为缺陷
   D-44-4**」。我引了前半句、略掉了缺陷标记，拿一个自身待复判的先例当既定依据。

**改判依据 `#67`**：「上调动态度（判 C）**需要源码或成文证据**；无上调证据 ⇒ 按
表面角色判 A / B」。实测 BottomInputBar 的 placeholder **没有任何此类证据**——doc
只写「输入框占位文字」，无 SearchField/TagInput 那种「运行期任意占位文案、调用方
可能传入分类名等动态字符串」的记载；缺省 `"iMessage"` 是纯 chrome ⇒ 判 **B**。

**连带的 `#43-1` 处置**：B 类参数的缺省兜底按 A 类处置 ⇒ `"iMessage"` 已改为经
`BottomInputBarDefaults.placeholder`（`String(localized:bundle:.module)`）取值并
注册进 catalog，不再是裸字面量。该 enum 必须 `public`——internal 类型无法被
public 默认参数引用（实测编译错误）。

⚠️ **由此产生的不一致已显式记录进登记表 notes**：BottomInputBar 判 B，而形态相同的
SearchField / TagInput 仍是 C。这是 **D-44-4 的直接后果**，三者应一并复判，
归属不变（D-44-4 / `oh-my-story#55`）。本条目取 #67 的字面结论，不预判那两条的走向。

⚠️ **注意两个参数面不要混**：本次分类的是 **struct init 侧**
`BottomInputBar.init#placeholder`；**modifier 侧** `View.bottomInputBar#placeholder`
仍在 `knownFunctionSideBareText` 的 func 侧留痕桶里（FR-4 的 AC 只点名 `init`）。

### 第二张 public 参数面（评审预警的那条，实测成立）

5 个 Bool（`wandEnabled` / `sendEnabled` / `showMenuButton` / `isRunning` /
`autoFocus`）在 struct 侧与 modifier 侧**各暴露一次**，守卫按 `Owner.init#param`
计键、不做跨面去重 ⇒ 各需一条独立豁免条目。

⚠️ **棘轮是上调，不是下调**：本仓惯例每轮把它压小（34→27），本次因扩大公开面
抬高 5 条（27→32、源码位置 30→35）。基线 rationale 里写明了代价：这 5 条与
modifier 侧同名条目是**同一批 Bool 的两个入口**，治理动作应一次覆盖两面。

## 3 · 文档

- **C1 裁决改写**：规则本身不变（「没有 public 类型 ⇒ 排除」仍成立，`SurfaceModifier`
  仍是活例），变的只是 `BottomInputBar` 不再满足该前提。保留原文为成因记录。
- **`:28` 豁免条目的失真前提更正**：其 reason 原以「struct 无 public 修饰符、
  排除出登记表」为据，该前提已被本轮推翻。
- C1 记录的缺口「`placeholder` 至今没有任何机器判据给它分类」**部分闭合**——
  struct init 侧已分类；modifier 侧按 AC 定义域本就不在 FR-4 主判据内，如实写明。

## 4 · demo 接通

⚠️ **初版走的是直接构造 struct，被评审判为未兑现 DoD**：任务书要求「非空 suggestions +
能看到显隐」，而 **suggestions 只存在于 modifier 面**——`BottomInputBarModifier` 才渲染
`BottomInputBarSuggestionsView`，`BottomInputBar.body` 只有 `mainRow`。直接构造时
`isShowingSuggestions` 只影响魔杖按钮的 a11y traits，**视觉上不会有任何建议条出现或消失**。
我在 progress 里写的「可切建议条显隐」是**假陈述**。

已改为走 `.bottomInputBar(suggestions:...)` modifier：4 条真实建议、`autoShowSuggestions`
开启、点魔杖按钮可展开/收起、可敲字提交（内容列在上方）、可切「模拟运行中」看发送变停止。
`ComponentData.swift` 与 `Previews.swift` 共用同一宿主——否则 demo 里看到的与快照流水线
出的图会是两个东西。

## 5 · 评审 checkpoint 的处置（BLOCK → 已修）

| 项 | 处置 |
|---|---|
| **C-1** demo 未兑现 suggestions | 改走 modifier 面（见上）；init doc 的误导措辞同步改写 |
| **C-2** placeholder 判 C 的两条依据都站不住 | 改判 B + 按 #43-1 处置兜底（见上） |
| **I-1** 走查未过停止规则、(b) 漏对质补充规则 3 | 重做走查：4 个具名候选 + 查过的名单；(b) 改判排布 |
| **I-2** 7 处现在时失真陈述 | 逐处改为过去时 + 现状（评审列了 5 处，我又找到 2 处历史叙述） |

⚠️ **I-2 是「重写后留下旧引用」的又一次**：我提 public 后**没有 grep 被否定命题的
关键词**，于是 `ComponentRegistryGuard` / `BoolParameterScanner` 里 7 处仍以现在时
断言「BottomInputBar 没有 public 修饰符 / 走排除而非登记」。讽刺的是其中一处
（`:311`）本身就在教育「trace 写错会让下一个读者在 100 行内证伪」。

## 验证

- **`swift test`：454 tests / 68 suites 全绿**（六个守卫全部处置后）
- **App 预览宿主：`** BUILD SUCCEEDED **`**（`xcodebuild -project
  App/CoreDesignPreview.xcodeproj`）——这条腿不受 `swift build` / CI 覆盖，须单独验
  ⚠️ 首次跑时我用 `... | head` 读到 `EXIT=0`，那是 `head` 的退出码；改用
  `pipefail` + `PIPESTATUS` 后才拿到真实结果

## 待完成

- [ ] 通知 `oh-my-story#50`（跨仓移交对象，**只通知不代改**）——留到 #226 收尾统一做
