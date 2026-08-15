# 公约缺陷记录 / Contract Defect Log

本文件记录在真实改造中撞上的**公约缺陷**（判定法给不出决定性答案、判据漏判、规矩与自身
先例不自洽等），供 `#44`（SC-8 公约回写）逐条裁断。

> ⚠️ **零缺陷也要写「零缺陷」**（41.md AC 原文）——空白与「没撞上」在事后是分不清的。

---

## #41 CoreDesign 试点改造

试点：`Rating`（+ 本轮新增的 `RatingDisplay`）、`View.surface(_:bordered:)` + `Card(bordered:)`、
`glass` 簇（`SolidButtonStyle` / `LightButtonStyle`）。**撞上 6 条缺陷，非零。**

### D-41-1（41-spec 第三节验收 7 已点名）：`SurfaceKind` 的命名规矩与自身先例不自洽

`SurfaceModifier.swift:12-13` 写着「不引入裸修饰词（如 `.subtle`、`.muted`）；每个 case 直接
对应一种容器角色」，而同一个枚举里 `:32` 就有 `case canvasSubtle`——「角色 + 修饰词」形态，
且其文档自标「兼容别名」。

**规矩没裁断的两件事**：(a)「角色+修饰词」算不算合规（规矩只禁**裸**修饰词）；(b)「兼容别名」
这一档是否豁免于该规矩。本轮为 `.grouped` 命名时因此**无法从规矩直接推出结论**，改用一条自造
判据「该 case 是否独立成立为一种容器角色」才收敛（论证见 41-spec 裁决 1）。自造判据能用一次，
但它不在公约里，下一个人不会知道要用它。

**交 #44**：把这条判据（或另一条）写进公约，并明确「兼容别名」档的地位。

### D-41-2：J-2 的 `customStyleProtocol` 通路只查符号存在性，查不出「组件真的把定制权交出去了」

`ComponentJudgeRules.swift:86-88` 判绿的条件是「协议已声明 + 至少一个类型采纳」。一个组件完全
可以声明协议、登记表填上名字，而 `body` 里照旧硬渲染——J-2 照绿。#40 的移交清单第 1 条已把这条
精度上限写在明处，本轮**主动不踩**（`Rating.body` 与 `RatingDisplay.body` 都真的经
`style.makeBody(configuration:)` 渲染），但那是靠人自觉，不是靠判据。

**交 #44**：评估是否值得把「组件是否消费该 style」做成机器判据（需要语义判断，成本明显更高），
或至少在公约里写明这是一条**人来守**的规矩。

### D-41-3：`RatingDisplay` 的判定法步骤 1 暴露「否决理由不可继承」

`Rating` 与 `RatingDisplay` 的步骤 1 结论相同（Apple 无可用原生协议），但 `Rating` 的否决理由
（「改写成 `ProgressView + 自定义 style` 会丢手势取整与 accessibility adjust action」）在
indicator 身上**完全不成立**——它本来就没有手势与 adjust action。必须重新论证一遍
（重新论证的结论是：`ProgressViewStyle.Configuration` 只给 `fractionCompleted`，`value/count`
这个比值丢掉了 `count` 本身，而离散档位数是评分展示的语义核心）。

公约第 1 节步骤 1 没有说「拆出来的兄弟组件必须重走一遍步骤 1」。本轮靠 41-spec 的一句
「不许照抄 `Rating` 的结论」挡住了，但那是任务级约束，不是公约条款。

**交 #44**：公约应写明「新增组件一律重走判定法，不得继承来源组件的结论；结论可以相同，理由必须
各自成立」。

### D-41-4：`ownersWithoutRegistryEntry` 台账不随最后一个豁免键回收

`BoolExemptionGuard.ownersWithoutRegistryEntry` 的三条宿主——`ButtonStyle`、`SolidButtonStyle`、
`LightButtonStyle`——在裁决 3 删掉 `glass` 之后已**没有任何活的豁免键**。
`exemptionOwnersReconcileWithRegistry` 的循环按豁免键遍历 ⇒ 不再访问它们 ⇒ 它们绑定的正向核对
（`.styleImplementation` ⇒ `scan.styleImpls.contains(owner)`）**零覆盖**，而判据仍是绿的。

删掉它们会让 `.styleImplementation` 这个分类彻底失去样本；保留则台账里有三行不再承重。本轮选
保留 + 在源码里留痕。

**交 #44**：裁断台账条目是否应随最后一个豁免键一并回收，以及分类的「样本保留」需求该怎么表达。

### D-41-5：README 组件索引的对账是**单向**的，且不检查快照存在性

`ComponentRegistryGuard.readmeIndexReconcilesWithRegistry` 只做 README → 登记表方向：索引**缺行**
不会红。它也不检查那一行里 `<img src="snapshots/...">` 指向的 PNG 是否真的存在。本轮新增
`RatingDisplay` 时，索引行与快照全靠人补（M17 已点名这是「无闸腐坏面」）。

**交 #44 / #43**：评估补一条反向断言（登记表里 `kind != "excluded"` 的条目都应在 README 有行）
与一条快照存在性断言的成本。

### D-41-6：公约正文的三处「前瞻例」在本轮落地后时态失真，但公约正文的修改统一走 #44（S2′）

- `docs/component-contract.md:234`：`例：Rating(allowsHalfStar: Bool) → Rating(step: Double)。`
- `:429`（附录 A.1）与 `:456`（A.1 续）：同一个例子的走查记录
- `:275`：`例：Rating(isReadOnly: Bool) 与 @Environment(\.isEnabled) 语义重叠`
- `:217`：`bordered: Bool → border: BorderStyle`（本轮实际落地的是 `SurfaceKind.grouped` + `CardKind`，
  与例句给的形状不同——例句本身没错，但读者会以为落地的就是 `BorderStyle`）
- `:265` / `:267`：`.surface(bordered: false)` 与 `Card(bordered: Bool)` 的反例
- `:468-494`（附录 A.3）：`surface(_ kind:, bordered: Bool = true)` 的整节裁决，含
  `:481` 「它不进豁免清单」、`:490-494` 「到期是机器强制的：#41 一旦删掉/改造 `bordered`…」

这七处现在描述的都是**已经不存在的 API**。本任务按 S2′ 的纪律**不改公约正文**（与「不改判
`Badge`/`Tag`、不成文第四出口」同一条：公约正文的修改统一走 #44 SC-8 回写）。

**交 #44**：把这七处从「前瞻例 / 待处置」改写为「已落地判例」，并核对落地形状与例句是否一致。

---
