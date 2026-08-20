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

### D-41-6：公约正文的三组（八处）「前瞻例」在本轮落地后时态失真，但公约正文的修改统一走 #44（S2′）

**组 1 —— `Rating(allowsHalfStar:)` → `step: Double`**（3 处）：
- `docs/component-contract.md:234`：`例：Rating(allowsHalfStar: Bool) → Rating(step: Double)。`
- `:429`（附录 A.1）与 `:456`（A.1 续）：同一个例子的走查记录

**组 2 —— `Rating(isReadOnly:)` 与 `@Environment(\.isEnabled)`**（1 处）：
- `:275`：`例：Rating(isReadOnly: Bool) 与 @Environment(\.isEnabled) 语义重叠`

**组 3 —— `bordered: Bool`（Surface / Card）家族**（4 处）：
- `:217`：`bordered: Bool → border: BorderStyle`（本轮实际落地的是 `SurfaceKind.grouped` + `CardKind`，
  与例句给的形状不同——例句本身没错，但读者会以为落地的就是 `BorderStyle`）
- `:265` / `:267`：`.surface(bordered: false)` 与 `Card(bordered: Bool)` 的反例
- `:468-494`（附录 A.3）：`surface(_ kind:, bordered: Bool = true)` 的整节裁决，含
  `:481` 「它不进豁免清单」、`:490-494` 「到期是机器强制的：#41 一旦删掉/改造 `bordered`…」

这三组共八处现在描述的都是**已经不存在的 API**（或——组 3 的 `:217`——例句给出的形状与实际
落地形状不同）。本任务按 S2′ 的纪律**不改公约正文**（与「不改判 `Badge`/`Tag`、不成文第四
出口」同一条：公约正文的修改统一走 #44 SC-8 回写）。

**交 #44**：把这三组八处从「前瞻例 / 待处置」改写为「已落地判例」，并核对落地形状与例句是否一致。

---

> ⚠️ **导航提示**：以下两节按 Task 时序排列（Task 4 在前、Task 5 在后），**不是**按 spec
> 小节号排列——「1.5」在前、「1.4」在后，找条目时看 Task 编号，不要按小节号从上往下找。

## #44 1.5 评审移交（Task 4 第 2 轮评审，I-B / I-D）

### D-44-1：新增判据（候选作用域 + 反事实必要性压测）只在登记表里跑过 6 条，其余 `step3` 判例仍是旧尺落盘

本轮（#44 1.5）新增的「候选形态的作用域」条款与随后评审逼出的「反事实必要性压测」严尺，
**只对 Task 4 处置的六条候选**（`RadioGroup` / `UnderlinedTabBar` / `SettingsRow` /
`ListRow` / `SidebarDocumentRow` / `InsetGroupedSection`）实际跑过——且六条**全部改判**
为 `tiebreaker`（`step3` 判例基线 `56` → `50`，`d6c5de8` 对照）。**Task 4 处置当下**，
登记表其余 `50` 条 `step3` 判例从未在这把新尺下复核过，仍是按新条款出台前的标准落盘；
新尺至今只产出过「不过」的实例，一个「过」的正例都没留下。⚠️ 该数字下方 Task 12
同步已更正——见下段。

⚠️ **Task 12 同步**：`Tag` 随后经 Task 5 反事实必要性压测已复核（结论「不过」，见
`D-44-3`；`decidedBy` 未翻转，仍落 `step3`）——故当前实测 `step3=50` 中，真正**从未**
被新尺复核过的只剩 **49** 条，不是 50 条。下文与其余文件引用本数字时，一律以 **49** 为准。

**交 #44 后续 / Task 12**：裁断是否需要对其余 `49` 条 `step3` 判例做一次抽样或全量复核，
或至少在公约里明确「新尺尚未覆盖的既有判例效力不受影响，直到被复核」这条过渡声明。

⚠️ **#52 裁断：不补跑，全部移交，但移交清单逐条可核。** 成本与范围不匹配 ⇒ 分三批：

- **移交 A（CoreDesign 侧，25 条）** ⇒ `wxlpp/oh-my-story` **#53**。
  **优先处理** `SidebarNavigationRow` / `StateLabel`（原 carve-out 两条），并一并承接
  `A.1` 尾巴（`Rating(allowsHalfStar:)` 走查步骤 2 仍用被本轮判为「无法证伪」的旧措辞，
  `#52` 授权范围不含 `A.1`）；排除清单里属本仓的逐条列出：`Descriptions` /
  `SettingsRowChevron` / `SectionFooter`。⚠️ `StateLabel` 与 **#49 / G-4 重叠**，issue
  正文已写明两条改动的顺序与互不干扰。
  ⚠️ **#53 处置留痕（`A.1` 尾巴）**：#53 已按完整修订回路改掉 `A.1` 走查表步骤 2 的提问
  措辞（→「能举出 ≥2 个业界真实替代形态吗？」），**结论不变**（`Rating` 仍 `step2`）；
  同批改掉 `A.2` 末尾那条「`A.1` 尚未改」的自认段（Step 5 一改它即失真）。台账留痕见
  `docs/component-contract-revisions.md` `R-14`。⚠️ **本条不另开 `D-53-x` 号**——该缺陷的
  登记处就是本段，#53 只是执行它移交的处置。
- **移交 B（StoryUI 侧，24 条）** ⇒ `wxlpp/oh-my-story` **#54**。需在
  `oh-my-story` 仓做**源码级压测**；排除清单里属该仓的逐条列出：`ManuscriptEditor` /
  `DynamicForm` / `ContextPicker` / `CodexEntryForm`。⚠️ **这项成本本条原记录未覆盖**——
  CoreDesign 的 CI 只 checkout 本仓，`ComponentRegistryGuard` 对 StoryUI 侧不做源码比对。
- **移交 C（`D-44-4` + `D-52-2`）** ⇒ `wxlpp/oh-my-story` **#55**。
  四件必带事项已转录进该 issue 正文；⚠️ **循环依据的四种措辞形态仍以本文件 D-52-2 的表为准**
  （#55 只链接回本条、**未转录**——#52 终审实测该 issue 正文对 `跨行` / `SharedFoundationTests` /
  `BREAKING-CHANGES` 命中均为 0）。**处置时必须读本条的表**：四种形态里有一种**跨行断开**，
  任何单一 grep 都抓不全——这正是 D-52-2 本身要防的东西，做成互指引用等于把它退回原状。

⚠️ **25（CoreDesign 余量，= 26 − 改判的 `Tag`）+ 24（StoryUI）= 49**，与本条上方「一律以
**49** 为准」吻合。⚠️ **不许只写「其余 49 条」**——**排除清单**（按判准考察过、因故不收进本轮的条目）已逐条
列在移交 A / B 的 issue 正文里；⚠️ **49 条的完整名单不在 issue 正文里**，以本仓
`docs/component-registry.json` 的 `decidedBy: step3` 为准。

### D-44-2：公约「候选形态的作用域」小节「登记表两侧都有成文样本」在 `step3` 侧的实测状态（#44 判「无幸存正例」；#52 收窄为「**未确认有合格实例**」，另有 4 条两可未裁——见本条 #52 裁断段）

公约「候选形态的作用域」小节的原话（不引行号，见小节标题 + 原话片段）——「登记表两侧都
有成文样本，不是空设：`Tag`（作用域排除后**另有**积极理由 ⇒ `step3`）与 `TagInput`
（作用域排除后**没有**积极理由 ⇒ `tiebreaker`）」——把 `Tag` 作为其**唯一**点名的
`step3` 侧样本。本轮 `RadioGroup` 经反事实必要性压测已确认改判（见 R-3），六条候选无一
维持 `step3`；若 `Tag`（Task 5 待裁）在同一把尺下同样判「不过」，则「另有积极理由 ⇒
`step3`」这条出路在**整个登记表里一个实例都没有**，该句「两侧都有成文样本」当场
变假，那条「登记表两侧都有成文样本」小节段落就成了没有对照面的单侧规则——这正是 R-1 当初拒绝把候选作用域条款写成
「第四出口」的理由（「层级不同，写成第四出口会变成万能逃生口」）的镜像：一条规则如果
从未在实践里产出过它自称存在的那一侧结果，它就不是在描述两条出路，而是在描述一条出路
加一句从未兑现的承诺。

⚠️ 本条**依赖 Task 5 的裁断结果**（`Tag` 是否改判），在此提前登记是为了不让这条系统性
风险等到 Task 12 凭记忆补；`Tag` 若维持 `step3`，本条自动不成立，Task 12 收口时应据实
勾销或改记为「已证伪」。

⚠️ **Task 5 已证实**：`Tag` 独立理由（源自公约附录 A.2）经反事实必要性压测，结论为
「不过」（见 `D-44-3`）——`step3` 侧唯一点名样本的独立理由确认扛不住新尺，本条**成立**，
不是「已证伪」。⚠️ **与本条上方「Tag 若维持 step3，本条自动不成立」的预期不同**：Task 5
最终未翻转 `Tag` 的 `decidedBy`（公约附录 A.2 正文点名钉死该结论，翻转须走完整修订回路，
超出本任务范围），`Tag` 在**登记表字段**层面**当时**仍是 `step3`（⚠️ #52 已改判 `tiebreaker`，见本条 #52 裁断段）；但本条真正关心的是「该出路是否
有一个**理由真能扛住新尺**的实例」，而不是字段取值本身——`decidedBy` 未变不代表理由站得
住。⇒ 本条的系统性风险依旧成立，裁断权仍在 epic 层面（Task 12），处置方向不变。

**交 #44 后续 / Task 12（epic 层面裁断，不由本 Task 决定）**：若 `Tag` 也判「不过」，
需要么在登记表或公约新增判例补上一条真能通过新尺的 `step3` 判例，要么承认「候选形态的
作用域排除后另有积极理由 ⇒ `step3`」这条出路在当前判据下**实际总是**落空、本设计系统
的组件在这把尺下走到步骤 2 排除候选后就没有再回到 `step3` 的，并据此重写公约
「候选形态的作用域」小节「登记表两侧都有成文样本」这一整段。

⚠️ **#52 裁断（本条从「已证实」转为「已处置」）**：不删这条出路（它是判定法的结构，
删了三出口就剩两个），删掉「登记表两侧都有成文样本」那句，改为如实陈述。**处置依据是
一次全量审计，不是抽样**。

**审计**：`oh-my-story` 仓 `.claude/epics/component-contract/52-step3-audit.md`，
对当时登记表全部 **50** 条 `decidedBy: step3` 逐条覆盖、**无抽样**。判准两项：
**(A)** 步骤 2 的答案站得住（`notes` 没举出 ≥2 个真实替代形态，**或**举出的候选确实被
皮肤变体条款 / 作用域条款正当排除）；**(B)** 有一条**不引用任何兄弟组件名**的、带**反事实
机制**的积极理由（形如「换成 X 就读成 Y 了」）。

| 档 | 条数 | 条目 |
|---|---|---|
| **两项都满足 = 合格实例** | **0** | —— |
| 只满足 (B)、(A) 不满足（举出了 ≥2 却仍判 `step3`） | 2 | `AvatarGroup` / `OutlineTree` |
| 只满足 (A)、(B) 不满足（无反事实机制） | 43 | 见审计档 3 逐条表 |
| 两项都不满足 | 1 | `CodexEntryList` |
| **存疑**（(A) 满足，(B) 两可） | **4** | `ApprovalRequestCard` / `DelegationTimeline` / `AgentMessageList` / `RunMetricsBar` |

⚠️ **结论的两重限制，缺一不可**（这两句是本条的承重部分，不许被摘录时省掉）：

1. **作用域**：审计判的是**登记表 `notes` 侧**，**不判** `docs/components/*.md` 与源码文档
   注释。⇒ 正确表述是「**登记表 `notes` 侧未确认有合格实例**」，**不是**「写不出来」——
   现成反例：`SettingsRow` 在 #44 初判时就写出过一条**形式**合格的句（**原文节选**，全句见
   `docs/component-registry.json` 的 `SettingsRow.notes` #44 检验段：「把图标方块换成头像圆、
   把 accessory 拿掉，读到的就变成通讯录行」），它是被**公开 API 反证**打掉的（**四个** `init`
   的 `icon` 参数默认 `nil`），**不是被判准 (B) 打掉的**。⇒ 判准的**句式**是可写的；但该样本的
   前提随后被公开 API 证伪、重新压测也判「不过」（`SettingsRow` **已因此改判 `tiebreaker`**）
   ⇒ **只能说「窗口未被证明关闭」，不能说「窗口存在」**——「能写出一句形状合规的话」推不出
   「存在一个真实的合格实例」。
   ⚠️ 本段与公约「候选形态的作用域」小节是**同款措辞，改一处须同批改另一处**——#52 终审实测：
   该收窄先在公约落地（`5065d37`），此处却把被撤回的原句又写了一遍，是同一模式的又一次复发（⚠️ **不写笼统序数**——本文件下方 D-52-2 自己立过同款规则（**大意**：落点要写清「哪种措辞、在哪、能不能 grep 到」，不要写一个笼统的、复算不出来的总数）；历次复发逐条见台账 R 系列与 #52 PR 正文）。
2. **未裁状态**：**4 条两可、本轮未裁** ⇒ 是「**未确认有**」，**不是「确证无」**。

⚠️ **44/50 条的 (A) 是靠「压根没枚举候选」通过的**：审计基线 50 条里只有 6 条的 `notes`
出现过「候选」或「替代」二字（`AvatarGroup` / `Card` / `Steps` / `Tag` / `CodexEntryList` /
`OutlineTree`，其中 `Card` 的「替代路径」指的是公约第 3 节的 Bool 替代路径、不是形态候选）
⇒ **操作化门槛（≥2）在其余条目身上从未被真正执行过**。⇒ 这不是某一条判例的问题，是**门槛
未被执行**。

⚠️ **「补一条真能过尺的判例」这条分支被否决**，依据即上表：50 条里合格实例 0；两条最接近的
（`AvatarGroup` / `OutlineTree`）都栽在 (A) 上——它们各自举出了 ≥2 个替代形态却仍登记
`step3`，是**待复核条目**，不是可用样例。

**已落地**：公约「候选形态的作用域」小节的「登记表两侧都有成文样本」一句已删除、替换为实测
状态陈述；同批处置了两处引用它的文本（公约里逐字引「本句『两侧都有成文样本』」的那条注、
以及 `docs/component-registry.json` 的 `TagInput.notes` 里「两侧实证」那句）。台账
`docs/component-contract-revisions.md` R-13。**⇒ 本条已处置，不再是待裁项。**

---

## #44 1.4 评审移交（Task 5）

### D-44-3：`Tag` 的 `step3` 独立理由（公约附录 A.2）未能通过反事实必要性压测，`Tag` 的 `step3` 结论建立在其上

`Tag` 现有 `step3` 结论由两段理由支撑：(1) 作用域排除——pill 候选由兄弟组件 `Badge`
承担（合法，三条件全过）；(2) 独立理由——源自公约附录 A.2 `Tag(removable:)` 走查表
（「不引用任何兄弟组件」这一要求下唯一可用的理由来源）。按 Task 4 处置六条 `step3`
条目时使用的同一把「反事实必要性压测」（判据：第 1 节步骤 2 原话「『只有一种合理长相』
这个措辞本身不构成理由……必须**额外**说清为什么换了长相就不是这东西」）复核 (2)，
**结论：不过**，三条依据：

1. **A.2 用同一句话回答步骤 2 与步骤 3，步骤 3 无独立支撑**——A.2 步骤 2 原话「chip 的
   长相就是它的含义」，步骤 3 原话「✅ 是」，步骤 3 除复述步骤 2 外无独立内容 ⇒ 循环
   论证，未给出公约「第 1 节步骤 2」骨架屏范例（`SkeletonCircle` 等，原话「圆形换成
   方形，占位对象就从『头像』读成『图片』」）那样「换了长相就读成别的东西」的机制 ⇒
   不满足步骤 2「额外」说清的门槛。
2. **公约自己给出了击穿它的反事实**：公约「候选形态的作用域」小节原话——`Tag` 的 pill
   「既是 `Badge` 的领域，又与 `Tag` 自身共享『低 chrome 状态色块』骨架」——公约亲口
   承认 pill 与 `Tag` 的圆角矩形共享同一骨架，即皮肤变体而非「换了长相就不是这东西」。
3. **源码自述也是关系性的**：`Sources/CoreDesign/Components/Tag/Tag.swift` 圆角规格段
   原话「不使用 `.full`——这是与 `Badge` 的视觉区分点之一」——剥掉 `Badge`，源码里没有
   任何非关系性的形状理由。

⚠️ **连锁（缺陷的实质影响比看上去大）**：公约「候选形态的作用域」条款的裁断是「本条
（组件间边界）优先于皮肤变体条款（组件内变体）」，这保证 `Tag` 的 pill 候选先被**排除**
而非直接计入皮肤变体判断，所以 `Tag` 不会因 pill 本身直接落 `tiebreaker`。但排除之后，
`Tag` 自身剩下的候选（实心 chip / 描边 chip 等画法差异）**仍共享同一「低 chrome 状态
色块」骨架**——公约同一小节明文规定「排除后若本组件自己仍有共享骨架的候选，再对**那些**
候选适用皮肤变体条款」——按此推演，剩余候选同样不计入 ≥2 ⇒ 举得犹豫 ⇒ 仍落
`tiebreaker`。⇒ **两条路径（直接复核 A.2 理由 / 走完排除后剩余候选的皮肤变体推演）都
指向 `tiebreaker`**，不是碰巧只有一条路径站不住。⚠️ **该组剩余候选（实心 chip / 描边
chip）为本轮推演，登记表与源码均未成文枚举**——`Tag.swift` 与 `Tag` 条目 `notes` 都
没有写出这组候选；若 Task 12 认定 `Tag` 无成文剩余候选，则本连锁只剩第一条路径（A.2
理由不过 ⇒ 按公约「说不清 ⇒ `tiebreaker`」），**结论不变**。

⚠️ **与 D-44-2 的关系**：`D-44-2` 提前登记的系统性风险——公约「候选形态的作用域」小节
「登记表两侧都有成文样本」一句在 `step3` 侧唯一点名的样本（`Tag`）可能没有幸存实例——
**本条即其证实**：`Tag` 的独立理由未能通过新尺，`D-44-2` 已从「待裁」转为「已证实」。

⚠️ **本 Task 未改判 `Tag` 的 `decidedBy`**：公约「事后补写的效力边界」条款明写「附录
A.2 对 `Tag` 的点名钉死的正是它的 `step3` 结论」——翻转它等于同时改公约正文与推翻教科书
判例，超出「处置一条登记表 `notes`」的范围，且该条款规定翻转须走完整修订回路（记入
缺陷 → 回写公约 → 台账留痕），不能仅凭一次 `notes` 压测代办。本条即该缺陷记录本身；
`Tag.notes` 已如实记入压测结果并显式声明「不改结论」，`decidedBy` / `kind` 均未动。

**交 #44 后续 / Task 12（epic 层面裁断，不由本 Task 决定）**：需要么给 `Tag` 找一条真正
非关系性、能通过新尺的独立理由并正式走修订回路改写公约附录 A.2，要么承认 `Tag` 的
`step3` 判例在当前判据下站不住、按修订回路正式改判为 `tiebreaker`（并处理随之而来的
`D-44-2`——`step3` 侧样本归零后公约「候选形态的作用域」小节「登记表两侧都有成文样本」
一句需要重写）。两个方向互斥，裁断权在 epic 层面。⚠️ **登记表侧还有一份同款已证伪断言**：
`docs/component-registry.json` 的 `TagInput` 条目 `notes`（Task 4 落的字，本 Task 无权改）
里「它与 `Tag`（排除后另有积极理由 ⇒ step3）合起来是『本条只排除候选、不决定落点』的
**两侧实证**」一句，是公约「候选形态的作用域」小节「登记表两侧都有成文样本」这一断言的
登记表副本——Task 12 处置公约那句时**须同步处置它**，否则登记表侧会留下一份公约正文已
改写但登记表侧仍宣称「两侧实证」成立的孤证。

⚠️ **#52 裁断：改判已执行。** `docs/component-registry.json` 的 `Tag.decidedBy`：
`step3` → `tiebreaker`（`kind` 仍 `prescriptive`——判定法对 `step3` 与 `tiebreaker`
是同一个 `kind` 映射，无需同步；`needsExtensionPoint` 仍 `false`）。

**承重依据只有一条**：附录 A.2 走查表的步骤 2 答「chip 的长相就是它的含义」、步骤 3 答
「✅ 是」——步骤 3 除复述步骤 2 外无独立内容 ⇒ 循环论证，不满足公约「必须**额外**说清」的
门槛（即上文依据 1）。

⚠️ **「钉死」= 翻转须走本回路，不是「不可翻转」**（I9，该阐释放在这里，不放进公约正文
「事后补写的效力边界」小节——那是规范小节，不新增规范性阐释）：`Tag` 被附录 A.2 钉死的
`step3` 结论，已走完本节规定的三步回路（记入本条缺陷 → 回写公约「候选形态的作用域」小节
与附录 A.2 → 台账 `docs/component-contract-revisions.md` R-13 逐条留痕）正式改判为
`tiebreaker`，附录 A.2 已同批改写。⇒ 钉死判例的翻转**成本**在回路，不在禁令。

⚠️ **上文「连锁」段的第二条路径（皮肤变体推演）经 #52 裁断为不承重**：该段自带 hedge
「该组剩余候选（实心 chip / 描边 chip）**为本轮推演，登记表与源码均未成文枚举**……
**若 Task 12 认定 `Tag` 无成文剩余候选，则本连锁只剩第一条路径**，结论不变」——#52 作出了
该 hedge 要求的那个认定：改判前（CoreDesign `511576f`）实测「实心 chip」/「描边 chip」在
`docs/component-registry.json`、`docs/component-contract.md` 与
`Sources/CoreDesign/Components/Tag/Tag.swift` **三处**命中**均为 0**（⚠️ 三处缺一不可：本条 hedge
原话点名的是「登记表**与源码**」，只扫前两个会漏掉源码那一半）（⚠️ 本段
自身与 #52 回写文本对这两个词的引用不计入该计数——它们描述的是改判前的状态）
⇒ **`Tag` 无成文剩余候选** ⇒ 皮肤变体路径不承重，**结论不变**（仍是 `tiebreaker`）。

⚠️ **「给 `Tag` 补强一条独立理由」这条并列分支被否决**：补强要求写出一条**非关系性**的独立
理由；通读 `Tag.swift` 全文（247 行）后，**唯一以圆角/形状为主语、并写明其含义**的陈述是圆角规格段的「**不**使用
`.full`——这是与 Badge 的视觉区分点之一」，**明文是关系性的** ⇒ 补强所需的材料在源码里不
存在，硬写等于凭空发明理由——那正是本 epic 判死其它六条时反对的做法。

⚠️ **必须回应的反驳（否则读者会说「`Tag` 有 `AvatarGroup` 那类理由，只是写得简略」）**：
`Tag.swift` 把自己锚在「GitHub issue label 风格」上，这与 `AvatarGroup` 锚在
Slack/Discord/Figma 惯例上是**同一类**行业惯例锚点。**区别**在于 `AvatarGroup` 的 `notes`
给出了**反事实机制**（换成别的排布就「读成别的东西」），而 `Tag` 的行业锚点只说明「它长
这样」，没说明「换了长相就不是 chip」——**而 pill 形的 chip 仍然是 chip**：同为 chip 语义
的组件在业界存在 pill 与圆角矩形两种画法，形状不承载「是不是 chip」这个分野。
（⚠️ 此处刻意不点名具体设计系统的具体版本——各版本的 chip 圆角规格不同，写死会造化石。）
⇒ **行业惯例锚点本身不是理由，带反事实的机制才是。**

**连带处置（8 处，逐条）**：① 作用域条款的 `Tag` 样本（随 D-44-2 处置）；② 逐字引「本句
『两侧都有成文样本』」的那条注（已改写，否则是悬空指针）；③ 皮肤变体优先序段（`Tag` 是它
唯一的举例，已追加读法说明）；④「钉为范例」条款的对照「钉死的正是它的 `step3` 结论」
（已改为「落点结论」；「钉死 = 翻转须走本回路，不是不可翻转」这条阐释按 I9 裁定
**不入公约正文**，记在本条上方与台账 R-13——#52 终审实测公约对该措辞 0 命中，原文误写成「补」）；⑤ 附录 A.2 走查表 + 结论行 +
其后的 ⚠️ 段（已同批改）；⑥ `TagInput.notes` 的「两侧实证」（已追加更正）；⑦ 条件 ③ 的
正例模板「`Tag` 的 pill 候选 → `Badge`」——**实测复核：改判后仍为真**（作用域三条件依旧
全过，变的只是落点）⇒ **不需改**；⑧ `docs/component-registry.json` 的 `Tag.notes` 里
「唯一带含义的形状陈述」这一全称断言——⚠️ **本处一度漏登记**：#52 终审把该断言收窄为
「唯一以圆角/形状为主语、并写明其含义的陈述」时，公约 / 本文件 / 台账三处同批改了，
registry 这一处因**不在本清单里**而漏掉（`dfd1f00` 漏改并在 commit message 谎报已改，
`55ce6e3` 补落并更正）。已按「只增不删」追加收窄更正段，原句保留。
台账 `docs/component-contract-revisions.md` R-13。
**⇒ 本条已处置，不再是待裁项。**

---

## #44 评审移交（Task 7）

### D-44-4：#43-1 的回写只裁了 B 类参数的兜底，C 类同形态兜底的分类未处置

#43-1 的回写（第 4 节「B 类参数的缺省兜底按 A 类处置」）实质理由是「文案本身写在组件
源码里」，而这条理由对**登记为 C 类**的同形态兜底同样成立——本仓现成实例：
`SearchField` / `TagInput` 的 `placeholder`（调用方可传参覆盖、缺省时由组件源码提供
文案，缺省值分别为 `"Search"` / `"Add tag"`），登记表 `category` 均为 `C`。回写没有一句
解释为什么 B 类参数的兜底是 A、C 类参数的兜底不是——只靠「B 类参数的」这个限定词把它们
挡在外面。

**交 #44 后续 / Task 12（epic 层面裁断，不由本 Task 决定）**：需要么把「文案写在组件
源码里 ⇒ A 类」的实质理由扩到所有源码提供的兜底（含 C 类，随之改动登记表
`SearchField.placeholder` / `TagInput.placeholder` 的 `category`），要么在公约里写明
为什么 C 类兜底应当除外。本 Task 只登记范围缺口，不做静默重分类（改动登记表分类超出
「补一行三分法」的范围）。

⚠️ **#52 裁断：本任务考察过的三条路径都不成立 ⇒ 登记 + 移交，不改公约条款。**
（⚠️ 这是「考察过的都不成立」，**不是**「给不出理由」这个全称否定——见下方未考察路径之二，
它当场证伪了那个全称否定。）

⚠️ **#52 移交落地**：`wxlpp/oh-my-story` **#55**。

**三次转向的完整记录**（这本身是交付物的一部分——不写出来，下一个人会重走同样三步）：

| 稿次 | 裁断 | 被什么推翻 |
|---|---|---|
| 初稿 | 把 `SearchField` / `TagInput` 的 `placeholder` 改分类为 **B** | `TagInput.swift` 在册的 **#173 收口裁决**（改 B 就要用 `LocalizedStringKey`、复活已删的死键、触发 `Tests/` 与 #42 迁移队列） |
| 第 2 稿 | 判「缺口本身不成立」 | **答错维度**——上游问的是**兜底维度**（`"Search"` / `"Add tag"` 这两个**组件源码字面量**为什么不按 A 处置），答的却是**分类维度**；上游给的两条出路一条都没走 |
| 第 3 稿 | 写实质理由「C 类兜底是被裁定不需本地化的默认值」 | **被公约自己当场否掉**：公约 B 类判别特征的括注**逐字包含「占位符」** ⇒ 改完之后同一节内隔十几行自相矛盾。且理由**又一次答错维度**（用「调用方可能传什么」去答「缺省值是什么」）。另有两处硬伤：把 #173 挂在从未被它裁决的 `SearchField` 头上（实测：全仓 `#173` 命中 25 行，`SearchField` 组件目录下 **0** 行）；把裁决原文的「**运行期**任意占位文案场景」写成「**开发期**占位」 |

⚠️ **三次都不对，第四次再硬编一个理由就是在重复同一个动作。** 与本轮在 D-44-2（承认未确认
有合格实例）与附录 A.5（承认空缺、不硬造样本）上采用的**同一口径**：**承认解不了优于硬造
理由。**

**移交时必须带上的四件事**（少一件，下一个人就会重走上面三步）：

1. **公约 B 类判别特征的括注逐字含「占位符」，而这两条登记为 C** ⇒ 任何处置都要**先解决
   这个冲突**，不能绕开。
2. **上游问的是兜底维度**：`"Search"` / `"Add tag"` 是**组件源码里的字面量**、用户会读到
   （`SearchField` 自己还把 `"Search"` 硬编码进 accessibility label）。「调用方可能传什么」
   **不能**回答这个问题。
3. **未考察路径之一**：**保持 `placeholder: String` 参数不变（#173 不动）+ 把组件源码里的
   那个缺省值按 A 处置**（如 `placeholder: String? = nil`，组件内部用 `String(localized:)`
   解析）。它**同时**满足 #173（调用方传入值仍 verbatim 消费）与 #43-1（源码写死的兜底文案
   本地化），且直接答在被问的那个维度上。⚠️ **本轮不采纳也不否决**——未评估其对 API 表面与
   #42 迁移面的影响。
4. **未考察路径之二**（⚠️ **最容易被按「三件」砍掉，而它正是证伪「给不出理由」的那条**）：
   **换一个维度——打 A 类的「看不见」判别特征，一个字都不用碰 B 类括注**。公约在 #43-1 回写
   时自己定义过：「看不见」指**调用方不能经由公开 API 读到这份文案字面量**。实测
   `SearchField.swift` / `TagInput.swift` 的兜底字面量**写在 public `init` 签名的缺省实参
   里、调用方读得到** ⇒ 按公约自己的判别特征**不落 A**；而 `ChapterStatus.defaultLabel` 是
   internal 计算属性 ⇒ 落 A。**区别不在参数是 B 还是 C，在兜底字面量是否暴露在公开 API
   表面**——这直接答在上游问的「兜底维度」上，与 B 类括注**零交集**，也不动 #173。
   ⚠️ 本轮**不采纳**（它要求把「B 类参数的缺省兜底」改写成按**可见性**分档，属条款重构），
   但**必须记下**：它证明「给不出理由」是个**未穷尽的全称否定**。

**⇒ 处置：登记 + 移交（移交 C），本轮不改公约 B 类括注、不改分类。**

---

## #52 公约层四条待裁的裁断（D-44-1 ~ D-44-4 收口）

> 上游四条的裁断分别记在各自条目末尾（D-44-1 见移交、D-44-2 / D-44-3 / D-44-4 见上）。
> 本节记的是**裁断过程中实测发现的新缺陷**，以及一条**被撤销的误登记**。

### ⚠️ D-52-1：**撤销**（它是已登记的 G-4，不是新发现）

#52 初稿把「`StateLabel` 的兜底文案未按 A 类处置」当成「最出乎意料的新发现」并准备开新
缺陷号。**这是错的**，实测两条：

- 公约「已知判据缺口」节的 **G-4 已完整登记**该缺口，含 `StateLabel` ↔ `ChapterStatus`
  的同构、不合规、以及「登记为已知例外 + 移交」的处置；
- **`wxlpp/oh-my-story` 的 #49 就是承接 G-4 的 issue**（实测 `gh issue view 49` ⇒
  `OPEN`，标题逐字含「公约缺口 G-4」），由 #44 收口时开出。

⇒ **撤销 D-52-1，编号作废不复用，不新建缺陷号。** #52 只在移交 A 里处理 `StateLabel` 的
**另一件事**（其 `notes` 套用 `Badge` 的规则却得相反结论），与 G-4 的类型改造是两回事，
两条改动的顺序与互不干扰要求写在移交 A 的正文里。

⚠️ **一并撤销初稿的另一条事实错误**：初稿称公约 G-4 行里「实测 A 计数恒为 **0**」会在 #49
落地后变假、须加时点限定。**它不会变假**——`defaultLabel` 是 internal `struct Spec` 的
字段，不是 public `init` 参数；`textParams[]` 按定义只收 **public 参数**；先例已裁：
`ChapterStatusBadge` 是 #43-1 的标准案例，它保持 `category: "B"`，`notes` 明写
「`defaultLabel` **不是 public init 参数**……非本条 `textParams` 覆盖范围」。
⇒ 给一个**定义上为真**的陈述加时点限定，等于往真陈述里注入假 hedge。**不做。**

### D-52-2：`SearchField` / `TagInput` 的 C 分类**互为循环依据**

两条的 C 分类各自把对方当依据，形成闭环：

- `TagInput` 的依据是 **#173 收口裁决**「仿 `SearchField` 先例」；
- `SearchField.notes` 的依据反过来是「**比照同款处理的** `TagInput.placeholder`」，
  另一侧的理由是「文档未给出迁移意图」——**消极描述**，不构成实质依据。

⚠️ **`SearchField` 源码从未被 #173 裁决**：实测（基线 `511576f`）全仓 `#173` 命中 **25 行**（⚠️ 本轮回写文本自身的 `#173` 引用不计入该数），
`Sources/CoreDesign/Components/SearchField/` 下 **0 行**。

⚠️ **循环措辞的落点要写清「哪种措辞、在哪、能不能 grep 到」，不要写一个笼统的总数**
（前两稿写过的「4 处」/「3 处」都复算不出来）：

| 措辞形态 | 位置 | 单行 `git grep` 能否命中 |
|---|---|---|
| 逐字 `仿 SearchField 先例`（无反引号） | `Tests/CoreDesignTests/SharedFoundationTests.swift` | **能**（1 处） |
| `仿 ` + 反引号包裹的 `` `SearchField` `` + ` 先例` | `docs/BREAKING-CHANGES.md` | 逐字 `仿 SearchField 先例` **不命中**；正则 `仿 \`\?SearchField\`\? 先例` 命中 |
| 同义但**跨行断开**：「仿 `SearchField.placeholder` / 先例，verbatim 消费…」 | `Sources/CoreDesign/Components/TagInput/TagInput.swift` | **不能**——单行 grep 对跨行断开的措辞必不命中 |
| 另一措辞，registry 侧互指（2 条） | `docs/component-registry.json` 的 `SearchField.notes`「比照同款处理的 `TagInput.placeholder`」+ `TagInput.notes`「与 `SearchField` 同款处理」 | **能**（各 1 处） |

**⇒ 移交**（并入移交 C，与 D-44-4 同批）：处置这条必须**同时**处理上面四种形态，只 grep
一种会漏。**本轮不裁**——它与 D-44-4 是同一个兜底维度问题的两面。

### D-52-3：公约对 `Skeleton*.notes` 的描述失实（**已修，本条为登记留痕**）

公约第 1 节步骤 2 原先称登记表 `SkeletonCircle` / `SkeletonLine` / `SkeletonRect` 三条的
`notes`「**对应的正是**『形状 = 占位内容类型的声明』这条积极理由」。**实测失实**：

- 三条 `notes` 全文分别只有 **58 / 39 / 39** 字符；
- 它们**确实点出了**形状 ↔ 占位内容类型的配对（头像→圆、文本行→圆角矩形、图片/卡片→矩形），
  但**没有一条写出反事实机制**——「圆形换成方形，占位对象就从『头像』读成『图片』」这句在
  **这三条 `notes` 里一次都没出现**（⚠️ 登记表里唯一出现该句的是 `Tag.notes`，那是 #44
  引用本公约例段的压测记录，与 `SkeletonCircle`/`SkeletonLine`/`SkeletonRect` 自己的机制
  陈述无关——不是「全登记表命中 0」）；
- 三条都终止于公约明令不算数的「长相即含义」这句**结论复述**。

⚠️ **公约内部对同一份 `notes` 给出两种描述**：另一处（「事后补写的效力边界」小节）自认
「`SkeletonCircle` … 是因为它的 `notes` **从未枚举过候选**」。

**处置**（按「先登记为缺陷、再修」的回路，与本 epic 自己写的「记入缺陷 → 回写公约 →
留痕」一致）：公约该处已改为**如实描述 `notes` 的实际内容**——公约不该替登记表声称它没写的
东西。⚠️ **`Skeleton*` 本身不改判**（#41 明令本 epic 不改判它）：实测四条的 `decidedBy`
仍全为 `step3`。

### D-52-4：`Skeleton*` 作为「非关系性积极理由」旗舰范例的两处自反（**本轮不裁，移交**）

1. **`SkeletonRect.cornerRadius` 是 public 参数且能渲染出圆形**（`Skeleton.swift`：
   `cornerRadius: CGFloat = CoreRadius.medium`，`CoreShape.rounded(self.cornerRadius)`）
   ⇒ 与判死 `SettingsRow` 的「**公开 API 自证骨架不固定**」**同型**——`SettingsRow` 正是
   因为公开 API 反证了它宣称的固定骨架而被判死的。
2. **`Skeleton*` 的机制是关系性的**（「圆形 vs 方形」这条反事实依赖兄弟 `SkeletonRect` 的
   存在才成立）⇒ 若成立，公约**最旗舰的「非关系性积极理由」样例本身是关系性的**。

⚠️ **本轮不裁、不改判**：#41 明令本 epic 不改判 `Skeleton*`，且改它会牵动公约多处旗舰引用。
**⇒ 登记 + 移交**（并入移交 A，标「优先复核」）。

#### ⚠️ #53 裁断（移交 A 收口；**只出结论，不改判**）

**逐条裁断**（两点**不是同一个问题**，分开写；每条附本轮实测证据，不裸断言）：

1. **`SkeletonRect.cornerRadius` 的公开 API 自反** —— 实测
   `Sources/CoreDesign/Components/Skeleton/Skeleton.swift` 的
   `public init(width: CGFloat? = nil, height: CGFloat = 120, cornerRadius: CGFloat = CoreRadius.medium)`
   （⚠️ 源码 `:178-181` 是**断行**写的，此处为便于阅读拼成一行，非逐字原文）
   把 `cornerRadius` 交给调用方；`Sources/CoreDesign/Tokens/CoreRadius.swift` 的
   `CoreShape.rounded(_:)` 返回普通 `RoundedRectangle`、**对 radius 无上限 clamp**
   ⇒ `width == height && cornerRadius == width / 2` 时 `SkeletonRect` 在几何上渲成与
   `SkeletonCircle` 视觉等价的圆形。四条 `Skeleton*` 的 `notes` 里**无一条讨论或排除**
   这一形态。**裁断：成立，理由**：`SettingsRow` 被判死的机制是——它曾写出一条形式合格
   的反事实句（「把图标方块换成头像圆、把 accessory 拿掉，读到的就变成通讯录行」），但
   四个 `init` 的 `icon` 参数默认 `nil` 这一公开 API 事实反证了「长相固定、不给扩展点」
   的前提，判死落点是 `tiebreaker`（见公约第 1 节 `:189-192`）。`SkeletonRect` 与此
   **同型但更强**：`SettingsRow` 的自反是**同类型内**的（同一个 `SettingsRow` 实例因
   `icon` 可选而读法不定）；`SkeletonRect` 的自反是**跨兄弟**的——公开可调的
   `cornerRadius` 能让 `SkeletonRect` 的一个具体实例在几何上直接坍缩成 `SkeletonCircle`
   的**规范形状本身**，比 `SettingsRow` 那种"读法漂移"更直接地反证了"形状固定、无
   configurability"这条 `step3` 前提。两者的公共机制是：`decidedBy: step3` 依赖的
   「长相即含义、不给扩展点」这句前提，被**同一个组件自己的公开 API** 证伪。
2. **「圆形 vs 方形」这条反事实是否关系性** —— 该句的 Y 是「图片」。**裁断：成立，
   理由**：公约第 1 节 `:77-81` 引出此句时，通篇是把 `SkeletonCircle`/`SkeletonLine`/
   `SkeletonRect` **三个具名兄弟**放在一起走查（「分别用固定几何形状…代表头像/文本行/
   图片卡片」），"图片"这个读法在公约正文里**唯一的来源**是 `SkeletonRect.notes`
   自己的措辞（「图片/卡片占位形状」）——实测公约本段前后**没有引用任何业界惯例**
   （如常见图片信息流 / 卡片加载态的截图或产品名），也**没有落到独立于登记表的具体
   渲染事实或源码符号**；(B) 的门槛原话是「Y 必须是可独立指名的真实误读对象（业界
   惯例引证，或落到具体渲染事实 / 源码符号）」，且明文排除「把兄弟组件剥掉后它就没有
   内容了」这类关系性理由（举例即「不使用 `.full`，这是与 `Badge` 的区分点」）。把
   `SkeletonRect` 从这句里剥掉——公约正文当前不提供任何独立于该兄弟组件的证据支撑
   "方形 = 图片"这个读法 ⇒ 按公约自己写的 (B) 判据，该句**如现状所写**是关系性的。
   ⚠️ 本裁断只判**公约现有文本**的证据链是否独立于兄弟组件，不排除存在一个更完整、
   引了独立业界惯例的版本能通过 (B)——但那样的版本**不是现在公约里写的这一版**。

**处置**：⚠️ **`Skeleton*` 四条一律不改判**（#41 明令，spec §七 硬边界）——实测四条
`decidedBy` 仍全为 `step3`，`docs/component-registry.json` 本条**零改动**。#53 只出结论 +
登记；**改判须另走完整修订回路**。

⚠️ **后果范围（hedge：本段是本轮裁断给出的判断，不是既成的改判事实）**：若上面两点
裁断成立这件事本身被采纳，它意味着公约**目前唯一**的 `step3` 教学范例（骨架屏例段）
按 (B) 门槛的字面标准**可能不再合格**——但这只是本轮对现有文本的裁断结论，**不等于
`Skeleton*` 已被改判、也不等于例段已被认定必须重写**：是否据此改判、是否需要给例段
换一个独立业界惯例引证以救活它，都须走下面的承接处，而不是本 task 自行决定。

⚠️ **承接处（不许留无主的结论）**：本裁断若要求改判 `Skeleton*`，承接方为 **#54 收口时
合并两侧结论后新开的公约修订 issue**；若 #54 收口时本条仍未被处置，**须新开 issue 明确
承接**——不得停在「已裁断但没人改」这个状态（与 `D-53-1` 收口段的递延规则同款）。

**连带**：公约第 1 节骨架屏例段的「⚠️ 照抄本范例前先看 D-52-4」指针句已同批改写为「已裁断」
形态（台账 `R-16`）；⚠️ **例段本体（「圆形换成方形，占位对象就从『头像』读成『图片』」）
本轮保留**——删它等于在没有替代样例的情况下抽掉公约唯一的 `step3` 教学范例，超出「只出
结论」的授权。

### D-52-5：两条豁免路径在「枚举出 ≥2」的场景下一次都没走通（**实证断言，不是结构性断言**）

**实测**（作用域：#52 审计基线，即 `Tag` 改判前的 50 条 `step3`）：6 条做过候选枚举的条目
中，**3 条枚举出了 ≥2**（`AvatarGroup` / `OutlineTree` / `CodexEntryList`），这 3 条
**全部未走通两条豁免路径**（皮肤变体条款 / 作用域条款）——`OutlineTree` 把皮肤变体条款
**用反了**（以「候选结构完全不同」为由排除，而「结构本身不同」正是公约评分范例用来**认定**
≥2 成立的判据）；`CodexEntryList` 用的是**功能性淘汰**（AX5 挤压、`ImageRenderer` 不渲），
不是这两条款中的任何一条；`AvatarGroup` 点名的只有业界产品（Slack/Discord/Figma）与
「头像列表」（`AvatarList` 不在登记表内，作用域条件①即告失败）。⇒ 三条**全部失 (A)**。

⚠️ **不能扩成「两条豁免路径从未被正确援引过」**——那是个被同一批数据证伪的全称否定：
**唯一一次正确援引的正是 `Tag`**（只枚举 1 个候选、经作用域条款三条件正当排除、(A) 通过），
公约还把它钉为作用域条款的正例模板。⚠️ 也**不说明**「窗口只有恰好 1 个候选」。

⚠️ **不写成结构性断言**（「举 0 则 (B) 必挂、举 ≥2 则 (A) 挂」）——**两个方向都被公约自身
范例证伪**：公约的旗舰范例是「**举不出**替代形态 + **能额外说清**『圆形换成方形就从头像读成
图片』」⇒ **0 个枚举 + 完整反事实并存**；而 (A) 的定义本就含「候选被**正当排除**」⇒ ≥2
只要排除得当照样过——`Tag` 自己就是「枚举 pill → 被作用域条款正当排除 → (A) 通过」的现成
反例（它栽在 (B)）。

**操作结论**：移交 issue **不能只写「去补跑枚举」**——执行者认真枚举后若不援引豁免路径，
会集体落到出口 1，那**不是复核，是批量改判**。移交 A / B 的正文必须写明这一点。

---

## #53 移交 A：CoreDesign 侧 25 条 `step3` 补跑复核

范围：`docs/component-registry.json` 中 `decidedBy == "step3"` 且 `repo == "coredesign"` 的
**25** 条（实测，`18f92fc`）。⚠️ **25 + 24（StoryUI，移交 B / #54）= 49**，与 `D-44-1`
「一律以 **49** 为准」吻合。

### D-53-1：(A)(B) 操作化门槛判的是 `notes` 现状还是组件实质——第一次真实使用即撞出的判定歧义

**成因**：#52 把 (A)(B) 写进公约步骤 3，但**它从未被任何真实判定检验过**；#53 是第一次
真实使用。摸底实测（`oh-my-story` 仓 `.claude/epics/component-contract/53-survey.md`，
25 条逐条、含 `notes` 全文）：**25 条中枚举数为 0 的有 23 条**，真正枚举了候选形态的
**2 条**（`AvatarGroup` 2 个、`Steps` 1 个），**同时满足 (A)(B) 的 0 条**；23 条直接以
「长相即含义」「固定结构」「无独立视觉身份可换皮」收尾——**这些恰是 (B) 明令不算的消极
描述或结论复述**。

**歧义本体**：(B) 的判据是「`notes` 里**有没有写出**一句带反事实机制、不引兄弟名的积极
理由」。但「`notes` 没写出来」与「这个组件实质上不满足」是**两件事**：

| 例 | `notes` 现状 | 组件实质 |
|---|---|---|
| `ChevronRightIcon` | 「长相即含义」（(B) 不算）| chevron 的**指向性**可能就是它的含义 ⇒ **可能真满足** |
| `Separator` | 「长相即含义」（(B) 不算）| 留白也能分隔 ⇒ **实质大概率也不满足** |

⇒ 存在**三种状态**，而门槛只区分了两种：① `notes` 不合格 + 实质也不满足 ⇒ 改判；
② `notes` 不合格 + 实质满足 ⇒ **补写 `notes`，不改判**；③ `notes` 合格 ⇒ 通过（实测 0 条）。
**只按 `notes` 现状判 ⇒ 25 条全灭**，那不是复核，是批量改判——正是 `D-52-5` 的操作结论在
(A) 侧警告过的形态，#53 实测它在 (B) 侧同样成立。

**处置（本轮已执行，不是移交）**：#53 把该歧义按完整修订回路处置——① 本条登记；
② **回写公约正文**（第 1 节步骤 3「操作化门槛」小节末尾新增「(A)(B) 判的是组件实质，
`notes` 现状只是证据」规范段，含三种状态表、两段式走法、「直接改判」档的可核验理由要求、
补写句自身过 (B) 的要求、以及「本段不改门槛措辞、不新增出口」的边界声明）；③ 台账
`R-15` 逐条留痕。

⚠️ **不设降级选项**：只写本缺陷条目**同样是公约正文里没有它**，只把层级抬了半格，仍是
私有解释；而且那会造成内在不一致——`A.1` 一句**不翻转结论**的措辞修订都被要求走完整回路
（见 `D-44-1`「移交 A」段的 #53 处置留痕 / 台账 `R-14`），而两段式这个**支配全部 25 条
走法**的再解释反倒允许跳过「回写公约」，说不通。

⚠️ **这不等于「修改 (A)(B) 门槛本身」**——门槛措辞一字未动。公约第 1 节骨架屏例段已示范
过合规写法，23 条同型失败更可能是「`notes` 写于门槛之前」的历史产物，不是门槛把一整类
合法理由排除在外。**澄清判定对象 ≠ 重写门槛 ≠ 废除出口**，三者是不同粒度的动作，#53 只
做第一件。

⚠️ **供 #54 引用**：StoryUI 侧 24 条**须采同一解释**，否则两侧结论不可比——而「两侧结论
可合并后再裁断 `step3` 通路存废」正是移交 A / B 拆分的前提。

### D-53-2：段 1「直接改判」档 2 条同型失败（`notes` 以消极结论收尾 + 零枚举）—— 合并登记

**批量口径的自我授权**：`53-spec.md` §六之二明文授权批量口径（先例：台账 `R-3` 的「六条
候选」就是批量条目）——「`notes` 失败原因同型（都以『长相即含义』『固定结构』这类消极
结论收尾、且无枚举）的条目，合并为一条缺陷 + 一条台账条目，但必须逐条列名、逐条给出
『直接改判』的可核验理由」「连带面分析仍须逐条做——**合并的是登记形式，不是审查深度**」。
`53-triage.md`「直接改判」档共 2 条（`SectionFooter`/`Descriptions`/`SettingsRowChevron`
三条为 §3.2 委托方，归 Task 8 独立重走，不并入本批），本条即该批量口径下的合并登记。

**逐条列名 + 逐条可核验理由**：

| 组件 | (A) 失在哪 | (B) 失在哪 | 可核验的「实质也不满足」理由 | `53-survey.md` 证据行 |
|---|---|---|---|---|
| `Card` | 枚举候选 0 个、零 elaboration（唯一提到的「外观变化」有/无描边是自身已有的历史变体，已被 `CardKind` 吸收，不是被排除的外部候选）| `notes` 仅「本身无独立视觉身份可换皮」「视觉即含义」两句消极描述/结论复述，无反事实句 | `notes` 自陈 Card 是 `.surface(.content)` / `.surface(.grouped)` 的具名薄封装，本身无独立视觉身份——组件文档自己承认调用方可直接用 `.surface(.content)` 达到同样效果，无需读源码即可判定 | 条目 2（"枚举候选"/"积极理由/反事实机制"两栏） |
| `Separator` | 枚举候选 0 个、零 elaboration | `notes`（95 字）仅「长相即含义」结论复述收尾，无反事实句 | `notes` 全部视觉内容仅为「hairline 宽度 + 语义 token 颜色固定」——这是分隔线的具体画法参数；「分隔相邻内容区块」这一功能语义在留白/间距不渲染任何可见线条时同样能达成，是与 hairline 并存的常见等效手段，`notes` 全文未论证为何必须用可见细线而非留白传达「分隔」 | 条目 10（"枚举候选"/"积极理由/反事实机制"两栏） |

**为什么不进段 2**：两条的 `notes` 本身已经把「唯一的视觉理由」写全（Card 的
`.surface(.content)` 薄封装身份、Separator 的 hairline 参数描述），不存在段 2 需要
「读源码 + 公开 API + 渲染语义」才能发现的额外信息——`notes` 描述 + 普通设计常识（组件
可被其薄封装的底层 modifier 直接替代；留白/间距同样传达「分隔」这一功能语义）即可判定
实质也不满足，符合 `53-triage.md`「直接改判」的操作标准（`notes` 描述 + 普通设计常识，
无需读源码 / 无需业界调研）。

⚠️ **`Separator` 专项说明**：本条的判定**未引**本文件公约正文第 1 节步骤 3 操作化门槛
小节末尾「合格理由形如『留白 / 空隙同样承担分隔，`Separator` 的具体画法不承载含义』」
一句作为依据（该句由 `R-15` 写入公约正文时以 Separator 的实质结论作范例，此刻若拿它作
本条判定的理由会构成循环论证）；本条改引 `53-triage.md` #10 / `53-survey.md` 条目 10
独立复核。`53-triage.md` 该条备注已自陈「留白同样承担分隔」是外部设计常识、不在 `notes`
里，且不宣称「独立推导」（同款论证逐字预存于 spec / plan / 公约三处，锚定效应无法排除，
只主张与预存范例同向、经独立核验成立）——本条采同一诚实口径。独立复核结论与公约范例
**一致**（非相反），不触发「须同批修订」标记，`docs/component-contract.md` 该处**不改**。

**回路指针**：公约回写——实测 `docs/component-contract.md` 两条在该文档的引证（`Card`
的 `CardKind`/`bordered:Bool` 迁移语境、`Separator` 的「合格理由」范例句）均判非承重，
**0 处**回写（见台账 `R-17`「连带改动」的逐条扫描）；台账 `R-17`。

---

## #53 移交 A 段 2：CoreDesign 侧「待压测」档 12 条源码级压测改判（逐条独立登记）

**批量口径边界（spec §六之二）**：段 2（待压测档）是本轮判断密度最高的部分——每条独立读
源码、逐条枚举、逐条走豁免路径，**不适用** `D-53-2` 那种「合并登记」口径。以下 `D-53-3` ~
`D-53-14` 共 **12** 条，每条一个缺陷号 + 台账一个 `R-` 号（`R-18` ~ `R-29`），逐条自足
（不写「见 53-stress.md」了事）。

**取证总源**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md`「结论汇总」表
（17 条待压测中，12 条改判、0 条保留、5 条按「## ⚠️ #53 裁定」段移交后续 issue、本轮零改动：
`SidebarStatusFooter` / `SidebarUtilityRow` / `SpinningModifier` / `Steps` / `Timeline`）。

**⚠️ 落点口径说明（`Descriptions` / `SettingsRowChevron` / `SectionFooter` 三条）**：
`53-triage.md` 在段 1/2 三分时把这三条标注为「委托方，Task 8 独立重走」（依赖兄弟
`InsetGroupedSection` / `ChevronRightIcon` / `SectionHeader` 的档位先定）。但三条与其依赖的
兄弟同属本轮「待压测」批、由同一次 `53-stress.md` 压测**一并**处理——兄弟档位在同一份文件里
已先行落定为 `tiebreaker`（`InsetGroupedSection` 更早、`ChevronRightIcon`/`SectionHeader` 与
这三条同批），三条各自的结论（见 `D-53-6`/`D-53-11`/`D-53-9`）也已逐条论证**不依赖**兄弟档位
本身（承重的是各自的公开 API 反证 + 第 2 项实质问句）。`53-stress.md` 收口时的「## ⚠️ #53
裁定」段与「## 统计」段据此把三条计入本轮「改判」12 条、末尾明写「本轮实际落地 14 条：
Task 6 的 2 条 + Task 7 的 12 条」——即 #53 在压测收口时把「委托方待兄弟先定」的前提确认为
已满足，三条随本批（Task 7）一并落地，**不再等待独立的「Task 8」处理**。`D-53-2`／`R-17`
（Task 6 落地时）沿用的是 `53-triage.md` 较早的委托方措辞，未反映这一收口结果——本条据实
更正落点，`D-53-2`／`R-17` 原文按「只增不删」不作回改，仅在此处记录口径演进，供 #54 与后续
复核参考。

### D-53-3：`AvatarGroup` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 1 节；
`53-survey.md` 证据行 1。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift:18,22,46,32-39,49-53,56-69,77-86。public init(max:avatars:) 只暴露 max 与 @ViewBuilder 头像槽；重叠靠 HStack(spacing: overlapOffset) 的负数（-6/-8/-10，按 controlSize），单元画法固定为 clipShape(Circle())+strokeBorder(surfaceCanvas)。

**② (A) 诚实枚举**：候选 1 = **并排不重叠的头像行 + 溢出计数**（来源：Google Docs 协作者栏、Microsoft Teams 成员条），豁免路径：皮肤变体走通（与现状同一 HStack 骨架，只差 spacing 正负号）；作用域 ③ 对 Avatar 落空（Avatar 只承担单个头像占位，不承担多头像并排排列）。 候选 2 = **纯计数徽标（无头像脸，只有『+12』文本块）**（来源：GitHub Contributors 计数、Linear issue assignee 计数），豁免路径：皮肤变体未走通（拿掉整个『每人一圆』单元骨架）；作用域 ③ 对 Badge 落空（Badge 只承担固定状态描述文案，不承担成员计数）。

**③ 皮肤变体交叉裁断**：候选 1 命中皮肤变体（AvatarGroup.swift:46 的 HStack spacing 正负号是并排/重叠的唯一差异，单元画法逐字不变）⇒ 不计入 ≥2；候选 2 非皮肤但只有 1 个 < 2 ⇒ 举得犹豫 ⇒ 落步骤 4。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 2 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：佐证（命中皮肤变体裁断，只能作佐证，不得据以判 step3）：把重叠交叠改成并排等距排列，这一组头像就从『同属一个组、数量被压缩显示的成员集合』读成『一份逐个列出的人员名单』——重叠本身在声明『这里还有没画出来的人』。Y=『逐个列出的人员名单』有 Google Docs/Microsoft Teams 业界锚点、不引兄弟组件名，已单独过 (B)。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-3` / `R-18`。

### D-53-4：`ChevronRightIcon` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 2 节；
`53-survey.md` 证据行 3。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/Form/Form.swift:87-98。public init() 零公开参数；body 只有 Image(systemName:"chevron.forward") + accessibilityHidden(true)；配色字号全部继承父容器（doc :84-86），doc 自留『未来可加默认参数走 CoreControlMetrics.iconSize(for:)』的扩展口。

**② (A) 诚实枚举**：候选 1 = **右向实心三角**（来源：SF Symbols arrowtriangle.forward.fill、macOS NSOutlineView 展开指示符），豁免路径：皮肤变体走通；作用域 ③ 落空（登记表内无 Triangle*/Disclosure* 组件）。 候选 2 = **右箭头字形**（来源：Material Symbols arrow_forward_ios、Gmail/Google 设置页），豁免路径：皮肤变体走通；作用域 ③ 落空。 候选 3 = **『>』半角字符**（来源：早期 Web 面包屑、iOS 前身纯文本披露符），豁免路径：皮肤变体走通；作用域 ③ 落空。

**③ 皮肤变体交叉裁断**：三者共享『单一字形占 trailing 一格、指向阅读方向下一级』同一骨架，差异只是字形画法 ⇒ 全部不计入 ≥2 ⇒ 举得犹豫 ⇒ 落步骤 4（与 Tag 的路径同型）。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：无合格句：唯一可写的『拿掉字形就从入口读成只读值』不是替代形态而是删除组件，论证等于论证『本组件存在有用』，不是『换个长相就不是这个东西』。不引兄弟组件名（SettingsRowChevron 只出现在枚举记录里）。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-4` / `R-19`。

### D-53-5：`DangerIcon` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 3 节；
`53-survey.md` 证据行 4。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/Form/Form.swift:107-120。public init() 零公开参数；body 为 Image(systemName:"exclamationmark.circle.fill")+foregroundStyle(statusDangerForeground)+accessibilityLabel("Alert")；尺寸继承父容器字号（doc :103）。

**② (A) 诚实枚举**：候选 1 = **三角形感叹号**（来源：SF Symbols exclamationmark.triangle.fill（与 circle.fill 并列提供）、Xcode issue navigator、Material Symbols warning），豁免路径：皮肤变体走通；作用域 ③ 落空（StateLabel 是文本状态标签、Badge 是状态色块，均不承担字形本身）。 候选 2 = **八边形/停止牌**（来源：SF Symbols exclamationmark.octagon.fill、Material dangerous、交通停止标志惯例），豁免路径：皮肤变体走通；作用域 ③ 落空。 候选 3 = **纯色圆点（无字形）**（来源：GitHub/Slack 的未读与告警红点），豁免路径：皮肤变体未走通（拿掉字形层，骨架不同）；作用域 ③ 落空（Sidebar.swift:355-363 的状态点是 SidebarStatusFooter 内部私有渲染，登记表内无独立状态点组件）。

**③ 皮肤变体交叉裁断**：候选 1、2 命中皮肤变体（同为『实心几何外框 + 内嵌感叹号 + 语义危险色』骨架，差异只是外框画法）；候选 3 非皮肤但只有 1 个 < 2 ⇒ 举得犹豫 ⇒ 落步骤 4。SF Symbols 同族并列提供 circle/triangle/octagon 三种外框是可当场核验的反例，『枚举为 0 的残余侧路』实测走不了。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：无合格句：拟句『换成中性灰读成附加说明』论证的是颜色 token 而非长相，属偷换；另一拟句『换成三角读成 warning』被源码自陈证伪——Form.swift:115-117 明写 danger(红)/warning(橙) 在本库靠颜色而非外框区分，是公约警告的『形式合格的假句』正面样本。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-5` / `R-20`。

### D-53-6：`Descriptions` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 4 节；
`53-survey.md` 证据行 5。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/Style/Descriptions.swift:99,112-122,128-139,191-193。public init(columns:dividerDensity:header:content:) 已带 DescriptionsColumns(.one/.two)×DescriptionsDividerDensity(.none/.row) 共 4 种公开可选长相；body 把全部 chrome 委托给 InsetGroupedSection(header:dividerInset:.textAligned) 与 .labeledContentStyle(.core)，本组件自己只画内边距。

**② (A) 诚实枚举**：候选 1 = **带边框的键值表格**（来源：Ant Design Descriptions 的 bordered prop——同名组件把有边框/无边框列表作为同一组件的两种长相发布），豁免路径：皮肤变体走通（同为『每行 label+value』骨架）；作用域 ③ 落空（InsetGroupedSection 承担的恰是无边框圆角卡片）。 候选 2 = **label 在值上方的纵向布局**（来源：Ant Design layout="vertical"、HTML <dl> 默认纵向），豁免路径：皮肤变体未走通（label/value 相对几何关系变了，非换画法）；作用域 ③ 落空。 候选 3 = **无卡片纯文本键值段**（来源：Semi Design Descriptions 的 plain 风格），豁免路径：皮肤变体走通；作用域 ③ 落空。

**③ 皮肤变体交叉裁断**：候选 1、3 命中皮肤变体（与 InsetGroupedSection 条目 I-3 裁断同型：insetGrouped/plain/sidebar 三者共享 header+行+footer 骨架）；候选 2 非皮肤但只有 1 个 < 2 ⇒ 举得犹豫。第 2 项实质问句独立答『是』（换成表格/纵向布局仍是一张键值描述列表）⇒ 两条路径同向落步骤 4。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：无合格句：通读源码 :99-195，本组件自己决定的渲染事实只有『1/2 列切分 + 分隔线密度 + 行内边距』，三样全部是公开参数或从 SettingsRowMetrics 借来的常量，写不出一句 X 不是公开参数值的『换成 X 就读成 Y』。⚠️ 53-triage.md 曾标注本条为『委托方，Task 8 独立重走』（依赖兄弟 InsetGroupedSection）——本结论不依赖该兄弟档位（InsetGroupedSection 已是 tiebreaker，且承重的是第 2 项实质答案 + 第 1 项公开 API 反证），随本批（Task 7）与其余 11 条一并处置，见文末『落点口径说明』。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-6` / `R-21`。

### D-53-7：`FloatingGlassModifier` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 5 节；
`53-survey.md` 证据行 6。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Modifier/FloatingGlassModifier.swift:10-17,19-35,38-45,55；Sidebar.swift:404-406。public struct 带 public let shape: S（任意 InsettableShape）+ isInteractive: Bool；View.floatingGlass(in:isInteractive:) 默认值只是 Capsule，仓内实际调用点传过 CoreShape.rounded(.large)/(.medium)。body 三层：inset(by:).fill(.background.opacity(0.64)) + .glassEffect(glass,in:shape) + overlay(strokeBorder(borderSubtle))。

**② (A) 诚实枚举**：候选 1 = **不透明面 + 投影（elevation）**（来源：Material Design 3 elevation/surface tint、Android FAB/bottom sheet），豁免路径：皮肤变体走通（同为『shape 轮廓 + 一层背景处理 + 一条边缘描边』骨架）；作用域 ③ 落空（Card 承担的是内容表面而非浮层）。 候选 2 = **半透明模糊/振动材质（非玻璃）**（来源：iOS 7–17 UIBlurEffect、macOS NSVisualEffectView（Liquid Glass 直接前身，真实在产）），豁免路径：皮肤变体走通；作用域 ③ 落空。 候选 3 = **纯描边无填充浮层框**（来源：Ant Design/Bootstrap popover 默认白底细描边），豁免路径：皮肤变体走通；作用域 ③ 落空。

**③ 皮肤变体交叉裁断**：三者与现状共享『调用方给定 shape 作轮廓 + 一层背景处理 + 一条边缘描边』同一骨架（源码即 :22-34 的 background+overlay 两句）⇒ 全部不计入 ≥2 ⇒ 举得犹豫 ⇒ 落步骤 4。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：无合格句：拟句『换成不透明白底读不出浮在内容之上』是假句——Material elevation 用阴影表达同一层级关系，业界几十年在用，Y 不成立（形式合格但内容为假，非关系性）。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-7` / `R-22`。

### D-53-8：`LabelIcon` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 6 节；
`53-survey.md` 证据行 7。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/Form/Form.swift:27-75。两个 public init（:36 systemName+backgroundColor:Color、:48 systemName+backgroundStyle:some ShapeStyle）——上层字形与底层着色（任意 ShapeStyle，含 gradient/material）均由调用方传入；组件自己固定的只剩 24pt/16pt 两个几何常量与 Color.contentInverse。

**② (A) 诚实枚举**：候选 1 = **无底色单色字形图标**（来源：Material list item leading icon、WhatsApp/Telegram 早期设置页），豁免路径：皮肤变体未走通（两层叠合的底层整个删掉，一层 vs 两层是骨架差异）；作用域 ③ 落空（SettingsRowIcon 承担同样的圆角色块+反白字形，不是无底字形；ChevronRightIcon/DangerIcon 是 trailing 指示符不是 leading 类别图标）。 候选 2 = **圆形底 + 字形**（来源：Google/Android 联系人与设置项圆形图标底、Gmail 圆形分类图标），豁免路径：皮肤变体走通（同为两层叠合，只换底层形状）；作用域 ③ 落空。 候选 3 = **emoji/图片替代字形**（来源：Notion 页面图标、Slack 自定义频道图标），豁免路径：皮肤变体走通（仍是『底+前景』两层）；作用域 ③ 落空。

**③ 皮肤变体交叉裁断**：候选 2、3 命中皮肤变体；候选 1 非皮肤但只有 1 个 < 2 ⇒ 举得犹豫。第 2 项实质问句独立答『是』（去掉方块底只留单色字形，仍是这一行的类别图标）⇒ 落步骤 4。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：无合格句：拟句『反白字形换同色字形读不出图标』既非形态替换也为假；真正固定的 24/16pt 常量是几何取值，公约明写取值层固定不构成含义（不引兄弟组件名）。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-8` / `R-23`。

### D-53-9：`SectionFooter` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 7 节；
`53-survey.md` 证据行 8。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/Section/SectionFooter.swift:20-41。整个渲染是 3 个 modifier——coreFont(.footnote)(:37)+foregroundStyle(contentSecondary)(:38)+frame(maxWidth:.infinity,alignment:.leading)(:39)；两个 public init 只区分 LocalizedStringKey 与 StringProtocol，不产生视觉差异。

**② (A) 诚实枚举**：候选 1 = **caption 字号 + 前缀信息字形的 helper text**（来源：Material supporting text（常带 leading icon）、Ant Design Form.Item extra），豁免路径：皮肤变体走通（同为『分组下方一段说明文本』骨架）；作用域 ③ 落空（Banner 承担带背景的提示块，不是分组说明文字）。 候选 2 = **浅底说明块**（来源：Ant Design Alert 型 form 说明、GitHub 设置页灰底说明框），豁免路径：皮肤变体走通（加背景仍是同一段文本的 chrome）。 候选 3 = **与卡片同宽的分隔线 + 说明**（来源：macOS 系统设置分组脚注排版），豁免路径：皮肤变体走通。

**③ 皮肤变体交叉裁断**：三个候选全部命中皮肤变体——结构性理由：本组件的全部渲染就是排版本身（3 个 modifier），组件自身 = 一套字号/字色/对齐时，其任何替代必然共享『一段文本置于分组下方』这唯一骨架，只能是皮肤变体 ⇒ 举得出但全是皮肤变体 ⇒ 举得犹豫 ⇒ 落步骤 4。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：佐证（命中皮肤变体裁断，只能作佐证）：把 footnote 灰换成 body 黑，这段字就从『对上面这组的说明』读成『正文内容的一部分』。Y=『正文内容』落在 :37-38 两个渲染事实上、不引兄弟组件名（SectionHeader 一词不出现在句中）。⚠️ 53-triage.md 曾标注本条为『委托方，Task 8 独立重走』（依赖兄弟 SectionHeader）——SectionHeader 在同批（本 task）已一并改判 tiebreaker，随本批与其余 11 条一并处置，见文末『落点口径说明』。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-9` / `R-24`。

### D-53-10：`SectionHeader` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 8 节；
`53-survey.md` 证据行 9。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/Section/SectionHeader.swift:15-17,25-51。渲染=5 个 modifier——coreFont(.footnote)+textCase(.uppercase)+foregroundStyle(contentSecondary)+frame(...)+accessibilityAddTraits(.isHeader)。doc comment 自陈『刻意用 .insetGrouped 惯例（大写）而非 .sidebar 风格（非大写）——Phase 1 视觉终审发现 demo 误用 .sidebar list style 导致 header 非大写』——本仓自记的『同一分组标题确有非大写在产渲染』事实。

**② (A) 诚实枚举**：候选 1 = **title-case、非大写的 sidebar 风格分组标题**（来源：SwiftUI .sidebar list style 系统渲染（本仓 :15-17 自述实测过）、macOS Finder 边栏分组标题），豁免路径：皮肤变体走通；作用域 ③ 对 SidebarSection（标题走 .headline+contentPrimary）看似满足，但排除后仍要走完步骤 2→3→4，不改变落点。 候选 2 = **较大字号加粗的 Material subheader**（来源：Material subheader、iOS .plain 列表 title-case header），豁免路径：皮肤变体走通；作用域 ③ 落空。 候选 3 = **带 trailing 动作/计数的分组标题行**（来源：Slack 频道分组头、Notion 数据库分组头），豁免路径：皮肤变体未走通（多了 trailing 槽，骨架不同）；作用域 ③ 对 SidebarSection（头部确有 trailing 字形，Sidebar.swift:62-67）满足 ⇒ 被正当排除。

**③ 皮肤变体交叉裁断**：排除候选 3 后，候选 1、2 与现状共享『一行文本置于分组之上』唯一骨架，差别全在字号/字重/大小写/色 ⇒ 皮肤变体、不计入 ≥2 ⇒ 举得犹豫 ⇒ 落步骤 4（与 SectionFooter 同一条结构性理由：组件自身=一套排版规则时，替代必为皮肤变体）。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：佐证（命中皮肤变体裁断，只能作佐证）：把大写与 footnote 灰同时换成 body 黑常规大小写，这一行就从『分组标题』读成『该组的第一条内容』。Y 落在 :43-44 两个渲染事实、不引兄弟组件名；说服力已被本条第 1 项源码自证削弱（.sidebar 风格下非大写系统 header 在产且不会被误读成正文）。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-10` / `R-25`。

### D-53-11：`SettingsRowChevron` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 9 节；
`53-survey.md` 证据行 11。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/SettingsRow/SettingsRow.swift:56-65。public init() 零公开参数；body 为 Image(systemName:"chevron.forward")+.font(.footnote.weight(.semibold))+foregroundStyle(contentTertiary)+accessibilityHidden(true)。本仓自证：本组件与 ChevronRightIcon（Form.swift:87-98）渲染同一个 SF Symbol，却给出两套字号与配色——同一披露语义在本设计系统内部就有两种在产长相。

**② (A) 诚实枚举**：候选 1 = **右向实心三角**（来源：SF Symbols arrowtriangle.forward.fill、macOS NSOutlineView），豁免路径：皮肤变体走通；作用域 ③ 落空。 候选 2 = **右箭头**（来源：Material Symbols arrow_forward_ios、Google 设置页），豁免路径：皮肤变体走通；作用域 ③ 落空。 候选 3 = **『>』字符**（来源：早期 Web 面包屑），豁免路径：皮肤变体走通；作用域 ③ 落空。⚠️ 作用域条款不能拿 ChevronRightIcon 来援引：它承担的是同一个 chevron.forward 形态、不是被排除的那三个候选中的任何一个，属公约反例警告的『点名一个真实存在但与该候选无关的组件不算数』。

**③ 皮肤变体交叉裁断**：三个候选共享『单一字形占 trailing 一格、指向阅读方向下一级』同一骨架 ⇒ 不计入 ≥2 ⇒ 举得犹豫 ⇒ 落步骤 4。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：无合格句：本条现状 notes 的全部视觉理由是『与 ChevronRightIcon 同构』，纯关系性表述；剥掉兄弟名后源码里只剩字号与色 token 两个取值，写不出非关系性的『换成 X 读成 Y』——D-52-4 #53 裁断所判关系性类型的教科书样本，本条因此不尝试补写，直接改判。⚠️ 53-triage.md 曾标注本条为『委托方，Task 8 独立重走』（依赖兄弟 ChevronRightIcon）——ChevronRightIcon 在同批（本 task）已一并改判 tiebreaker，随本批与其余 11 条一并处置，见文末『落点口径说明』。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-11` / `R-26`。

### D-53-12：`SidebarSection` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 10 节；
`53-survey.md` 证据行 13。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/Sidebar/Sidebar.swift:33-80。public init(title:showsChevron:content:)（:34-42）——showsChevron 就是公开外观开关（:51）；头部（:46-68）：Text(title).headline+primary、条件 chevron、Spacer、Image("ellipsis")。⚠️ 决定性渲染事实：溢出字形『…』在源码注释 :65-67 被自陈为『装饰性占位符，当前无 action』且对 VoiceOver 隐藏。

**② (A) 诚实枚举**：候选 1 = **折叠三角（disclosure triangle）头部**（来源：Xcode navigator、macOS Finder 边栏、VS Code 侧栏分组），豁免路径：皮肤变体走通（同为『标题+折叠字形』骨架）；作用域 ③ 落空。 候选 2 = **纯大写小标签头、无任何字形**（来源：iOS 分组列表 header、Slack 早期频道分组），豁免路径：皮肤变体走通；作用域 ③ 对 SectionHeader（大写 footnote 灰分组标题）满足三条件 ⇒ 被正当排除。 候选 3 = **头部带计数徽标/未读数**（来源：Discord 频道分组、Notion 侧栏分组），豁免路径：皮肤变体未走通（多一个数据槽）；作用域 ③ 落空。

**③ 皮肤变体交叉裁断**：候选 1 命中皮肤变体；候选 2 被作用域条款排除（组件间边界优先于皮肤变体，公约 :220-224）；剩余非皮肤候选只有候选 3，1 个 < 2 ⇒ 举得犹豫 ⇒ 落步骤 4。第 2 项实质问句独立答『是』（chevron 换折叠三角、『…』拿掉后仍是带标题的侧栏分组）⇒ 两条路径同向。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：无合格句：头部三件东西——chevron 由公开 showsChevron 控制、『…』自陈为无动作装饰占位符（:65-67）、标题只是 .headline 排版——没有一个是『换掉就不是这个东西』的承重视觉，不是关系性问题而是没有机制。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-12` / `R-27`。

### D-53-13：`SidebarTagRow` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 12 节；
`53-survey.md` 证据行 15。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Components/Sidebar/Sidebar.swift:307-334,116-159。public init(title:action:)——只有文案与动作，无外观参数；leading『#』（Text("#").title2，:320-321）、trailing chevron（自陈『装饰性指示箭头』，:323-328）都写死。结构性反证：本组件是私有共享骨架 SidebarRow（:116-159）的一次实例化，leading/trailing 是该骨架的两个 @ViewBuilder 槽（:121-122），同一骨架也被 SidebarNavigationRow/SidebarUtilityRow/SidebarDocumentRow 实例化。

**② (A) 诚实枚举**：候选 1 = **标签字形前缀**（来源：SF Symbols tag.fill、Apple 提醒事项/邮件标签行、Things 3），豁免路径：皮肤变体走通（SidebarRow leading 槽换填充物）；作用域 ③ 对 SidebarUtilityRow（任意 SF Symbol 前缀的工具行，:239-240）满足 ⇒ 被正当排除。 候选 2 = **彩色圆点前缀**（来源：Linear label、Todoist 项目/标签色点、Notion 多选属性色点），豁免路径：皮肤变体走通（仍是 leading 槽的一种填法）；作用域 ③ 落空。 候选 3 = **无前缀的彩色 chip 行**（来源：Notion、Things 3 把标签渲染成 chip 而非行），豁免路径：皮肤变体未走通（不再是行结构）；作用域 ③ 对 Tag（自述 GitHub issue label 风格圆角矩形 chip）满足 ⇒ 被正当排除。

**③ 皮肤变体交叉裁断**：两个候选被作用域条款正当排除后，本组件自己剩下候选 2（彩色圆点前缀），与现状共享逐字同一的 SidebarRow 源码骨架（:116-159）⇒ 不计入 ≥2 ⇒ 举得犹豫 ⇒ 落步骤 4。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：佐证（命中皮肤变体裁断，只能作佐证）：把『#』前缀换成一个彩色圆点，这一行就从『按名字寻址的话题/频道』读成『被打了某种颜色标记的条目』。Y=『颜色标记条目』有 Linear/Todoist 业界锚点，不引兄弟组件名（Tag 只出现在枚举记录里）。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-13` / `R-28`。

### D-53-14：`TelegramGlassButtonModifier` 段 2 源码级压测改判 —— 皮肤变体交叉裁断封死落点

**取证留痕**：`oh-my-story` 仓 `.claude/epics/component-contract/53-stress.md` 第 16 节；
`53-survey.md` 证据行 24。基线 CoreDesign `18f92fc`（`git diff --stat 18f92fc HEAD -- Sources/`
输出为空，源码事实与基线逐字一致）。

**① 源码事实**：Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift:58-95。四个公开存储属性——shape:S（任意 InsettableShape）、isPressed:Bool、border:Color?、pressFeedback:Bool；body（:78-94）逐层：第 1 层轮廓由调用方 shape 给、底色由调用方 backgroundStyle 注入（doc :16-17）；第 3 层描边色是公开 border（仓内 CoreMenuButton 传 .borderSubtle 换掉默认半透明白）；第 4 层按压反馈可由公开 pressFeedback 整个关掉。

**② (A) 诚实枚举**：候选 1 = **实心填充按钮容器**（来源：Material Design 3 filled button、Apple .borderedProminent），豁免路径：皮肤变体走通；作用域 ① 落空（被点名的 Solid/Light/CircularGlass 三个 ButtonStyle 均不在 71 条登记表内）。 候选 2 = **描边/tonal 容器**（来源：Material 3 outlined/tonal button、Ant Design default 与 dashed 按钮），豁免路径：皮肤变体走通；作用域 ① 同样落空。 候选 3 = **无容器的纯文字按钮**（来源：Material text button、Apple .plain），豁免路径：皮肤变体未走通（去掉全部容器层）；作用域 ③ 落空。

**③ 皮肤变体交叉裁断**：候选 1、2 命中皮肤变体（三者共享『调用方给定 shape 内缩填底 + 一层表面处理 + 一条描边 + 按压缩放』同一骨架，源码即 :80-93 四句固定次序，候选只换第 2 层画法）；非皮肤候选只剩候选 3，1 个 < 2 ⇒ 举得犹豫 ⇒ 落步骤 4。

**④ 枚举为 0 的残余侧路**：不适用——本条举出 3 个真实业界候选，「为什么业界举不出」的
可核验说明义务未触发。

**⑤ (B) 判定**：无合格句：第 1 项已证四层里三层可换（轮廓/底色/描边色/按压反馈），任何『换掉这套结构就不是它』的句子与公开 API 直接冲突（与判死 SettingsRow 的同一把刀在本条的复现）。

**⑥ 结论**：改判 `tiebreaker`（`kind`/`needsExtensionPoint` 不动）。回路：`D-53-14` / `R-29`。
