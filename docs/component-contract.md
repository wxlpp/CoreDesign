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
   ⚠️ **否决理由不可继承**（#41 撞上，缺陷 D-41-3）：从既有组件拆出的新组件**一律重走判定法**，
   **不得继承来源组件的结论；结论可以相同，理由必须各自成立**。
   实例：`Rating` 对步骤 1 的否决理由是「改写成 `ProgressView` + 自定义 `ProgressViewStyle`
   会丢手势取整与 accessibility adjust action」——而拆出的 `RatingDisplay` **本来就没有**手势与
   adjust action，该理由在它身上完全不成立，必须重新论证（重新论证的结论是：
   `ProgressViewStyle.Configuration` 只给 `fractionCompleted`，`value/count` 这个比值丢掉了
   `count` 本身，而离散档位数是评分展示的语义核心）。
   ⚠️ 这条对**所有**步骤都成立，写在步骤 1 只因为 D-41-3 是在步骤 1 暴露的。
   ⚠️ **本条位于弃用条款 > 祖父条款 > 本条这个次序的最后**：命中前两条的组件仍不进
   判定法；「重走」只约束真正进入判定法的新组件。（不是理论撞车：`RatingDisplay` 的
   登记表 `customStyleProtocol` 就是复用既有的 `RatingStyle`，其 notes 明确推荐扩展点
   复用同一个 `RatingStyle`——下一个复用已发布协议的拆分兄弟组件会同时命中祖父条款与
   本条，此时祖父条款胜出，不必重走判定法。）
2. **调用方会合理地想要一个「看起来完全不同、但含义相同」的版本吗？**
   ⚠️ **操作化门槛**：能**当场举出 ≥2 个业界真实存在的替代形态**才算「会」
   （**替代 = 不含组件当前的形态**）。
   ⚠️ **三个出口，不是两个**：
   · 举得出 ≥2（且非皮肤变体）⇒ **会**，语义组件
   · 举不出，**但能说清「长相即含义」的理由** ⇒ **不会**，进**步骤 3**
   · 举不出**且说不清理由**、或**举得犹豫** ⇒ 视为答不上来，**落步骤 4**
   （第一版只写了后两个出口中的一个，于是「不会 → 步骤 3」这条路在字面上不存在、
   步骤 3 成死代码——而**当时**附录 A.2 走了步骤 3、A.4 落了步骤 4，**两个样本对同一门槛
   给出相反走法**（⚠️ A.2 已于 #52 改判 `tiebreaker`，两个样本现在落点相同 ⇒ 该对照只作为
   本条的**成因记录**保留，不再是附录里现存的实证；见台账 R-13）。影响的是 `decidedBy` 元数据与「写明两可理由」的义务归属。
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
   犹豫」而非自动获得步骤 3）。
   ⚠️ **本处原先引登记表 `SkeletonCircle`/`SkeletonLine`/`SkeletonRect` 三条判例，称其
   `notes`「对应的正是」上面那条积极理由——#52 实测该描述失实，现改为如实陈述**：
   三条 `notes` 全文分别只有 **58 / 39 / 39** 个字符（如 `SkeletonCircle` 的全文是
   「头像占位圆形，纯几何形状（`Color.skeletonBase` 填充）⇒ 长相即含义，步骤 3 规定性，
   不给扩展点。」），它们**确实点出了**形状 ↔ 占位内容类型的配对（头像→圆、文本行→圆角
   矩形、图片/卡片→矩形），但**没有一条写出反事实机制**——「圆形换成方形，占位对象就从
   『头像』读成『图片』」这句在**这三条 `notes`（`SkeletonCircle`/`SkeletonLine`/
   `SkeletonRect`）里一次都没出现**（⚠️ 登记表里唯一出现该句的是 `Tag.notes`，那是
   #44 引用本公约例段的压测记录，不是这三条 `Skeleton*` 自己的机制陈述——本句判的是
   `Skeleton*` 自身，不是「全登记表命中 0」）；三条 `notes` 都终止于本公约明令不算数的
   「长相即含义」这句结论复述。
   ⇒ **上面那条积极理由是本公约自己的走查推理，不是在转述登记表。** 本节下方「事后补写的
   效力边界」小节另有一句自认——「`SkeletonCircle` 当前判 `step3` …是因为它的 `notes`
   **从未枚举过候选**」——两处讲的是同一份 `notes`，但**并不冲突**：那句说的是 `notes` **未枚举候选形态**，
   此处说的是 `notes` **未写出反事实机制**，#52 的实测（三条 58/39/39 字符、无候选枚举）
   恰恰**同时证实**两者。⚠️ 本句原写「以此处的如实陈述为准」，是凭一个不存在的矛盾对下方
   规范条款的说理句下降级裁定——#52 终审改。
   该失实已登记为缺陷（`docs/contract-defects.md` D-52-3）。
   ⚠️ **照抄本范例前先看 D-52-4**：本范例的反事实机制是否属**非关系性**（「圆形换成方形」
   是否隐含依赖兄弟 `SkeletonRect`），以及 `SkeletonRect.cornerRadius` 是 public、能渲成圆形
   这一点是否构成与 `SettingsRow` 同型的公开 API 自反——两条均**已登记、未裁**。
   （`Skeleton` 本身是容器，notes 理由是「redacted + shimmer 叠加固定」，与「形状 =
   内容类型」这条推理无关，不计入本处引证。）
   ⚠️ **候选还有一条作用域约束**：由本设计系统的**另一个具名组件**承担的形态，不计入本
   组件的候选——见本节下方「候选形态的作用域」小节。它**只排除候选、不决定落点**，
   排除后仍要走完步骤 2 → 3 → 4。
   → **会** ⇒ 语义组件，需要扩展点
3. **组件的视觉是它含义的一部分吗？**（换个长相就不是这个东西了）
   → **是** ⇒ 规定性组件，不给扩展点

   ⚠️ **操作化门槛（步骤 3 判「是」的两个条件，缺一不可）**：
   - **(A) 步骤 2 的答案站得住**——步骤 2 若靠「没写候选」而非「真的举不出」通过，
     本步骤不成立（⚠️ 这是登记表现存条目最常见的失效方式，见下方实测状态）。
   - **(B) 有一条带反事实机制的积极理由**——形如「**换成 X 就读成 Y 了**」，
     且该句**不依赖任何兄弟组件名**。
     ⇒ 「只有一种合理长相」「结构固定」「视觉即含义」这类**消极描述或结论复述**不算；
     「不使用 `.full`，这是与 `Badge` 的区分点」这类**关系性**理由也不算——把兄弟组件
     剥掉后它就没有内容了。
   - **两条任一不成立 ⇒ 视为答不上来，落步骤 4。**

   ⚠️ 这条门槛是 #44 反事实必要性压测所用的判准，#52 正式写进本条
   （在此之前它只存在于 `docs/contract-defects.md` D-44-2 与移交 issue 里，
   而本节下方的实测状态却已经在引用它的结论——见 R-13「连带改动」）。
4. **以上都答不上来** ⇒ **tiebreaker（见下）**

### ⚠️ 候选形态的作用域：由兄弟组件承担的形态不计入候选

**这是步骤 2 的入口条件，不是第四个出口。** 三条出路回答的是「候选枚举完之后往哪走」；
本条回答的是「**什么算候选**」——层级不同，并列会让判定法逻辑错位；写成「第四出口」还会
让它变成万能逃生口（任何组件都能声称「想要别的观感？用兄弟组件」），而作为**步骤 2 的
作用域规则**，它天然受下面三条可证伪条件约束。

> **候选形态的作用域**：枚举替代形态时，**由本设计系统的另一个具名组件承担的形态，
> 不计入本组件的候选**——「想要那种观感」的正确答案是**换用那个组件**，不是给本组件
> 加扩展点。

⚠️ **援引本条必须同时满足三条，缺一不可**：

1. **被点名的兄弟组件必须真实存在于 `docs/component-registry.json`**（不是「将来可以做一个」）；
2. `notes` 里**写明是哪一个**（组件名），不许写「换用别的组件」这种无指向表述；
3. **被点名的兄弟组件必须真实承担被排除的那个候选形态**（其登记表条目或文档可佐证）。
   ⚠️ 只有前两条的话，随便点名一个**真实存在但与该候选无关**的组件即可绕过——两条件都
   满足、候选照样被排除。正例模板：`Tag` 的 pill 候选 → `Badge`（`Badge` 的 `notes` 自己
   就写着它与 `Tag` 的唯一区分点是**固定的 Capsule（pill）视觉**——它**真的承担**这个形态）。
   ⚠️ **反例**：不能拿「兄弟组件把该形态列为自己的**候选**」来满足本条——`Badge` 的 `notes` 里
   「候选形态（pill 填充 / 描边 / 圆点指示）……这些候选**不计入** ≥2」说的恰是 `Badge`
   **没有采用**它们。若那样也算数，本条就退化成 ①② 的重复，反绕过功能归零。

⚠️ **本条只排除候选，不决定落点**：候选排除后仍要走完步骤 2 → 3 → 4。能**额外**说清
「长相即含义」⇒ `step3`；说不清 ⇒ `tiebreaker`。**不得**用本条直接推出 `step3`。
> **实测状态（#52 全量审计）**：登记表现有全部 `step3` 条目中，**没有一条被确认合格**——
> 没有一条同时满足「步骤 2 的答案站得住」与「有不引兄弟组件的反事实机制」；
> ⚠️ **另有 4 条两可、本轮未裁**（见 `oh-my-story` 仓
> `.claude/epics/component-contract/52-step3-audit.md` 的「档 5：存疑」，该文件已随 #52 落地于
> `oh-my-story` main @ `a169832`）——所以是「**未确认有**」，不是「**确证无**」。
> 且其中大多数条目的步骤 2 是靠**未枚举候选**通过的，操作化门槛在它们身上从未执行。
> ⇒ 这不是某一条判例的问题，是**门槛未被执行**。处置见移交（本任务不批量补跑）。
> 该状态若变化，须走修订回路更新本句。

⚠️ **本句的作用域，不许外推**：上面判的是**登记表 `notes` 侧**，**不判**
`docs/components/*.md` 与源码文档注释。所以正确的说法是「登记表 `notes` 侧未确认合格实例」,
**不是**「写不出来」——`SettingsRow` 在 #44 初判时写出过一条形式合格的句子（原文节选，全句见 `docs/component-registry.json` 的 `SettingsRow.notes` #44 检验段）
（「把图标方块换成头像圆、把 accessory 拿掉，读到的就变成通讯录行」），它是被**公开 API
反证**打掉的（四个 `init` 的 `icon` 默认 `nil`），**不是被「有反事实机制」这条判准打掉的**。
⇒ 判准的**句式**是可写的；但该样本的前提随后被公开 API 证伪、重新压测也判「不过」（`SettingsRow` 已因此改判 `tiebreaker`）
⇒ 只能说「**窗口未被证明关闭**」，**不能说「窗口存在」**——「能写出一句形状合规的话」推不出「存在一个真实的合格实例」。
⚠️ 这处措辞是 #52 Task 2 评审改的：原文写「判准可达，窗口存在」，正是本节自己在防的那个病**在反方向**的复发。

⚠️ **本条款现在只有 `tiebreaker` 一侧的成文样本**（`TagInput`：作用域排除后没有积极理由
⇒ `tiebreaker`）。`step3` 一侧原先唯一点名的样本是 `Tag`，已于 #52 改判 `tiebreaker`
（见下一段）。

⚠️ **原「登记表两侧都有成文样本，不是空设：…」一句已于 #52 删除**，替换为上面的实测状态段
——原句在 `step3` 侧唯一点名的样本是 `Tag`，其独立理由经 #44 反事实必要性压测判「不过」
（见 docs/contract-defects.md D-44-2 / D-44-3），#52 据此按本节下方「事后补写的效力边界」
条款规定的修订回路，把 `Tag` 正式改判为 `tiebreaker`（`docs/component-registry.json` 的
`Tag.decidedBy`：`step3` → `tiebreaker`；台账留痕见
`docs/component-contract-revisions.md` R-13）。⇒ 该句已无对照面，故删而不是加注。

⚠️ **与皮肤变体条款的交叉——优先序（缺了这条就是同一种病的第三次）**：
一个候选可能**同时**命中本条与皮肤变体条款（`Tag` 的 pill 就是：既是 `Badge` 的领域，
又与 `Tag` 自身共享「低 chrome 状态色块」骨架）。两条款对落点的规定是**冲突**的——
皮肤变体条款明文规定「落点固定为步骤 4，`decidedBy: tiebreaker`」，本条却允许继续走 3。

**裁断：本条（组件间边界）优先于皮肤变体条款（组件内变体）。**
理由：皮肤变体条款要解决的是「同一个组件的同一个骨架换画法」；一旦该形态**由另一个具名
组件承担**，它就不再是「本组件的皮肤」——两条款的**适用对象**根本不同，不是强度之争。
⇒ 命中本条时，先按本条排除候选；排除后若**本组件自己**仍有共享骨架的候选，
再对**那些**候选适用皮肤变体条款。

⚠️ **`Tag` 这个例子在 #52 改判后仍然成立，但要读对它说明了什么**：本条优先适用 ⇒ pill 被
排除，`Tag` **不因 pill 本身**直接落 `tiebreaker`；排除之后，`Tag` 自己**没有成文的**剩余
共享骨架候选（改判前〔CoreDesign `511576f`〕实测：`实心 chip` / `描边 chip` 在
`docs/component-registry.json`、本文件、`Sources/CoreDesign/Components/Tag/Tag.swift` 命中
**均为 0**——⚠️ **三处缺一不可**：D-44-3 的 hedge 原话是「**登记表与源码**均未成文枚举」，
只扫登记表与公约会漏掉它点名的**源码**那一半。
⚠️ 本句自身与本轮回写文本对这两个词的引用不计入该计数；`docs/contract-defects.md` 的命中
**即该推演记录本身**，不构成成文枚举——那组剩余候选是**该轮的推演**，原文自带该 hedge）⇒ 皮肤变体条款这条路径**不承重**。
`Tag` 最终落 `tiebreaker`，走的是「排除后说不清『长相即含义』⇒ 步骤 4」这条路。
⇒ **本段的教学价值不变**（两条款的适用对象根本不同，不是强度之争），但**不要**把 `Tag`
当成「优先序改变了最终落点」的例子——在 `Tag` 身上，**皮肤变体路径的前提（剩余候选成文）不成立
⇒ 只剩第一条路径，结论不变**。
⚠️ 本句原写「两条路径殊途同归」，与它自己引的 D-44-3 hedge 正面矛盾（上游原文：「若…认定 `Tag`
无成文剩余候选，则本连锁**只剩第一条路径**…**结论不变**」）——公约刚作出那个认定，此时不存在
「两条路径」可供殊途同归。#52 Task 3 评审改。

⚠️ **不追溯**：本条**不构成对既有 `tiebreaker` 条目重新路由的依据**。已落盘条目要按本条
重 derive，须走下面「事后补写的效力边界」的修订回路——否则 `StreamingIndicator` 式条目
（其「顶部进度条」候选可论证为 `ProgressIndicator` 的领域）的重诉通路就是敞开的。

⚠️ **边界反例，不要误援引**：`Rating` / `RatingDisplay` 是一对具名兄弟组件，但它们拆的是
**control vs indicator 的交互语义**（Apple 自己就这么分：`Slider` vs `ProgressView`），
不是外观变体——证据是两者**共用同一个 `RatingStyle`**，外观候选并没有被兄弟组件消化掉。
⇒ **不属于本条的适用范围**（`RatingDisplay` 条目的 `notes` 原文已记下这一点）。

### ⚠️ 事后补写的效力边界：只能补强记录，不得单方面翻转落点

事后往登记表 `notes` 补枚举候选、补援引，**只能补强现有结论的记录，不得单方面翻转落点**
（`decidedBy` / `kind`）。要翻转，必须走**公约修订回路**——记入 `docs/contract-defects.md`
→ 回写本公约 → 在 `docs/component-contract-revisions.md` 逐条留痕——**不能只改一条 `notes`**。

⚠️ **「钉为范例」按结论逐条计，不按组件整体计**：某个组件被本公约正文点名，只对**被点名的
那个结论**构成钉死。例：`InsetGroupedSection` / `SettingsRow` 在第 4 节被点名，那是
**textParams 语境**，**不构成**对它们 `decidedBy` / `kind` 的钉死；而附录 A.2 对 `Tag` 的
点名钉死的正是它的**落点结论**。按组件整体计会把前者误挡。

⚠️ **未钉死条目同样要走回路**：本条对「翻转须走修订回路」的要求**不限于**钉死判例——
任何已落盘条目的 `decidedBy` / `kind` 翻转都要留痕。钉死与否的区别只在**补强**：
钉死判例的补强也须在修订记录里**显式声明「不改结论」**。

⚠️ **理由**：`SkeletonCircle` 当前判 `step3` **不是因为候选真的枚举不出**，而是因为它的
`notes` **从未枚举过候选**。若允许事后补枚举直接翻转，任何已发布判例都可由后来者的一次
`notes` 补写悄悄推翻——判例就不再是判例。
（`Skeleton*` 本身**不因本条改判**；本条只是把它暴露的规则空白补上。）

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
`LightButtonStyle.swift` 曾在参数表内暴露 `glass: Bool` public 参数——正是本节
下方引用的 `SegmentedControl.swift` 注释所斥的「布尔 hack」，故此处**不构成整体背书**。
该参数**已于 `v0.8.0` 删除**（#41 裁决 3；迁移写法见 `docs/BREAKING-CHANGES.md` 的 B3/B4），
**已按第 3 节处置完毕，不再属该节的处置范围**。
⚠️ `SegmentedControl.swift` 内仍有名为 `glass` 的**内部**字段（**两处，均非 public**），
那是形态 B 的实现细节，**不受第 3 节约束**。

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
`decidedBy`（裁决人）/ `decidedOn`），`docs/bool-exemptions-baseline.json` 记两个
上限（`maxEntries`、`sourceSites`）与这次抬高的 `raisedBy` / `raisedOn` / `rationale`
——共 5 个字段。守卫要求
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
  与配套的严格等式断言（见 `BoolExemptionGuard.swift` 的 `baselineRatchetHoldsExactly`），
  但**只保证这次变化在 diff 里可见**——`scripts/bool-exemptions-ratchet.sh` 从头到尾
  只读 `maxEntries`、不读 `sourceSites`，`sourceSites` 未纳入该脚本的跨历史破例流程；
  跨历史闸**至今未实现**——曾移交 `#41` / `#43`，两者的工作都已完成而这条闸**都没做**；
  `docs/bool-exemptions-baseline.json` 的
  `rationale` 原话即「`sourceSites` 的跨历史闸仍未实现（`scripts/bool-exemptions-ratchet.sh`
  只读 `maxEntries`）」）⇒ 见 `oh-my-story` 仓
  `.claude/epics/component-contract/close-out.md` 的「## 四、移交清单」（该文件随 #44 收口 PR 落地；已开 issue `#50` 承接）。
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
⚠️ **本例句是构造出来演示「两 case enum 逃逸」的，不是本仓的落地形状**：
`bordered` 在 `v0.8.0` 的实际处置是**删除参数**、改走 `SurfaceKind.grouped`（`View.surface(_:)`）
与 `CardKind`（`Card(kind:)`）这两个**独立成立的角色枚举**（#41 裁决 1，见
`docs/BREAKING-CHANGES.md` B1/B2）——**本仓从未落地过 `BorderStyle` 这个类型**。
例句保留是因为它演示的逃逸路径本身仍然有效；标注是为了不让读者以为 `BorderStyle` 已存在。
⚠️ **`CardKind` 恰好也只有两个 case**（`.content` / `.grouped`，`CardKind` 自己的文档
注释自称「刻意只有两个 case」）——字面上它落在上面「头号反例」判据的射程内，但它
**合规**，与 `bordered: Bool` 不是同一回事。理由（#41 裁决 1，两点独立成立）：
① **取值域是刻意收窄的结果，不是巧合**——`Card` 是 `.surface(.content)` 的薄封装，
若开放全部 `SurfaceKind`，`Card(kind: .canvas)` 这类组合会把薄封装拓宽成万能容器
（卡片贴画布 ⇒ 隐形，正是 Issue #140 的塌缩回归形态），两个 case 是有意为之的范围
限定；② `.grouped` 本身按上面「取值域的命名规矩」判据**独立成立为一种容器角色**
（iOS 自己把这种形态叫 `.insetGrouped`，本仓 `InsetGroupedSection` 已在用同名角色），
不是「换个名字的同一个布尔旋钮」。⇒ **两 case 数本身不是判据**，「是否独立成立为
角色」才是；`CardKind` 靠②过审，`bordered: Bool` 过不了②。

**这是最廉价的逃逸路径，而公约文档是唯一能封住它的地方。**

**判据**：两 case enum 只有在**存在真实的第三 case 或连续取值域**时才算替代路径。
造不出第三种合理取值，就说明它本来就是布尔旋钮 ⇒ 回去从下面四条里重选。

⚠️ **判据范围限定**：本判据只适用于**「把已存在的 Bool 参数改写成两 case enum」**
这个动作本身，不倒过来审判**本来就是 enum、且与系统类型同构**的既有域——例如
`StepsAxis`（`horizontal` / `vertical`）与 SwiftUI 自己的 `Axis` 同构、同样只有
两个 case，它不是「Bool 换皮」，是复刻系统惯例，**豁免于本判据**。

### ⚠️ 取值域的命名规矩：「角色 + 修饰词」允许，禁的是**裸**修饰词

按 3.1 把布尔还原成取值域时，新 case 的命名受一条规矩约束（原文在
`Sources/CoreDesign/Modifier/SurfaceModifier.swift` 的 `SurfaceKind` 文档注释）：
**不引入裸修饰词**（如 `.subtle`、`.muted`）；每个 case 直接对应一种容器角色。

⚠️ **这条规矩此前与自身先例不自洽**（#41 撞上，缺陷 D-41-1）：同一个枚举里
`case canvasSubtle` 正是「角色 + 修饰词」形态，且其文档自标「兼容别名」。
规矩没裁断的两件事，本次一并写死：

- **(a)「角色 + 修饰词」不是禁区，但也不是通行证**：禁的是**裸**修饰词单独成 case
  （`.subtle` ❌）；带角色前缀只解除「凡带修饰词即禁」的误读，**不构成独立的合规
  依据**——合规与否**一律回到下面的判据**。
  ⚠️ 本条**不给**「角色 + 修饰词」形态的正例：本仓现有的 `.canvasSubtle` 是靠 (b)
  的兼容别名豁免存活的，**它过不了判据**（「更淡的画布」离开 `canvas` 无法定义，
  与判据判负的 `.contentPlain` 同型），因此不能充当「通过审判」的证据。**一个豁免
  于审判的 case 不是正例。**
- **(b)「兼容别名」是独立一档，且优先于 (a)/判据**：为保持源码兼容而保留的 case
  （如 `SurfaceKind.canvasSubtle`）**不受本规矩审判**，但须同时满足两点：
  ① **必须在文档注释里显式标注该档位**——不许默默留着，标注缺失时按普通 case 审判；
  ② **该档只适用于本条款成文之前已存在的 case**——新增 case 一律走判据，**不得以
  标注取得豁免**。命中 (b) 后不再走判据审判，但该豁免**不使它成为 (a) 的正例**。

**判据（#41 为 `.grouped` 命名时实测可用，本次成文）**：一个新 case 是否合规，问
「**该 case 是否独立成立为一种容器角色**」——
`.grouped` 独立成立（iOS 自己把这种形态叫 `.insetGrouped`，本仓也已有同名组件
`InsetGroupedSection` 在用它）；`.contentPlain` 离开 `.content` 就没法定义，
是**变体名**不是**角色名** ⇒ 不合规。

⚠️ **为什么必须写进公约**：#41 当时是靠一条**自造**判据才收敛的。自造判据能用一次，
但它不在公约里，下一个人不会知道要用它——这正是本 epic 反复出现的「规矩在源码注释里、
决策在别处」的病型。

### 3.1 专用 init / 专用参数

**适用**：布尔背后其实是一个**被压扁的取值域**。

例：`Rating(allowsHalfStar: Bool)` → `Rating(step: Double)`（**已于 `v0.8.0` 落地**，#41 裁决 4a；
迁移写法见 `docs/BREAKING-CHANGES.md` 的 B5）。
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

⚠️ 上表的 `.surface(bordered: false)` 是**判据示意**，该参数已于 `v0.8.0` 删除（#41 裁决 1）；
保留它是因为它是这条判据最清晰的反例形状。

**反例**：把 `Card(bordered: Bool)` 挪成 `.card(bordered: false)` —— **错**。
换了个位置的同一个布尔旋钮，不是替代路径。
⚠️ **已于 `v0.8.0` 落地**（#41 裁决 1）：`Card(bordered:)` 删除，改为 `Card(kind: CardKind)`
——走的是 3.1（还原成真实取值域），**不是** 3.3。

### 3.4 环境值

**适用**：这个选择**作用于一整棵子树**，或**已有系统环境值表达同一件事**。

⚠️ **优先复用系统环境值，不要自造平行开关**。
例：`Rating(isReadOnly: Bool)` 与 `@Environment(\.isEnabled)` 语义重叠
（**已于 `v0.8.0` 落地**，#41 裁决 4b：`isReadOnly` 已删除）
——`Rating` 的手势注释写明「`isReadOnly` 或外层 `.disabled(true)` 时手势整体不挂载」,
**两条路径做同一件事**。

**反例（重要）**：直接把 `isReadOnly` 删掉、让调用方用 `.disabled(true)` —— **不够**。
`disabled` 会连带**禁用态的灰色外观**，而只读评分的典型用途是「显示平均分」,
需要**正常外观**。⇒ 这类「行为重叠但视觉诉求不同」的情形，
正确解法可能是**拆成两个语义组件**（交互 `Rating` vs 展示 `RatingDisplay`,
类比 `Slider` vs `Gauge`）。
**已于 `v0.8.0` 落地为拆分方案**（#41 裁决 4b）：交互 `Rating` + 展示 `RatingDisplay`，
两者共用同一个 `RatingStyle`；**未采用归并**。
⚠️ 拆分而非归并的理由（#41 实测）：`isEnabled == false` 走 SwiftUI 原生 disabled 视觉
（变灰 + 降低对比度），语义是「这个控件现在不能用」，而展示态不是「不能用」是「本来就不是控件」
——归并会造成语义错配导致的视觉回归，不是 API 收敛。拆分后控制展示态的路径只剩一条：**选哪个类型**。

## 4. 文案类型三分法

| 类别 | 判别特征 | 类型 |
|---|---|---|
| **A. 组件自带 chrome** | 文案**写在组件源码里**，调用方看不见也改不了 | `LocalizedStringResource` |
| **B. 调用方传入的可本地化文案** | 调用方传，但内容是**界面文案**（标题、说明、占位符） | **新增用 `LocalizedStringKey`；存量迁移见下** |
| **C. 用户数据** | 调用方传，内容是**用户自己产生的**（设定名、章节标题） | `String`，**不得改** |

⚠️ **B 类参数的缺省兜底按 A 类处置**（#43 撞上，缺陷 #43-1）：调用方可传参覆盖、但**缺省时
由组件源码提供**的兜底文案（如 StoryUI `ChapterStatus.defaultLabel`），**文案本身写在组件
源码里** ⇒ 按 **A 类**处置，用 `LocalizedStringResource`。
⇒ 据此**明确 A 判别特征中两个词的所指**：「**看不见**」指**调用方不能经由公开 API 读到
这份文案字面量**（`defaultLabel` 是 internal ⇒ 看不见），**不是**「看不到渲染结果」；
「**改不了**」指**不能修改这份默认值本身**，**不是**「不能覆盖最终渲染的文案」。两项都
按前一义读，兜底文案才落进 A。
（第一版只写「文案写在组件源码里，调用方看不见也改不了」——「看不见」「改不了」各自都有
两义：字面量意义上兜底文案确实**看不见**（`defaultLabel` 是 internal）、也**改不了**
（不能修改默认值本身）；但渲染意义上它「看得见」（渲染结果可见）、「改得了」（能传参覆盖
最终显示的文案）。三分法对这一形态给不出答案，#43 只能做解释性裁定填空白。）
⚠️ **本条的范围**：只裁 **B 类参数**的兜底。本仓另有形态相同但登记为 **C 类**的兜底
（`SearchField` / `TagInput` 的 `placeholder`，缺省值 `"Search"` / `"Add tag"` 由组件
源码提供），**本条不处置**——它们的分类要不要一并改，属登记表层面的连带改判，已记为缺陷
（`docs/contract-defects.md` D-44-4）。

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
会立刻变成化石），这是预期，不是覆盖缺口。
⚠️ 但「A 不进 `textParams[]`」只说明**这条路不该覆盖 A**，**不等于 A 的类型要求有
判据**——A 类的类型要求当前无任何机器判据，见本节末「已知判据缺口」G-4。
三方仍各自保留 A 取值（它是三分法本身的一部分，只是不经由参数这条路进登记表）。

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

### 三条判据的机器落点（#40）

| 判据 | 落点 | 定义域 | 现状 |
|---|---|---|---|
| **J-2** 语义组件必须有样式扩展点 | `Tests/CoreDesignTests/ComponentExtensionPointGuard.swift` 的 `ComponentExtensionPointGuard` | `kind == semantic && needsExtensionPoint && repo == coredesign`，实测 5 条 | 3 条满足；`Rating` / `Toast` 是**待补的扩展点**，以 `withKnownIssue` + 块外固定集合 canary 落账，补齐后判据主动判红逼人清理 |
| **J-3** 标注 `nativeProtocol` 的组件作用域内不得有自有样式协议 | `Tests/CoreDesignTests/NativeProtocolPurityGuard.swift` | `nativeProtocol != nil && repo == coredesign`，实测 **1** 条（`ProgressIndicator`） | 零违规。⚠️ 1 条输入的判据靠非空断言挡不住「探针退化成恒空」⇒ 另设**绿色正对照**（把探针反向施加到 `Banner` / `SegmentedControl`，必须命中）。判据**消费**该探针而不内联重写，正对照的红因此能推到判据的探测能力上（规则层 `j3JudgeConsumesTheProbe` 钉住这条结构约束） |
| **FR-4** public init 的裸文本参数必须有分类条目 | `Tests/CoreDesignTests/ComponentTextParamGuard.swift` | 宿主可解析到 `repo == coredesign` 登记表条目的 public `init`，实测覆盖 29 条 | 4 条已知违规（三条 Sidebar row 的 `systemImage` + `SidebarUtilityRow.trailingSystemImage`）——与 `LabelIcon.systemName` 同类的 SF Symbol 标识符，但 `notes` 未点名 ⇒ 缺陷已报回 #38 |

**自有样式协议的识别是结构性的，不是名字匹配**：信号为「`protocol` 成员里有
`func makeBody(configuration:)` requirement」（Apple `ButtonStyle` / `ToggleStyle` 的形状）。
本仓实测恰好识别出 2 个：`BannerStyle`（`Banner.swift:77`）、`SegmentedControlStyle`
（`SegmentedControl.swift:66`）。Apple 的原生样式协议声明在 SwiftUI 里、不在扫描范围内，
因此**天然**不会被误当自有协议——这是构造保证，不是名字白名单。
⚠️ **诚实留痕**：本仓只有这 2 个 `protocol` 且两个都是样式协议 ⇒ **真实源码上没有反例能区分
「结构性识别」与「名字后缀识别」**，两种实现在真实源码上结果完全相同。能区分它们的证据全部
来自合成输入（`ComponentJudgeScannerTests` 里的 `StyleToken`：有 `Style` 无 `makeBody`；
`Appearance`：有 `makeBody` 无 `Style`）。

⚠️ **三条判据各占一个文件，不要合并**：`swift test --filter` 除类型名 / 函数名外**也按源文件名
匹配**（实测：J-3 的 suite 曾与 J-2 同在 `ComponentExtensionPointGuard.swift`，于是
`--filter 'ComponentExtensionPointGuard'` 把 J-3 **一起跑了**——两个 struct 名毫无子串关系；
把它移进独占文件后、**struct 名一字未改**，同一条 filter 只跑 1 个 suite）。⇒ 一条判据想被
`--filter` 单独跑起来，**必须独占一个文件**；合并文件会静默破坏 AC「三条判据可独立运行」的取证，
而合并后的输出看起来完全正常。

**跨仓边界（裁决 (a)，继承 #38 Task 2 的 `registryCoversCoreDesignTypes`）**：三条判据
都**只对 `repo == "coredesign"` 的条目跑**，其余在输出里**显式报告跳过条数**（现状
`storyui` 25 条 / 3 个 `textParams`），并由三条棘轮断言盯住：跳过计数固定、StoryUI 侧
不得出现 `kind == semantic` 的条目、不得出现 `nativeProtocol` 非空的条目。语义是
**「这条不归本仓判据管，已移交 #43」**，不是「查不出问题所以放行」。

⚠️ **`by-type` 的「无孪生重载」筛子现在有机器判据**：`ComponentTextParamGuard` 的
`byTypeCategoryHasNoBareStringTwin` 双向核对——登记为 `by-type` 的参数在源码里不得有裸串
/ `StringProtocol` 孪生重载；登记为 B/C 的参数必须有裸串入口。现状 2 条 `by-type`
（`Descriptions.header` / `SpinningModifier.text`）+ 28 条 B/C 全部满足。

### ⚠️ 已知判据缺口：本公约有规定、机器判据够不到的地方

⚠️ **本节是「诚实留痕」，不是待办清单。** 列在这里的每一条都是**当前靠人守**的规矩——
读到它就该知道「判据绿了**不代表**这一条被查过」。实现层的修复各自有移交去向。
⚠️ **公约缺陷的定义明文包含「判据漏判」**（`docs/contract-defects.md` 开篇），
因此这些条目**同样要回写公约**，不能因为「实现层不在本任务范围」就整条划出。

| # | 缺口 | 判据侧现状 | 靠什么补位 | 实现层 |
|---|---|---|---|---|
| **G-1** | J-2 的 `customStyleProtocol` 通路**只查符号存在性**，查不出「组件真的把定制权交出去了」 | 判绿条件是「协议已声明 + 至少一个类型采纳」（规则层 `Tests/CoreDesignTests/ComponentJudgeRules.swift`；消费该规则的 suite 是下方 J-2 行落点 `ComponentExtensionPointGuard.swift`，两者对应同一条判据的不同层次）。组件完全可以声明协议、登记表填上名字，而 `body` 里照旧硬渲染 ⇒ J-2 照绿 | **一条人来守的规矩 + spy 测试**：#41 的 `Rating` / `RatingDisplay` 用「`body` 真的经 `style.makeBody(configuration:)` 渲染」的测试补位，#43 同款。**靠人自觉，不是靠判据** | 做成机器判据需要语义判断、成本明显更高 ⇒ 移交，本公约先把精度上限写在明处 |
| **G-2** | `BoolExemptionGuard.ownersWithoutRegistryEntry` 台账**不随最后一个豁免键回收** | 三条宿主（`ButtonStyle` / `SolidButtonStyle` / `LightButtonStyle`）在 #41 删掉 `glass` 之后都已**没有任何活的豁免键**；`exemptionOwnersReconcileWithRegistry` 的循环按豁免键遍历 ⇒ 不再访问它们。但三者归类不同：`SolidButtonStyle` / `LightButtonStyle` 绑 `.styleImplementation`，它们绑定的正向核对（`scan.styleImpls.contains(owner)`）**零覆盖**，判据仍是绿的。`ButtonStyle` 绑的是 `.externalProtocolExtension`——该分类另有 `View` 的 11 个活豁免键撑着，正向核对**非零覆盖**，`ButtonStyle` 单独按下方裁断 (ii)② 的回收条件**今天已满足**，单独表态见下方裁断 | 无——保留的行不承重，靠人守；处置口径见下方**裁断** | 台账条目的标注与回收触发条件的落地 ⇒ 移交 |
| **G-3** | README 组件索引的对账是**单向**的，且不检查快照存在性 | `ComponentRegistryGuard.readmeIndexReconcilesWithRegistry` 只做 README → 登记表方向：索引**缺行不会红**；也不检查该行 `<img src="snapshots/...">` 指向的 PNG 是否真的存在 | 无——靠人补。#41 新增 `RatingDisplay` 时索引行与快照全靠人手补 | 补一条反向断言（`kind != "excluded"` 的条目都应在 README 有行）+ 一条快照存在性断言 ⇒ 移交 |
| **G-4** | **A 类的类型要求有规定、无判据，且本仓参考实现自己不合规** | 公约要求「A 类必须用 `LocalizedStringResource`」，而 CoreDesign `Sources/` 下 `LocalizedStringResource` 命中 **0**（实测）；`StateLabel.swift` 的 `StateLabelStyle.Spec.defaultLabel`（A 类 chrome，值是 `"Active"`/`"Draft"` 等英文）是裸 `String`。⚠️ **A 类文案不经任何一路进入 FR-4 的机器视野**：源码侧 FR-4 只扫 public `init` 参数、A 类不是参数；登记表侧 `textParams[]` 收 public 参数、A 计数恒为 0 | 评审（无机器判据） | ⚠️ **本公约在此明写：A 类的类型要求当前无机器判据，靠评审**；并把 CoreDesign 侧 `StateLabel.defaultLabel` 登记为**已知例外**。StoryUI 的 `ChapterStatus.defaultLabel` 是整个 epic 中**唯一**遵守该条的地方——这个不对称必须记录，否则下一个人会以为 `String` 是既定惯例。`StateLabel` 的改造 ⇒ 移交 |
| **G-5** | 跨仓登记表守卫的 `derivedDataCandidates()` 有**陈旧命中**风险（失效方向**静默**） | StoryUI 侧 `CrossRepoRegistryGuard` 做 8 级有界上溯、`allEntries()` first-hit-wins。若 `.build/checkouts` 缺席而上层恰有一份陈旧的 `SourcePackages/checkouts/CoreDesign`，守卫会**静默读到旧版登记表**——判据照常绿，但对的是过期事实 | 概率极低（需同时满足两个条件），按 #43 终审裁定**留痕而非加固** | 若要收紧，落点是在 `allEntries()` 里核对「该 checkout 的 git 版本 ≟ `Package.resolved` 的 pin」⇒ 移交 |
| **G-6** | StoryUI 侧 `CrossRepoRegistryGuard` 的 View 扫描：同一扫描器的两处口径边缘（失效方向 **fail-loud**） | (i) `visit(_:StructDeclSyntax)` 只看结构体自身修饰符 ⇒ 嵌在非 public 容器内、有效访问级实为 internal 的 `public struct` 仍被计入；(ii) `*Demo` 排除后返回 `.visitChildren` ⇒ Demo 内嵌的 public View 也会被采集 | 今日**零命中**（扫描命中集与登记表条目逐名闭合可证），且失效方向是多扫 ⇒ `missing` ⇒ 红 | 留痕即可 |
| **G-7** | `ComponentIndexGuardTests` 的 27-slug roster 是**手工清单**，有方向性盲区 | 新 View 从未进 roster 时，文档索引与 roster **一起**漏掉它、两集合仍相等、判据永绿 | 无 | 移交 |
| **G-8** | FR-4 的 StoryUI 侧 `storyuiTextParams == 3` 只做「计数 + 条目名」核对，**无参数级源码扫描** | 工作量取舍，**非能力边界**——测试 target 已依赖 swift-syntax，基建现成；参数级扫描是独立一块工程 | 无 | 移交 |

#### G-2 的裁断（#44 本次成文，D-41-4 原文要求的正是「裁断」而不只是留痕）

D-41-4 移交给 #44 的原话要求裁断两件事：**(i) 台账条目是否应随最后一个豁免键一并回收**；
**(ii) 分类的「样本保留」需求该怎么表达**。逐条给出结论：

**(i) 裁断：不随最后一个豁免键回收——但保留必须是「显式标注的保留」，不是「沉默的保留」。**
理由：三条宿主行**今天已经零覆盖**——`SolidButtonStyle` / `LightButtonStyle` 绑定的
`.styleImplementation` 正向核对一次都不会被执行，删与不删这两条宿主行，覆盖率都是 0，
「删掉会让它失去覆盖」这个说法不成立（它本来就没有覆盖）。更直接的理由是 `switch kind` 对
`OwnerExclusionKind` 穷尽分支，**分支代码不随台账行的存在与否而增删**——台账行今天的
价值不是「喂给机器判据」，是**文档性样本**：`.styleImplementation` 这个分类值**唯一的
成文样本**，以及它背后的 AD 依据（AD-3），删掉它会让下一个人遇到这个分类时要重新从源码
反推。⇒ 保留的是**样本**，不是**覆盖率**；覆盖缺口本身由 G-2 这一行留痕，回收/加固的
处置移交实现层。而**静默保留**与**显式标注保留**的区别，正是「这几行还承不承重」能不能
被下一个人读出来。⇒ **保留 + 标注**，不是**保留 + 沉默**。

**(i) 对 `ButtonStyle` 的单独表态**：`ButtonStyle` 绑定的是 `.externalProtocolExtension`，
不是 `.styleImplementation`——它不落在 (i) 要保的「唯一成文样本」范围内（`.externalProtocolExtension`
分类另有 `View` 的 11 个活豁免键撑着正向核对，从不缺样本）。⇒ `ButtonStyle` **按 (ii)②
的回收条件今天已满足**，本次裁断结论是**可回收**；(i) 的保留结论只覆盖
`SolidButtonStyle` / `LightButtonStyle` 这两行。回收动作本身（删除台账里的
`ButtonStyle` 行）属于改判据实现，本任务不做 ⇒ 移交实现层。

**(ii)「样本保留」的表达形式（三条，缺一不可）：**
1. 台账条目旁必须注明 **`样本保留`** 字样，并写清它**保留的是哪一个分类值的样本**；
2. 必须写清**回收的触发条件**——即「什么时候可以删掉它」：**仅当移除后该分类在台账中
   仍 ≥1 行时**方可回收；**(i) 对每个分类的最后一行恒优先于 ②**——顺序未定义会反噬样本：
   同一分类下先死的豁免键按 ② 被删、后死的按 (i) 被留，若不钉死优先序，「最终留下谁」
   取决于键死亡的先后，且 ② 有可能在轮到 (i) 之前就把某分类删到 0 行；
3. 必须写清**它当前不承重**这件事，即「按豁免键遍历的正向核对已不再访问它」。
⇒ 三条齐备时，条目是**有据的样本**；缺任何一条，它就退化成一行「不知道还有没有用」的死账，
下一个人只能凭猜删或凭猜留。

⚠️ **本裁断只回写公约，不改判据实现**（`44-spec.md` 第四节）。把上述三条标注真正写进
`Tests/CoreDesignTests/BoolExemptionGuard.swift` 的 `ownersWithoutRegistryEntry`、
以及（若采纳）**对 `ownersWithoutRegistryEntry` 全表跑一遍分类核对**（不局限于当前有活键
的宿主），都属实现层 ⇒ **移交**。⚠️ 这条全表核对与「给分类值加一条至少一个活样本的断言」
不是同一件事：后者只断言**样本存在**（抓的是「分类缺席」），一次核对完就通过，抓不到
`SolidButtonStyle` 被改名/删除后台账行**静默变成假样本**这种腐坏；前者对台账每一行的
分类标注都做一次正向核对，能抓住腐坏，是更简单也更完整的补法，评估后一并移交实现层，
本任务不实现。
⚠️ **「移交裁断权 ≠ 完成裁断」**——D-41-4 要的是裁断，本节给的就是裁断；移交出去的只有落地动作。

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

⚠️ **本附录当前没有 `step3` 通路的走查样例。** 原 A.2（`Tag`）是唯一走到步骤 3 的样本，
已于 #52 改判 `tiebreaker`；全量审计（`oh-my-story` 仓
`.claude/epics/component-contract/52-step3-audit.md`（该文件已随 #52 落地于 `oh-my-story` main @ `a169832`），对当时全部
50 条 `step3` 逐条覆盖、无抽样）显示登记表现有 `step3` 条目中**没有已确认合格的实例**
可充当样例——另有 4 条两可、
#52 未裁，所以是「**未确认有**」，不是「**确证无**」。**这是实测状态，不是遗漏。**

⚠️ **为什么不补一条充数**：审计「只满足 (B)、(A) 不满足」档的 2 条，其 `notes` 自身举出了
≥2 个替代形态却仍登记 `step3`，是**待复核条目**，不是样例（另有 1 条同样举出 ≥2、但连 (B)
也不满足，不在此列）——逐条见 `docs/contract-defects.md` D-44-2 的分档表。
⚠️ 此处**不作**「离合格最近」的排序断言：审计不排序，且按判准，本档的 (A) 是被**证否**的，
反倒是「存疑」档的 4 条 (A) 满足、(B) 两可，一旦裁断更可能成为合格实例。⚠️ **本段刻意不点名**：点名会撞上上方「钉为范例
按结论逐条计」条款——公约正文点名即把被点名者的 `step3` **钉死**，抢在它们自己的新尺复核
之前锁死结论，⇒ **正因为它们仍待复核，这里不能点名**。⇒ **承认空缺优于硬造样本**，
逐条名字与处置见移交（`docs/contract-defects.md` D-44-2 的分档表与移交 issue 正文——那两处
不受「钉为范例」条款约束）。

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

⚠️ **本走查已落地**（`v0.8.0`，#41 裁决 4a/4c）：`allowsHalfStar` 已收成 `step: Double`，
且 `RatingStyle` 协议 + `StarRatingStyle` 默认实现 + `View.ratingStyle(_:)` 已补齐
——本节从「前瞻例」转为**已落地判例**。

PRD 原文：「控制**手势步进粒度**（0.5 vs 1.0），同时影响渲染 ⇒ 外观还是行为？」

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ❌ 无 `RatingStyle` 之类 |
| 2. 能举出 ≥2 个业界真实替代形态吗？ | ✅ **举得出 ≥2**——数字条（IMDb，连续条形）/ 表情（NPS 量表，单一图形）；当前形态「星」不计入替代枚举，且两者**结构本身不同**（连续条形 vs 单一图形，不是同一布局骨架换画法）⇒ **不命中皮肤变体条款**，计入 ≥2 |
| — | ⇒ **语义组件，需要扩展点** |

⇒ 结论：**语义组件，需要扩展点**。**未卡住。**

### A.2 `Tag(removable:)`

PRD 原文：「与 `onRemove` 闭包耦合 ⇒ 既是外观也是行为」。
`Tag.init(onRemove:)` 参数文档实证：「`onRemove == nil` 时按钮仍可见但 `.disabled(true)`」
——一个参数控制了「画不画按钮」与「按钮能不能点」两件事。

| 步骤 | 结论 |
|---|---|
| 1. Apple 有原生协议吗？ | ❌ 无 |
| 2. 能举出 ≥2 个业界真实替代形态吗？ | 唯一被枚举出的候选是 **pill** —— 它由兄弟组件 `Badge` 承担，按「候选形态的作用域」三条件逐条核验**被正当排除**（`Badge` 真实存在于登记表、此处写明了组件名、`Badge` 真的承担 pill 形态）。排除后 `Tag` 自己**没有成文的剩余共享骨架候选**——⚠️ 限定词「共享骨架」不可省：取证是 `实心 chip` / `描边 chip` **两个字面串**的缺席，支撑得起「该组被点名的候选未成文」，支撑不起「任何候选都没有」（上游 D-44-3 的 hedge 原话「登记表与源码均未成文枚举」正是留的这个认定口）。**取证与三文件实测见第 1 节「候选形态的作用域」小节，此处不复述**（同一证据留两份拷贝正是 #52 已经栽过一次的漂移源：那份副本漏了源码那一半）⇒ **举得犹豫**（皮肤变体，不计入 ≥2）。
⚠️ **本格的取证方式有边界，别照抄**：上面查的是「这两个候选**在本仓成文没有**」，
而步骤 2 问的是「**业界能不能举出**」——两者不是一回事。诚实执行「当场举出」应答
**举得出**（Material Design 3 明确定义 filled / outlined chip 两种变体）；它们共享同一
布局骨架 ⇒ 命中**皮肤变体条款** ⇒ 不计入 ≥2 ⇒ 走「举得犹豫」这条出口。
**落点不变**（仍固定落步骤 4），但走法是「举得出但全是皮肤变体」，不是「举不出」。
⇒ ⚠️ **不要用 grep 回答步骤 2**——本节自己在上文诊断的正是这个失效方式（门槛 (A)） |
| 3. 视觉是含义的一部分吗？（能**额外**说清「换了长相就不是这东西」吗？） | ❌ **说不清**——本走查原先用同一句「chip 的长相就是它的含义」回答步骤 2 与步骤 3，步骤 3 除复述步骤 2 外无独立内容 ⇒ 循环论证，不满足步骤 2「必须**额外**说清」的门槛。且 `Tag.swift` 里唯一**以圆角/形状为主语、并写明其含义**的陈述是「**不**使用 `.full`——这是与 Badge 的视觉区分点之一」，**明文是关系性的** ⇒ 剥掉 `Badge` 后没有可用的非关系性理由。⚠️ 该文件其余提到形状词的位置（`:10`/`:15`/`:47`/`:66`/`:68` 等，**不写总数**——此处不作闭合枚举）均**不构成**此类陈述：`:15`「GitHub issue label 风格的 chip」与 `:47`「紧凑 chip 形态」是**形态归类**、未写明「换了长相就不是这东西」；`:36`「`0.12` 是 chip 类组件常用的…基线」的主语是**不透明度**、不是形状 |
| — | ⇒ 视为答不上来，**落步骤 4** |
| 4. tiebreaker | ⇒ **规定性组件 / 不给扩展点**，`decidedBy: tiebreaker` |

⇒ 结论：**规定性组件，不给扩展点**，`decidedBy: tiebreaker`。**未卡住**，
且这是附录里**第二个**真的落到 tiebreaker 的样本（另一个是 A.4 `PinCode`）。

⚠️ **本节已于 #52 按修订回路改判**：该样本的独立理由经 #44 反事实必要性压测判「不过」
（见 docs/contract-defects.md D-44-2 / D-44-3），#52 据此作出裁断并正式改判——步骤 3
由原来的「✅ 是」改为「❌ 说不清」，落点由 `step3` 改为 `tiebreaker`（`kind` 仍
`prescriptive`：判定法对 `step3` 与 `tiebreaker` 是同一个 `kind` 映射，无需同步）。
回路三步：记入缺陷（D-44-3）→ 回写本公约（本节 + 第 1 节「候选形态的作用域」小节 +
「钉为范例」条款的对照）→ 台账逐条留痕（`docs/component-contract-revisions.md` R-13）。
⚠️ 步骤 2 的提问措辞也一并改了：原文「想要『长相不同、含义相同』的版本吗？」问的是**意愿**，
无法证伪；现改为与 **A.4** 一致的「能举出 ≥2 个业界真实替代形态吗？」。
⚠️ **A.1 已于 #53 改**——它**曾是**本公约里**唯一**仍在用上面这句被本段判为「无法证伪」
的措辞的走查（#52 的授权范围不含 A.1，故当轮不顺手改，已记入 `docs/contract-defects.md`
`D-44-1`「移交 A」段）。#53 按公约「事后补写的效力边界」条款规定的完整修订回路，把 A.1
走查表步骤 2 的提问改为与 **A.2 / A.4** 一致的「能举出 ≥2 个业界真实替代形态吗？」，
**只改提问句式，不改 A.1 已落地的判定结论**（`Rating` 仍 `decidedBy: step2`，语义组件、
需要扩展点）；台账留痕见 `docs/component-contract-revisions.md` `R-14`。
⚠️ **不要因此推出「作用域排除 ⇒ 必落 tiebreaker」**——公约明文「本条只排除候选、不决定
落点」。`Tag` 落 `tiebreaker` 是因为排除**之后**说不清「长相即含义」，不是因为被排除。

### A.1 续：`allowsHalfStar` 这个参数改成什么形状

`Rating` 的手势注释写明它算出 `step`（`allowsHalfStar ? 0.5 : 1.0`）供手势
取整用 ⇒ 按 **3.1**，它是**被压成布尔的连续量**，替代路径是**专用参数**（`step`）。

⚠️ **不塞进样式协议** —— 手势粒度是行为，违反第 2 节的「样式不得携带行为」。

⚠️ **已落地**（`v0.8.0`）：`step: Double` 已是 `Rating` 的正式参数，形状与本节例句一致。

### A.2 续：`removable` 这个参数改成什么形状

Bool + 配套闭包 ⇒ 按 **3.2** 走**子视图槽**，一并消除 `Tag.init(onRemove:)` 参数
文档记录的自相矛盾状态：「`onRemove == nil` 时按钮仍可见但 `.disabled(true)`」。

### A.3 `surface(_ kind:, bordered: Bool = true)`（modifier 形态）

⚠️ **本节已从「待办项」转为已落地判例**（`v0.8.0`，#41 裁决 1）：
`View.surface(_:bordered:)` 的 `bordered` 参数**已删除**，容器角色改由 `SurfaceKind.grouped`
承担；`View.surface#bordered` 已不在任何违规集合里，`BoolExemptionGuard` 里包住它的
`withKnownIssue` 块也已随之删除（见 `BoolExemptionGuard.swift` 中三处 `#41 裁决 1` 的留痕注释）。
下面保留原判决记录，是为了让「为什么它当年被判不合规」可追溯。

这不是组件，是 **View extension 上的 public modifier** —— 用来验证 **3.3** 的 modifier 条款。

`SurfaceModifier.swift` 的文档注释：「`bordered` 是否画描边，默认 `true`。
置 `false` 只保留背景 + 圆角、去描边」。

| 第 3 节判据 | 结论 |
|---|---|
| modifier 表达**语义选择**？ | `.surface(.content)` 的 `kind` 是 ✅ |
| modifier 承载**布尔旋钮**？ | `bordered` 是 ❌ **不合规** |

⇒ 结论：**不合规**（当年判决）。**最终处置已于 `v0.8.0` 落地**：删除参数（#41 裁决 1），
走的是第 3 节终局条款的出口 **(b) 论证这个参数本不该存在**——这也是终局条款「(b) 是现实中
最常见的处置」这句话的第一个实证。
⚠️ **以下两段（『它不进豁免清单』/『落法是 `withKnownIssue`』）是 `v0.8.0` 之前的落法
记录，不是现状**：`bordered` 参数已删除，`BoolExemptionGuard.swift` 里包住它的
`withKnownIssue` 块也已随之删除（见上方「本节已从『待办项』转为已落地判例」段与下面
「到期确实是机器强制的」段）；保留这两段是为了让「当年为什么选 `withKnownIssue`
而不是让 CI 字面红」可追溯。
⚠️ **它不进豁免清单**：`View.surface#bordered` 不在 `docs/bool-exemptions.json` 里，
因此**不占** `maxEntries` 的格子、**不受**棘轮保护——它不是「被接受的 API」，
而是一条**已知的、未解决的违规**。
⚠️ **落法是 `withKnownIssue` 而不是让 CI 字面红**（#39 的裁决，AC 偏离已登记）：
J-1 主判据 `BoolExemptionGuard.j1NoUnexemptedBoolParameters` 用 Swift Testing 的
`withKnownIssue` 只包住「未豁免违规集合为空」这一条断言，其余（过期条目、棘轮、
宿主台账、新违规）照常判红。理由：epic / main 分支**都没有分支保护**，字面红拦不住
任何合并、只是信号；而它会让 `.github/workflows/ci.yml` 里「仅已知 flake 才重跑」的
保护恒走「直接判红」分支，等于在整个 epic 期间关掉那道保护。
⚠️ **到期确实是机器强制的，且已经兑现**：#41 删掉 `bordered` 之后，`withKnownIssue` 块内不再
记录到 issue ⇒ Swift Testing 判「Known issue was not recorded」⇒ 主判据自己红，逼人回来清理
——`BoolExemptionGuard.swift` 里那个块因此已被删除。第二道闸
`j1ViolationSetIsExactlyTheContractPending` 同轮转为裸判据。

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
public API 面，需要治理——6 个 Bool 已由 `39.md` 的 J-1 覆盖（走 `docs/bool-exemptions.json`
台账，不经登记表）。⚠️ **`placeholder: String` 这一侧的旧句「已移交 39.md（J-1/FR-4）」
与落地结果不符，本次改正**：#39 只做了 J-1；#40 的 FR-4 判据以**登记表条目**为定义域，
而 `BottomInputBar` 按本裁决**不登记** ⇒ 它的 `placeholder` 落在 FR-4 的**定义域之外**
（`ComponentTextParamGuard.knownFunctionSideBareText`，有固定集合断言盯着，不是静默略过）。
真正的处置 #41/#42 **均未做**：`BottomInputBar` 仍在，`View.bottomInputBar#placeholder`
至今没有任何机器判据给它分类 ⇒ 见 `oh-my-story` 仓
`.claude/epics/component-contract/close-out.md` 的「## 四、移交清单」（该文件随 #44 收口 PR 落地；已开 issue `#50` 承接）。
两条出路仍是：删掉这个组件，或给它一个可登记的 public 类型表面。

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
（`styleImpls` 打印清单）与 J-3 判据（#40 已落地，见 `Tests/CoreDesignTests/NativeProtocolPurityGuard.swift`；
读取 `nativeProtocol` 交叉核对源码作用域）覆盖，
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
