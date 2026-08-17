# 公约修订记录 / Contract Revision Log

> ⚠️ **本文件内的所有行号均指「改动前」位置，基线为 `0c863a0`（`origin/epic/component-contract`）上的实测值**，
> 后续会随上游改动漂移；核对时请 checkout 该 SHA。
> **「改动后」一律不写行号**——本轮回写自身就会让公约行号整体位移，写了当天即失真。
> 引用 oh-my-story 侧文件（如 `43-report.md`）的行号时，基线是 oh-my-story `fbcee17`。
> （本文件属「时点记录」档，允许写行号；`docs/component-contract.md` 属 living document 档，
> 一律不写行号，改写「文件名 + 符号名 / 计数」。）

本文件是 `docs/component-contract.md` 的**修订台账**（PRD SC-8 的「公约修订回路」留痕物）。
每条记录回答三件事：**哪个试点组件撞上的 / 撞上公约哪一条 / 公约具体怎么改的（前后文字对照）**。

> ⚠️ **为什么单独成文件**：回写记录含「改动前后文字对照」，塞进公约正文会把正文撑散
> （`44-spec.md` 第五节第 4 条定死）。
> ⚠️ **本文件不是缺陷清单**——缺陷原始记录在 `docs/contract-defects.md`（#41）与
> `oh-my-story` 的 `43-report.md` §4（#43）。本文件记的是**对那些缺陷做了什么**。

## 记录格式

每条固定 7 个字段，缺一不可：

- **来源试点** / **撞上公约哪一条** / **改动前（逐字）** / **改动后（逐字）** /
  **落点** / **连带改动** / **验证**

## 一、判定法层面的裁断（#41 终审 I2 移交）

<!-- R-1（Task 2）/ R-2（Task 3）/ R-3（Task 4）/ R-4（Task 5）追加于此。
     ⚠️ R-4（Badge/Tag 均不改判）放在本节而不是第二节：它是 1.4 的**判定法裁断**，
     不是 8 条缺陷之一。放进第二节会让「8 条缺陷逐条回写」被一条非缺陷记录混淆。 -->

### R-1｜#41 终审 I2：判定法的「第四种出口」——裁断为**不加第四出口**

- **来源试点**：#41 CoreDesign 试点（终审 I2 移交）。涉 6 条 `step3` 条目：
  `InsetGroupedSection` / `ListRow` / `RadioGroup` / `SettingsRow` / `SidebarDocumentRow` /
  `UnderlinedTabBar`，另加 `Tag` / `TagInput` 共 8 条援引兄弟组件惯例。
- **撞上公约哪一条**：`docs/component-contract.md` 第 1 节步骤 2（改动前 `:34-75`）——
  它只写了三条出路，而上述条目实际走的是「组件名钉死风格，想要别的观感应换用具名兄弟组件」
  这条**未成文**的路径。
- **改动前（逐字）**：步骤 2 的三个出口之后直接是 `→ **会** ⇒ 语义组件，需要扩展点`，
  全节**零处**提及「兄弟组件」「候选的作用域」。
- **改动后（逐字）**：步骤 2 内新增指针段「⚠️ **候选还有一条作用域约束**：…」；
  第 1 节新增小节 `### ⚠️ 候选形态的作用域：由兄弟组件承担的形态不计入候选`，
  含三条援引条件、「只排除候选不决定落点」、与皮肤变体条款的**交叉优先序**、
  「不追溯」、以及 `Rating`/`RatingDisplay` 边界反例。
- **落点**：`docs/component-contract.md` 第 1 节（步骤 2 与 `### ⚠️ Tiebreaker` 之间）。
- **连带改动**：`Tests/CoreDesignTests/ComponentContractStructureGuard.swift`
  ——`requiredSubsections` 10 → 11 条，注释计数词 `**10 个**` → `**11 个**`。
- **验证**：`swift test --filter ComponentContractStructureGuard` → `2 tests in 1 suite passed`（`No matching` 0 次）；
  `swift test` → `370 tests in 61 suites passed … with 3 known issues`。

**裁断理由（为什么不写成「第四出口」）**：
1. **它不是出口，是入口条件**。三条出路回答「候选枚举完之后往哪走」；兄弟组件惯例回答
   「**什么算候选**」，层级不同，并列会让判定法逻辑错位。
2. **写成第四出口会变成万能逃生口**；作为步骤 2 的作用域规则，它天然受三条可证伪条件约束。

**闸门成本（实测，不是估计）**：8 条援引条目里，
- **条件 ①/② 零成本**：被点名的兄弟组件（`SettingsRow` / `ListRow` / `InsetGroupedSection` /
  `SegmentedControl` / `SidebarNavigationRow` / `SidebarUtilityRow` / `SidebarTagRow` /
  `Badge` / `Tag`）**100% 在登记表内**，且全部写明了组件名 ⇒ 挡得住空头援引，不误伤任何现有条目。
- **条件 ③ 已知一例过不了**：`InsetGroupedSection` 被排除的「sidebar 风格」候选**没有任何
  被点名组件承担它**（其 `notes` 里的 `ListRow` vs `SettingsRow` 是**类比援引**，不是
  「哪个兄弟承担哪个候选」的指认）⇒ 条件 ③ **不是零成本**，其第一个代价就是 R-3 的处置。

### R-2｜#41 `Skeleton*` 段的连带裁断：事后补写的效力边界

- **来源试点**：#41（`Skeleton*` 段明令：第四出口成文时应**一并裁断**「事后补枚举皮肤候选，
  能否推翻已被钉为范例的 `step3`/`step2` 结论」）。
- **撞上公约哪一条**：第 1 节判定法整节——公约从未规定「已落盘结论能不能被一次 `notes`
  补写翻转」。⚠️ 本任务自己安排的「`Tag` 补一句援引」（R-4）**正是一次对公约附录 A.2 钉死的
  教科书样本做事后 `notes` 补写**，不先裁这条，那个动作自身的合法性都没有依据。
- **改动前（逐字）**：公约第 1 节零处提及「事后补写」「翻转落点」「修订回路」（基线 `0c863a0` 实测 0/0/0）。
  ⚠️ 相对**直接父提交**（R-1 落地后）不成立：Task 2 的「不追溯」段已前向引用本小节名，
  故那时 `事后补写`×1、`修订回路`×1。本文件顶部的基线声明只覆盖**行号**，
  文字性 claim 的基线在此就地标注（Task 3 评审 M-2）。
- **改动后（逐字）**：新增小节 `### ⚠️ 事后补写的效力边界：只能补强记录，不得单方面翻转落点`，
  含「翻转须走修订回路」「钉为范例**按结论逐条计**，不按组件整体计」「未钉死条目的翻转同样
  要走回路，区别只在补强须显式声明不改结论」「`SkeletonCircle` 判 `step3` 是因为 notes 从未
  枚举过候选」四段。
- **落点**：`docs/component-contract.md` 第 1 节，紧随「候选形态的作用域」小节之后。
- **连带改动**：`ComponentContractStructureGuard.requiredSubsections` 11 → 12；注释计数词 `**11 个**` → `**12 个**`；
  注释**列举句**追加「…是第 12 条。」。⚠️ 三处缺一不可——该守卫注释自己写着「新增的那条不在
  列举里，最容易被后人当成多余而误删」，只记两处等于在留痕层复刻同一个病（Task 3 评审 M-1）。
- **验证**：`swift test --filter ComponentContractStructureGuard` → `2 tests in 1 suite passed`；
  `swift test` → `370 tests in 61 suites passed … with 3 known issues`。

**据此确立的三条下游效力**（R-3 / R-4 直接引用）：
- R-3 的「补痕」**合法**——补强记录、落点不变。
- R-3 里任何真改判（`InsetGroupedSection` 等）**必须走本回路并留痕**，不能只改 `notes`。
- `Skeleton*` 本身**仍不改判**（#41 明令本 epic 不改判它）。

## 二、缺陷逐条回写（SC-8，8 条：D-41-1~D-41-6 + #43-1 + #43-2）

<!-- R-5 … R-12 由 Task 6 – Task 10 追加（含 R-9 下挂的 `#### R-9 附`）。
     ⚠️ 全部 R- 条目共 12 条（R-1~R-12），本节 8 条、第一节 4 条。 -->

## 三、本轮未改判 / 未回写的项（诚实留痕）

<!-- 由 Task 12 追加 -->
