# Shader 许可来源裁定表（#249 / `shipswift-foundation` 闸②）

> 覆盖 ShipSwift 的全部 **28** 个 Metal shader。**每一行都有裁定，没有空行。**
> 本表是**裁定过程**；对外的许可声明在 `ACKNOWLEDGEMENTS.md`，前者判为可落地的行
> 必须在后者有对应条目。

## 为什么必须做这件事

**Shadertoy 的默认许可通常被表述为 CC BY-NC-SA 3.0——完全禁止商用**，除非 shader 源码
开头有注释声明了别的许可（**参考/概述**：[Wikipedia · Shadertoy](https://en.wikipedia.org/wiki/Shadertoy)）。
CoreDesign 以 MIT 分发，**与 CC BY-NC-SA 不兼容**（既禁商用，又有传染性 share-alike）。

⚠️ **该链接是二手概述，不是证据；上一版在此标「已核实」，措辞过强，已撤回**
（PR #259 review round-4）。**一切以 Shadertoy 官方条款/许可说明为准**——本表**未**
独立核验其官网条款原文（未访问、未留存原文出处，此处也不臆造一个官方条款 URL）。
⇒ 任何要落地 **Shadertoy 来源件**的 task，**硬前置**是自己读到官方条款原文、把一手
出处补回本节；在此之前本节只用于说明「为什么必须逐件裁定」，**不足以单独支撑任何
个案的可落地结论**。逐个案的裁定另有各自的一手证据（如 `StarNest` 行要求人工目视
确认源码头的 MIT 声明，见《A. 有上游标注的 7 个》）。

而 ShipSwift 的 `ACKNOWLEDGEMENTS.md` **只标注了 7/28 个** shader 的来源，
**其余 21 个零来源标注**。直接移植那 21 个 = 在不知道原始许可的情况下重新分发。

---

## ⚠️ 本表第 1 版的核心前提被证伪 —— 必读

**第 1 版写**：「那 21 个零标注 shader 的**实际出处**无法确立；它们的可落地性完全建立在
clean-room 重写这条出口上。」

**这句话是错的，而且错在有法律后果的那一侧。** 终审 reviewer 用**参数签名比对 + 文件头
描述句比对**，在一小时内追到了其中 10+ 个的真实上游：

> **[`paper-design/shaders`](https://github.com/paper-design/shaders) —— Apache-2.0，
> 且带 `NOTICE` 文件。**

本人一手复核（读 paper 源码，非转述）：

| | 文本 |
|---|---|
| paper `voronoi.ts:11` | "Anti-aliased animated Voronoi pattern with **smooth and customizable edges**" |
| ShipSwift `SWVoronoi.metal` | "Anti-aliased animated Voronoi pattern with **smooth, customizable edges**" |
| paper `neuro-noise.ts:6` | "**A glowing, web-like structure of fluid lines and soft intersections**" |
| ShipSwift `SWNeuroNoise.metal` | "**A glowing web-like structure of fluid lines and soft intersections**" |

参数集同样逐个对应（Voronoi：`scale` / 最多 5 色 / `colorsCount` / `stepsPerColor` /
`colorGlow` / `colorGap` / `distortion` / `gap` / `glow`，连 `randomGB` ↔
`textureRandomizerGB` 都对得上）。paper 的 `NOTICE` 内容是
`Powered by Paper Shaders: https://shaders.paper.design`，**Apache-2.0 §4(d) 让这条署名
对衍生作品具有约束力**。

### 第 1 版会造成什么后果

按第 1 版裁定，这十几个走「对照 webgl-noise 重写」⇒ **产物是 Paper 作品的衍生物，
却以零署名落地，违反 Apache-2.0 的 NOTICE 义务**。

⚠️ **这正是"判太松"**——只不过方向与预期相反：不是"CC BY-NC-SA 混进来了"，而是
**我把一个一小时就能查到的东西宣布为"不可知"，而 clean-room 出口恰好会把署名义务洗掉**。

### 方法论教训（写给后续 task）

**追溯 shader 出处的有效方法不是搜算法名，是比对签名与散文**：
① `[[stitchable]]` 形参列表 vs 候选上游的 uniform 列表；
② 文件头描述句的逐字比对（移植者极少重写这段）。
⇒ **本表标 `待追溯` 的那些，落地前必须先用同一方法再追一轮**，不得直接走 clean-room。

---

## 裁定方法：正向裁定，不证否定

⚠️ **"证明来源不明"是要证一个否定，做不到。** 本表用**正向裁定**——每个 shader 只有
拿到下表**五种**结论之一才算裁定完成（取值域即下表，正文任何位置不得出现表外取值；
⚠️ **留档段落引用已废除的 `clean-room 重写` 时须显式标为留档**，见下方
《〔留档 · 历史说明〕`clean-room 重写` 的成立条件与可核产物条款》，**不得当作裁定值使用**）：

| 裁定 | 含义 | 落地义务 |
|---|---|---|
| `已追到兼容许可 · MIT` | 追到原始实现，许可为 MIT / BSD / PD / CC0 | 可移植；`ACKNOWLEDGEMENTS.md` 转载原始许可 |
| `已追到兼容许可 · Apache-2.0` | 追到原始实现，许可为 Apache-2.0 | 可移植；**须转载 LICENSE + `NOTICE`，并标注修改**（§4(a)(b)(d)） |
| `自研实现` | 属**效果类别**（非某人的具体设计），按**下方**《第三条出路》的**六轴**差异化自研 | 五轴之外**必过第六条轴（函数体）**；参数面须从 CoreDesign 概念推出。⚠️ 上一版这里写「**上方**…**五轴**」——方位与轴数两处都错（第 5 轮终审 I2），而这是本档位的**操作性定义**，只读裁定方法一节的人拿到的就是被证伪的旧标准 |
| `待追溯` | 尚未用上面《方法论教训》的方法追过 | **不得据现状落地**；先追一轮 |
| `不落地` | 追过且追不到兼容来源，也无具名参考实现 | 不进 `CoreDesignShaders` |

⚠️ **`Apache-2.0` 是第 1 版遗漏的档位**（第 1 版只列 MIT / BSD / PD / CC0）。它与 MIT
分发兼容，但**义务更多**：保留 LICENSE、保留 NOTICE、标注修改。

### 〔留档 · 历史说明〕`clean-room 重写` 的成立条件与可核产物条款

⚠️⚠️ **本小节整节是留档，不是本版有效的裁定路径。** `clean-room 重写` **不在上方取值表的
五种取值域内**——该档已随本 PR 删除（见《第三条出路：自研实现》与《汇总与闸②判定》），
本表任何一行都不得再取该值，本版的替代者是 `自研实现`。
⇒ **下列条款只用于一件事：识别并处置旧文档里残留的 `clean-room` 声称**（本表第 1 版、
`.claude/` 下的历史 epic / task 文稿、旧 PR 描述）——读到一条 `clean-room` 声称时，
按下列条款判它当年**是否曾经成立**，然后**一律改判为本版五种取值之一**（追过且追不到
兼容来源 ⇒ `不落地`；尚未追过 ⇒ `待追溯`）。**它不是一条可供新条目走的出口。**

**（留档）该档在第 1 版形同虚设**：第 1 版判 24 行 clean-room，其中
**17 行没有具名任何参考实现**——只写了「标准教科书内容」「Blinn 1982」「公开的图形学配方」。
**没有具名参考实现，"不看 ShipSwift" 就退化成"看 Shadertoy"**，而 Shadertoy 默认许可
一般被表述为 CC BY-NC-SA（**二手概述，未核官方条款**——见《为什么必须做这件事》的撤回注）。
⇒ 当年据此定下的降级规则是「**`clean-room` 行必须给出 URL + 已核实的许可，
否则一律降级为 `待追溯`**」。⚠️ **本版已无 `clean-room` 行可降级** —— 该规则今天的
唯一用途，是解释**为什么**《汇总与闸②判定》里第 1 版那 2 行 clean-room
（`FractalClouds` / `InkSmoke`，见 §C #19 / #20）落到了 `待追溯`。

**（留档）可核产物三条**——当年用来把 `clean-room` 写成**可核**而非自证的条款。
**不写成"不看 ShipSwift 的 `.metal`"**——那既不可执行（本次调研本身已 grep 过全部
34 个 `.metal`），法律风险也不在读 ShipSwift（它是 MIT），**而在于 ShipSwift 的文件
本身若是 CC BY-NC-SA 衍生**。可核的三条：

1. 本表的 `参考实现` 列**必须指向参考实现**，不得指向 ShipSwift；
2. 新 `.metal` 文件头注明参考实现 URL + 其许可；
3. 评审**对照参考实现**核，不对照 ShipSwift。

⚠️ **这三条的实质判据仍有留档价值，只是不再挂在 `clean-room` 这个取值下**：
它们在《对 ShaderKit 那 5 个的裁断》里被引用（「可核产物三条只保证文档与评审的指向，
**不建立独立性**」），而作为**正式判据**，本版由《第三条出路：自研实现》的
可验证差异化（五轴 + 第六条轴）取代。

---

## A. 有上游标注的 7 个 —— 逐个追传递来源

⚠️ **不得因为 ShipSwift 标了来源就当作预先通过**——要追到**原始作者**，而不是止步于
它的直接上游。

| # | shader | 直接上游 | 上游许可 | 传递来源核验 | 裁定 |
|---|---|---|---|---|---|
| 1 | `GlassOrb` | [Inferno](https://github.com/twostraws/Inferno) 的 "Warping Loupe"（Paul Hudson） | **MIT**（已核实读取 LICENSE 全文） | ✅ **链条闭合**。Inferno 的 LICENSE 附逐 shader 移植清单，**6 组**（Circle/Circle Wave/Diamond/Diamond Wave ← PolkaDotsCurtain、Crosswarp、Radial、Swirl、Wind、Genie）；**"Warping Loupe" 不在其中** ⇒ **推论**为 Inferno 原创。⚠️ 第 1 版写"仅含 5 项"**漏数了第一组**；"不在清单 ⇒ 原创"是**推论不是断言** | **已追到兼容许可 · MIT** |
| 2 | `StarNest` | ["Star Nest" by Pablo Roman Andrioli（Kali）](https://www.shadertoy.com/view/XlfGRj) | **MIT**（作者在源码头声明，覆盖 Shadertoy 默认许可） | ✅ 多个独立移植各自记录其为 MIT（[a-frame 组件](https://github.com/urish/aframe-starnest-component)、[Godot Shaders](https://godotshaders.com/shader/star-nest-2/)、[NatronGitHub/openfx-misc](https://github.com/NatronGitHub/openfx-misc/blob/master/Shadertoy/presets/default/star%20nest-natron.frag.glsl)）。⚠️ shadertoy.com 对自动抓取返回 403，**未能直读源码头**——证据是多个独立第三方的一致记录，非一手 | **已追到兼容许可 · MIT**（⚠️ **人工目视确认该页面源码头是落地 task 的硬 AC，不是"建议"**——另有 xscreensaver `hacks/glx/glsl/starnest.glsl`、pythonarcade/arcade 等**五个独立来源逐字一致**） |
| 3 | `ChromaticGlass` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun） | **MIT**（GitHub 识别 + 已核 LICENSE） | ⚠️ **第 1 版说"ShaderKit 没有任何来源说明"是错的**：LICENSE 里没有，但 `docs/shadercards/css-parity.md` 声明视觉参考是 [simeydotme/pokemon-cards-css](https://github.com/simeydotme/pokemon-cards-css)（**GPL-3.0**），并主张自身是 "original, procedural Metal recreation" | **`待追溯`**（见下方裁断） |
| 4 | `Foil` | 同上 | 同上 | 同上 | **`待追溯`** |
| 5 | `Glitter` | 同上 | 同上 | 同上 | **`待追溯`** |
| 6 | `IntenseBling` | 同上 | 同上 | 同上 | **`待追溯`** |
| 7 | `PolishedAluminum` | 同上 | 同上 | 同上 | **`待追溯`** |

### 对 ShaderKit 那 5 个的裁断：从 `clean-room` 降为 `待追溯`

⚠️ **第 1 版判它们走 clean-room，理由是"效果都是公开的图形学配方"——该理由不成立**：
**没有具名参考实现**（按《〔留档 · 历史说明〕`clean-room 重写` 的成立条件与可核产物条款》
所记的当年成立条件，这一判断当时就不成立 ⇒ 直接降级）；**且 clean-room 在这里本就
做不到**——本表作者与实现者都已读过 ShaderKit / ShipSwift 的实现（调研阶段 grep 过全部
34 个 `.metal`），**在已读原实现的情况下"重写"是改写（paraphrase），不是 clean-room**。
可核产物三条只保证**文档与评审的指向**，**不建立独立性**。ShaderKit 明示的 **GPL-3.0
视觉参考**让这更敏感，而不是更轻。

⇒ **三选一，由落地 task 定案**：① 接受 ShaderKit 的 MIT 与其明示的原创主张（记录风险）；
② 具名一个真实的、许可已核的参考实现；③ 不落地。**本表不替它拍板。**

<details><summary>第 1 版的原裁断（已作废，留档）</summary>

**MIT 在 ShaderKit 那一层是真的**，问题在于**它上面还有没有一层**。ShaderKit 没有记录，
我也无法证明它有或没有。两个选项：

- **按"上游声明 MIT 即可"接受** —— 风险：若 ShaderKit 自己移植自 CC BY-NC-SA 的
  Shadertoy 作品，它无权以 MIT 再许可，我们跟着错。
- **走 clean-room** —— 这五个的效果（箔片彩虹、闪片、色散玻璃、金属拉丝、强烈 bling）
  都是**公开的图形学配方**（fresnel 边缘 + 相位偏移的彩虹 ramp + 高次幂 sparkle 项），
  有充分的公开文献可依。

⇒ **裁定走 clean-room**：成本增量不大（本来就要把它们的调色板从 `.metal` 提到 Swift 侧，
见 spike #248 交付 B：这 7 个"颜色写死"件本就 ≈2–3h/个），换掉一个**无法闭合的法律不确定性**。
⚠️ 这不是说 ShaderKit 有问题——是说**我们无法核实**。

</details>

---

---

## 第三条出路：**自研实现**（取代 `clean-room 重写`）

⚠️ **`clean-room 重写` 这个名字要退场。** 严格意义的 clean-room 要求**实现者从未接触过
原实现**——该前提本仓已经违反（调研阶段 grep 过全部 34 个 `.metal`），所以拿它当裁定
是自欺，终审 reviewer 也是这么判的。

**但这条路本身成立，只是法理依据不同**：

> **著作权保护的是「表达」，不是「思路 / 算法」。** "一团旋转的等离子背景""程序化星空"
> 是思路，不受保护；具体的 GLSL / MSL 代码是表达，受保护。

⇒ 正名为 **`自研实现`**。它的保障**不是**"我没看过"（已不可能，且**不可验证**），
**而是「可验证的差异化」**——这比 clean-room **更硬**，因为它能拿出来核。

### 差异化的五个轴（每一条都是本仓/PRD 既有约束，不是为此临时发明的；⚠️ 其中「颜色」轴的**机器判尚未存在**，见该行注）

| 轴 | 上游（paper / ShaderKit / Shadertoy） | CoreDesign 自研 |
|---|---|---|
| **颜色** | shader 内部调色板 / uniform 传一组固定色 | **只吃 `.tint` 与第 3/4 层语义 token**（FR-8 禁色相字面量）。⚠️ **`EffectsColorLiteralGuard` 目前只存在于 PRD/epic 文档，本仓无实现**——它**将由** #246 / PR #265（`A0-3` 守卫建设，尚未合入 `epic/shipswift-foundation`）**交付后**机器判；在那之前 FR-8 是**人工评审判**，不得当作已有的机器闸 |
| **参数集** | `u_stepsPerColor` / `u_colorGlow` / `u_distortion` 等上游自创的调参面 | 按 CoreDesign 概念表达：`controlSize`、`CoreSpacing` 尺度、语义枚举（Bool 走 J-1 禁令） |
| **API 形态** | `.colorEffect(ShaderLibrary.xxx(...))` 裸暴露 | 裸名 `public struct: View` + `#Preview`，与 `Badge` / `Card` 同构 |
| **动效契约** | 无 | Reduce Motion / Reduce Transparency / 后台 / 低电量**四条降级路径从第一行就在** |
| **代码风格** | 英文注释、无 `self.` | 中英混排注释、显式 `self.`、`// MARK: -` |

⚠️ **「参数集」这一轴最关键**——它正是本表用来指认 paper 的证据（签名逐个对应，见 §B）。

### ⚠️⚠️ 第六条轴：**函数体**（五轴是必要不充分的，这一条由 #261 用四轮实证补上）

**上面五个轴全部只描述 API 表面。而受版权保护的表达在函数体里。**

第 1 版据此写下过一句承诺：「只要我们的参数面是从 CoreDesign 概念推出来的，那条指认链
在我们身上就不成立——这是**可被下一个 reviewer 用同样方法反查**的承诺」。
**PR #261 的五轮终审逐轮证伪了它，四次命中，每次都在函数体：**

| 轮次 | 五轴全部满足（参数面确实是 CoreDesign 概念）| 而函数体里被一击命中的 |
|---|---|---|
| 1 | ✅ | `hash21` 与 ShipSwift 的 `swInkSmokeHash21` **逐字节相同**（`grep 123.34`）|
| 2 | ✅ | `grep 0x27d4eb2d` → Thomas Wang / Nathan Reed；`grep 73856093` → Teschner et al. 2003；`coreDesignInkSmoke` 是 iq《Domain Warping》的结构复制，**连变量名 `q`/`r` 都保留** |
| 3 | ✅ | `Plasma` / `DotGrid` 的「射程限定」引了它们**根本没调用**的原语——**与错引 ashima 互为镜像** |
| 4 | ✅ | `cd::fbm` 逐行同构于 The Book of Shaders ch.13；`Plasma` 的四相正弦是 Lode Vandevenne 的公式 |
| 5 | ✅ | `ramp3` / `edgeWidth` / `coreDesignRefractiveGlass` **主体**三处零署名 |

⇒ **裁定：五轴是必要条件，不是充分条件。** 任何「自研实现」的声称，**必须额外**通过
一条函数体判据：

1. **逐常量 grep**（⚠️ **本条无条件适用于任何落地件**，含已追到兼容许可的移植件
   ——第 5 轮终审 I3：它是 **provenance 发现工具**，不是原创性测试。
   `grep 0x27d4eb2d` 会找出一个未署名的 Wang 常数，与外层 shader 标的是
   `自研` / `移植` / `待追溯` 无关；而 §B 的移植件**正是**最需要它的地方
   ——paper 的移植件可能带着**追过 paper 之外**的常数，那正是
   「paper 之上还有一层」在说的事）：把函数体里所有魔数（`0x…`、七位以上素数、`123.34` 这类）拿去搜。
   本仓四次命中全部来自这一步，**它比五轴便宜一个数量级，却被放在最后**。
2. **逐结构对照**：级联层数、变量命名、循环体形态与已知公开片段比对
   ——「改常量、改名不构成独立」（本仓已成文）。
3. **逐原语核对调用面**：声称"自研"的件，其**实际调用的**共享原语必须逐个有出处
   ——不是"我用到的那些"，是 `grep cd::` 出来的那些。第 3 轮的镜像错误就出在这里。

### ⚠️ 清偿条款：已落地件的 `待追溯` 怎么办（第 5 轮终审 C4）

本表 `待追溯` 的定义是「**不得据现状落地**；先追一轮」。而 #261 **已经**落地了
若干被本表登记为 `待追溯` 的原语 ⇒ **本表如果原样合入，会把 #261 从"未裁定"
变成"已裁定为不得落地"——比合入前更糟。**「一条被它唯一的消费者在第一天就违反的规则，
不是规则。」**

⇒ **裁定：`待追溯` 按指纹强度分两档，只有强档阻断落地。**

| 档 | 判据 | 对已落地件的效力 |
|---|---|---|
| **待追溯（低指纹）** | ⚠️ **判据已改写**（第 2 轮终审 C-4）：不是「函数体是不是算法定义」，而是**复制量 + 可主张的著作权保护**——① 复制量小（个位数行）；② 其中的常数/结构是**功能性**的（换一组就不工作，不是审美选择）；③ 来源为无许可的公开发表 ⇒ **plausibly 低于独创性门槛 / de minimis** | **不阻断**。条件：ⓐ 不作任何原创声称；ⓑ 有具名承接 issue：**合入 `main` 前编号必须填实**；在此之前**允许且只允许**临时写 `TBD`（不得写「后继 issue」「同上」这类无法机器检出的模糊指代），`TBD` 一律视为**未清偿**，`epic → main` 的 PR 评审须逐行核对已换成真实编号；ⓒ 下一次该文件被实质修改时必须追完 |
| **待追溯（强指纹 · 阻断）** | 有可辨识的个人表达：**级联结构 / 变量命名保留 / 审美性的参数组合**——本表自评「指纹强度不低于 `InkSmoke` 的 q/r 级联」者一律入此档 | **阻断**。追完前不得合入 `main`（合入 epic 分支可，须在 PR 记账）|

⚠️ **判定人与争议处置（上一版零指定，正是「⚠️ 确有需要时」型条款的复刻）**：
分档由 provenance 表 owner 判、**merge 前评审复核**；
**分档有争议时一律按强档处理**（向保守侧倒）⇒ 本条由此可证伪。
⚠️ **每一行的分档必须引用它所依据的判据原文**，不得只写结论。

**当前分档**（#261 已落地的 **5 项**：4 项低指纹 + 1 项强指纹；⚠️ 上一版此处写「四项」，
与紧接着的 5 行表格不符，第 5 轮 review 收口时改齐）：

⚠️ **本表上一版把「承接」与「分档理由」挤在同一列**，于是 `ramp3` / `edgeWidth` 两行
写成占位符「#249 后继 issue / 同上」、另两行干脆写成理由，**与上表 ⓑ「编号必须填」直接
打架**（PR #259 review round-4）。已拆成两列，缺的东西按 ⓑ 一律写 `TBD` 而**不编造编号**。

| 项 | 档 | 承接 issue（ⓑ） | 分档理由（须引上表判据原文） |
|---|---|---|---|
| `ramp3` | 低指纹 | `TBD` —— ⚠️ 承接 issue **尚未创建**（建 issue 属独立决策，本 PR 不顺手代做，故此处不编造编号）；合入 `main` 前必须换成真实编号 | ⚠️ **本行未引判据原文**，违反上方「每一行的分档必须引用它所依据的判据原文」。本表已有的一手事实只有《共享原语的逐项出处》表的 `ramp3` 行：「三档插值 \| **未指认到具体上游** \| ⇒ 待追溯（不作原创声称）」——它支撑 `待追溯`，**不足以单独支撑「低指纹」这一档**。⇒ 上一列那个 `TBD` issue **须同时补齐本行的 ①②③ 判据评估**；补齐前本行分档按「有争议一律按强档处理」随时可被翻成强档 |
| `edgeWidth` | 低指纹 | `TBD` —— 同 `ramp3`：尚未创建，合入 `main` 前必须换成真实编号 | 引《共享原语的逐项出处》表 `edgeWidth` 行：「`max(fwidth, ε)` + 下游 smoothstep \| iq 的 **distance-AA** 一族，**公开惯用法** \| ⇒ 待追溯」⇒ 对应判据 ③（来源为无许可的公开发表）；①（复制量小：一行 `max`）与 ②（功能性：换一组抗锯齿就坏）由本行认定。⚠️ 三条中 ①② 系本表认定而非引自他处，须在上一列的承接 issue 里复核 |
| `wangHash` | **低指纹** | `TBD` —— 承接 issue 尚未创建，合入 `main` 前必须换成真实编号 | ⚠️ **上一版的理由「已具名出处，只缺许可裁定」不是判据表里的任何一条**，且它不能区分任何东西——q/r 级联同样"已具名出处"却判强档 ⇒ 该理由在这里不做任何工作。**按改写后的判据重判**：6 行整数运算（复制量小 ✓）、常数与移位表是**功能性**的（换一组雪崩性质就坏 ✓）、Wang 的页面无许可声明 ✓ ⇒ 低指纹成立。⚠️ 但**「逐字符一致」这个事实必须同时记着**——它不改变分档，改变的是**不得作任何原创声称**这条的严格程度 |
| Teschner 素数三元组 | **低指纹** | `TBD` —— 承接 issue 尚未创建，合入 `main` 前必须换成真实编号 | 三个常数，功能性（空间散列的经典取值），论文公开发表 ⇒ 同 `wangHash` 的三条判据评估 |
| **`coreDesignRefractiveGlass` 主体** | **强指纹** | **不适用** —— ⓑ 只加在低指纹档；强档的义务是「追完前不得合入 `main`」 | ⚠️ **阻断 epic→main**，须在 B-4 前追完。判据引强档行：「**指纹强度不低于 `InkSmoke` 的 q/r 级联**」（《共享原语的逐项出处》表同名行） |

⚠️ **兜底写死**：追溯失败（追不到 / 追到不兼容）⇒ **`不落地`**，
**不得默认回落到「自研」**——那正是本表第 1 版栽的跟头。

⚠️ **「指认不到」不等于「原创」**：`ramp3` 至今未指认到上游，本表登记为**待追溯**
而非「自研」。**空白等于默认原创，而本 PR 已因这个默认吃了四次亏。**

### ⚠️⚠️ The Book of Shaders 的许可实查结果 —— 本表最重要的一条实查

**实查（`raw.githubusercontent.com/.../thebookofshaders/master/LICENSE`）：`All rights reserved`。**
逐字：

> You cannot host, display, distribute or share this Work in any form…
> **You cannot use this Work in any commercial or non-commercial product, website or project.**

⇒ **比 Shadertoy 的默认 CC BY-NC-SA 还严**（后者至少允许非商业使用；
该「默认许可」本身是二手概述，见《为什么必须做这件事》）。

⚠️ **这正是本表存在的理由的第二次兑现**：第 1 版因为完全没碰 Shadertoy 的默认许可而
把 24 行判成 clean-room；这一次，如果不是评审点名「唯一标注『逐行同构』的来源，
许可从未核过」，`cd::fbm` 会带着一个**比 Shadertoy 更严**的来源标注合入
——而它是多个已落地 shader 共用的原语。

**但结论有两个方向，必须都写清楚：**

1. **不能以 The Book of Shaders 作为许可依据。** 它的 LICENSE 排除一切商业与非商业使用。
2. **⚠️ 而我上一轮把自己写重了**：`cd::fbm` 与该书 ch.13 的示例**并非「逐行同构」**
   ——实查对照，我们多了 `total` 累加与 `sum / total` 归一化（该书没有），
   且 `octaves` 是**函数参数**而非 `#define OCTAVES`。
   循环体本身（`amplitude = 0.5` / `sum += noise(p) * amplitude` / `p *= 2` /
   `amplitude *= 0.5`）**就是 fBm 的定义**（gain 0.5、lacunarity 2.0），
   属 Mandelbrot–Perlin–Musgrave 谱系的**事实性算法**，不是某一份教学资源的表达。
   ⇒ 署名对象应当是**算法本身**，而不是「我在哪里读到它」。

⇒ **裁定：`fbm` 可落地**（事实性算法），但**引用来源改指算法谱系**，
并在此**永久记录 The Book of Shaders 的许可实查结果**——因为下一个人很可能
和我一样，第一反应是去引那本书。

⚠️ 本条同时是对第六条轴的一次**反向校准**：轴 6 防的是「低估抄袭」，
而这一条显示**高估同样有代价**——它会把一个事实性算法错误地绑到一个
`All rights reserved` 的来源上。**两个方向都要查实，不能只朝一边使劲。**

### ⚠️ 第六条轴的生效范围（按 `docs/component-contract.md` #59 的形状写，非选答题）

**标准提高了，既判的 28 行要不要重来？** 本表必须自己回答，否则第六条轴就是
「新规矩只约束别人」。

- ⚠️⚠️ **判据 1（逐常量 grep）无条件适用，§A / §B 亦不豁免。**
  上一版这一节写「§B 的 11 条与 §A #1–2 …… **不受影响**」，而同一轮加的
  《第六条轴》逐字写着「本条**无条件**适用于任何落地件，含已追到兼容许可的移植件
  ——而 **§B 的移植件正是最需要它的地方**」⇒ **同一轮做的两处修复直接对撞**，
  且按前者读会把**本表最大的可落地组**豁免掉逐常量 grep
  ——恰恰是本表自述"四次命中全部来自这一步"的那一步。
- **不回溯的只是判据 2/3 的原创性测试**（移植件本就没有原创声称可证伪）。轴 6 提高的是
  **`自研实现` 声称**的门槛，而：
  · §B 的 11 条与 §A #1–2 是**已具名上游的移植**，没有原创声称可供证伪 ⇒ 不受影响；
  · §A #3–7（ShaderKit 5）与 §C #21–28 已是 `待追溯` ⇒ 不受影响；
  · **真正暴露的只有 §C #19/#20 两行**，而它们因独立理由（依据被删）本轮已改判。
- **新口径约束**：今后的**新判定**、以及**任何被实质修改的既判条目**。
- ⚠️ **代价如实记录**：本表会在一段时期内**两把尺并存**——读到一条既判条目时，
  **须知它可能是五轴口径下的结论**。

### 共享原语的逐项出处（#261 落地时补，本表的必填项）

| 原语 / 片段 | 出处 | 许可地位 |
|---|---|---|
| `wangHash`（`0x27d4eb2d`） | Thomas Wang 整数 hash，GPU 版经 **Nathan Reed**《Quick And Easy GPU Random Numbers in D3D11》(2013) | 页面无许可声明 ⇒ **待追溯**（算法层，风险低但**低风险 ≠ 已裁定**）|
| `hash21`/`hash22` 的素数三元组 `73856093 / 19349663 / 83492791` | **Teschner et al. 2003**《Optimized Spatial Hashing for Collision Detection of Deformable Objects》 | 论文里的常数 ⇒ **事实性算法**，可落地 |
| `valueNoise`（嵌套 `mix` 形态） | **iq** 的嵌套 `mix(mix(a,b,u.x), mix(c,d,u.x), u.y)` 形态 | 教科书算法 ⇒ 可落地。⚠️ **上一版把 The Book of Shaders 也列为出处——而本表上一节刚写完"不能以它作为许可依据"，34 行后自己就引了它**（第 2 轮终审 C-5）。实证支持删除：该书用的是**展开式** `mix(a,b,u.x)+(c-a)*u.y*(1-u.x)+(d-b)*u.x*u.y`，**我们用的恰恰不是它那一种** |
| `fbm`（gain 0.5 / lacunarity 2.0 循环体） | **算法本身**：fBm 的标准形式（Mandelbrot–Perlin–Musgrave 谱系，见 Ebert et al.《Texturing & Modeling》）。⚠️ 我最初是在 **The Book of Shaders 第 13 章**读到它的 | **可落地**（事实性算法）——⚠️ 但见下方两条更正 |
| 域扭曲的 `q`/`r` 三级级联（落地函数 `coreDesignInkSmoke`；组件 `InkSmoke` / `FractalClouds`） | **Inigo Quilez《Domain Warping》** | ⇒ **待追溯**；`InkSmoke` 已按此**撤回原创声称** |
| `Plasma` 的四相正弦叠加 | **Lode Vandevenne**《Lode's Computer Graphics Tutorial — Plasma》，逐项对应 | ⇒ **待追溯** |
| `roundedBoxSDF` | **iq 2D distance functions** 的标准闭式解（另有四半径变体） | 页面无许可声明 ⇒ **待追溯（低指纹）**。⚠️ **与 `valueNoise` 的双标已消**（第 2 轮终审 C-5）：两条都归 iq、都被本表称「标准闭式解 / 教科书」，却一个判可落地、一个判待追溯。**判别标准现明写**：`valueNoise` 的**具体写法**在野有两种、我们选的那种不是任何单一来源的独有表达；而 `roundedBoxSDF` 是**唯一闭式解**、逐字符可比 ⇒ 复制量更确定 ⇒ 保守判待追溯 |
| `edgeWidth`（`max(fwidth, ε)` + 下游 smoothstep） | iq 的 **distance-AA** 一族，公开惯用法 | ⇒ **待追溯** |
| `ramp3`（三档插值） | **未指认到具体上游** | ⇒ **待追溯**（不作原创声称）|
| `coreDesignRefractiveGlass` 的位移 + 通道色散**主体**（= 组件侧 `Glass`（`RefractiveGlass`）的主体原语，见《统一裁定表》同名行） | 2025 年 SwiftUI `layerEffect` "liquid glass" 一族的通行形态，**指纹强度不低于 InkSmoke 的 q/r 级联** | ⇒ **待追溯** |

### ⚠️ 界线：「效果类别」可自研，「某人的具体设计」不可

| 分类 | 判断 | 能否自研 |
|---|---|---|
| **效果类别**——等离子、星空、Voronoi 距离场、值噪声域扭曲、半调网屏 | 公开的图形学配方，**思路层** | ✅ **能** |
| **某人的具体设计**——ShaderKit 的箔片 / 闪片 / bling（"看起来像宝可梦卡"的观感就是设计本身）、`AnimatedLoop` 的 18 参数 hand-tuned 组合 | **观感即作品**，参数与调校本身是表达 | ❌ **不能**——自研出来的会是另一个东西；不如诚实地不做，或接受上游许可 |

⚠️ ShaderKit 那 5 个尤其要小心：它自己在 `docs/shadercards/css-parity.md` 里声明视觉参考
是 **GPL-3.0** 的 `pokemon-cards-css`。**那个观感是别人的设计**——我们"自研"一个像它的
东西，规避的只是代码、不是设计。

### 走查样例：`Plasma` 的自研 API 面长什么样

⚠️ **不是空谈**——把「参数集」这一轴摊开看，两边的调参面**根本不是同一套东西**：

**上游的形态**（Shadertoy 系经典等离子，调参面是「shader 内部参数」）：

```
u_time, u_scale, u_frequency, u_amplitude,
u_color1, u_color2, u_color3,      // shader 自带调色板
u_iterations, u_warpStrength
```

**CoreDesign 自研的形态**（调参面是「设计系统概念」）：

```swift
/// 程序化等离子背景。
///
/// ⚠️ 本类型**不持有任何颜色**——渲染色全部来自调用方的 `.tint` 与第 3 层语义 token，
/// 与 `ProgressView` / `Label` 的 `.core` style 走同一条 `TintShapeStyle` 通路
/// （见 CLAUDE.md《系统控件 `.core` style》：强调色一律经 `.tint` 取，不得写死 `Color.accent`）。
public struct Plasma: View {

    /// 视觉密度。⚠️ 不是上游的 `u_frequency` / `u_iterations` 两个独立旋钮——
    /// 本仓的调参惯例是**单个语义枚举**（对照 `ButtonRoleStyleRole` 是 role 调色板的唯一来源）。
    public enum Density: Sendable { case subtle, regular, dense }

    /// 运动速度。⚠️ 同理不暴露 `u_time` 缩放，改为语义档位。
    public enum Motion: Sendable { case calm, regular, lively }

    private let density: Density
    private let motion: Motion

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(density: Density = .regular, motion: Motion = .regular) {
        self.density = density
        self.motion = motion
    }

    public var body: some View {
        // ⚠️ Reduce Motion 下冻结在某一帧而非停止渲染——保留视觉、去掉运动（FR-12）。
        // ⚠️ 颜色经 .tint 通路取，`.metal` 侧零硬编码色（FR-8）。
        …
    }
}
```

**差异化在此可核**：
- **零 Bool 参数**（J-1）—— 上游那种 `showX: Bool` 在本仓要么改语义枚举、要么抬棘轮基线；
- **零颜色入参** —— 上游传 3 个色，我们一个都不传，全走 `.tint`；
- **参数从 9 个 uniform 收敛成 2 个语义枚举** —— 这不是"改个名"，是**调参面的重新设计**，
  且理由来自本仓既有惯例（`ButtonRoleStyleRole` 是 role 调色板唯一来源、`.core` style 走
  `.tint` 通路），不是为规避而临时发明；
- **a11y 从第一行就在** —— 上游没有这个概念。

⇒ **下一个 reviewer 可以用指认 paper 的同一套方法反查我们**：拿我们的形参列表去比对任何
上游的 uniform 列表，**对不上**。这就是「可验证的差异化」的意思。

### 逐件适用性

| 可走自研（效果类别） | 不走自研（具体设计） |
|---|---|
| `Plasma` `Starfield` `Dots` `LiquidChrome` `FractalClouds` `InkSmoke` `Glass` `GlassLogo` | `ChromaticGlass` `Foil` `Glitter` `IntenseBling` `PolishedAluminum`（ShaderKit 5，观感即设计 + GPL-3.0 视觉参考）· `AnimatedLoop`（18 参数 hand-tuned 组合） |

⚠️ `LiquidMetal` 待 §C 的追溯结论出来再定档。

⚠️⚠️ **本表左列是「**效果类别**层面可以自研」，不是「实现出来就是自研的」**
——两者被 #261 的五轮实证分开了。**实际落地后的档位以 #261 为准，全部下调：**

| 件 | 本表原判 | #261 落地后的实际档位 |
|---|---|---|
| `InkSmoke` | 可走自研 | **不是自研**——域扭曲级联派生自 iq，hash 层出处见上表 |
| `FractalClouds` | 可走自研 | **不是自研**——同上（单级 warp，指纹较弱）|
| `LiquidChrome` | 可走自研 | 「自研」射程**仅限组合与参数化**，不含共享原语 |
| `Plasma` | 可走自研 | **撤回「非移植」**——四相正弦是 Vandevenne 的公式 |
| `Starfield` | 可走自研 | **撤回「非移植」**——网格 hash + step 熄灭 + smoothstep 辉光 + sin 相位是网格星空模板的逐项形态（`id`/`gv` 只是改名成 `cell`/`local`）|
| `Dots`（`DotGrid`）| 可走自研 | **撤回「非移植」**——网格 + 抗锯齿圆盘是公开形态 |
| `Glass`（`RefractiveGlass`）| 可走自研 | **撤回「自研的 Metal 折射」**——主体零署名，见上表 |
| `GlassLogo`（**落地名 `GlassSymbol`**）| 可走自研 | ⚠️ **上一版本行缺失**（第 2 轮终审 C-8）：对账表只有 7 行而 B-1 首批是 **8 个**。一个已落地组件在这张表上留白 = **本表自己制造了一次「空白等于默认原创」**，而那正是本表亲笔立的规矩。⚠️ 且 `GlassSymbol.swift` 里**零 provenance 引用** ⇒ 待补。改名 `GlassLogo → GlassSymbol` 亦未记录，导致交叉引用 grep 不到 |

⚠️ **这不是"当初判错了"**：本表判的是**效果类别可不可以自研**（那个判断仍然成立），
而实现出来的东西是否**事实上**是自研的，只能在**函数体写完之后**用第六条轴查。
⇒ **本表的左列是准入，不是结论**——落地件的档位由 provenance 复查决定，
且**默认档位是「待追溯」而不是「自研」**。


## §B 追到 `paper-design/shaders` 的 11 个 —— 9 个正向裁定 Apache-2.0 + 2 个待追溯

⚠️ **标题里的 11 是「追到 paper 的件数」，不是「Apache-2.0 档的件数」**——本节内
`NeuroNoise`（上游是无许可推文，paper 的再许可断言无法独立核实）与 `GrainGradient`
（参数仅部分匹配、匹配未确认）**均为 `待追溯`**，Apache-2.0 档实为 **9**。
⇒ 与《统一裁定表》《汇总与闸②判定》的 9 逐档一致。

上游：**[paper-design/shaders](https://github.com/paper-design/shaders)，Apache-2.0，
3414 stars，带 `LICENSE` 与 `NOTICE`**（一手核，GitHub API）。

| # | shader | paper 对应文件 | 匹配依据 | 核验者 |
|---|---|---|---|---|
| 8 | `Voronoi` | `voronoi.ts` | 描述句**近逐字** + 参数集全对应 + `randomGB`↔`textureRandomizerGB` | **本人一手** |
| 9 | `NeuroNoise` | `neuro-noise.ts` | 描述句**逐字** + `brightness/contrast/colorFront/colorMid/colorBack` | **本人一手**（⚠️ **匹配确认、许可未确认** ⇒ 裁定 `待追溯`，不在 Apache-2.0 档） |
| 10 | `Swirl` | `swirl.ts` | `bandCount/twist/center/proportion/softness/noise` | 终审 reviewer |
| 11 | `SimplexNoise` | `simplex-noise.ts` | `stepsPerColor/softness/10 colors`；双层 simplex 叠加 | 终审 reviewer |
| 12 | `Water` | `water.ts` | `highlights/layering/edges/waves/caustic/size/colorBack/colorHighlight` | 终审 reviewer |
| 13 | `ColorPanels` | `color-panels.ts` | `density/angle1/angle2/length/edges/blur` | 终审 reviewer |
| 14 | `DotOrbit` | `dot-orbit.ts` | `size/sizeRange/spreading/stepsPerColor` | 终审 reviewer |
| 15 | `SmokeRing` | `smoke-ring.ts` | `thickness/radius/innerShape/noiseScale/noiseIterations/colorBack` | 终审 reviewer |
| 16 | `Metaballs` | `metaballs.ts` | `count/size/colors` | 终审 reviewer |
| 17 | `Halftone` | `halftone-dots.ts` + `halftone-cmyk.ts` | 两入口一一对应；`classic/gooey/holes/soft`、`originalColors`、`colorC/M/Y/K`。**ShipSwift 自己在 `SWHalftone.metal:350` 写着 "simplified port"** | 终审 reviewer |
| 18 | `GrainGradient` | `grain-gradient.ts` | 参数**部分**匹配 | 终审 reviewer（**存疑**） |

**裁定：#8、#10–#17 共 9 个为 `已追到兼容许可 · Apache-2.0`；#9 `NeuroNoise` 与
#18 `GrainGradient` 为 `待追溯`**——前者的上游是一条**无任何许可声明的推文**，
paper 以 Apache-2.0 再许可是 paper 的断言、我们无法独立核实（见下方《paper 之上还有一层》
与《汇总与闸②判定》的第 5 轮终审 I4）；后者参数仅部分匹配、匹配未确认。
⚠️ **上一版这里写「#8–17」（10 个）**，与《统一裁定表》《汇总与闸②判定》的 9 打架
（PR #259 review round-2 指出）——**以统一裁定表为准，本行已改**。

### 落地义务（与 MIT 档不同，别混）

1. 转载 paper 的 **LICENSE 全文**；
2. 转载其 **`NOTICE`**：`Powered by Paper Shaders: https://shaders.paper.design`；
3. **标注修改**（§4(b)）——我们改了参数化与色彩层，属"修改"；
4. 逐 shader 的 `.metal` 文件头注明 paper 的对应 `.ts` 路径。

### ⚠️ paper 之上还有一层，落地前必须直读确认

- `voronoi.ts:14`：`Original algorithm: https://www.shadertoy.com/view/ldl3W8`（iq）。
  ⚠️ 该 shader 的许可**变过**：2013 年第三方拷贝头是 **CC BY-NC-SA 3.0**，较新拷贝头是
  **MIT**。**落地前须直读现页面确认。** ⚠️ 这也是"Shadertoy 许可看头部、且会变"的活例。
- `neuro-noise.ts:33`：`Original algorithm: x.com/zozuar/status/1625182758745128981`
  —— **一条推文，无任何许可声明**（默认保留所有权利）。paper 以 Apache-2.0 再许可
  **是 paper 的断言**，我们无法独立核实 ⇒ **这一条须单独评估是否落地**。

---

## §C 仍未追到的 10 个

⚠️ **第 1 版把这些判为 clean-room 且未具名参考实现 ⇒ 本版按新规则降级。**

| # | shader | 第 1 版 | 本版 | 理由 |
|---|---|---|---|---|
| 19 | `FractalClouds` | clean-room | **`待追溯`** | ⚠️ **本轮再降一级**：参考实现候选 [ashima](https://github.com/ashima/webgl-noise) / [stegu](https://github.com/stegu/webgl-noise) / [glsl-noise](https://github.com/hughsk/glsl-noise) 虽均 **MIT**，但只覆盖 FBM 底座，**domain-warp 与调色的组合本就未追到出处** ⇒ 依据不成立；且 `clean-room 重写` 档已随本 PR 删除，本行不得再用该取值 |
| 20 | `InkSmoke` | clean-room | **`待追溯`** | 同上。⚠️ #261 实证：域扭曲的 `q`/`r` 三级级联派生自 **iq《Domain Warping》**，已撤回原创声称 |
| 21 | `Plasma` | clean-room（"经典 demoscene"） | **`待追溯`** | 无具名参考实现 |
| 22 | `Starfield` | clean-room（"标准做法"） | **`待追溯`** | 无具名参考实现 |
| 23 | `Dots` | clean-room（"网格 + 三角函数"） | **`待追溯`** | ⚠️ paper 有 `dot-grid.ts` 但描述不同（静态几何网格 vs ShipSwift 的 5 个 `.metal` 变体）⇒ **不是**匹配 |
| 24 | `Glass` | clean-room（"iq 的 SDF 文章"） | **`待追溯`** | iq 的 distfunctions2d / warp 页面**无许可声明**——"iq 文章代码是 MIT"是需要证的。⚠️ paper 的 `fluted-glass.ts` 是肋纹图像滤镜，与此 SDF 折射玻璃**不是**同一件 |
| 25 | `GlassLogo` | clean-room | **`待追溯`** | 同上 |
| 26 | `AnimatedLoop` | clean-room（"调度器，无独立算法"） | **`待追溯`** | ⚠️ **第 1 版是事实误读**：`SWAnimatedLoop.metal:5-21` 是四个 **hand-tuned styles**，共享 per-line phase ramp + RGB 通道分离 + 加法合成，仅距离度量与 pattern 项不同；"dispatch by name" 指在**这四个自有入口**间选，不是分派到别的效果。18 个参数，是**独立作品** |
| 27 | `LiquidChrome` | **不落地** | **`待追溯`** | ⚠️ **准则统一**：`SWLiquidChrome.metal:7-9` 自述 "Three sequential value-noise samples are domain-warped"，与 InkSmoke / FractalClouds **同一算法类别**。第 1 版用"观感特征性强"判它不落地、却用"算法类别"给 InkSmoke 放行，是**双标** |
| 28 | `LiquidMetal` | **不落地** | **`待追溯`** | ⚠️ 线索未穷尽：`SWLiquidMetal.metal:26-28` 用 Ashima simplex 常量；paper 有 `liquid-metal.ts` 但描述与参数集**不同**（paper 的是"应用到上传 logo"）⇒ **线索，非匹配**，须追 |

⚠️ **`待追溯` 不等于"判不了"**——它是「**尚未用有效方法追过**」。§A/§B 的经验表明，
用签名 + 散文比对追一轮的成本是**小时级**，而错判的代价是**署名义务落空**。

---

## 统一裁定表（28 行 · AC 固定 5 列）

⚠️ **本节是 #249 AC 逐字指定的表结构**——`shader | 原始出处 | 许可 | 证据链接 | 裁定`，
**一行一个 shader，28 行无空裁定**，行序即上文的 #1–#28。
上面的 §A / §B / §C 与各裁断段落是**同一批结论的论证与备注**，不是另一张表；
**两处冲突时以本表为准，并回改论证段落**。

⚠️ **与 AC 的一处显式偏离，必须连同本表一起读**：AC 写「裁定取值仅三种
（`已追到兼容许可` / `clean-room 重写` / `不落地`）」，而本表实际取值为
`已追到兼容许可 · MIT` / `已追到兼容许可 · Apache-2.0` / `自研实现` / `待追溯` / `不落地`
（定义见《裁定方法：正向裁定，不证否定》）。理由本文已逐条写明，此处只作索引：
① **Apache-2.0 是 AC 遗漏的档位**，义务与 MIT 不同（LICENSE + `NOTICE` + 修改标注）；
② **`clean-room 重写` 已废除**（见《第三条出路：自研实现》与《汇总与闸②判定》）；
③ **`待追溯` 不能折进 `不落地`**——前者是「尚未用有效方法追过」，后者是「追过且追不到」，
把前者报成后者等于把「未查」谎报成「查过且不兼容」。

⚠️⚠️ **关闭 #249 的硬前置（本偏离必须先被批准，不得默认生效）**：本 PR 以 `Closes #249`
关闭 issue，而 issue 的 AC 逐字写的仍是「裁定取值仅三种」。**「文档解释了偏离」不等于
「AC 被满足」**——照现状合入会留下一个「已关闭但未满足 AC」的记录。
⇒ **合入本 PR / 关闭 #249 之前，下列二者必须至少做到一条，并在 PR 里指明做的是哪条**：

- [ ] **改 AC**：把 `.claude/epics/shipswift-foundation/249.md` 与 GitHub issue #249 的
      「裁定取值仅三种」同步为本表实际的五种取值；**或**
- [ ] **显式批准偏离**：在 #249 的关闭评论里逐字写明「AC 的三取值域已被本表的五取值域
      取代，批准该偏离」，并附上文 ①②③ 的理由索引。

**两条都没做 ⇒ 不得关闭 #249**（可先合 PR、把 `Closes` 改为 `Refs`，留 issue 开着）。
⚠️ 本条款在 `.claude/epics/shipswift-foundation/249.md` 的 AC 处有反向指针，两边不得单改。

⚠️ **`—` 表示本表未持有该字段的可核内容**（不是「没有出处」，是「尚未追到 / 尚未核」）
⇒ 按定义即 `待追溯`，**不得据现状落地**。凡填 `—` 的行，落地前必须先按
《方法论教训》的签名 + 散文比对追一轮。

| shader | 原始出处 | 许可 | 证据链接 | 裁定 |
|---|---|---|---|---|
| `GlassOrb` | [Inferno](https://github.com/twostraws/Inferno) 的 "Warping Loupe"（Paul Hudson）——**不在 Inferno LICENSE 的移植清单内 ⇒ 推论为其原创，不是断言** | **MIT**（已读 LICENSE 全文） | https://github.com/twostraws/Inferno | **已追到兼容许可 · MIT** |
| `StarNest` | "Star Nest"，Pablo Roman Andrioli（Kali），Shadertoy | **MIT**（作者在源码头声明）。⚠️ **二手证据**：shadertoy 返 403，未直读原页面 ⇒ 人工目视确认是落地 task 的硬 AC | https://www.shadertoy.com/view/XlfGRj | **已追到兼容许可 · MIT** |
| `ChromaticGlass` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `Foil` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `Glitter` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `IntenseBling` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `PolishedAluminum` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `Voronoi` | [paper-design/shaders](https://github.com/paper-design/shaders) 的 `voronoi.ts`；paper 自述 `Original algorithm` 为 iq 的 Shadertoy 作品 | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ iq 原页面许可**变过**（旧拷贝头 CC BY-NC-SA 3.0 / 新拷贝头 MIT）⇒ 落地前须直读现页面 | https://github.com/paper-design/shaders · https://www.shadertoy.com/view/ldl3W8 | **已追到兼容许可 · Apache-2.0** |
| `NeuroNoise` | paper 的 `neuro-noise.ts`；paper 自述 `Original algorithm` 是 **@zozuar 的一条推文，无任何许可声明**（默认保留所有权利） | paper 以 Apache-2.0 再许可**是 paper 的断言，我们无法独立核实** ⇒ 不构成正向裁定 | https://github.com/paper-design/shaders · https://x.com/zozuar/status/1625182758745128981 | **`待追溯`** |
| `Swirl` | paper 的 `swirl.ts`（参数签名逐项对应） | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ **未查「paper 之上还有一层」** | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `SimplexNoise` | paper 的 `simplex-noise.ts`（参数签名逐项对应） | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ **未查「paper 之上还有一层」** | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `Water` | paper 的 `water.ts`（参数签名逐项对应） | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ **未查「paper 之上还有一层」** | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `ColorPanels` | paper 的 `color-panels.ts`（参数签名逐项对应） | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ **未查「paper 之上还有一层」** | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `DotOrbit` | paper 的 `dot-orbit.ts`（参数签名逐项对应） | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ **未查「paper 之上还有一层」** | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `SmokeRing` | paper 的 `smoke-ring.ts`（参数签名逐项对应） | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ **未查「paper 之上还有一层」** | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `Metaballs` | paper 的 `metaballs.ts`（参数签名逐项对应） | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ **未查「paper 之上还有一层」** | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `Halftone` | paper 的 `halftone-dots.ts` + `halftone-cmyk.ts`（两入口一一对应；**ShipSwift 自己在 `SWHalftone.metal:350` 写着 "simplified port"**） | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）。⚠️ **未查「paper 之上还有一层」** | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `GrainGradient` | paper 的 `grain-gradient.ts`——**参数仅部分匹配，匹配未确认** | —（paper 为 Apache-2.0，但匹配未确认 ⇒ 不得据此定档） | https://github.com/paper-design/shaders | **`待追溯`** |
| `FractalClouds` | **—**（未追到）；FBM 底座可对照 ashima / stegu / glsl-noise，但 **domain-warp 与调色的组合未追到出处** | 参考实现 **MIT**；本体 — | https://github.com/ashima/webgl-noise · https://github.com/stegu/webgl-noise · https://github.com/hughsk/glsl-noise | **`待追溯`** |
| `InkSmoke` | **—**（未追到）；#261 实证：域扭曲的 `q`/`r` 三级级联派生自 **iq《Domain Warping》** | —（iq 页面无许可声明） | — | **`待追溯`** |
| `Plasma` | **—**（未追到）；#261 实证：四相正弦叠加是 **Lode Vandevenne《Lode's Computer Graphics Tutorial — Plasma》** 的公式 | —（本表未核该页面许可） | — | **`待追溯`** |
| `Starfield` | **—**（未追到）；#261 实证：网格 hash + step 熄灭 + smoothstep 辉光 + sin 相位，是网格星空模板的逐项形态 | — | — | **`待追溯`** |
| `Dots`（`DotGrid`） | **—**（未追到）；paper 有 `dot-grid.ts` 但描述不同（静态几何网格 vs ShipSwift 的 5 个 `.metal` 变体）⇒ **不是**匹配 | — | — | **`待追溯`** |
| `Glass`（`RefractiveGlass`） | **—**（未追到）；第 1 版曾引 iq 的 SDF 文章；#261 实证主体为 2025 年 `layerEffect` "liquid glass" 一族的通行形态 | —（iq distfunctions2d / warp 页面**无许可声明**） | — | **`待追溯`**（⚠️ 其主体原语 `coreDesignRefractiveGlass` 经 #261 复查为**强指纹**档 ⇒ **阻断 epic→main**，须在 B-4 前追完） |
| `GlassLogo`（落地名 `GlassSymbol`） | **—**（未追到）；同 `Glass`；⚠️ `GlassSymbol.swift` 里**零 provenance 引用**，改名亦未记录 | — | — | **`待追溯`** |
| `AnimatedLoop` | **—**（未追到）；`SWAnimatedLoop.metal:5-21` 是四个 **hand-tuned styles**、18 个参数，属**独立作品**（第 1 版"调度器无独立算法"是事实误读） | — | — | **`待追溯`** |
| `LiquidChrome` | **—**（未追到）；`SWLiquidChrome.metal:7-9` 自述 "Three sequential value-noise samples are domain-warped" | — | — | **`待追溯`** |
| `LiquidMetal` | **—**（未追到）；`SWLiquidMetal.metal:26-28` 用 **Ashima simplex 常量**（线索，非匹配）；paper 有 `liquid-metal.ts` 但描述与参数集**不同** | — | https://github.com/ashima/webgl-noise | **`待追溯`** |

**计数校验**：2（MIT）+ 9（Apache-2.0）+ 17（待追溯）+ 0（自研实现）+ 0（不落地）= **28** ✅
——与下方《汇总与闸②判定》逐档一致。

**逐行详情与论证**：§A（#1–#7）· §B（#8–#18）· §C（#19–#28）·
共享原语层（跨 shader）见《共享原语的逐项出处》。

---

## 汇总与闸②判定

| 裁定 | 数量 | 明细 |
|---|---|---|
| **已追到兼容许可 · MIT** | **2** | GlassOrb、StarNest |
| **已追到兼容许可 · Apache-2.0** | **9** | §B 的 #8–17，**减 `NeuroNoise`**（上游是无许可推文，paper 的再许可断言无法独立核实 ⇒ 不构成正向裁定）|
| ~~**clean-room 重写**~~ | ~~2~~ → **0** | ⚠️ **该档已随本 PR 删除**（第 5 轮终审 C1）：`FractalClouds` / `InkSmoke` 的依据（ashima / stegu / glsl-noise 均 MIT）**已被证明本就不成立**，且《裁定方法：正向裁定，不证否定》自己的规则「`clean-room` 行必须给出 URL + 已核实的许可，否则一律降级为 `待追溯`」本就该触发。两件改判 `待追溯`。**该档亦不在裁定取值表里** ⇒ 正文任何位置都不得再作为裁定值出现（⚠️ 上一版只在本行写了改判，§C 的 #19 / #20 两行仍留着这个已废除的取值 —— **PR #259 review round-1 指出，本轮已同步改掉**）|
| **待追溯** | **17** | ShaderKit 5 + GrainGradient + §C 的 8 个 + FractalClouds / InkSmoke（本轮改判）+ NeuroNoise（下条）|
| **不落地** | **0** | ⚠️ 第 1 版判的 2 个已改判 `待追溯`——原理由与 §C 其余项双标 |
| **自研实现** | **0** | ⚠️ 显式写 0——《逐件适用性》左列有 8 个名字，但那是**准入不是结论**；实际落地件经第六条轴复查**无一维持自研** |
| 合计 | **28** | 2 + 9 + 0 + 17 + 0 = 28 ✅ |

### 闸②判定：**通过**

⚠️ **`NeuroNoise` 从 Apache-2.0 档移出**（第 5 轮终审 I4）：本表 §「paper 之上还有一层」
自己写着它的上游是**一条无任何许可声明的推文**（默认保留所有权利），
「paper 以 Apache-2.0 再许可**是 paper 的断言，我们无法独立核实**」
⇒ 按《裁定方法：正向裁定，不证否定》的「正向裁定」定义，**一个无法独立核实的第三方再许可断言不是正向裁定**。
⇒ Apache-2.0 档 **10 → 9**。这正是第 1 版「判太松」在更正之后的原样复现。

- **现可落地数 = 2 + 9 = 11**（⚠️ 上一版写 14，把两件 clean-room 与 NeuroNoise 都算进去了）
- ⚠️ **11 条中「无条件可落地」为 0**：GlassOrb 建立在**推论**上（《A. 有上游标注的 7 个》的 `GlassOrb` 行明写不是断言）、
  StarNest 是二手证据且有人工核验的硬 AC、Voronoi 须直读一个**许可变过**的页面、
  §B 的 10 条里**只有 2 条**查过「paper 之上还有一层」（另外 8 条未查）
  ⇒ 每条都各带一项**落地前必做的核验**。
- **`N_B` = 5**（由 #248 spike 按「固定成本 8–12h ÷ 边际 2.0–2.5h/shader」反推）
  ⚠️ #248 初稿曾给 10（按 10–16h ÷ 1.5h），该推导有分子分母重叠等三处问题，**已作废**
- **11 ≥ 5 ⇒ 闸②仍然通过**，`shipswift-shaders`（#243）可启动
- ⚠️ **但 `N_B` = 5 的分母被本表自己作废了**（第 5 轮终审 I6）：#248 spike 的
  成本推导段落逐字写着「边际成本是从『难件 + 逐 shader 文档』推的、**不是**从
  clean-room 推的 ⇒ **边际成本须按 clean-room 再核一次**」，而本表又把成本故事
  改成「移植比 clean-room 便宜」+「17 个待追溯每个要先追一轮」——**两个方向相反**。
  ⇒ **重开触发器**：B-2 / B-3 分解时按「移植 + 署名」重估 `N_B`；
  **若重估后 `N_B` > 可落地数，闸②须重开**。本判定按现有 `N_B` = 5 做。
- ⚠️⚠️ **分子侧也必须有触发器**（第 2 轮终审 C-7）：上一版只在分母挂了触发器，
  而本表的兜底逐字写着「追溯失败 ⇒ **不落地**」——**分子会掉**，且 `NeuroNoise`
  已经实际掉过一次（10 → 9）。
  ⇒ **§A / §B 任一落地前核验失败 ⇒ 可落地数 −1；降至 < `N_B` 时闸②须重开。**
- ⚠️ **最坏地板**：把上面列的核验**全部**判失败（GlassOrb 的推论被推翻、StarNest
  人工目视不符、Voronoi 的页面回到 CC BY-NC-SA、§B 未核的 8 条全不兼容）
  ⇒ **地板 = 1**，**低于 `N_B` = 5**。
  ⇒ **闸②当前通过，是建立在「这些核验多数会过」这个预期上的**——本表如实写下，
  而不是让读者以为 11 是硬数。
- ⚠️ **口径**：本表的「可落地」= **已正向裁定为兼容许可、落地前尚有具体核验项**，
  **不等于无条件可落地**（后者当前为 **0**）。闸②谓词用的是前者。
- **可落地 11 的名单**（本表此前从未列出，读者得自己做减法）：
  `GlassOrb`、`StarNest`（§A #1–2）+ `Voronoi`、`Swirl`、`SimplexNoise`、`Water`、
  `ColorPanels`、`DotOrbit`、`SmokeRing`、`Metaballs`、`Halftone`（§B #8–17 减 `NeuroNoise`）。

### ⚠️ 与第 1 版相比，成本方向**反转了**

第 1 版说「24/26 走 clean-room，比移植贵得多，B-2/B-3 须上调工时」。**本版相反**：

- **9/11 是"带署名的移植"，不是 clean-room**（⚠️ 上一版写 12/14，是 `NeuroNoise` 降档与两件 clean-room 改判之前的数） —— 移植**比** clean-room **便宜**；
- 但多了 **Apache-2.0 的署名义务**（LICENSE + NOTICE + 修改标注）；
- 另有 **17 个 `待追溯`**，每个须先追一轮（小时级）才能定档（⚠️ 上一版写 14——那是
  `FractalClouds` / `InkSmoke` 改判与 `NeuroNoise` 降档**之前**的数，与《统一裁定表》
  《汇总与闸②判定》的 17 打架，PR #259 review round-2 一并改齐）。

⇒ **B-2 / B-3 分解时按「移植 + 署名」重估，不是按 clean-room。**

---

## ⚠️ #261 的落地反馈（本表的第一次实战复查）

`shipswift-shaders` 的 B-1 首批 8 个 shader 落地时（PR #261）跑了**五轮**署名鉴定，
**每一轮我都声称"这次全了"，每一轮都还有**。给本表留下三条可操作的结论：

1. **五轴框架必须加第六条（函数体）** —— 见上文，四次命中全在函数体，而五轴全部满足。
2. **默认档位是「待追溯」不是「自研」** —— 落地件的档位由函数体复查决定，
   本表的「可走自研」左列是**准入**不是**结论**。
3. **逐常量 grep 必须前置** —— 它比五轴便宜一个数量级，四次命中全部来自这一步，
   而第 1 版把它放在最后。

⚠️ **本表与 #261 的引用关系是双向的**：#261 共 **5 处**引用本文件（`CoreDesignShaders.metal` ×3、`Plasma.swift` ×1、`Starfield.swift` ×1，即 **1 个 metal + 2 个 Swift 文件**）
（⚠️ 上一版写「三个 Swift 文件共四处」，两个数都错——而本表的立身之本正是「逐常量 grep 比五轴便宜一个数量级」，这一段却是没 grep 就写下的，第 2 轮终审 I-b），而本文件的《共享原语的逐项出处》是 #261 写出来的。⇒ **#261 不得先于本 PR 合入**
（该前置已写在 #261 的描述顶部）。

## ⚠️ #261 合入前必须同步改口径的代码注释（第 2 轮终审 C-6）

`shaders-plasma:Sources/CoreDesignShaders/CoreDesignShaders.metal` 的 `fbm` 注释
逐字写着「与 **The Book of Shaders 第 13 章**…**逐行同构**」。
本表已撤回该说法（见《The Book of Shaders 的许可实查》），但**合入顺序是本 PR 先、
#261 后** ⇒ 按现状 #261 会带着一份**对 `All rights reserved` 来源的书面逐行同构自认**
发出去——正是 `ACKNOWLEDGEMENTS.md` 自己写的「一份没有辩护的书面自认，
比它取代的沉默更糟」。
⚠️ 同一份注释还用**同一事实**（"唯一差异是除 total"）得出了**相反结论**
——两份文档对同一事实的判读对立，无人调和。

- [ ] **#261 合入的硬前置**：`fbm` 注释改口径（出处指**算法谱系**，删该书引用）
- [ ] 顺带：`hash22` 的第四个素数 `50331653` **不在两份文档的原语表里**
      ——本表刚宣布「逐常量 grep 无条件适用」，而一个已知落在具名来源之外的常数
      **就已经漏在表外**。补进原语表。

## 需要回改的文档

- `.claude/epics/shipswift-shaders/epic.md`：
  - AD-G 补本表结论；`N_B` 填 **5**；SC 的「可落地数 ≥ `N_B`」标记为**已满足（11 ≥ 5）**（⚠️ 上一版写 14 ≥ 5——那个 14 已被撤回，而本行是写进 epic SC 的指令，会把撤回的数字固化进闸②验收记录）
  - **B-2 / B-3 的工时按「移植 + 署名」重估**（⚠️ **不是** clean-room——第 1 版结论已反转）
  - 新增：**17 个 `待追溯` 件必须先追一轮**才能进 B-2 / B-3 的任务清单（⚠️ 上一版写 14，
    同上，已按《统一裁定表》改齐）
  - 删除「`LiquidChrome` / `LiquidMetal` 不在范围内」——已改判 `待追溯`
- `.claude/epics/shipswift-foundation/epic.md`：A0-6 的 SC 勾选
- `ACKNOWLEDGEMENTS.md`：**预留 Apache-2.0 + NOTICE 段**（paper-design/shaders）

## 证据强度声明

- **一手核实**：paper-design/shaders 的许可与 NOTICE（GitHub API）· Voronoi 与 NeuroNoise
  的描述句逐字比对（读 paper 源码）· Inferno LICENSE 全文 · ShaderKit LICENSE ·
  webgl-noise / glsl-noise 许可
  - ⚠️ **上一版这一行还列着「Shadertoy 默认许可」——已移到「二手」**（PR #259 review
    round-4）：本表从未直读 Shadertoy 官方条款，唯一依据是一条 Wikipedia 概述。
- **采信终审 reviewer 的一手比对**：§B 表中标注"终审 reviewer"的 9 行（参数签名比对）
- **二手**：StarNest 的 MIT（五个独立来源逐字一致，但未直读 shadertoy 原页面）·
  **Shadertoy 的默认许可 CC BY-NC-SA 3.0**（仅据 Wikipedia 概述，**未核官方条款原文**，
  见《为什么必须做这件事》）
- **未证**：§C 全部 **10** 个 `待追溯` 的实际出处（含本轮由 clean-room 改判的
  `FractalClouds` / `InkSmoke`）—— 故判 `待追溯` 而非 clean-room
  （⚠️ 上一版写 8，是那两件改判前的数）

⚠️ **第 1 版在此处写「本表没有声称知道那 21 个来自哪里，故日后有人追到也不受影响」——
该辩护随本版作废**：它建立在"追不到"的前提上，而那个前提被一小时的比对推翻了。
