---
issue: 221
started: 2026-09-03
completion: 95%
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
- **步骤 2**（槽/排布/装饰三分法）：
  - (a) 当前形态：浮起胶囊，按钮与输入框并排同一行
  - (b) 全宽贴底工具栏 → 与 (a) 差在**背景/外壳画法**，属补充规则 1 的**纯装饰层**
    ⇒ **不计入 ≥2**
  - (c) 双层形态（输入框一行、按钮另起一行，Telegram 附件面板展开态）→ 子视图空间
    关系改变 ⇒ **排布，计入**
  - 合计只举得出 **1** 个骨架差异，且 (c) 是否算「同含义替代」两可 ⇒ **举得犹豫**
    ⇒ 落**步骤 4 / tiebreaker**，规定性组件不给扩展点
- 落点与同族 `SearchField` / `TagInput` 一致（三者都是包 TextField 的 wrapper）

### `placeholder` 分类：C 类

裸 `String`、**无 `LocalizedStringKey` / `StringProtocol` 孪生重载** ⇒ 不满足 B 类
类型判据。缺省值 `"iMessage"` 虽写在源码里，但 #43-1「B 类兜底按 A 类处置」只裁
**B 类参数**；公约同处明写「本仓另有形态相同但登记为 C 类的兜底」——`SearchField` /
`TagInput` 的 placeholder 正是该形态 ⇒ 判 **C 类**。

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

`ComponentData.swift` 与 `Previews.swift` 的占位文本改为同一个可交互宿主
`BottomInputBarPreview`：可敲字、可提交（提交内容列在上方）、可切「模拟运行中」
看发送按钮变停止、可切建议条显隐。两处共用同一宿主——否则 demo 里看到的与快照
流水线出的图会是两个东西。

## 验证

- **`swift test`：454 tests / 68 suites 全绿**（六个守卫全部处置后）
- **App 预览宿主：`** BUILD SUCCEEDED **`**（`xcodebuild -project
  App/CoreDesignPreview.xcodeproj`）——这条腿不受 `swift build` / CI 覆盖，须单独验
  ⚠️ 首次跑时我用 `... | head` 读到 `EXIT=0`，那是 `head` 的退出码；改用
  `pipefail` + `PIPESTATUS` 后才拿到真实结果

## 待完成

- [ ] 通知 `oh-my-story#50`（跨仓移交对象，**只通知不代改**）
- [ ] `docs/components/bottom-input-bar.md` 更新
