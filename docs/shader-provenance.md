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

⚠️⚠️ **第二个档位缺口：`CC-BY-4.0`（#281 实查发现，形态与当年漏掉 Apache-2.0 完全相同）。**
`cd::wangHash` 逐字符复制的那一份写法出自 **Nathan Reed 的博客，而该站页脚逐字是
「© 2007–2025 by Nathan Reed. Licensed CC-BY-4.0.」**（见《共享原语的逐项出处》该行）。
`CC-BY-4.0` **既不在 `已追到兼容许可 · MIT` 那一行列举的 MIT / BSD / PD / CC0 里，
也不是 Apache-2.0** ——它允许再分发（与本仓 MIT 分发兼容），但**署名是许可条件而非礼节**。
⇒ **本表暂不新设第六个取值**（新设取值要动 28 行与三处计数，属独立决策）；
本版的处理是：该行**记在 `已追到兼容许可` 这一族里**，并在《共享原语的逐项出处》
逐字写明许可名与义务。⚠️ **下一次有人动本取值表时必须一并定案**——把它一直挂在
"族里但没有自己的行"上，正是第 1 版对 Apache-2.0 做过的事。

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

⚠️⚠️ **#281 之后，本行的判据句必须这样读（否则会被读反）**：参照物 `InkSmoke` 的 q/r 级联
**现在已经追完、且许可兼容（iq，MIT）**，因而**不再阻断**——但它的**指纹依然强**
（三级级联 + 变量名逐字保留）。⇒ **判据句量的是「指纹强度」这把尺，不是「当前是否阻断」。**
拿"q/r 现在不阻断了"去论证"没有东西够得上强档"是**偷换了坐标系**。
⚠️ 同理，**强档 ≠ 不能用**：强档的义务是「**追完前**不得合入 `main`」，
追完之后结论有两种——许可兼容 ⇒ **署名后可用**（q/r 级联走的就是这条）；
许可不兼容 ⇒ **`不落地`**（`Starfield` 走的是这条）。上一版把「指纹强」与「不能用」
混成了一件事，#281 把它们拆开。

⚠️ **判定人与争议处置（上一版零指定，正是「⚠️ 确有需要时」型条款的复刻）**：
分档由 provenance 表 owner 判、**merge 前评审复核**；
**分档有争议时一律按强档处理**（向保守侧倒）⇒ 本条由此可证伪。
⚠️ **每一行的分档必须引用它所依据的判据原文**，不得只写结论。

**当前分档（#281 重写）。** ⚠️ 上一版这张表只有 **5 行**，而《共享原语的逐项出处》
里判 `待追溯` 的有 **7 项**、#261 落地的 shader **本体**有 **8 个**且一个都没进表
——按本表自己的「分档有争议时一律按强档处理」，**那 10 个漏项当时全部默认落在强档，
即全部阻断 `epic → main`**。本 task 的三件事：① 把 4 个 `TBD` 填实；
② 把漏项补全并逐行引判据原文；③ 收敛两表打架。

⚠️ **本表上一版把「承接」与「分档理由」挤在同一列**，于是 `ramp3` / `edgeWidth` 两行
写成占位符「#249 后继 issue / 同上」、另两行干脆写成理由，**与上表 ⓑ「编号必须填」直接
打架**（PR #259 review round-4）。已拆成两列。

⚠️⚠️ **AC「零 `TBD`」的可机器判形态（写明，否则下一个人会 grep 出一堆假阳性）**：
判据是「**表 A / 表 B 的『承接 issue（ⓑ）』列里没有 `TBD`**」，
**不是**「全文没有 `TBD` 这四个字母」——ⓑ 的规则原文本身要写出 `TBD` 才能说清规则。
⇒ **可判命令**（只看**表格行**，把散文里讲规则的命中排除掉）：
```
grep -n '^| ' docs/shader-provenance.md | grep TBD
```
**期望输出恰为 1 行**——上面那张判据表里 ⓑ 的**规则原文**那一行（规则要说清
「允许且只允许临时写 TBD」，就必须写出这四个字母）。**没有第 2 行即通过。**

⚠️ 之所以把判据和期望输出一起写死在这里：AC 逐字是「零 `TBD`（grep 可判）」，
而**朴素的 `grep TBD` 会命中若干处、全是假阳性**。不写清判据，下一个人要么误判
「AC 没满足」，要么反过来**为了让 grep 干净而去删规则原文**——后者更糟。

#### 表 A · 共享原语（覆盖《共享原语的逐项出处》**全部 7 个 `待追溯` 项** + 1 个已收敛项）

| 项 | 档 | 承接 issue（ⓑ） | 分档理由（须引上表判据原文） |
|---|---|---|---|
| `ramp3` | 低指纹 | **#281** | ⚠️ 上一版**未引判据原文**，且自己写着「须在承接 issue 里补齐 ①②③」——**本 task 补齐**：<br>**①（复制量小）✓** 3 行；<br>**②（常数/结构是功能性的）✓** 两段 `smoothstep` 的分界点 `0.0/0.5` 与 `0.5/1.0` 由「三档」这个需求**唯一确定**，`step(0.5, v)` 只是选边，换一组接缝就不连续 ⇒ 是功能性的，不是审美选择；<br>**③（来源为无许可的公开发表）⚠️ 不成立，但不成立的方向是"更弱"不是"更强"**：#281 又追了一轮（四种 code-search 措辞 + 两次 web search + 查 LYGIA）**仍未指认到任何上游** ⇒ 根本没有"来源"可谈。<br>⇒ 判据 ①② 成立、③ 无对象 ⇒ **低指纹成立**。⚠️ 上一版说的「补齐前随时可被翻成强档」**已解除**——但「指认不到 ≠ 原创」照旧，ⓐ 与 ⓒ 继续生效 |
| `edgeWidth` | 低指纹 | **#281** | ⚠️ 上一版自己写着「①② 系本表认定而非引自他处，须在承接 issue 里复核」——**本 task 复核，结论是 ①② 站得住，而 ③ 引错了来源**：<br>**①（复制量小）✓** 1 行 `max(fwidth(x), 1e-4)`；<br>**②（功能性）✓** `fwidth` 是内建函数，把它夹到 0 以上是为了躲 `smoothstep(x-0, x+0, ·)` 的 0/0 → NaN（本文件注释里有实证），无表达余地（merger）；<br>**③ ⚠️ 改述**：上一版引的「iq 的 **distance-AA** 一族」**经实查不成立**——#281 逐页 grep 了 iq 的五篇相关文章，`fwidth` 一次都没出现。⇒ ③ 由「无许可的公开发表」改为「**无可归属上游的通用惯用法**」（一手读到三份互不相关的独立实现）。<br>⇒ **低指纹成立**，且**风险比上一版认定的更低**（连可主张权利的人都没有） |
| `wangHash` | 低指纹 | **#281** | ⚠️⚠️ **上一版的判据 ③「Wang 的页面无许可声明 ✓」——事实错误，#281 实查推翻。** ①（6 行整数运算，复制量小 ✓）与 ②（常数与移位表是功能性的，换一组雪崩性质就坏 ✓）不变；③ **不成立且方向相反**：<br>· Jenkins 逐字「So are the ones on Thomas Wang's page」⇒ Wang/Jenkins 那一份是**公有领域**；<br>· ⚠️ **而本仓复制的是 Reed 那一份**（`seed *= 9` 是 Reed 的改写，Wang/Jenkins 写 `a + (a << 3)`），**Reed 的站点是 `CC-BY-4.0`**。<br>⇒ **不是「无许可」，是「有许可且带署名条件」** ⇒ 本项**离开 `待追溯`，改判 `已追到兼容许可`**（见《共享原语的逐项出处》该行与《裁定方法》的档位缺口注）。<br>⚠️ 「**逐字符一致**」这个事实照旧记着——它现在不只加严 ⓐ，它还是**署名义务的触发点**：CC-BY-4.0 下署名是许可条件，不是礼节 |
| Teschner 素数三元组 | ⚠️ **不适用（本项不是 `待追溯`）** | **#281**（收敛在本 issue 完成） | ⚠️⚠️ **两表打架的收敛（本 task 的第 ④ 件事）。** 打架现状：《共享原语的逐项出处》判「论文里的常数 ⇒ **事实性算法，可落地**」，本表却把它列为 `待追溯（低指纹）`。<br>**收敛结论：以《共享原语的逐项出处》为准——本项不是 `待追溯`，因而不进分档。** 三条理由：<br>**(i) 分档的适用对象是 `待追溯` 项**（本节标题即「已落地件的 `待追溯` 怎么办」）。本项从未在原语表里被判 `待追溯` ⇒ 它进本表本身就是误入。<br>**(ii) 事实与表达**：三个已发表的整数是**事实**，不是表达；#281 一手读了 VMV 2003 的 PDF，§4.1 逐字给出这三个数。事实不承载著作权 ⇒ 没有可分档的「指纹」。<br>**(iii) 两个结论的落地效力本来就一样**（低指纹不阻断 / 可落地不阻断）⇒ 这是**命名与取值域的一致性问题，不是实质分歧**，收敛不改变任何操作后果。<br>⚠️ **本行保留而不删除**：删掉会让下一个人重新发现这处打架、重新推一遍。义务是**学术引用**（已在 `.metal` 与 `ACKNOWLEDGEMENTS.md` 具名），不是许可义务 |
| `roundedBoxSDF` | ⚠️ **不适用（已离开 `待追溯`）** | **#281** | ⚠️ **上一版漏项**：原语表自己写着「待追溯（低指纹）」，本表却没有这一行。<br>**#281 追完后本项已离开 `待追溯`**：出处 = **iq 的 3D `sdRoundBox`（单半径两行式）**，许可 = iq 站点级 **MIT**（`/articles/` 逐字，两次独立一手读取）⇒ **`已追到兼容许可 · MIT`**，不进分档。义务：MIT 通知 + 具名 iq |
| 域扭曲的 `q`/`r` 三级级联 | ⚠️ **不适用（已离开 `待追溯`）** | **#281** | ⚠️⚠️ **上一版漏项，而它正是强档判据的参照物**（强档行逐字：「指纹强度不低于 `InkSmoke` 的 q/r 级联」）——**判据的参照物自己不在表里**，于是"强档"这条线没有任何一端是锚定的。<br>**#281 追完**：出处 = **iq《Domain Warping》**，许可 = iq 站点级 **MIT** ⇒ **`已追到兼容许可 · MIT`**。<br>⚠️⚠️ **连带效果：`InkSmoke` / `FractalClouds` 解除阻断。** 强档的义务是「**追完前**不得合入 `main`」——现在既追到、许可又兼容 ⇒ **义务已兑现**，不是被绕过。义务转为署名：MIT 通知 + 具名 iq。<br>⚠️ 本项的指纹**确实强**（三级级联 + 变量名 `q`/`r` 逐字保留 + iq 自述「那些偏移常量没有特殊含义」⇒ 恰恰是表达而非事实）——**强指纹从来不等于不能用，它等于必须署名**。上一版把这两件事混成了一件 |
| `Plasma` 的四相正弦叠加 | ⚠️ **不适用（已离开 `待追溯`）** | **#281** | ⚠️ **上一版漏项。#281 追完**：出处 = **Lode Vandevenne**，许可 = **BSD-2-Clause**（`lodev.org/cgtutor/legal.html` 把散文与代码分开授权，两次独立一手读取）⇒ 落进 `已追到兼容许可 · MIT` 档（该档定义逐字含 **BSD**）。<br>义务：**BSD 第 1 条要求源码里保留版权通知 + 条件 + 免责声明**——一句「参考自 Lode 的教程」不满足。<br>⚠️ 同时如实记下有利的一半：他那组具体取值（中心 / 除数）**本仓一个都没用** ⇒ 取的是思路层。**通知照给**，成本为零 |
| **`coreDesignRefractiveGlass` 主体** | ⚠️ **强指纹 → 低指纹（改判，须评审复核）** | **#281** | ⚠️⚠️ **上一版判强档的唯一依据是「指纹强度不低于 `InkSmoke` 的 q/r 级联」这句自评，而该自评是在没做追溯的情况下下的。** #281 做了追溯，逐条对照强档判据原文「有可辨识的个人表达：**级联结构 / 变量命名保留 / 审美性的参数组合**」——**三条全部不成立**（无级联；`edgeness`/`rimBand` 追不到任何来源，谈不上"保留"；常量全是功能性的，**逐常量 grep 无物可 grep**）。<br>而 q/r 级联的指纹恰恰是**级联结构 + 变量名逐字保留**——本函数两样都没有 ⇒ 「不低于 q/r 级联」这句话**在事实层面是反的**。<br>⇒ **改判 `待追溯（低指纹）`**：①（可具名的复制只有 `roundedBoxSDF` 那 2 行）②（常量全功能性）③（无可归属上游）。<br>⚠️ **裁定值仍是 `待追溯`，不是「自研实现」**；ⓐⓒ 照旧。逐候选一手比对、遗留缺口与撤回预案见下方专节 |

#### 表 B · #261 已落地的 **8 个 shader 本体**（上一版**一个都没有**）

⚠️ **本表的分档规则（新立，写明以便证伪）**：一个 shader 本体的档 =
**max(它自己借用的结构的档, 它实际调用的原语的档)**。
「实际调用」按判据 3 用 `grep cd::` 取，**不是"我用到的那些"**（第 3 轮的镜像错误就出在这里）。
调用面逐个核过，列在表里。

| 件（落地名） | `grep cd::` 调用面 | 档 | 承接 issue（ⓑ） | 分档理由（引判据原文） |
|---|---|---|---|---|
| `Plasma` | `ramp3` | 低指纹 | **#281** | 自身借用 = 四相正弦 ⇒ **已追到 BSD-2-Clause**（表 A）；调用面只有 `ramp3`（低指纹）⇒ max = **低指纹**。不阻断 |
| **`Starfield`** | `hash21` `hash22` | ⚠️⚠️ **强指纹 ⇒ 已追完 ⇒ 裁定 `不落地`** | **不适用** —— 强档的义务是「追完前不得合入 `main`」；本项**已追完**，结论是许可不兼容 ⇒ 走 `不落地`，不是走承接 issue | ⚠️⚠️ **#281 追到了具名上游，而它的许可不兼容。** 详见下方《`Starfield` 的追溯》专节。判据引强档行「**有可辨识的个人表达：级联结构 / 变量命名保留**」：网格分解 `id`/`gv` → `cell`/`local` 是**改名**（本表已成文「改名不构成独立」），且**同一份 CC BY-NC-SA 源文件的 `Hash21` 曾被本仓逐字符复制**（本文件自己的注释记着 `123.34 / 456.21 / 45.32`）⇒ **接触与复制均已确立**。<br>⇒ ✅ **撤回已执行**（整件删除，见本文《执行记录》）⇒ **不再阻断 `epic → main`** |
| `DotGrid` | `edgeWidth` | 低指纹 | **#281** | 自身借用：#281 追了一轮（paper 的 `dot-grid.ts` 一手读全文 ⇒ **不匹配**：静态、simplex 随机化、polygon SDF；Inferno 的 `LightGrid.metal` ⇒ 不匹配；code search 无候选）⇒ **未指认到上游**。调用面只有 `edgeWidth`（低指纹）。<br>判据：①（可具名复制 = 0 行）②（`sin(length(centred)*12 - time*2)` 的同心波与 AA 圆盘均为功能性构造）③（无可归属上游）⇒ **低指纹**。不阻断 |
| `FractalClouds` | `fbm` `ramp3` | 低指纹 | **#281** | 自身借用 = **单级** warp（`offset` 一层，**无 `q`/`r` 命名、无三级级联**）⇒ 指纹弱于 `InkSmoke`；其所属的 iq domain-warp 一族现已 **MIT**（表 A）。调用面 `fbm`（事实性算法）+ `ramp3`（低指纹）⇒ max = **低指纹**。不阻断 |
| `InkSmoke` | `fbm` `ramp3` | 低指纹 | **#281** | ⚠️ **本件曾是"强档参照物"的宿主**。自身借用 = q/r 三级级联 ⇒ **#281 追完，iq 站点级 MIT**（表 A）⇒ **强档的阻断义务已兑现**，转为署名义务。调用面 `fbm` + `ramp3` 均不阻断 ⇒ max = **低指纹**。<br>⚠️ **不阻断 ≠ 无义务**：`ACKNOWLEDGEMENTS.md` 必须转载 MIT 通知并具名 iq，否则就是拿着兼容许可却不履行它唯一的条件 |
| `LiquidChrome` | `edgeWidth` `fbm` `ramp3` | 低指纹 | **#281** | 自身借用：#281 追了一轮（paper 的 `liquid-metal.ts` 一手读全文 ⇒ **不匹配**，零 fbm、stripe-cascade + `textureGrad`；react-bits 的 `LiquidChrome` 一手读 ⇒ **不匹配**，余弦级联 warp + `1/|sin|`）⇒ **未指认到上游**；⚠️ shadertoy 403，「某个知名 Shadertoy Liquid Chrome」这条线索**未能核实，已丢弃，不作为证据**。调用面三项均不阻断 ⇒ **低指纹**。不阻断 |
| **`RefractiveGlass`**（`Glass`） | `edgeWidth` `roundedBoxSDF` | 低指纹（**由强指纹改判**） | **#281** | 自身借用 = `coreDesignRefractiveGlass` 主体 ⇒ 见表 A 该行（三条强档判据全不成立 ⇒ 改判低指纹）。调用面：`roundedBoxSDF` ⇒ **已追到 iq MIT**；`edgeWidth` ⇒ 低指纹。⇒ max = **低指纹**。<br>⚠️ **本行的改判须在 `epic → main` 的 PR 上由评审显式确认**；不确认则回落 `不落地`（撤回预案见专节） |
| **`GlassSymbol`**（`GlassLogo`） | 经 `.refractiveGlass()` ⇒ `coreDesignRefractiveGlass` | 低指纹（随 `RefractiveGlass`） | **#281** | ⚠️ 本件**没有自己的 shader**——它是 `Image(systemName:)` + 渐变背衬 + `.refractiveGlass(...)` 的组合 ⇒ **档位完全随 `RefractiveGlass`**，`RefractiveGlass` 若回落 `不落地`，本件随之撤回。<br>⚠️ 上一版本件在《#261 落地后的实际档位》对账表里**留白**（第 2 轮终审 C-8），且 `GlassSymbol.swift` 里**零 provenance 引用**、改名 `GlassLogo → GlassSymbol` 亦未记录 ⇒ #281 一并补上（源码注释已加，交叉引用两个名字都写） |

**计数校验**：表 A 8 行（其中 `待追溯` 仍在档的 3 项：`ramp3` / `edgeWidth` /
`coreDesignRefractiveGlass` 主体；离开 `待追溯` 的 5 项：`wangHash` / Teschner /
`roundedBoxSDF` / q/r 级联 / `Plasma` 四相正弦）+ 表 B 8 行 = **16 行，
覆盖《共享原语的逐项出处》的全部 7 个 `待追溯` 项与 #261 落地的全部 8 个本体，无遗漏** ✅

⚠️ **兜底写死**：追溯失败（追不到 / 追到不兼容）⇒ **`不落地`**，
**不得默认回落到「自研」**——那正是本表第 1 版栽的跟头。
⚠️⚠️ **#281 用到了这条兜底的两个分支，结果相反，必须分开读**：
· `Starfield` 命中「**追到不兼容**」分支 ⇒ **`不落地`**（毫不含糊，见专节）；
· `coreDesignRefractiveGlass` 命中「**追不到**」分支 ⇒ ⚠️ 该分支**本身是歧义的**
（「有权利人但没找到」vs「本来就没有可主张的表达」），处置见其专节。

⚠️ **「指认不到」不等于「原创」**：`ramp3` 至今未指认到上游，本表登记为**待追溯**
而非「自研」。**空白等于默认原创，而本 PR 已因这个默认吃了四次亏。**

### ⚠️⚠️⚠️ `Starfield` 的追溯：**追到了，而且不兼容**（#281 最重要的一条实查）

**这是本表存在的理由的第三次兑现，也是第一次真的抓到不兼容许可。**
前两次（Shadertoy 默认许可、The Book of Shaders 的 `All rights reserved`）都停在
"差点"；这一次是**一个已落地、已合入 epic 分支的 shader**。

⚠️ 别和 `StarNest` 搞混：`StarNest`（Kali，MIT，**未落地**）与 `Starfield`
（#261 **已落地**）是两件东西，名字像而已。本节说的是后者。

#### 具名上游（一手）

| | |
|---|---|
| 作者 | **Martijn Steinrucken**，aka **BigWings** / *The Art of Code* |
| 作品 | **"Starfield Tutorial"（2020）**，YouTube 系列 *Shader Coding: Making a starfield* 的配套代码 |
| 许可 | ⚠️⚠️ **源码头逐字：`// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.`** |
| 证据强度 | **一手**（读到源码全文与许可头），⚠️ **但不是从 shadertoy.com 原页读的**——该站对自动抓取返 **403**。证据是**两份互相独立的 GitHub 拷贝逐字一致**（`sentinelweb/processink` 的 `st_starField_orig.glsl`、`GalaxyCr8r/solarance-beginnings` 的 `starfield.glsl`），另有第三份独立文件（`TornaxO7/website`）使用同一 `id`/`gv` 形态。**#281 两次独立读取**：调研 agent 一次、本人复核一次 |
| ⚠️ 遗留 | **人工目视确认 `https://www.shadertoy.com/view/ls3Xzn` 原页的许可头，是本行的硬 AC**。⚠️⚠️ **该 AC 至今未满足，而撤回已在 owner 指示下执行** —— 为什么未满足仍执行、以及它现在改为阻断哪一侧（任何**恢复**动作），见下方《执行记录》——形态同 `StarNest` 行（那一行是二手证据判**有利**方向，这一行是二手证据判**不利**方向；⚠️ **不利方向更不能只凭二手就执行撤回**）|

#### 逐行对应（一手，两边都读过）

| 本仓 `coreDesignStarfield` | BigWings `StarLayer` | |
|---|---|---|
| `float2 cell = floor(uv * grid);` | `vec2 id = floor(uv);` | **对应**（改名）|
| `float2 local = fract(uv * grid) - 0.5;` | `vec2 gv = fract(uv)-.5;` | **逐字对应**（改名）|
| `float brightness = cd::hash21(cell + 7.0);` | `float n = Hash21(id+offs);` | 结构对应（格点 id 取 hash）|
| `float2 jitter = cd::hash22(cell) - 0.5;` + `length(local - jitter * 0.7)` | `Star(gv - offs - vec2(n, fract(n*34.)) + .5, …)` | 结构对应（每格 hash 抖动星心）|
| `float phase = brightness * 6.2831853;`<br>`glow *= 1.0 - twinkle * 0.5 * (1.0 - sin(time * 2.0 + phase));` | `star *= sin(u_time*3.+n*6.2831)*.5+1.;` | **单条最强对应**：同一构造 `sin(时间·k + hash·TAU)·0.5 + c`。⚠️ `twinkle = 1` 时本仓式代数化简为 `0.5 + 0.5·sin(…)`，与右式同形 |

**≈ 13 行中 5 行对应。**

⚠️ **同时必须写下相反方向的事实，否则这条记录就是选择性的**：
BigWings 的那些**最有辨识度**的部分本仓**一个都没有**——3×3 邻格循环、
衍射光芒（diffraction rays）、`Rot()`、6 层视差星层、`.05/d` 的反距离辉光。
而本仓的 `step(0.55, brightness)` 熄灭门限与 `smoothstep(0.16, 0.0, d)` 圆盘辉光
**追不到任何上游**。⇒ **上一版说"整条级联都是网格星空模板的逐项形态"是过度归因**
（`step` 熄灭与 `smoothstep` 辉光不是他的），本节按实测改述。

#### ⚠️⚠️ 决定性的旁证：**接触与复制已由本仓自己的注释确立**

`CoreDesignShaders.metal` 文件头逐字记着，`hash21` 的**第一版**是
`fract(p * float2(123.34, 456.21)); p += dot(p, p + 45.32)`。
**那正是上面这份 CC BY-NC-SA 文件里 `Hash21` 的常量，逐字符一致。**

⇒ 写这个 shader 的人**手里就有这份文件**。本表已成文：
「**在已读原实现的情况下"重写"是改写（paraphrase），不是 clean-room**」。
hash 层后来被换掉了（现为 Wang/Reed 构造，见表 A），**但星场本体的结构没有换**。
⇒ 这不是"两个人碰巧写出相似代码"，**接触（access）与复制（copying）两个要件都有直接证据**。

#### 裁定

**`Starfield` ⇒ `不落地`。** 逐条对齐本表自己的规则：

1. 《裁定方法》的 `不落地` 定义是「**追过且追不到兼容来源**」——本项追过了，
   追到的来源**明确不兼容**：CC BY-NC-SA 3.0 **既禁商用又有传染性 share-alike**，
   而 CoreDesign 以 **MIT** 分发。本表开篇第一句写的就是这个不兼容。
2. 《清偿条款》的兜底逐字：「追溯失败（追不到 / **追到不兼容**）⇒ **`不落地`**」。
   本项命中的是**第二个分支**，该分支**没有任何歧义**。
3. ⚠️ **不得改走「自研」**：兜底同一句写着「**不得默认回落到「自研」**」。
   而且本项连"追不到"都不是——是追到了。

#### ✅ 执行记录（原《执行缺口》一节）

**撤回已执行**：`Starfield` 已从 `epic/shipswift-shaders` 整件删除。
⇒ ⚠️ **本行不再阻断 `epic → main`**。

保留本节的历史读法：#281 只做裁定与撤回预案、不执行撤回（撤回已合入件由 owner 拍板）；
本表批评过「一条被它唯一的消费者在第一天就违反的规则，不是规则」，所以在执行落地之前
它一直被写死为阻断项。**owner 拍板后由独立的撤回 PR 执行**，其范围与结果记在下面。

**实际删除的东西**（与下方《撤回范围与代价》对齐，逐项核对过）：

| 落点 | 处置 |
|---|---|
| `Sources/CoreDesignShaders/Starfield.swift` | 整份删除 |
| `CoreDesignShaders.metal` 的 `// MARK: - Starfield` 段 | 整段删除（含 `coreDesignStarfield`） |
| `CoreDesignShaders.metal` 的 `hash21` 溢出说明 | 改述——原文拿 `Starfield.Density.dense` 当算例，改为不依赖已撤件的表述 |
| `DotGrid.swift` 头注释的「同 `Starfield`」 | 去掉交叉引用 |
| `PlasmaTests.swift` | 入口清单去 `"coreDesignStarfield"`、测试名「七个入口」→「六个」、删 `Starfield.Density` 单调性断言、头注释的 bundle 计数 18 → 17 |
| `RenderProofTests.swift` | `Background` 去 `.starfield`、测试名「六个背景」→「五个」、全图扫描那条设计说明改为不依赖已撤件 |
| `ACKNOWLEDGEMENTS.md` | 「撤回尚未执行 ⇒ 阻断」→ 执行记录；⚠️ **不为本件写署名条目**这条不变 |

⚠️ **撤回时复核过的一件事**（本节自己的《决定性旁证》要求）：当前
`cd::hash21` / `cd::hash22` / `cd::wangHash` **确已不含** `123.34 / 456.21 / 45.32`
——`hash21` 现为 `(i.x * 73856093u) ^ (i.y * 19349663u)` 喂给 Wang/Reed 的
`0x27d4eb2d` 雪崩。那三个常量只以**历史记录**形态留在注释与本文档里。
⇒ 撤回 `Starfield` 一件即清干净这条污染，**撤回范围不需要扩大到原语层**。

⚠️ **`hash22` 自本次撤回起无调用方**（`hash21` 仍经 `valueNoise` → `fbm` 服务另外三件）。
**有意保留**、不顺手删：它自身已 `已追到兼容许可`，删它属于与本次裁定无关的清理。

⚠️ **本次未走替代方案**：没有"重写那 5 行以保留 `Starfield`"。理由见下方《唯一的替代方案》
——它需要 owner 显式承担独创性门槛的判断，且重写者已读过原文、独立性存疑。

##### ⚠️⚠️ 一条**未满足**的前置，写明而不掩盖

本节《具名上游（一手）》表的「⚠️ 遗留」行给撤回设了一条硬 AC：
「**人工目视确认 `https://www.shadertoy.com/view/ls3Xzn` 原页的许可头**」，
理由是「不利方向的判定更不能只凭二手证据就执行」。

**该 AC 在本次撤回执行时仍未满足**（`shadertoy.com` 对自动抓取持续返 **403**，
见《一手实查清单》的「未能直读」段）。**撤回是在 owner 指示下执行的**，
未等这条目视确认。写下这条而不悄悄划掉，理由：

1. **这条 AC 的风险方向是不对称的**，而原文设它时按对称处理了：它防的是
   「凭二手证据误删一件本可保留的作品」——代价是**丢一个未发布的 shader**；
   反向的代价是**在 MIT 分发里带一件 CC BY-NC-SA 的移植**。⇒ 未满足该 AC 而执行撤回，
   落在**保守侧**，与本表「分档有争议时一律按强档处理」同向。
2. ⚠️ **但这不等于该 AC 作废**：它仍是**若要反悔（恢复 `Starfield` 或走重写方案）
   的前置**。任何恢复动作必须先补上目视确认，不得引用本次执行当作"已经核过了"。

#### 撤回范围与代价（`Starfield`）

**删除**：`Sources/CoreDesignShaders/Starfield.swift`（整份）·
`CoreDesignShaders.metal` 的 `// MARK: - Starfield` 段（`coreDesignStarfield`）。
⚠️ `cd::hash21` / `cd::hash22` / `cd::wangHash` **留下**——`hash22` 目前只有
`Starfield` 一个调用方，但 `hash21` 经 `valueNoise` → `fbm` 被另外三件使用；
且这三个原语自身已 `已追到兼容许可`，不随本件走。

**改测试**：`PlasmaTests.swift` 的 `entryPoints` 去掉 `"coreDesignStarfield"`
（suite 名的入口计数同步）、删 `Starfield.Density` 的单调性断言；
`RenderProofTests.swift` 里以 `Starfield` 为被测对象的用例。

**改文档**：《统一裁定表》`Starfield` 行 · 《逐件适用性》与《#261 落地后的实际档位》
两表 · `ACKNOWLEDGEMENTS.md` · `epic.md` 的「已落地的 8 个」。

**代价**：⚠️ **公开 API 破坏 = 0**——`origin/main` 的 `Sources/` 下只有 `CoreDesign`
一个目录，`CoreDesignShaders` 从未随任何 tag 发布 ⇒ 撤的是**尚未发布**的 API；
仓内下游引用 = 0（`App/project.yml` 只 link product，`downstream-probe` 有意未接）。

#### ⚠️ 唯一的替代方案（如实列出，不替 owner 拍板）

对应的 5 行里，**逐条看每一条都很弱**：网格分解 `floor`/`fract-0.5` 在野有独立实例、
把 `[0,1)` 的 hash 乘 `2π` 变相位是算术而非表达。**若** owner 判定
"残留的对应部分均不达独创性门槛"，则可**不撤回**，改为：
① 重写那 5 行以消除对应；② 在 `ACKNOWLEDGEMENTS.md` 记录本次追溯与判断理由。
⚠️ **但本表的规则是「分档有争议时一律按强档处理」（向保守侧倒），而这一条的
"争议"发生在一个许可明确不兼容、且接触与复制均有直接证据的项上**
⇒ **#281 的建议是撤回**；走替代方案须由 owner 显式承担该判断并写进 PR。

### ⚠️⚠️ `coreDesignRefractiveGlass` 主体的追溯（#281 执行，**强档义务的兑现**）

**追溯方法**：按本表《方法论教训》与《第六条轴》的三条判据逐条执行。

| 判据 | 执行内容 | 结果 |
|---|---|---|
| 1 · 逐常量 grep | 把函数体（`.metal` 的 `coreDesignRefractiveGlass` 全段）里的全部数值常量取出：`0.0` `0.5` `0.99` `1.0` `1e-5` `3.0` | ⚠️ **零个可 grep 的指纹常量**。本表四次命中（`123.34` / `0x27d4eb2d` / `73856093` / Vandevenne 的除数）全部来自这一步，而本函数**没有任何一个同类常量**——没有魔数可拿去搜 |
| 2 · 逐结构对照 | 拆成六个可比对的指纹：(a) 圆角矩形 SDF；(b) 厚度项 `saturate(1.0 + d / depth)`；(c) 位移 `normalize(centred+ε) · 厚度² · 强度`；(d) R/B 各偏 ±spread、G 不动的色散；(e) 边缘高光 `1 - smoothstep(0, k, abs(d))`；(f) 变量名 `centred` / `bend` / `edgeness` / `rimBand`。逐个到 GitHub code search（已认证，默认分支）与具名候选库里比 | 见下表 |
| 3 · 逐原语核对调用面 | `grep cd::` ⇒ 实际调用面恰为 `cd::roundedBoxSDF` + `cd::edgeWidth` 两个，二者各自在《共享原语的逐项出处》有行 | ✅ 无漏项、无错引 |

**逐候选比对结果**（⚠️ 下表每一行的「读到的东西」都是**一手**：实际取回源码文件全文 /
实际读 LICENSE 文件；两个读不到的候选**明标为未读**，不作任何关于其内容的断言）：

| 候选 | 一手读到的 | 许可（是否真有 LICENSE 文件）| (a)–(f) 命中 | 结论 |
|---|---|---|---|---|
| [Czajnikowski/GlassEffect](https://github.com/Czajnikowski/GlassEffect) | `Sources/GlassEffect/Shaders/GlassEffect.metal` 全文 + LICENSE 全文 | **MIT**，LICENSE 存在 | **零命中**。无 SDF；折射走法线 + Snell：`refract(incident, normal, 1/1.49)` | 非匹配 |
| [krispuckett/SwiftUIShaders](https://github.com/krispuckett/SwiftUIShaders) | `Sources/SwiftUIShaders/Shaders/SwiftUIShaders.metal`（2327 行，逐指纹 grep）+ LICENSE | **MIT**，LICENSE 存在 | **零命中**。其 `bcs_refractLens` 是球面 + Snell | 非匹配 |
| [DnV1eX/LiquidGlassKit](https://github.com/DnV1eX/LiquidGlassKit) | `Sources/LiquidGlassKit/LiquidGlassFragment.metal`（540 行） | ⚠️ **无 LICENSE 文件** ⇒ 保留所有权利 | 仅 (d) 的**概念**（用三个折射率而非 ±spread） | 非匹配 |
| [BarredEwe/LiquidGlass](https://github.com/BarredEwe/LiquidGlass) | `Sources/LiquidGlass/Shaders/LiquidGlassShader.metal` 全文 | ⚠️ **无 LICENSE 文件** ⇒ 保留所有权利 | 仅 (a)。厚度项是 `(sdf/boxSize.y)+1.0` 再 `pow(…,10)`，位移沿 **SDF 梯度**而非 `normalize(centred)`；**完全没有色散** | 部分 (a) |
| [twostraws/Inferno](https://github.com/twostraws/Inferno) | 34 个 `.metal` 的文件清单 + `WarpingLoupe.metal` / `SimpleLoupe.metal` 全文 + LICENSE 全文 | **MIT**，LICENSE 存在 | **零命中**。⚠️ Inferno **根本没有折射 / 玻璃 / SDF shader**；"Warping Loupe" 是圆形缩放 | 非匹配 |
| Victor Baro, *Implementing a Refractive Glass Shader in Metal*（Medium） | ⚠️ **未读到 —— HTTP 403** | — | — | ⚠️ **未读，遗留缺口**（见下） |
| [victorBaro/TryMetal](https://github.com/victorBaro/TryMetal)（同作者的 GitHub，枚举其仓库找到）| `Example App/LayerEffect/RefractingGlass.metal`、`Workshop/Final/…`、`Workshop/Start/…` **三份全文** | ⚠️ **无 LICENSE 文件** ⇒ 保留所有权利 | 仅 (d) 的**约定**（G 不动、R 多弯、B 少弯），代数形式不同（乘法 `(1±chromaticStrength)`）。**(a) 不成立**（是圆不是 SDF）、**(b) 反向**（`1 - r²`，中心最强，与 `edgeness` 相反）、(c)(e)(f) 均不成立 | 部分 (d) |
| [metal.graphics ch.10](https://metal.graphics/chapter10-texture-effects) | 页面全文 | 页面无许可声明 | 零命中 | 非匹配 |
| Hacking with Swift · layerEffect 教程 | ⚠️ **未读到 —— HTTP 403** | — | — | ⚠️ **未读，遗留缺口** |
| [benediktms/claude-orb](https://github.com/benediktms/claude-orb) —— 由 `"saturate(1.0 + d /" language:Metal` 搜到，**是该式在 GitHub 上唯一的 Metal 命中** | `Sources/ClaudeOrb/Shaders/Glass.metal` 全文 | ⚠️ **仓库树里没有任何 LICENSE 文件** ⇒ 保留所有权利 | **(a) 逐字符、(b) 逐字符、(c) 逐字符、(f) 部分**：`float2 centred = in.uv * u.size - halfSize;`／`float2 q = abs(p) - halfSize + r; return length(max(q,0.0)) + min(max(q.x,q.y),0.0) - r;`／`float rim = saturate(1.0 + d / lensDepth);`／`float2 bend = -normalize(centred + float2(1e-4)) * rim * rim * lensDepth;`。**(d)(e) 不成立**——它没有色散、没有 rim band，且是 ScreenCaptureKit 纹理上的 `fragment` shader，不是 `[[stitchable]]` / `SwiftUI::Layer` | ⚠️ **(a)(b)(c)(f) 强结构匹配** |
| [markovsdima/Zyna](https://github.com/markovsdima/Zyna) | `Zyna/Glass/GlassShader.metal` 相关段 | **AGPL-3.0** | 仅 (d) 的约定 + `rimBand` 这个名字；无 SDF 玻璃、无 `centred`、无 `edgeness` | 部分 |
| MohamedFuad16/resume-studio-dashboard | `ios/InternshipPortal/Shaders.metal` 全文 | ⚠️ 无 LICENSE ⇒ 保留所有权利 | (d) 近乎一致（`spread` 同名、R/B 各 ±spread）+ `rimBand` 同名；但主体是**球面**，(a)(b)(c)(e) 全不成立 | 部分 |
| [signerlabs/ShipSwift](https://github.com/signerlabs/ShipSwift)（本 epic 的参照项目）| `SWPackage/SWAnimation/SWMetal/SWGlass.metal`(299 行) 与 `SWGlassLogo.metal`(185 行) 全文 | **MIT**，LICENSE 存在 | **本体非匹配**。它同样有 (a) 的闭式解作 helper，但厚度项是 `(1-depthNorm)²`（**不是** `saturate(1.0+d/depth)`）、位移沿**有限差分 SDF 梯度**（**不是** `normalize(centred)`）、色散是黄金角三心采样。无 `centred`/`bend`/`edgeness`/`rimBand` | 非匹配 |
| [Inigo Quilez《2D distance functions》](https://iquilezles.org/articles/distfunctions2d/) | 页面全文 | ⚠️ **页面上没有任何许可、版权行或使用条款** | **(a) 的具名上游**：`vec2 q = abs(p)-b+r.x; return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;`（与本仓两项互换顺序） | **(a) 的具名上游** |

**空手而归的搜索**（同样是结论的一部分，逐条记下来省得下一个人重跑）：
`"centred + 1e-5"` → 0；`"* refraction * dispersion"` → 0；
`"thickness = saturate(1.0 +"` → 0；`"1.0 + dist /" language:Metal` → 0；
`"edgeness" language:Metal` → 1（无关的火焰 shader）；
`"rimBand" language:Metal` → 2（均为上表的部分匹配）。

#### 追溯结论（三条，分开写，别合并）

1. ⚠️⚠️ **上一版那句事实主张被本轮追溯证伪。** 本表原写「2025 年 SwiftUI `layerEffect`
   "liquid glass" 一族的**通行形态**」——**没有找到这样一族**。逐个读完具名的
   SwiftUI-Metal 玻璃库（Inferno / GlassEffect / SwiftUIShaders / LiquidGlass /
   LiquidGlassKit / TryMetal / ShipSwift），**没有任何一个**带 (b)+(c)，
   更没有一个带 (a)+(b)+(c)+(d)+(e)+(f) 的组合。
   ⇒ 「通行形态」这四个字当时是**没有证据的断言**，与本表判掉的那些否定式断言同类，
   只是方向相反：它**高估**了外部来源的存在。本表已因「高估同样有代价」栽过一次
   （The Book of Shaders 的 `All rights reserved` 那条），这是第二次。
2. **没有具名上游。** 可具名的只有 (a) `roundedBoxSDF` ⇒ Inigo Quilez，
   **其页面无任何许可声明**（一手读页）。(b)(c) 在 GitHub 上只有一处 Metal 先例
   （`claude-orb`，**无许可**，早 7 天，不同 shader 种类、无色散无 rim band，
   且同一 idiom 在更早的 Unity HLSL 仓 `Heerozh/PromptUGUI`(Apache-2.0, 2026-05)
   里也出现过 `float g = saturate(1.0 + d / size); color.a *= g * g * inside;`）
   —— ⚠️ **三处的共同点是它们都是 LLM 驱动的仓库**，这是「同一 idiom 被独立生成」
   的最好证据，而不是「转抄自某份人类发表的配方」的证据。
   **两个方向都不可证**：本仓无从接触 `claude-orb`，`claude-orb` 也无从接触本仓。
   ⇒ 如实记下这条**对我们不利的发现**（一个无许可仓里有逐字符相同的 `roundedBox`
   函数体），而不是把它藏起来——下一个 reviewer 会用同一条 grep 找到它。
3. (d) 色散约定（R 多弯 / G 不动 / B 少弯）读到三份独立实现，**三份代数式各不相同**
   ⇒ 是物理事实的直接编码，不是某一份的表达。(e)(f) **追不到任何东西**。

#### 分档改判：**强指纹 → 低指纹**（⚠️ 这是**下调既有裁定**，须评审复核）

逐条对照强档判据原文「有可辨识的个人表达：**级联结构 / 变量命名保留 / 审美性的参数组合**」：

| 强档判据 | 本函数 | 成立？ |
|---|---|---|
| 级联结构 | 无级联。单次 SDF → 单次位移 → 至多两次额外通道采样 | ❌ |
| 变量命名保留 | `edgeness` / `rimBand` **追不到任何来源**，谈不上"保留"；`centred` / `bend` 只与一个**无许可、无法证明有传递关系**的仓共现 | ❌ |
| 审美性的参数组合 | 常量只有 `0.5` / `1e-5` / `3.0` / `0.99` —— **全部是功能性的**（半宽、除零兜底、rim 带宽 = 3×抗锯齿宽、预乘合法性阈值），无一是审美取值。**逐常量 grep 无物可 grep** | ❌ |

⇒ **三条判据全部不成立。** 上一版判强档的唯一依据是那句「指纹强度不低于 `InkSmoke`
的 q/r 级联」，而 q/r 级联的指纹恰恰是**级联结构 + 变量名 `q`/`r` 逐字保留**
（见《共享原语的逐项出处》同名行）——本函数**两样都没有**。
⇒ 该自评是在没做追溯的情况下下的，本轮追溯把它的事实前提取消了。

**改判为 `待追溯（低指纹）`**，按低档判据逐条：
① 复制量小 —— 可具名的复制只有 (a) 那 **2 行**闭式解；
② 功能性 —— (a) 是圆角矩形 SDF 的闭式解、常量全是功能性取值，换一组就不工作；
③ 来源为无许可的公开发表 —— iq 的 `distfunctions2d` 页面**无任何许可声明**（一手读页）。

⚠️⚠️ **这不是改判为「自研实现」，本条必须读清楚。** 裁定值仍是 **`待追溯`**，
ⓐ（不作任何原创声称）与 ⓒ（下次实质修改时必须追完）**照旧生效**，
承接 issue = **#281**。改变的**只有档位**，而档位的定义就是**指纹强度**——
本轮实测了指纹强度。**「追不到上游」不等于「原创」**，本表这句话在这里同样约束本行。

#### ⚠️ 遗留缺口（写死，不得当作已核）

- [ ] **Victor Baro《Implementing a Refractive Glass Shader in Metal》（Medium）返 403，未读到正文。**
      同作者的 `victorBaro/TryMetal` 里三份 `RefractingGlass.metal` 已一手读完且**不匹配**
      （(a)(b)(c)(e)(f) 全不成立），这**大幅缩小**但**没有关闭**该缺口。
      ⇒ **人工目视确认该文正文的 shader 源码，是本行的硬 AC**——形态同 `StarNest` 那行
      （二手证据 ⇒ 人工目视列为硬 AC），不是"建议"。
- [ ] Hacking with Swift 的 `layerEffect` 教程页返 403，未读到。同上处理。

#### ⚠️ 为什么不是直接套「兜底 ⇒ `不落地`」——本表自己已有先例

兜底逐字是「追溯失败（**追不到** / 追到不兼容）⇒ `不落地`」。它的两个触发条件
**法律含义完全不同**，而本表把它们写在了一起：

- 「追到不兼容」= 有权利人、许可不容 ⇒ 不落地是唯一出路；
- 「追不到」= ⚠️ **在「有权利人但我没找到」与「本来就没有可主张的表达」之间是歧义的**。
  兜底的推理只对前者成立（找不到人就拿不到许可）。

**本表已经对同一情形做过一次裁决，而且不是判 `不落地`**：`ramp3` 那一行逐字写着
「**未指认到具体上游**」，判的是 **`待追溯（低指纹）`、不阻断**，承接 issue 走 ⓑ。
⇒ 「追过、没找到上游、指纹弱」在本表里的既定处置就是**低档不阻断**，不是 `不落地`。
本行与 `ramp3` 的证据处境相同（都追过、都没找到具名上游），
**唯一的差别是上一版的一句自评说它"强"，而本轮把那句自评的事实前提取消了。**

⚠️ 顺带一提量级：若把兜底按「追不到 ⇒ 一律不落地」机械适用，
`ramp3` 同样要撤——而 `ramp3` 被 `Plasma` / `FractalClouds` / `InkSmoke` /
`LiquidChrome` **四件**调用。这不是"所以不能撤"的理由，是**"两行同证据不同判"
本身就是要修的不一致**的证据。

⚠️⚠️ **本改判是对既有裁定的下调，按本表规定「分档由 provenance 表 owner 判、
merge 前评审复核」**，且「分档有争议时一律按强档处理」。
⇒ **本行在 `epic → main` 的 PR 上须由评审显式确认；评审不确认则回落到 `不落地`**，
撤回范围见下方《若不接受本改判：撤回范围》。

#### 若不接受本改判：撤回范围与代价（**#281 不执行撤回，留给拍板**）

**删除**：

| 文件 | 量 | 内容 |
|---|---|---|
| `Sources/CoreDesignShaders/RefractiveGlass.swift` | 145 行（整份）| `RefractiveGlassModifier` · `public enum RefractiveGlassStrength` · `public func View.refractiveGlass(corner:strength:rim:isEnabled:)` · `#Preview` |
| `Sources/CoreDesignShaders/GlassSymbol.swift` | 107 行（整份）| `public struct GlassSymbol`（**唯一消费者**）|
| `Sources/CoreDesignShaders/CoreDesignShaders.metal` | 第 338–447 行（110 行）| `cd::roundedBoxSDF` + `coreDesignRefractiveGlass`。⚠️ `cd::edgeWidth` **留下**——`DotGrid` / `LiquidChrome` 还在用；`cd::roundedBoxSDF` 只有这一个调用方，随之删 |

**改测试**：

- `Tests/…/PlasmaTests.swift`：`entryPoints` 去掉 `"coreDesignRefractiveGlass"`；
  suite 名「**七个**入口全部解析得到」→ 六个；删 `@Test("RefractiveGlassStrength：…")`
- `Tests/…/RenderProofTests.swift`：删 3 个 `@Test`
  （`glassRefracts` / `rimShowsOnTransparentContent` / `rimDoesNotPunchHolesInOpaqueContent`）
  —— ⚠️ 这三个是**唯一**覆盖「预乘 source-over 的两种失效形态」的回归证据，删了就没了
- `Tests/…/AccessibilityBehaviorTests.swift`：删 `GlassSymbol.isDecorative` 的 FR-13 断言

**改文档**：本表《统一裁定表》两行改判 `不落地`（待追溯 17 → 15、不落地 0 → 2、计数校验行）·
《逐件适用性》与《#261 落地后的实际档位》两表 · `ACKNOWLEDGEMENTS.md` 的
`roundedBoxSDF` / `coreDesignRefractiveGlass` 两行 · `epic.md` 的「已落地的 8 个」→ 6 个。

**代价评估**：

- ✅ **公开 API 破坏 = 0**：`origin/main` 的 `Sources/` 下**只有 `CoreDesign` 一个目录**
  （`git ls-tree -d --name-only origin/main Sources/`），`CoreDesignShaders` 从未随任何
  tag 发布过 ⇒ 撤的是**尚未发布**的 API。
- ✅ **仓内下游引用 = 0**：`App/project.yml` 只 link `product: CoreDesignShaders`，
  **不引用任何被撤符号**；`scripts/downstream-probe` **有意未接** `CoreDesignShaders`。
- ❌ 落地件 **8 → 6**；`CoreDesignShaders` 失去唯一的 `layerEffect` 类效果
  （其余 6 个全是 `colorEffect` 背景层）⇒ `SwiftUI::Layer` 通路在本仓**零覆盖**，
  连带失去上面那三条预乘正确性的回归证据。
- ❌ 约 **350 行**源码 + 测试删除。

### ⚠️⚠️ The Book of Shaders 的许可实查结果（⚠️ 本节上一版自称「本表最重要的一条实查」——**#281 之后不再是**：它抓到的是一个**差点**引错的来源，而上方《`Starfield` 的追溯》抓到的是一个**已落地、已合入 epic 分支**的件带着不兼容许可。本节仍然重要，但排第二）

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

### 共享原语的逐项出处（#261 落地时补，本表的必填项；**#281 逐行做了许可实查**）

⚠️⚠️ **本表上一版有四行的「许可地位」是错的，而且错在同一个方向：把「我没看见许可」
写成了「没有许可」。** #281 逐个打开来源页面读了一遍，结果是**四行都有真实许可**，
其中三行还带**署名义务**——「无许可声明」这个结论一旦写下，就没有人再去找了。
⇒ 本表新增第 3 列**「许可实查（#281 一手）」**，逐行贴出**读到的原文**；
凡是写「未找到许可声明」的行，必须同时写明**读了哪一页**。

| 原语 / 片段 | 出处（具名） | 许可实查（#281 一手，附逐字原文） | 裁定 / 分档 |
|---|---|---|---|
| `wangHash`（`0x27d4eb2d`） | ⚠️ **三层，必须分清**：算法 = **Thomas Wang**《Integer Hash Function》(1997/2007)；「公有领域」的说法出自 **Bob Jenkins**《Integer Hashing》；⚠️ **本仓逐字符复制的是 Nathan Reed**《Quick And Easy GPU Random Numbers In D3D11》(2013) **的写法** | ⚠️⚠️ **判别点：Wang 与 Jenkins 都写 `a = a + (a << 3)`，Reed 把它改写成 `seed *= 9`——而本仓写的正是 `seed *= 9u`** ⇒ 复制对象是 Reed 那一份。<br>· Wang 原页（Wayback 2007-04-03 快照）：**通篇无版权、无许可、无 public domain 字样**；<br>· Jenkins `burtleburtle.net/bob/hash/integer.html` 逐字：「The hashes on this page … are all public domain. **So are the ones on Thomas Wang's page. Thomas recommends citing the author and page when using them.**」<br>· ⚠️ **Reed 的站点页脚逐字：「© 2007–2025 by Nathan Reed. Licensed CC-BY-4.0.」** | **已追到兼容许可**（可再分发）⚠️ 但**署名是许可条件不是礼节**：CC-BY-4.0 要求署名 Reed。⚠️ **`CC-BY-4.0` 不在本表取值域内**——同 Apache-2.0 当年，见《裁定方法》的档位缺口注 |
| `hash21`/`hash22` 的素数三元组 `73856093 / 19349663 / 83492791` | **Teschner et al. 2003**《Optimized Spatial Hashing for Collision Detection of Deformable Objects》(VMV 2003) | 一手读 PDF（`matthias-research.github.io/pages/publications/tetraederCollision.pdf`），§4.1 逐字：「where p1, p2, p3 are large prime numbers, in our case **73856093, 19349663, 83492791**, respectively.」<br>⚠️ **论文里未读到任何许可声明**（读的是这份 PDF；页脚只有 VMV 2003 的会议行） | **事实性常数 ⇒ 可落地**。三个已发表的数字是**事实不是表达**，无著作权义务；义务是**学术引用**。⚠️ **本行与《清偿条款》分档表的打架已收敛，见该表 Teschner 行** |
| `hash22` 的第四个素数 `50331653` | **SGI STL / libstdc++ 的标准哈希表素数梯**（倍增素数表条目） | 一手读 `gcc-mirror/gcc` 的 `libstdc++-v3/include/backward/hashtable.h`：`25165843ul, **50331653ul**, 100663319ul, …`。文件头带 GPLv3+Runtime Exception 与 SGI 的 1996/1997 许可通知 | **事实性常数 ⇒ 可落地**。单个素数是事实，不产生任何许可义务。⚠️ **上一版本行缺失**——本表刚宣布「逐常量 grep 无条件适用」，而一个已知落在具名来源之外的常数就已经漏在表外（#261 自己记下的遗留项，本 task 补入） |
| `valueNoise`（嵌套 `mix` 形态） | **iq** 的嵌套 `mix(mix(a,b,u.x), mix(c,d,u.x), u.y)` 形态 | 见下面 `roundedBoxSDF` 行的 iq 站点级 MIT 声明（同一站点） | **教科书算法 ⇒ 可落地**。⚠️ **上一版把 The Book of Shaders 也列为出处——而本表上一节刚写完"不能以它作为许可依据"，34 行后自己就引了它**（第 2 轮终审 C-5）。实证支持删除：该书用的是**展开式** `mix(a,b,u.x)+(c-a)*u.y*(1-u.x)+(d-b)*u.x*u.y`，**我们用的恰恰不是它那一种** |
| `fbm`（gain 0.5 / lacunarity 2.0 循环体） | **算法本身**：fBm 的标准形式（Mandelbrot–Perlin–Musgrave 谱系，见 Ebert et al.《Texturing & Modeling》）。⚠️ 我最初是在 **The Book of Shaders 第 13 章**读到它的 | The Book of Shaders 的 LICENSE 实查结果见下方专节（`All rights reserved`）⇒ **不以它作许可依据** | **可落地**（事实性算法）——见《The Book of Shaders 的许可实查结果》 |
| 域扭曲的 `q`/`r` 三级级联（落地函数 `coreDesignInkSmoke`；组件 `InkSmoke` / `FractalClouds`） | **Inigo Quilez《Domain Warping》** `https://iquilezles.org/articles/warp/` | ⚠️⚠️ **上一版写「页面无许可声明」——错的，只是没读对页面。** warp 页本身确实没有；但它的父页 `https://iquilezles.org/articles/` 有**站点级授权**，逐字：「**all technical code snippets you'll find are under the MIT license so you can easily reuse them**, but the mathematical/shader art is protected and requires a license for use.」（**#281 两次独立一手读取**：调研 agent 一次、本人复核一次）| ⚠️⚠️ **改判：`待追溯` → `已追到兼容许可 · MIT`**。⇒ **强指纹档的阻断义务「追完前不得合入 `main`」已兑现**（既追到、许可又兼容）⇒ **不再阻断 `epic → main`**。义务：`ACKNOWLEDGEMENTS.md` 转载 MIT 通知并具名 iq。⚠️ iq 自述那几个偏移常量「don't have any special meaning」——**恰恰因此它们是表达而非事实**，本仓换了偏移**也不构成独立**（本表已成文），署名照给 |
| `Plasma` 的四相正弦叠加 | **Lode Vandevenne**《Lode's Computer Graphics Tutorial — Plasma》 `https://lodev.org/cgtutor/plasma.html` | ⚠️⚠️ **上一版写「页面无许可声明」——同样是没读对页面。** plasma 页页脚确是「Copyright (c) 2004-2007 by Lode Vandevenne. All rights reserved.」，**但 `https://lodev.org/cgtutor/legal.html` 把散文与代码分开授权**，逐字：「**The source code of QuickCG and all the source code of the examples given in this tutorial and all its articles is released under the following license:** Copyright (c) 2004-2007, Lode Vandevenne / All rights reserved. / Redistribution and use in source and binary forms … *Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.* …」= **BSD-2-Clause**（**#281 两次独立一手读取**）| ⚠️ **改判：`待追溯` → `已追到兼容许可 · MIT`档**（该档的定义逐字含 **BSD**）。义务：**BSD-2-Clause 第 1 条要求在源码中保留版权通知 + 条件 + 免责声明**，一句「参考自 Lode 的教程」**不满足**该条。<br>⚠️ **同时如实记下有利于我们的一半**：受保护的表达是他那组具体取值（中心 `(128,128)`/`(64,64)`/`(192,64)`/`(192,100)`、除数 `/8 /8 /7 /8`），**本仓一个都没用**（四项全部参数化 + 各带不同时间相位）⇒ 我们取的是**思路层**。**BSD 通知照给**——成本为零，而省下的是一次"我认为自己没抄"的自我裁判 |
| `roundedBoxSDF` | **Inigo Quilez 2D/3D distance functions** —— ⚠️ 精确来源是 **3D 页的 `sdRoundBox`**（单半径两行式），2D 页上的 `sdRoundedBox` 是**四半径 `vec4` 变体**，与本仓的写法不是同一个 | 同上 iq 站点级 **MIT**（`/articles/` 逐字见 q/r 级联行）。3D 页逐字：`vec3 q = abs(p) - b + r; return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;` ⇒ 本仓的 2 行是它的 2D 降维 | ⚠️ **改判：`待追溯（低指纹）` → `已追到兼容许可 · MIT`**。义务：MIT 通知 + 具名 iq。⚠️ **上一版「与 `valueNoise` 的双标已消」那段的判别标准（唯一闭式解 ⇒ 保守判待追溯）现已无关**——不是靠加严判据解决的，是靠**去把许可读了** |
| `edgeWidth`（`max(fwidth, ε)` + 下游 smoothstep） | ⚠️⚠️ **归属改判：没有可归属的上游。** 上一版写「iq 的 **distance-AA** 一族」——**该归属经实查不成立** | #281 逐页 grep 了 iq 的 `distfunctions2d/` `distfunctions/` `functions/` `distance/` `filterableprocedurals/` 五篇：**`fwidth` 一次都没出现**。⇒ 上一版是**凭印象归的属**。<br>最接近的**具名**发表是 Stefan Gustavson《2D Shape Rendering by Distance Fields》(OpenGL Insights ch.12, 2011)，其代码逐字「**This code is in the public domain.**」——但他写的是 `0.7 * length(vec2(dFdx, dFdy))`，**不是** `max(fwidth(x), ε)`，**不是同一表达**。<br>`max(fwidth(x), ε)` 本身在多个互不相关的仓里独立出现（一手读到：google/filament、Checkpoint、LiquidBounce 三份，另有 organicmaps / box3d / MyGUI / osgearth 等） | **`待追溯（低指纹）`**（档不变，**理由换了**）。1 行；`fwidth` 是内建函数、把它夹到 0 以上是无表达余地的防御性写法（merger）⇒ 判据 ①②成立；③ **改述为「无可归属上游的通用惯用法」**，而不是伪称某人的一族 |
| `ramp3`（三档插值） | **未指认到具体上游**（#281 又追了一轮，仍未指认到） | #281 用 GitHub code search 试了四种措辞（`mix(mid, high, smoothstep(0.5`、`mix(lower, upper, step(0.5`、`lower = mix(low, mid, smoothstep`、`smoothstep(0.5, 1.0, v)) step(0.5, v)`）+ 两次 web search + 查了 LYGIA 的 color-ramp 条目：**无任何具名作者 / 出版物 / 库发表过这三行结构**。最接近的只是一份 2025 年的 app 仓（阈值不同、用 `select` 不用 `step`），**不是上游** | **`待追溯（低指纹）`**。⚠️ **「又追了一轮仍没找到」不等于「原创」**——本表这句话在这里同样约束本行；不作任何原创声称，承接 issue **#281**（判据评估见《清偿条款》分档表） |
| `coreDesignRefractiveGlass` 的位移 + 通道色散**主体**（= 组件侧 `Glass`（`RefractiveGlass`）的主体原语） | ⚠️⚠️ **上一版写「2025 年 SwiftUI `layerEffect` "liquid glass" 一族的通行形态」——该事实主张经 #281 追溯被证伪：没有找到这样一族。** 详见下方《`coreDesignRefractiveGlass` 主体的追溯》 | 见该专节的逐候选一手比对表 | ⚠️ **分档改判：强指纹 → `待追溯（低指纹）`**（裁定值仍是 `待追溯`，**不是**「自研」）。详见该专节，**含遗留缺口与撤回预案** |

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

⚠️⚠️ **左列的 `Starfield` 现已被 #281 判 `不落地`** —— 保留它在左列是为了记住教训本身：
「**效果类别可以自研**」这个判断至今成立（程序化星空当然是效果类别），
而**实际写出来的那一份不是自研的，且它的上游许可不兼容**。
⇒ 左列（准入）与实际档位（结论）之间的落差，`Starfield` 是最极端的一例。

⚠️⚠️ **本表左列是「**效果类别**层面可以自研」，不是「实现出来就是自研的」**
——两者被 #261 的五轮实证分开了。**实际落地后的档位以 #261 为准，全部下调：**

| 件 | 本表原判 | #261 落地后的实际档位 |
|---|---|---|
| `InkSmoke` | 可走自研 | **不是自研**——域扭曲级联派生自 iq，hash 层出处见上表。⚠️ **#281 追完许可：iq 站点级 MIT** ⇒ 从「派生自 iq 但许可未知」变成「派生自 iq 且**可用**，条件是署名」⇒ **不再阻断 `epic → main`** |
| `FractalClouds` | 可走自研 | **不是自研**——同上（单级 warp，指纹较弱）。#281 同样解除许可未知：iq MIT |
| `LiquidChrome` | 可走自研 | 「自研」射程**仅限组合与参数化**，不含共享原语。#281 又追了一轮（paper 的 `liquid-metal.ts` / react-bits 的 `LiquidChrome` 均一手读全文 ⇒ **均不匹配**；shadertoy 403，一条「知名 Shadertoy Liquid Chrome」的线索**未能核实、已丢弃，不作为证据**）⇒ **仍未指认到上游**，判 `待追溯（低指纹）` |
| `Plasma` | 可走自研 | **撤回「非移植」**——四相正弦是 Vandevenne 的公式。⚠️ **#281 追完许可：BSD-2-Clause**（`lodev.org/cgtutor/legal.html` 把代码与散文分开授权）⇒ 可用，条件是**保留版权通知 + 条件 + 免责声明** |
| **`Starfield`** | 可走自研 | ⚠️⚠️ **#281 再下调一级：`不落地`** —— 不是「不是自研」，是**追到了不兼容许可**（Martijn Steinrucken / BigWings《Starfield Tutorial》(2020)，源码头 **CC BY-NC-SA 3.0**）。⚠️ **上一版这一格「整条级联都是网格星空模板的逐项形态」是过度归因**：`step` 熄灭与 `smoothstep` 圆盘辉光**追不到任何上游**，BigWings 用的是 `.05/d` 反距离辉光且**没有** `step` 门限。真正对应的是网格分解（`id`/`gv` → `cell`/`local`，**改名**）、每格 hash 抖动、与闪烁相位那一行。详见《`Starfield` 的追溯》|
| `Dots`（`DotGrid`）| 可走自研 | **撤回「非移植」**——网格 + 抗锯齿圆盘是公开形态。#281 又追了一轮（paper 的 `dot-grid.ts` / Inferno 的 `LightGrid.metal` 均一手读全文 ⇒ **不匹配**）⇒ **仍未指认到上游**，判 `待追溯（低指纹）` |
| `Glass`（`RefractiveGlass`）| 可走自研 | **撤回「自研的 Metal 折射」**——主体零署名，见上表。⚠️ **#281 追完：仍未指认到具名上游**，且上一版「2025 年 layerEffect liquid glass 一族的通行形态」这句**被证伪**（没有这样一族）⇒ 分档由**强指纹改判低指纹**，详见《`coreDesignRefractiveGlass` 主体的追溯》|
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
| 19 | `FractalClouds` | clean-room | **`待追溯（低指纹）`** | ⚠️ **本轮再降一级**：参考实现候选 ashima / stegu / glsl-noise 虽均 **MIT**，但只覆盖 FBM 底座，**domain-warp 与调色的组合本就未追到出处** ⇒ 依据不成立。⚠️ **#281 更新**：其 domain-warp 所属的 iq 一族**已追到 iq 站点级 MIT**；本体自身仍未指认到上游 ⇒ 低指纹，不阻断 |
| 20 | `InkSmoke` | clean-room | **`待追溯（低指纹）`** | 同上。#261 实证：域扭曲的 `q`/`r` 三级级联派生自 **iq《Domain Warping》**，已撤回原创声称。⚠️⚠️ **#281 追完许可：iq 的 `/articles/` 站点级声明逐字「all technical code snippets you'll find are under the MIT license」** ⇒ 该级联 **`已追到兼容许可 · MIT`**，**强档的阻断义务已兑现** ⇒ 本件**不再阻断 `epic → main`**，义务转为署名 |
| 21 | `Plasma` | clean-room（"经典 demoscene"） | **`待追溯（低指纹）`** | 上一版：无具名参考实现。⚠️ **#281 更新**：四相正弦已具名 **Lode Vandevenne**，且**许可实查为 BSD-2-Clause**（`lodev.org/cgtutor/legal.html` 代码与散文分开授权）⇒ 该片段 `已追到兼容许可`，义务是**保留版权通知 + 条件 + 免责声明**。本体其余部分未指认到上游 ⇒ 低指纹，不阻断 |
| 22 | **`Starfield`** | clean-room（"标准做法"） | ⚠️⚠️ **`不落地`** | ⚠️⚠️ **上一版写「无具名参考实现」——#281 追到了。** **Martijn Steinrucken（BigWings / The Art of Code）《Starfield Tutorial》(2020)**，源码头逐字 `// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.` ⇒ **与 MIT 分发不兼容**（禁商用 + 传染性 share-alike）。命中兜底的「**追到不兼容**」分支 ⇒ `不落地`。⚠️ **旁证：本仓 `hash21` 第一版的 `123.34/456.21/45.32` 正是该文件 `Hash21` 的常量，逐字符一致** ⇒ 接触与复制均有直接证据。✅ **判定已下、撤回已执行（整件删除）⇒ 本行不再阻断 `epic → main`**，详见《`Starfield` 的追溯》|
| 23 | `Dots` | clean-room（"网格 + 三角函数"） | **`待追溯（低指纹）`** | ⚠️ paper 有 `dot-grid.ts` 但描述不同（静态几何网格 vs ShipSwift 的 5 个 `.metal` 变体）⇒ **不是**匹配。⚠️ **#281 又追了一轮**：一手读全 paper 的 `dot-grid.ts`（静态、simplex 随机化、polygon SDF ⇒ 不匹配）与 Inferno 的 `LightGrid.metal`（无圆盘、无 `fwidth` ⇒ 不匹配），code search 无候选 ⇒ **仍未指认到上游**，低指纹，不阻断 |
| 24 | `Glass` | clean-room（"iq 的 SDF 文章"） | **`待追溯（低指纹）`** | ⚠️ 上一版写「iq 的 distfunctions2d / warp 页面**无许可声明**——"iq 文章代码是 MIT"是需要证的」。⚠️⚠️ **#281 把它证了**：iq 的 `/articles/`（两篇文章的父页）逐字「**all technical code snippets you'll find are under the MIT license**」⇒ `roundedBoxSDF` **`已追到兼容许可 · MIT`**。而**主体**（位移 + 通道色散）追完**仍未指认到具名上游**，且上一版「2025 年 layerEffect liquid glass 一族的通行形态」这句被证伪 ⇒ 分档**强指纹改判低指纹**，详见专节 |
| 25 | `GlassLogo` | clean-room | **`待追溯（低指纹）`** | 同上（**落地名 `GlassSymbol`**）。本件无自有 shader，档位完全随 `Glass` |
| 26 | `AnimatedLoop` | clean-room（"调度器，无独立算法"） | **`待追溯`** | ⚠️ **第 1 版是事实误读**：`SWAnimatedLoop.metal:5-21` 是四个 **hand-tuned styles**，共享 per-line phase ramp + RGB 通道分离 + 加法合成，仅距离度量与 pattern 项不同；"dispatch by name" 指在**这四个自有入口**间选，不是分派到别的效果。18 个参数，是**独立作品** |
| 27 | `LiquidChrome` | **不落地** | **`待追溯（低指纹）`** | ⚠️ **准则统一**：`SWLiquidChrome.metal:7-9` 自述 "Three sequential value-noise samples are domain-warped"，与 InkSmoke / FractalClouds **同一算法类别**。第 1 版用"观感特征性强"判它不落地、却用"算法类别"给 InkSmoke 放行，是**双标**。⚠️ **#281 又追了一轮**：paper 的 `liquid-metal.ts`（零 fbm、stripe-cascade）与 react-bits 的 `LiquidChrome`（余弦级联 + `1/|sin|`）均一手读全文 ⇒ **均不匹配**；shadertoy 403，一条 Shadertoy 线索**未核实、已丢弃** ⇒ **仍未指认到上游**，低指纹，不阻断 |
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
| `FractalClouds` | **—**（本体未追到）；FBM 底座可对照 ashima / stegu / glsl-noise，但 **domain-warp 与调色的组合未追到出处**。⚠️ **#281 又追一轮，本体仍未指认到上游** | 参考实现 **MIT**；本体 —；⚠️ **其 domain-warp 所属的 iq 一族已追到 iq 站点级 MIT** | https://github.com/ashima/webgl-noise · https://iquilezles.org/articles/ | **`待追溯（低指纹）`**（#281 分档，不阻断） |
| `InkSmoke` | **—**（本体未追到）；#261 实证：域扭曲的 `q`/`r` 三级级联派生自 **iq《Domain Warping》** | ⚠️⚠️ **改判**：上一版写「iq 页面无许可声明」——**错的，只是没读对页面**。文章父页 `iquilezles.org/articles/` 逐字「**all technical code snippets you'll find are under the MIT license**」（#281 两次独立一手读取）⇒ 该级联 **MIT** | https://iquilezles.org/articles/warp/ · https://iquilezles.org/articles/ | **`待追溯（低指纹）`** —— ⚠️ **强档阻断已解除**（既追到、许可又兼容 ⇒ 义务已兑现，转为署名） |
| `Plasma` | **—**（本体未追到）；#261 实证：四相正弦叠加是 **Lode Vandevenne《Lode's Computer Graphics Tutorial — Plasma》** 的公式 | ⚠️ **改判**：上一版写「本表未核该页面许可」——**#281 核了**。plasma 页页脚确为 `All rights reserved`，但 `lodev.org/cgtutor/legal.html` **把散文与代码分开授权**，代码逐字为 **BSD-2-Clause**（保留版权通知 + 条件 + 免责声明）| https://lodev.org/cgtutor/plasma.html · https://lodev.org/cgtutor/legal.html | **`待追溯（低指纹）`**（该片段已 `已追到兼容许可`；本体其余未指认 ⇒ 低指纹，不阻断） |
| **`Starfield`** | ⚠️⚠️ **#281 追到了**：**Martijn Steinrucken（BigWings / *The Art of Code*）《Starfield Tutorial》(2020)**。⚠️ 上一版写「未追到 / 网格星空模板」是**既漏了具名上游、又过度归因了范围**（`step` 熄灭与 `smoothstep` 圆盘辉光不是他的） | ⚠️⚠️ **CC BY-NC-SA 3.0**——源码头逐字 `// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.`。**与本仓 MIT 分发不兼容**（禁商用 + 传染性 share-alike） | ⚠️ **二手载体、一手读取**：shadertoy 返 403，未直读原页；证据是两份互相独立的 GitHub 拷贝逐字一致（`sentinelweb/processink`、`GalaxyCr8r/solarance-beginnings`）⇒ **人工目视确认 https://www.shadertoy.com/view/ls3Xzn 是硬 AC** | ⚠️⚠️ **`不落地`** —— 兜底的「追到不兼容」分支。**判定已下、撤回未执行 ⇒ 阻断 `epic → main`** |
| `Dots`（`DotGrid`） | **—**（未追到）；paper 有 `dot-grid.ts` 但描述不同 ⇒ **不是**匹配。⚠️ **#281 又追一轮**：一手读全 paper `dot-grid.ts` 与 Inferno `LightGrid.metal`，**均不匹配**；code search 无候选 | — | https://github.com/paper-design/shaders · https://github.com/twostraws/Inferno | **`待追溯（低指纹）`**（#281 分档，不阻断） |
| `Glass`（`RefractiveGlass`） | **—**（主体未追到）；第 1 版曾引 iq 的 SDF 文章。⚠️⚠️ **#281 证伪了上一版的事实主张**：所谓「2025 年 `layerEffect` "liquid glass" 一族的通行形态」——**逐个读完具名的 SwiftUI-Metal 玻璃库后，没有找到这样一族** | `roundedBoxSDF` ⇒ **iq 站点级 MIT**（已追到）；**主体 ⇒ 仍未指认到具名上游** | https://iquilezles.org/articles/ · 逐候选比对表见《`coreDesignRefractiveGlass` 主体的追溯》 | **`待追溯（低指纹）`** —— ⚠️ **由强指纹改判**（三条强档判据逐条不成立，逐常量 grep 零命中）⇒ **不再阻断**；⚠️ **该改判须 `epic → main` 评审显式确认**，不确认则回落 `不落地` |
| `GlassLogo`（落地名 `GlassSymbol`） | **—**（未追到）；同 `Glass`。⚠️ `GlassSymbol.swift` 里**零 provenance 引用**、改名 `GlassLogo → GlassSymbol` 亦未记录 ⇒ **#281 已补**（源码注释加了 provenance 段并同时写出两个名字，便于交叉引用 grep） | 随 `Glass` | — | **`待追溯（低指纹）`**（无自有 shader，档位完全随 `Glass`） |
| `AnimatedLoop` | **—**（未追到）；`SWAnimatedLoop.metal:5-21` 是四个 **hand-tuned styles**、18 个参数，属**独立作品**（第 1 版"调度器无独立算法"是事实误读） | — | — | **`待追溯`** |
| `LiquidChrome` | **—**（未追到）；`SWLiquidChrome.metal:7-9` 自述 "Three sequential value-noise samples are domain-warped"。⚠️ **#281 又追一轮**：paper `liquid-metal.ts` 与 react-bits `LiquidChrome` 均一手读全文 ⇒ **均不匹配**；shadertoy 403，一条线索**未核实、已丢弃** | — | https://github.com/paper-design/shaders · https://github.com/DavidHDev/react-bits | **`待追溯（低指纹）`**（#281 分档，不阻断） |
| `LiquidMetal` | **—**（未追到）；`SWLiquidMetal.metal:26-28` 用 **Ashima simplex 常量**（线索，非匹配）；paper 有 `liquid-metal.ts` 但描述与参数集**不同** | — | https://github.com/ashima/webgl-noise | **`待追溯`** |

**计数校验**：2（MIT）+ 9（Apache-2.0）+ **16**（待追溯）+ 0（自研实现）+ **1**（不落地）= **28** ✅
⚠️ **#281 改动了两档**：`Starfield` 由 `待追溯` 改判 **`不落地`** ⇒ 待追溯 17 → **16**、不落地 0 → **1**。
⚠️ **其余 7 个已落地件仍在 `待追溯`，但全部由 #281 分入低指纹档**（见《清偿条款》表 B）⇒ 不阻断；
`Glass` 那一行的低指纹是**由强指纹改判**而来，须评审确认。
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
| **待追溯** | **16** | ShaderKit 5 + GrainGradient + §C 的 8 个 + FractalClouds / InkSmoke（第 5 轮改判）+ NeuroNoise，**减 `Starfield`**（#281 改判 `不落地`）。⚠️ **其中 #261 已落地的 7 件全部由 #281 分入低指纹档**（《清偿条款》表 B）⇒ 不阻断 `epic → main` |
| **不落地** | **1** | ⚠️⚠️ **`Starfield`（#281）** —— 追到 **Martijn Steinrucken / BigWings《Starfield Tutorial》(2020)**，源码头 **CC BY-NC-SA 3.0**，与本仓 MIT 分发不兼容 ⇒ 命中兜底的「追到不兼容」分支。⚠️ **判定已下、撤回未执行 ⇒ 这是当前唯一阻断 `epic → main` 的裁定项**。<br>（第 1 版判的另 2 个仍维持第 5 轮的 `待追溯` 改判——原理由与 §C 其余项双标）|
| **自研实现** | **0** | ⚠️ 显式写 0——《逐件适用性》左列有 8 个名字，但那是**准入不是结论**；实际落地件经第六条轴复查**无一维持自研** |
| 合计 | **28** | 2 + 9 + 0 + 16 + 1 = 28 ✅ |

⚠️⚠️ **#281 对本表的净效果，一句话**：**阻断项从「1 个强指纹原语 + 10 个未分档的默认强档项」变成「1 个具名不兼容许可的落地件」**。
前者是**没查**造成的阻断，后者是**查出来**的阻断——数字变小了，但严重性变高了，别读反。

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
- ⚠️ **#281 把 `Starfield` 判成 `不落地`，闸②的分子不受影响**：闸②的谓词是
  **「可落地数 ≥ `N_B`」**，而可落地 11 的名单（见下）里**从来没有 `Starfield`**
  ——它一直在 `待追溯` 里。⇒ **11 仍是 11，闸②不重开。**
  ⚠️ 但《汇总与闸②判定》上面那条「分子侧触发器」说的是 §A / §B 的核验失败会让分子掉；
  **`Starfield` 属 §C，掉的是"已落地件数"（8 → 7），不是"可落地数"**——两个数不同，别混
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
- ⚠️⚠️ **#281 新增的署名义务（`epic → main` 前必须落地，逐条不可省）**：
  · **Inigo Quilez —— MIT**（`roundedBoxSDF` + 域扭曲 `q`/`r` 级联两项）：转载 MIT 通知 + 具名；
  · **Lode Vandevenne —— BSD-2-Clause**（`Plasma` 四相正弦）：⚠️ **必须保留版权通知 + 两条条件 + 免责声明全文**，
    一句「参考自 Lode 的教程」**不满足**第 1 条；
  · **Nathan Reed —— CC-BY-4.0**（`wangHash` 的 `seed *= 9` 写法）：署名是**许可条件**；
    另注明算法本身出自 Thomas Wang（Jenkins 称其为公有领域）；
  · **Teschner et al. 2003**：学术引用（常数是事实，不是许可义务）。
  ⚠️ 这四条**替换**了 `ACKNOWLEDGEMENTS.md` 里现存的三处「页面无许可声明」——那三处是**事实错误**，
  #281 已直接改在该文件里，不是留待 #284


### ⚠️ #281 的一手实查清单（逐条可复核）

**本节是 `epic → main` 评审的核对底稿。** 每一行都是**打开来源读到的原文**，
不是搜索摘要；凡未能直读的，**明标 403 / 未读**并说明替代证据。

| # | 读了什么（URL） | 读到的原文（节选，逐字） | 影响 |
|---|---|---|---|
| 1 | `https://iquilezles.org/articles/` | 「**all technical code snippets you'll find are under the MIT license** so you can easily reuse them, but the mathematical/shader art is protected and requires a license for use.」 | ⚠️⚠️ **推翻**本表三处「iq 页面无许可声明」。⇒ q/r 级联 + `roundedBoxSDF` 转 **MIT**，`InkSmoke` 的强档阻断解除 |
| 2 | `https://lodev.org/cgtutor/legal.html` | 「**The source code of QuickCG and all the source code of the examples given in this tutorial and all its articles is released under the following license:** Copyright (c) 2004-2007, Lode Vandevenne / All rights reserved. / Redistribution and use in source and binary forms … *Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.*」 | ⚠️ **推翻**「Plasma 来源页无许可声明」。= **BSD-2-Clause**，带**通知保留义务** |
| 3 | `https://www.reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/` | 代码 `seed *= 9;`（Wang/Jenkins 原式是 `a + (a << 3)`）；页脚「**© 2007–2025 by Nathan Reed. Licensed CC-BY-4.0.**」 | ⚠️ 本仓写的正是 `seed *= 9u` ⇒ 复制的是 **Reed 那一份** ⇒ 署名是**许可条件**。⚠️ 暴露取值域缺 `CC-BY` 档 |
| 4 | `http://www.burtleburtle.net/bob/hash/integer.html` | 「The hashes on this page … are all public domain. **So are the ones on Thomas Wang's page. Thomas recommends citing the author and page when using them.**」 | Wang/Jenkins 那一份是 **PD**；Wang 自己的页（Wayback 2007 快照）通篇无版权/许可字样 |
| 5 | `raw.githubusercontent.com/sentinelweb/processink/.../st_starField_orig.glsl`（另有 `GalaxyCr8r/solarance-beginnings` 独立拷贝逐字一致） | 「`// Starfield Tutorial by Martijn Steinrucken aka BigWings - 2020`」「**`// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.`**」；`Hash21` 用 `123.34, 456.21, 45.32` | ⚠️⚠️⚠️ **`Starfield` 判 `不落地`**，且本仓 `hash21` 第一版的常量与之逐字符一致 ⇒ 接触与复制均有直接证据 |
| 6 | `matthias-research.github.io/pages/publications/tetraederCollision.pdf` §4.1 | 「where p1, p2, p3 are large prime numbers, in our case **73856093, 19349663, 83492791**, respectively.」 | 三个常数是**事实**；论文中**未读到许可声明** ⇒ 义务是学术引用 |
| 7 | `gcc-mirror/gcc` 的 `libstdc++-v3/include/backward/hashtable.h` | `25165843ul, **50331653ul**, 100663319ul, …` | `hash22` 的第四个素数补进原语表（#261 遗留项）|
| 8 | iq 的 `distfunctions2d/` `distfunctions/` `functions/` `distance/` `filterableprocedurals/` 五篇 | **`fwidth` 零出现** | ⚠️ **推翻**「`edgeWidth` 属 iq 的 distance-AA 一族」这一归属 |
| 9 | `https://iquilezles.org/articles/distfunctions/` | `vec3 q = abs(p) - b + r; return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;` | `roundedBoxSDF` 的精确来源是 **3D 页的单半径式**，不是 2D 页的四半径 `vec4` 变体 |
| 10 | Czajnikowski/GlassEffect · krispuckett/SwiftUIShaders · DnV1eX/LiquidGlassKit · BarredEwe/LiquidGlass · twostraws/Inferno · victorBaro/TryMetal · signerlabs/ShipSwift · paper-design/shaders · DavidHDev/react-bits 的 shader 源码与 LICENSE | 逐份读全文，比对结果见各专节 | ⚠️ **证伪**「liquid glass 一族的通行形态」；`DotGrid` / `LiquidChrome` 仍未指认到上游 |

**⚠️ 未能直读的（明标，不得当作已核）**：
`shadertoy.com` 全站返 **403**（`Starfield` 上游原页、`StarNest` 原页、
`LiquidChrome` 的 Shadertoy 线索均未直读）· Victor Baro 的 Medium 文章 **403** ·
Hacking with Swift 的 layerEffect 页 **403**。
⇒ 这四处各自的处置写在对应行/专节，**一律以「人工目视确认」为硬 AC**。

**⚠️ 明确丢弃的线索**：web search 曾给出「Shadertoy 上的 Liquid Chrome 作者是 `morisil`」
——**该断言未能核实（403），已丢弃，不作为证据**。写下来是为了防止它在下一轮被当成已知事实捡回去。

### ⚠️ `epic → main` 的 PR 评审清单（#281 交付；本清单不逐条打勾不得合入）

- [ ] **逐行核对承接编号已填实**：`grep -n 'TBD' docs/shader-provenance.md` 的输出里，
      **不得有任何一行出现在《清偿条款》的表 A / 表 B 内**（现存的 `TBD` 字样只在
      ⓑ 的**规则原文**与本节说明里，那是在讲规则，不是占位符）
- [ ] **表 A / 表 B 无遗漏**：表 A 覆盖《共享原语的逐项出处》全部 7 个 `待追溯` 项，
      表 B 覆盖 #261 落地的全部 8 个本体。⚠️ **`Starfield` 撤回后树上只剩 7 件，
      但表 B 仍保留它那一行**——那一行现在是**撤回的记录**，不是登记；删掉它就等于
      抹掉「为什么这个仓不提供星空 shader」，下一个人会把它重新写回来
- [x] ⚠️⚠️ **`Starfield` 的撤回已执行** —— 整件删除，执行记录见《`Starfield` 的追溯》
      的《执行记录》小节。⚠️ 该小节记着一条**未满足**的前置（Shadertoy 原页的人工目视
      确认，403 未读），评审要读的是那条为何不阻断撤回、却仍阻断任何恢复动作
- [ ] ⚠️ **`Glass`（`RefractiveGlass`）由强指纹改判低指纹一事，评审已显式确认**
      —— 不确认则按兜底回落 `不落地`，撤回预案见其专节
- [ ] **署名义务已落地到 `ACKNOWLEDGEMENTS.md`**：iq（**MIT**，两项）·
      Lode Vandevenne（**BSD-2-Clause**，通知 + 条件 + 免责声明全文）·
      Nathan Reed（**CC-BY-4.0**）· Teschner et al.（学术引用）
- [ ] **已落地件的源码注释与文档零原创声称**（ⓐ）

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
- **未证**：⚠️ **#281 后本行必须改小**——§C 里**已不再是"全部 10 个都未证"**：
  `Starfield` 已追到具名上游与其许可（**CC BY-NC-SA 3.0**）、`InkSmoke` / `FractalClouds`
  的 domain-warp 与 `Plasma` 的四相正弦已追到许可（iq **MIT** / lodev **BSD-2-Clause**）。
  ⇒ **仍未指认到上游的是 6 个**：`Dots`(`DotGrid`) · `Glass` 的主体 · `GlassLogo` ·
  `LiquidChrome` · `AnimatedLoop` · `LiquidMetal`（另 `ramp3` / `edgeWidth` 在原语层同样未指认）。
  ⚠️ **「未指认到上游」不等于「原创」**，这几项一律留在 `待追溯`，低指纹档不阻断
- **#281 新增的一手核实**：见上方《#281 的一手实查清单》10 条（iq 站点级 MIT ·
  lodev BSD-2-Clause · Reed CC-BY-4.0 · Jenkins 关于 Wang 的 PD 断言 · BigWings 的
  CC BY-NC-SA 头 · Teschner PDF §4.1 · libstdc++ 素数表 · iq 五篇零 `fwidth` ·
  iq 3D 页的单半径式 · 九个候选库的源码与 LICENSE）
- **#281 新增的二手 / 未读（明标）**：`shadertoy.com` 全站 **403**
  （`Starfield` 上游原页未直读，证据是两份独立 GitHub 拷贝逐字一致）·
  Victor Baro 的 Medium 文章 **403** · Hacking with Swift 的 layerEffect 页 **403**

⚠️ **第 1 版在此处写「本表没有声称知道那 21 个来自哪里，故日后有人追到也不受影响」——
该辩护随本版作废**：它建立在"追不到"的前提上，而那个前提被一小时的比对推翻了。
