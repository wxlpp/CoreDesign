# Shader 许可来源裁定表（#249 / `shipswift-foundation` 闸②）

> 覆盖 ShipSwift 的全部 **28** 个 Metal shader。**每一行都有裁定，没有空行。**
> 本表是**裁定过程**；对外的许可声明在 `ACKNOWLEDGEMENTS.md`，前者判为可落地的行
> 必须在后者有对应条目。

## 为什么必须做这件事

**Shadertoy 的默认许可是 CC BY-NC-SA 3.0——完全禁止商用**，除非 shader 源码
开头有注释声明了别的许可。CoreDesign 以 MIT 分发，**与 CC BY-NC-SA 不兼容**
（既禁商用，又有传染性 share-alike）。

### ✅ 官方条款原文（**#280 补齐；本节的地基条款自此有一手内容**）

**出处**：`https://www.shadertoy.com/terms`（Shadertoy 官方《Privacy Policy and Terms of
Service》页，"What license will my Shaders have?" 一节）。**逐字**：

> All the shaders you create in Shadertoy are owned by you. You decide which license applies
> to every shader you create. **We recommend you paste your preferred license on top of your
> code, if you don't place a license on a shader, it will be protected by our default license:**
> This work is licensed under a **Creative Commons Attribution-NonCommercial-ShareAlike 3.0
> Unported License**.

同页《Terms of Service》另有一句支撑「许可归作者、且可变更」：

> Although Shadertoy owns the data storage, databases and the Shadertoy site, **the users
> retain all rights to their creations and can decide a specific license for it**.

⚠️⚠️ **载体标注（一手内容 / 归档载体，不是实时页面）**：`shadertoy.com` **全站**在
Cloudflare 挑战后对自动访问返 **403**（`/terms`、`/view/*`、`/embed/*`、`/api/v1/*` 逐个
实测，普通 UA 与浏览器 UA 均 403，响应体为 `<title>Just a moment...</title>`）。
上面的原文是从 **Internet Archive 对官方 URL 本身的快照**读出的：
`https://web.archive.org/web/20250920061115id_/https://www.shadertoy.com/terms`
（快照时间 **2025-09-20**）。

⚠️⚠️ **上一版这里写「2025-03…2025-10 间有 7 个 `statuscode:200` 快照、`digest` 反复为
同一值 `VXQDYWRJX6VUYTNE6MNEYNC5IWHKSI6V` ⇒ 该期间条款文本未变」——第 6 轮终审 I2
复算不成立，本轮换成可复现的写法。** 该窗口实际是 **18 个 200 快照、三个不同 digest**：
9 × `MPDBENGYRF46CLHLYCHQ2EZHIS6SFWAG`、8 × `VXQDYWRJX6VUYTNE6MNEYNC5IWHKSI6V`、
1 × `3I42H3S6NNFQ2MSVX7XZKYAYSCX5QBYJ`（**最后这个是空载荷的 SHA-1**，2025-10-11）。

⇒ **「文本未变」改由逐字比对证明，不再由 digest 证明**（本轮实做，可复现）：取两个
**不同 digest** 的快照 —— `20250920061115`（`VXQDY…`）与 `20251001020819`（`MPDBE…`）
—— 以 `id_` 原样取回并解压，**两份各 29202 字节、MD5 同为
`a2550c88cf19fdad987d8aff09dc5d35`** ⇒ **内容逐字节相同**。
⇒ digest 交替出在**存储层的编码**（一份存 gzip、一份存明文），**不在文本层**。
⚠️ 这一行是全表地基又被标为可重核，**下一个人跑 CDX 会看到 18 / 三个 digest**——
所以必须按上面这个口径读，不要拿 digest 当文本证据。
⇒ **它是官方页面自身的内容，不是第三方转述**（这与 Wikipedia 概述、与第三方 GitHub
拷贝头是三个不同的证据档次）；但**不是实时读取**，快照与"今天"之间有约 11 个月的窗口。
⇒ **降级掉的只有"实时性"，不是"一手性"。** 上一版的 Wikipedia 链接已作废、不再作为依据。

⚠️ **两条由该原文直接推出、下游必须照做的规则**：
① **许可看源码头**——官方明说"没在 shader 上放许可才落到默认许可"，⇒ 逐件裁定必须读到
**那一件的源码头**，站级默认不能替代个案；
② **许可会变**——官方明说用户保留全部权利且可自行决定许可，⇒ **旧拷贝的头部不能证明
现许可**（`Voronoi` 就是活例：2013 年的第三方拷贝头是 CC BY-NC-SA 3.0，现页面是 MIT，
见《#280 的落地前核验》④）。

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
| `待追溯` | 尚未用上面《方法论教训》的方法追过；⚠️ **或已追到具名上游、但该上游没有任何许可声明**（第 6 轮终审 S2 补的限定：`NeuroNoise` / `Water` 就是这一形态——追是追到了，卡在无法正向裁定许可，**照字面读会白白重追一轮**）| **不得据现状落地**；先追一轮。⚠️ 若属后一形态，"追一轮"的内容不是再找上游，而是**取得许可或换实现**（见《#280 的落地前核验》⑥-B 给 `Water` 列的两个出口）|
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
| 1 | `GlassOrb` | [Inferno](https://github.com/twostraws/Inferno) 的 "Warping Loupe"（Paul Hudson） | **MIT**（已核实读取 LICENSE 全文；#280 复核一致） | ⚠️ **#280 下调**。Inferno 的 LICENSE 附逐 shader 移植清单，**6 组**（Circle/Circle Wave/Diamond/Diamond Wave ← PolkaDotsCurtain、Crosswarp、Radial、Swirl、Wind、Genie）；**"Warping Loupe" 不在其中**。⚠️ 第 1 版写"仅含 5 项"**漏数了第一组**；"不在清单 ⇒ 原创"是**推论不是断言**。⚠️⚠️ **#280 发现该推论的前提更弱**：Inferno 的 **README 清单是 7 条**（多一个 `Shimmer`），与 LICENSE 的 6 组**互不一致** ⇒ **清单被自身证明非穷尽**。⇒ 理由改挂两条并列：① Inferno 以 MIT 对整仓授权；② `WarpingLoupe.metal` **函数体零魔数**（逐常量 grep 零命中）且自述派生自 Inferno 自有的 `SimpleLoupe`。**残余风险接受并记录**，见《#280 的落地前核验》③ | **已追到兼容许可 · MIT** |
| 2 | `StarNest` | ["Star Nest" by Pablo Roman Andrioli（Kali）](https://www.shadertoy.com/view/XlfGRj) | **MIT**（作者在源码头声明，覆盖 Shadertoy 默认许可） | ✅ **#280 升档**：读到 **Shadertoy 公开 API 对该 shader 的响应本身**（`GabeRundlett/shadertoy-api-shaders` `shaders/XlfGRj.json`，刷新 2025-05-29），`info.username = "Kali"`，code 头逐字 `// Star Nest by Pablo Roman Andrioli` / `// License: MIT` ⇒ **一手内容 · 归档载体**。⚠️ **上一版在这里写「此前的多个独立移植记录（a-frame / Godot Shaders / openfx-misc / xscreensaver / pythonarcade）与之**逐字一致**」——第 6 轮终审 I3 复算不成立，本轮撤回该说法。** 实读两份：[NatronGitHub/openfx-misc](https://github.com/NatronGitHub/openfx-misc/blob/master/Shadertoy/presets/default/star%20nest-natron.frag.glsl) 头部逐字是 `// Star Nest by Pablo Román Andrioli`（**带重音**）/ `// This content is under the MIT License.`，[urish/aframe-starnest-component](https://github.com/urish/aframe-starnest-component) 内嵌 fragment shader 同为后一种措辞；**与转储的 `// Star Nest by Pablo Roman Andrioli` / `// License: MIT` 是两种措辞**。其余三份本轮**未逐字复核，不再声称**。⇒ **一致的是「具名作者 + MIT 授予」这个事实，不是字面**——而授予本身比逐字一致更强，裁定不受影响。⚠️⚠️ **并按 ④ 对 `Voronoi` 定下的同一把尺（「旧的第三方拷贝不能确立当前许可」），这些移植拷贝在本行只能作旁证，主证是 API 转储本身**——两处必须用同一把尺。⚠️ shadertoy.com 仍全站 403，**非实时** | **已追到兼容许可 · MIT**（⚠️ **人工目视确认仍是硬 AC**，但**不阻断开工**——先验已升档，且失败时 10 → 9 仍 ≥ `N_B`；⚠️ 该头**无版权行、无 MIT 全文**，署名只能写「作者声明 MIT」） |
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
| ⚠️ **#280**（对 §B 的 **移植件** 做，不是对自研声称做）| ✅ 参数签名与描述句**全部对得上，零异常** | `water.ts` 的 `getCausticNoise()` 与 paper 自己标了来源的 `neuro-noise.ts` 是**同一个算法** ⇒ `Water` 掉出 Apache-2.0 档；`shader-utils.simplexNoise` 是 **Ashima `noise2D.glsl` 逐行同构、许可头被删**；`19.19` → **Dave Hoskins**；`0.3183099` → **iq**；`voronoi()` 的 `0.00001` + 变量名 → **iq `ldl3W8`** |

⇒ **裁定：五轴是必要条件，不是充分条件。** 任何「自研实现」的声称，**必须额外**通过
一条函数体判据：

1. **逐常量 grep**（⚠️ **本条无条件适用于任何落地件**，含已追到兼容许可的移植件
   ——第 5 轮终审 I3：它是 **provenance 发现工具**，不是原创性测试。
   `grep 0x27d4eb2d` 会找出一个未署名的 Wang 常数，与外层 shader 标的是
   `自研` / `移植` / `待追溯` 无关；而 §B 的移植件**正是**最需要它的地方
   ——paper 的移植件可能带着**追过 paper 之外**的常数，那正是
   「paper 之上还有一层」在说的事）：把函数体里所有魔数（`0x…`、七位以上素数、`123.34` 这类）拿去搜。
   本仓**六次**命中全部来自这一步（#261 四次 + **#280 两次**：`Water` 的算法同源、
  `shader-utils.simplexNoise` 的 Ashima 身份），**它比五轴便宜一个数量级，却被放在最后**。
  ⚠️ **#280 补一条使用要点**：`Voronoi` 与 `Water` 这两次命中**不是靠魔数**
  （前者只有一个 `0.00001`，后者一个都没有），是靠**把函数体读全 + 拿特征代码行去 code search**。
  ⇒ **判据 1 的正确读法是「逐常量 grep **以及** 逐特征行 code search」**，只 grep 数字会漏。
  ⚠️⚠️ **这条修正的追溯范围，以及它依赖什么（第 6 轮终审 S3 要求写明）**：本修正**不要求
  整体重做既往的零命中结论**——理由是 #281 已对 §C 各项做过 code search（`ramp3` 四种
  措辞、`DotGrid`、`LiquidChrome`），#280 的 ⑥ 表又把 11 件的函数体全读了一遍。
  ⚠️ **但这个"不需要重做"的判断，依赖的是本文档自己的记录，本轮并未独立重跑那些
  code search。** 谁要推翻它，去重跑；谁要沿用它，知道它建立在什么上面。
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
  ——恰恰是本表自述"命中全部来自这一步"的那一步。
  ⇒ ✅ **#280 已按"无条件适用"执行**：对 11 件逐条做了逐常量 grep + 逐结构对照，
  **在 §B 的移植件上抓到 4 处**（`Water` 掉档 + 三份被 paper 删掉的第三方 MIT 通知）
  ⇒ **"§B 不受影响"那个读法被实证证伪，本条的"无条件"是对的。**
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


## §B 追到 `paper-design/shaders` 的 11 个 —— 8 个正向裁定 Apache-2.0 + 3 个待追溯

⚠️ **标题里的 11 是「追到 paper 的件数」，不是「Apache-2.0 档的件数」**——本节内
`NeuroNoise`（上游是无许可推文，paper 的再许可断言无法独立核实）、`GrainGradient`
（参数仅部分匹配、匹配未确认）与 **`Water`（#280 改判：与 `NeuroNoise` 同一算法、
同一条无许可推文，而 paper 连来源都没标）** 三条**均为 `待追溯`**，Apache-2.0 档实为 **8**。
⇒ 与《统一裁定表》《汇总与闸②判定》的 8 逐档一致。

上游：**[paper-design/shaders](https://github.com/paper-design/shaders)，Apache-2.0，
3414 stars，带 `LICENSE` 与 `NOTICE`**（一手核，GitHub API）。

| # | shader | paper 对应文件 | 匹配依据 | 核验者 |
|---|---|---|---|---|
| 8 | `Voronoi` | `voronoi.ts` | 描述句**近逐字** + 参数集全对应 + `randomGB`↔`textureRandomizerGB` | **本人一手** |
| 9 | `NeuroNoise` | `neuro-noise.ts` | 描述句**逐字** + `brightness/contrast/colorFront/colorMid/colorBack` | **本人一手**（⚠️ **匹配确认、许可未确认** ⇒ 裁定 `待追溯`，不在 Apache-2.0 档） |
| 10 | `Swirl` | `swirl.ts` | `bandCount/twist/center/proportion/softness/noise` | 终审 reviewer；⚠️ **#280 已本人一手读全文复核**（含 `shader-utils.ts` 层），匹配成立 |
| 11 | `SimplexNoise` | `simplex-noise.ts` | `stepsPerColor/softness/10 colors`；双层 simplex 叠加 | 终审 reviewer；⚠️ **#280 已本人一手读全文复核**（含 `shader-utils.ts` 层），匹配成立 |
| 12 | **`Water`** | `water.ts` | `highlights/layering/edges/waves/caustic/size/colorBack/colorHighlight` | ⚠️⚠️ **本人一手（#280 读全文）**：匹配确认，**但 `getCausticNoise()` 与 `neuro-noise.ts` 是同一算法、同源于同一条无许可推文** ⇒ **改判 `待追溯`，移出 Apache-2.0 档** |
| 13 | `ColorPanels` | `color-panels.ts` | `density/angle1/angle2/length/edges/blur` | 终审 reviewer；⚠️ **#280 已本人一手读全文复核**（含 `shader-utils.ts` 层），匹配成立 |
| 14 | `DotOrbit` | `dot-orbit.ts` | `size/sizeRange/spreading/stepsPerColor` | 终审 reviewer；⚠️ **#280 已本人一手读全文复核**（含 `shader-utils.ts` 层），匹配成立 |
| 15 | `SmokeRing` | `smoke-ring.ts` | `thickness/radius/innerShape/noiseScale/noiseIterations/colorBack` | 终审 reviewer；⚠️ **#280 已本人一手读全文复核**（含 `shader-utils.ts` 层），匹配成立 |
| 16 | `Metaballs` | `metaballs.ts` | `count/size/colors` | 终审 reviewer；⚠️ **#280 已本人一手读全文复核**（含 `shader-utils.ts` 层），匹配成立 |
| 17 | `Halftone` | `halftone-dots.ts` + `halftone-cmyk.ts` | 两入口一一对应；`classic/gooey/holes/soft`、`originalColors`、`colorC/M/Y/K`。**ShipSwift 自己在 `SWHalftone.metal:350` 写着 "simplified port"** | 终审 reviewer；⚠️ **#280 已本人一手读全文复核**（含 `shader-utils.ts` 层），匹配成立 |
| 18 | `GrainGradient` | `grain-gradient.ts` | 参数**部分**匹配 | 终审 reviewer（**存疑**）；#280 未改判（不在 11 件范围） |

**裁定：#8、#10、#11、#13–#17 共 8 个为 `已追到兼容许可 · Apache-2.0`；
#9 `NeuroNoise`、**#12 `Water`**、#18 `GrainGradient` 为 `待追溯`**
——`NeuroNoise` 与 `Water` 的上游是**同一条无任何许可声明的推文**，
paper 以 Apache-2.0 再许可是 paper 的断言、我们无法独立核实（见下方《paper 之上还有一层》、
《#280 的落地前核验》⑥-B 与《汇总与闸②判定》的第 5 轮终审 I4）；
`GrainGradient` 参数仅部分匹配、匹配未确认。
⚠️ **本行改过两次**：上上版写「#8–17」（10 个），与《统一裁定表》《汇总与闸②判定》的 9 打架
（PR #259 review round-2 指出）⇒ 改为 9；**#280 再减 `Water` ⇒ 8**。**以统一裁定表为准。**

### 落地义务（与 MIT 档不同，别混）

1. 转载 paper 的 **LICENSE 全文**；
2. 转载其 **`NOTICE`**：`Powered by Paper Shaders: https://shaders.paper.design`
   （⚠️ **#280 一手核**：paper 的 `NOTICE` 文件**全文就是这两行**，无任何第三方署名）；
3. **标注修改**（§4(b)）——我们改了参数化与色彩层，属"修改"；
4. 逐 shader 的 `.metal` 文件头注明 paper 的对应 `.ts` 路径。

#### ⚠️⚠️ 5. **paper 之外的第三方 MIT 通知义务（#280 新增，paper 未兑现）**

**Apache-2.0 不能替代第三方的 MIT 通知义务。** 下面三份都是 **MIT**（与本仓兼容，
**不影响可落地判定**），但各自的 "The above copyright notice … shall be included in all
copies" **必须由我们自己转载**——paper 把它们删干净了。

| 来源 | 逐字要转载的 | 影响哪些落地件 | 一手出处 |
|---|---|---|---|
| **Ashima Arts / Stefan Gustavson**（`webgl-noise` 的 2D simplex） | `Copyright (C) 2011 by Ashima Arts (Simplex noise)` / `Copyright (C) 2011-2016 by Stefan Gustavson (Classic noise and others)` + MIT 全文 | `Swirl` · `SimplexNoise`（凡引用 `shader-utils.simplexNoise` 者） | https://github.com/ashima/webgl-noise `LICENSE` 与 `src/noise2D.glsl` |
| **Inigo Quilez** | `// The MIT License` / `// Copyright © 2013 Inigo Quilez` + MIT 全文 | `Voronoi`（两趟 Voronoi 边界算法）· `Halftone`（`0.3183099` hash 形状） | Shadertoy `ldl3W8` 源码头 · https://iquilezles.org/articles/ 站级声明 |
| **David Hoskins** | `Copyright (c)2014 David Hoskins` + MIT 全文 | `Halftone`（`19.19` / `hash23` 一族） | Shadertoy `4djSRW`（"Hash without Sine"）源码头 |

⚠️ **另有一条"不要写"的义务**：`colorBandingFix` 里的 `12.9898/78.233/43758.5453123`
是无从指认著作权人的通行 sin-fract hash ⇒ **署名指向算法本身，不得引 The Book of Shaders**
（本表已实查其 LICENSE 为 `All rights reserved`）。

### ⚠️ paper 之上还有一层 —— **#280 已逐条查完**

**paper 自述的来源标注只有两条**（一手：对**本表相关的 14 个** `shaders/*.ts` +
`shader-utils.ts` 做来源关键词 grep，**该检查集内**的输出只有下面两行 + 一行无关的
参数文档。⚠️ **不是"全仓全量"**——`main` 分支该目录**今日共 30 个** `.ts`，检查集的
完整枚举与理由见 ⑤）：

- `voronoi.ts:14`：`Original algorithm: https://www.shadertoy.com/view/ldl3W8`（iq）。
  ✅ **#280 查实**：现许可为 **MIT**（`// The MIT License` / `// Copyright © 2013 Inigo
  Quilez`，Shadertoy 公开 API 响应，转储 2025-05-29）；三份 2013 vintage 的第三方拷贝头
  仍是 **CC BY-NC-SA 3.0** ⇒ **"许可会变、旧拷贝不能当证据"的活例**，详见
  《#280 的落地前核验》④。⇒ `Voronoi` **可落地**，义务加转载 iq 的 MIT 通知。
- `neuro-noise.ts:33`：`Original algorithm: x.com/zozuar/status/1625182758745128981`
  —— **一条推文，无任何许可声明**（默认保留所有权利）。paper 以 Apache-2.0 再许可
  **是 paper 的断言**，我们无法独立核实 ⇒ `NeuroNoise` 维持 `待追溯`。

⚠️⚠️ **而"paper 没自述"不等于"上面没有一层"——#280 抓到了两处 paper 没标的：**

1. **`water.ts` 与 `neuro-noise.ts` 是同一个算法**（同一循环、同一累加器对、同一归约），
   第三方 `guil` 的 `mlBXRK` 把同一循环独立指向**同一条 zozuar 推文** ⇒
   **`Water` 与 `NeuroNoise` 同因，从 Apache-2.0 档改判 `待追溯`。** 见 ⑥-B。
2. **真正的"上面那一层"在 `shader-utils.ts` 里，不在各 shader 文件里**——§B 的 11 条
   全部从它取原语，而本表此前的比对**只做到 `<shader>.ts`**。该文件里的
   `simplexNoise` 是 **Ashima 的 `noise2D.glsl`**（常量与结构逐行相同、**许可头被整段删除**），
   `proceduralHash21` / `halftone-cmyk.hash23` 是 **Dave Hoskins + iq** 一族。
   三者**都是 MIT ⇒ 不影响可落地**，但通知义务由我们补。见 ⑥-A / ⑥-C 与《落地义务》第 5 条。

⇒ **本节的"落地前必须直读确认"已由 #280 执行完毕**；剩余的只有三项**人工目视**
（shadertoy.com 对自动访问全站 403），清单见《须用户人工完成的核验》。

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

## ⚠️⚠️ #280 的落地前核验（可落地 11 → **10**）

**本节是闸②的第二次实战复查。** 上一版《汇总与闸②判定》逐字写着「11 条中**无条件可落地**
为 0，每条都各带一项落地前必做的核验」；#280 把那 6 项核验逐条做完。**结论是可落地数
减 1（`Water` 掉档），并给全部 10 条补出了此前缺失的三个上游署名义务。**

### 载体分级（本节全篇按这三档标注，不得混用）

| 档 | 含义 | 本节的实例 |
|---|---|---|
| **一手 · 实时** | 今天直接读到发布方自己的页面 / 仓库 | iq `/articles/` 与 `/articles/voronoilines/` · Inferno LICENSE/README/`.metal` · paper LICENSE/NOTICE/`.ts` · Ashima `webgl-noise` |
| **一手内容 · 归档载体** | 内容出自官方 URL 本身，但读的是快照 / API 转储，**非实时** | Shadertoy `/terms`（IA 快照 2025-09-20）· Shadertoy 公开 API 对 `XlfGRj` / `ldl3W8` / `4djSRW` / `mlBXRK` 的响应（第三方转储，刷新于 **2025-05-29**） |
| **二手** | 第三方自己抄写 / 移植的拷贝 | Natron · uniVR · ShaderLoader 三份 `ldl3W8` 拷贝头 |

⚠️ **`shadertoy.com` 全站对自动访问返 403**（Cloudflare 挑战，`/terms` `/view/*` `/embed/*`
`/api/v1/*` 逐个实测；普通 UA / 浏览器 UA / WebFetch 均同）。**本节没有任何一条来自实时
读取 shadertoy.com**——凡涉及它的都落在第 2 档，且各自的「人工目视确认」硬 AC **保留**
（见《须用户人工完成的核验》）。

### ① Shadertoy 官方条款原文 —— ✅ **已补**（一手内容 · 归档载体）

见《为什么必须做这件事》的新增小节。**全表地基自此不再只有一条 Wikipedia 概述。**
两条派生规则（许可看源码头 / 许可会变）已写在那一节，下游按那两条执行。

### ② `StarNest`（MIT · Shadertoy `XlfGRj`）—— ✅ **确认**（一手内容 · 归档载体）

**读到的是 Shadertoy 公开 API 对该 shader 的响应本身**（`api/v1/shaders/XlfGRj` 的 JSON），
经第三方转储仓 `GabeRundlett/shadertoy-api-shaders`（`shaders/XlfGRj.json`）取得，
该文件最近一次刷新 commit 为 **2025-05-29**（`Update shaders May 29, 2025`；仓库 README
自述"a back-up of all the shaders made public through the Shadertoy API"）。

- `info`：`{"name": "Star Nest", "username": "Kali", "date": "1371432930"}`（= 2013-06-17）
- `renderpass[0].code` 的**前两行逐字**：

  ```glsl
  // Star Nest by Pablo Roman Andrioli
  // License: MIT
  ```

⇒ 载体是 **API 响应本身**而非移植拷贝 ⇒ **主证在此**。
**裁定维持 `已追到兼容许可 · MIT`。**

⚠️⚠️ **上一版在这里写「与……五个独立移植**逐字一致**」——第 6 轮终审 I3 复算不成立，撤回。**
实读 `NatronGitHub/openfx-misc` 与 `urish/aframe-starnest-component` 两份，头部逐字为
`// Star Nest by Pablo Román Andrioli`（**带重音**）/ `// This content is under the MIT License.`
——**与转储的 `// Star Nest by Pablo Roman Andrioli` / `// License: MIT` 是两种措辞**；
两种写法在公开代码里都广泛流传。其余三份（xscreensaver / Godot Shaders / pythonarcade）
本轮**未逐字复核**，不再声称。⇒ **一致的是「具名作者 + MIT 授予」这个事实，不是字面。**
⚠️ **标准一致性（本轮补正）**：④ 对 `Voronoi` 已裁定「旧的第三方拷贝**不能**确立当前许可」。
同一把尺对 `StarNest` 也适用 ⇒ **移植拷贝在这里只作旁证，主证是 API 转储**。
上一版对两件用了两把尺，本轮统一。

⚠️⚠️ **对转储本身的交叉验证（第 6 轮终审补的缺口：转储是可以被篡改的）**——
`shaders/XlfGRj.json` 在 `90091f43d47a`（**2024-10-06**，initial commit）与
`f6d538adf936`（**2025-05-29**，Update shaders）两个版本里，`renderpass[0].code`
**逐字节相同**；两版之间只有 `likes`（1300 → 1414）、`viewed`（91276 → 103929）、
`usePreview`（1 → 0）三个计数字段变了。
⇒ **同一份 `// Star Nest by Pablo Roman Andrioli` / `// License: MIT` 头在该仓存在了
至少 8 个月且未被改动过**，不是一次性写入的孤证。
（`Voronoi` 的同类交叉验证，另加两条非转储载体，见 ④ 的 (b′)。）

⚠️ **两条必须写下的瑕疵，不掩盖**：
1. 该头**只写 `License: MIT`，既无版权行、也无 MIT 全文** ⇒ 是一个**形式不完整的 MIT 授予**
   （MIT 自身要求"the above copyright notice"，而这里没有 "above copyright notice"）。
   落地时的署名写法只能是「Star Nest — Pablo Roman Andrioli (Kali)，作者声明 MIT」，
   **不得替作者补造一行版权声明**。
   ⚠️ **本轮补一条限定**：移植拷贝里的措辞变体（`Román` + `This content is under the
   MIT License.`）说明**该头部的文本可能随时间变过** ⇒ 本条 caveat 只对**转储所记的那一版
   头部**成立；人工目视核验（下方转交清单第 1 项）要照抄**当天页面上的实际写法**，
   不要照抄本表。
2. 载体仍是归档，**人工目视确认 `https://www.shadertoy.com/view/XlfGRj` 的硬 AC 保留**
   （但先验已从"五份二手拷贝"升级为"API 响应本身"）。

### ③ `GlassOrb`（MIT · Inferno）—— ⚠️ **推论未被推翻，但其前提被证明比上一版说的弱**

四条一手实时读取（今天）：

| 读了什么 | 读到的 |
|---|---|
| `raw.githubusercontent.com/twostraws/Inferno/main/LICENSE` | MIT（Copyright (c) 2023 Paul Hudson and other authors）+ 移植清单 **6 组**：Circle/Circle Wave/Diamond/Diamond Wave ← PolkaDotsCurtain · Crosswarp · Radial · Swirl · Wind · Genie。**"Warping Loupe" 不在其中**（复核了本表 §A #1 的"6 组"计数，正确） |
| `.../main/README.md`（License 一节） | 移植清单在这里是 **7 条**——**多出 `Shimmer`**（"inspired by SwiftUI-Shimmer by markiv; ported to Metal by @bwhtmn"）。"Warping Loupe" 同样不在其中 |
| `.../Sources/Inferno/Shaders/Transformation/WarpingLoupe.metal` | 文件头只有 `// See LICENSE for license information.`，**无任何上游标注**；文档注释自述 **"This works identically to the simple loupe shader, except that we add back to the zoom some amount of our distance"** ⇒ 由 Inferno **自己的** `SimpleLoupe.metal` 派生 |
| GitHub API：该文件的 commit 历史 / 仓库 commit 总数 | 仓库全部历史 **98 个 commit，最早 2023-11-16**；该 `.metal` 只在 2023-11-30 的 `First pass at SPM support`（目录搬迁）里出现过 ⇒ **无早于批量导入的历史可追** |

⚠️⚠️ **对上一版理由的下调，必须显式记录**：本表 §A #1 与《统一裁定表》把裁定挂在
「**不在 Inferno LICENSE 的移植清单内 ⇒ 推论为其原创**」上。**这个前提比上一版描述的弱**
——因为 Inferno **自己的两份清单不一致**（LICENSE 6 组 / README 7 条，差一个 `Shimmer`）
⇒ **该清单被自身证明不是穷尽的**，"不在清单上"能推出的东西相应变少。

**支持不掉档的证据（同为一手）**：
- **逐常量 grep 零命中**：`warpingLoupe` 函数体里**没有任何魔数**——全部字面量是
  `0.0h` / `1.0h` / `2.0h` 与 `smoothstep`，算式为 `delta * totalZoom + center` 的
  UV 位移放大镜。**没有可供追溯的指纹，也没有可供隐藏抄袭的指纹。**
- Inferno 的 LICENSE 对整仓声明 MIT，且其移植清单自述 "All licenses are MIT"。

⇒ **裁定维持 `已追到兼容许可 · MIT`，但把理由改写为两条并列**（不再只挂在"不在清单上"）：
① Inferno 以 MIT 对整仓授权，我们的直接上游许可清楚；
② 该件函数体零指纹、且自述派生自 Inferno 自有的 `SimpleLoupe` ⇒ 无第三方上游的迹象。
⚠️ **残余风险如实写**：若 "Warping Loupe" 其实是一个**未登记**的、来自非 MIT 来源的移植，
Inferno 的 MIT 对它就是无权再许可，我们跟着错。**该风险与 #280 之前同类，但因清单被证
非穷尽而略有上升。** 这不是可以靠再查一轮消除的风险（追不到就是追不到），是要**接受并记录**的。

### ④ `Voronoi`（`ldl3W8`）—— ✅ **确认为 MIT**；**许可确实变过，且变的方向对我们有利**

⚠️ **这一条最容易读反，两条证据必须一起读：**

**(a) 旧拷贝 = CC BY-NC-SA 3.0（二手，三份互相独立，逐字一致）**

| 拷贝 | 头部逐字 |
|---|---|
| `NatronGitHub/openfx-misc` · `Shadertoy/presets/default/voronoi distance-natron.frag.glsl` | `// https://www.shadertoy.com/view/ldl3W8` / `// Created by inigo quilez - iq/2013` / **`// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.`** |
| `fenollp/uniVR` · `data/shaders/glsl/public/ldl3W8,voronoi___distances.glsl` | 同上（另带 `// Shader downloaded from ...` 与 `Name: Voronoi - distances`） |
| `leadedge/ShaderLoader` · `Shaders/Revised/ShaderToy-ldl3W8#_voronoi-distances.txt` | 同上 |

⇒ **拿这三份中任何一份当证据，都会得出 `不落地`。这正是本表警告过的陷阱。**

**(b) 现许可 = MIT（一手内容 · 归档载体：Shadertoy 公开 API 响应，刷新于 2025-05-29）**

`GabeRundlett/shadertoy-api-shaders` · `shaders/ldl3W8.json`：
- `info`：`{"name": "Voronoi - distances", "username": "iq", "date": "1369238474"}`
- `renderpass[0].code` **前五行逐字**：

  ```glsl
  // The MIT License
  // Copyright © 2013 Inigo Quilez
  // https://www.youtube.com/c/InigoQuilez
  // https://iquilezles.org/
  // Permission is hereby granted, free of charge, to any person obtaining a copy of this software …
  ```

  （MIT 全文在同一行内展开，含 "The above copyright notice and this permission notice shall
  be included in all copies or substantial portions of the Software."）

**(b′) 对转储本身的交叉验证（第 6 轮终审补的缺口：转储是可以被篡改的）**

上一版只有 (b) 这一个仓库承载，**结论不该只靠单一仓库**。本轮补三条：

1. **同一转储的两次提交内容一致**（一手内容 · 归档）：`shaders/ldl3W8.json` 在
   `90091f43d47a`（**2024-10-06**，initial commit）与 `f6d538adf936`（**2025-05-29**，
   Update shaders）两个版本里，`renderpass[0].code` **逐字节相同**；两版之间只有
   `likes`（553 → 575）、`viewed`（112999 → 122212）、`usePreview`（1 → 0）三个计数字段变了。
   ⇒ **同一份 MIT 头在该仓存在了至少 8 个月且未被改动过。**
2. **非转储的独立载体之一**（二手 · 归档）：`diwi/PixelFlow` ·
   `examples/Shadertoy/Shadertoy_VoronoiDistances/data/VoronoiDistances.frag` **`:31-33`**
   逐字带 `// The MIT License` / `// Copyright © 2013 Inigo Quilez` + MIT 全文
   （该文件提交于 **2017-10-07**）。
3. **非转储的独立载体之二**（二手 · 归档）：`studentutu/shadertoy-to-unity-URP` ·
   `Assets/UmutBebek/URP/ShaderToy/Scenes and Shaders/Voronoi - distances ldl3W8.shader`
   **`:145-147`** 同样逐字带 MIT 头（提交于 **2020-07-11**）。

⚠️ **这三条的作用要说准**：它们**不确立"今天的许可"**——按本表对 `Voronoi` 自己定下的
尺子，旧的第三方拷贝不能确立当前许可（(a) 的三份 2013 拷贝就是反例）。
它们确立的是**转储没有被伪造**：一份 2017 的拷贝与一份 2020 的拷贝都已经是 MIT ⇒
**许可变更发生在 2013 与 2017 之间，且此后 MIT 一直稳定**，与 (b) 完全吻合。
⇒ **载体档次**：(b) = 一手内容 · 归档载体；(b′)-1 = 同上（同一载体的时间维交叉）；
(b′)-2/3 = **二手 · 归档**（旁证，不作主证）。

**(c) 独立第二条通路（一手 · 实时，今天读取，完全绕开 shadertoy.com）**

iq 把**同一个算法**发表在自己站点的文章里：`https://iquilezles.org/articles/voronoilines/`
（"Voronoi edges"）。该页的最终算法小节给出 `float voronoiDistance( in vec2 x )`，
即 `res = 8.0` 起手的**两趟**邻域搜索 + `dot(0.5*(a+b), normalize(b-a))` 边界距离
——与 `ldl3W8` 的 `voronoi()` 是同一份代码。而其父页 `https://iquilezles.org/articles/`
逐字（今天一手复核，与 #281 读到的一致）：

> **all technical code snippets you'll find are under the MIT license** so you can easily reuse
> them, but the mathematical/shader art is protected and requires a license for use.

⇒ **(b) 与 (c) 互相独立，指向同一结论。** `Voronoi` **裁定维持可落地**。

⚠️ **档位改判：`已追到兼容许可 · Apache-2.0` → `已追到兼容许可 · Apache-2.0 + MIT（双层）`**
——理由见下方 ⑥ 的逐行比对：paper 的 `voronoi()` 是 iq 代码的**结构性逐行复制**
（连变量名 `ip`/`fp`/`mg`/`mr`/`md` 与 `0.00001` 守卫都保留），**paper 的 Apache-2.0 不能
替代 iq 的 MIT 通知义务**。落地义务因此**多一条**：转载 `// The MIT License / Copyright ©
2013 Inigo Quilez` 及 MIT 全文。

⚠️ **残余口径分歧，写下来不替 owner 拍板**：iq 的站级声明有一句 **"but the
mathematical/shader art is protected"**。`voronoiDistance` 是**技术代码片段**而非
"shader art"（它是文章正文里的工具函数），本表按"技术代码片段"读；但**这一句的边界由
iq 单方定义，不是我们能穷尽的**。若评审不接受这一读法，通路 (c) 失效，仍有通路 (b)
（源码头的完整 MIT）独立成立 ⇒ **结论不变**。

### ⑤ §B 的 8 条「paper 之上还有一层」—— ✅ **逐条查完**（一手 · 实时）

**做法**：一手取 `paper-design/shaders` `main` 分支下**与本表相关的 14 个**
`packages/shaders/src/shaders/*.ts` + `packages/shaders/src/shader-utils.ts` +
`LICENSE` + `NOTICE`，对**这些文件**做 `grep -n -i -E 'original algorithm|based on|
adapted|credit|author|thanks|inspired|shadertoy|iquilezles|https?://|copyright|license|
ashima|stefan|gustavson|@\w+'`。

⚠️⚠️ **检查集的完整枚举（第 6 轮终审 I4：上一版写「全部 14 个」，对仓库的描述是错的）**：
`main` 分支 `packages/shaders/src/shaders/` **今日共 30 个 `.ts`**，本次读的是其中
**14 个** —— §B 的 11 件对应的 12 个文件（`voronoi` / `neuro-noise` / `swirl` /
`simplex-noise` / `water` / `color-panels` / `dot-orbit` / `smoke-ring` / `metaballs` /
`halftone-dots` / `halftone-cmyk` / `grain-gradient`）**＋** 两个候选比对件
（`dot-grid` / `liquid-metal`）。
**未读的 16 个**（`dithering` / `fluted-glass` / `gem-smoke` / `god-rays` / `heatmap` /
`image-dithering` / `lens-distortion` / `mesh-gradient` / `paper-texture` / `perlin-noise` /
`pulsing-border` / `spiral` / `static-mesh-gradient` / `static-radial-gradient` / `warp` /
`waves`）**与本表 28 件无对应关系** ⇒ 不在检查集内。
⇒ **⑤ 的结论只覆盖这 14 个，而八条未查项全在其中 ⇒ 结论成立**；但**不得读成"paper 仓
已被穷尽"**——它没有。

**结果（上述 14 文件 + `shader-utils.ts` 检查集内的完整输出，3 行命中）**：

```
neuro-noise.ts:33: * Original algorithm: https://x.com/zozuar/status/1625182758745128981/
voronoi.ts:14:     * Original algorithm: https://www.shadertoy.com/view/ldl3W8
water.ts:17:       * - u_waves (float): Additional distortion based on simplex noise, …
```

（第三行是参数文档，不是来源标注。）

⇒ **`Swirl` / `SimplexNoise` / `Water` / `ColorPanels` / `DotOrbit` / `SmokeRing` /
`Metaballs` / `Halftone` 八条，paper 均无 `Original algorithm:` 自述。**

⚠️⚠️ **但"paper 没自述"≠"paper 之上没有一层"——这正是 `Starfield` 的失败形态。**
所以 ⑤ 不止于 grep 自述行：本次把八条的 **shader 函数体逐个读全**，并对每条挑 1–2 句
**特征代码行**做 GitHub code search（排除 paper 自身与其下游拷贝）。结果并入 ⑥。

**⑤ 单独产出的一条硬结论**：`shader-utils.ts` 是本表此前**从未看过的一层**——
§B 的 11 条**全部**从它取原语，而**上一版的比对只做到 `<shader>.ts`**。
⇒ **§B 的"paper 之上还有一层"真正的那一层在 `shader-utils.ts` 里，不在各 shader 文件里。**

⚠️ **该文件的导出是 10 个，不是 6 个**（第 6 轮终审 S1：上一版只列了 6 个，而这一节的
标题恰恰是"此前没人看过的那一层"）。逐个列全，并标出本表是否有件用到：

| 导出 | GLSL 符号 | 可落地 10 件用到？ | 备注 |
|---|---|---|---|
| `declarePI` | `PI` / `TWO_PI` | ✅ | 常数定义，无出处问题 |
| `rotation2` | `rotate(vec2,float)` | ✅ | 2×2 旋转矩阵，事实性构造 |
| `proceduralHash11` | `hash11(float)` | ❌ | ⚠️ §B 内**唯一使用者是 `grain-gradient.ts`**（`import` 于文件头，调用在 `:212`），而 `GrainGradient` 是 `待追溯`、不在可落地 10 件内。与 `hash21` 同族（`0.3183099` / `19.19` = iq + Dave Hoskins 谱系）|
| `proceduralHash21` | `hash21(vec2)` | ✅（`halftone-dots`）| 已追溯：Hoskins / iq，见 ⑥-C |
| `proceduralHash22` | `hash22(vec2)` | ❌ **§B 全 11 件均未使用** | ⚠️ 同上，同族 |
| `textureRandomizerR` | `randomR(vec2)` | ✅ | 从 `u_noiseTexture` 采样 |
| `textureRandomizerGB` | `randomGB(vec2)` | ✅ | 同上 |
| `colorBandingFix` | 内联 dither 行 | ✅ | 通行 sin-fract hash，署名指向算法本身 |
| `simplexNoise` | `permute` / `snoise` | ✅ | = Ashima `noise2D.glsl`，许可头被 paper 删，见 ⑥ |
| `fiberNoise` | `fiberRandom` / `fiberValueNoise` / `fiberNoiseFbm` / `fiberNoise` | ❌ **§B 全 11 件均未使用** | 亦从 `u_noiseTexture` 采样（`.b` 通道）|

⇒ **本轮实查（检查集 = §B 的 11 件对应的 12 个 `.ts`，逐个读 `import` 语句与调用点）**：
`proceduralHash22` / `fiberNoise` **11 件全未使用**；`proceduralHash11` **只被
`GrainGradient` 使用**，而它是 `待追溯`、不在可落地 10 件内。
⇒ **可落地 10 件对这三个原语零依赖 ⇒ 没有遗漏的通知义务。**
⚠️ **但 `hash11` / `hash22` 与已追溯的 `hash21` 同属 Hoskins / iq 家族**（同样的
`0.3183099` / `0.3678794` / `19.19`）⇒ **将来若有件用到，通知义务与 `hash21` 相同**，
不必重追一轮。

⚠️⚠️ **口径提醒（第 6 轮终审 I1 的同族盲区）**：按**共享原语名**（`randomR` / `hash21` /
`snoise` …）匹配会**漏掉在 shader 文件里本地重定义的等价物**。本轮按「本地等价定义」
的口径把可落地 10 件复查了一遍，结果见下方 ⑤-bis。

### ⑤-bis 「本地等价定义」复查（第 6 轮终审 I1 要求，可落地 10 件逐个）

⚠️ **盲区的形态**：按共享原语名匹配 ⇒ **在 `<shader>.ts` 里本地重定义的等价函数会逃逸**。
本表**抓到过一次**（`water.ts` 已 `import rotate()` 却又本地写 `rotate2D`），
**又漏掉过一次**（`halftone-cmyk.ts` 本地写 `randomRG`，见下）。⇒ 本轮逐件重查。

| 件 | 本地定义的函数（`<shader>.ts` 内） | 是否共享原语的等价物 | 结论 |
|---|---|---|---|
| `GlassOrb` | —（非 paper 件，Inferno `.metal`）| — | 无 |
| `StarNest` | —（非 paper 件，Shadertoy 原文）| — | 无 |
| `Voronoi` | `voronoi()` | ❌ | 已由 ⑥ #3 处置（iq） |
| `Swirl` | 无（全部走 `import`）| — | 无 |
| `SimplexNoise` | `getNoise` / `steppedSmooth` | ❌ | 无 |
| `ColorPanels` | `getPanel` / `blendColor` | ❌ | 无 |
| `DotOrbit` | `voronoiShape` | ❌ | 已由 ⑥ 处置（Worley 谱系） |
| `SmokeRing` | `valueNoise` / `fbm` / `getNoise` / `getRingShape` | ⚠️ `valueNoise` 与 `shader-utils.fiberValueNoise` 同形 | 双线性 value noise = **事实性算法**，无新义务 |
| `Metaballs` | `noise(float)` / `getBallShape` | ❌（`noise` 建在 `import` 的 `randomR` 上）| 无 |
| **`Halftone`** | `halftone-cmyk.ts:98` **`randomRG`**、`:102` `hash23`、`:108` `sst`、`:112` `valueNoise3`；`halftone-dots.ts:70` `valueNoise`、`:87` `sst` … | ⚠️⚠️ **`randomRG` 是 `textureRandomizerR/GB` 的本地等价物** | ⇒ **`Halftone` 也依赖 `u_noiseTexture`**，见下 |

⚠️⚠️ **本轮新发现（第 6 轮终审 I1）**：`halftone-cmyk.ts:80` 声明 `uniform sampler2D
u_noiseTexture;`，`:98-101` **本地定义**等价随机器，`:171` 真的调用：

```glsl
vec2 randomRG(vec2 p) { vec2 uv = floor(p) / 100. + .5; return texture(u_noiseTexture, fract(uv)).rg; }
…
return cellCenter + (randomRG(cellCenter + channelIdx * 50.) - .5) * u_gridNoise;
```

⇒ **依赖 `u_noiseTexture` 的是 5 件，不是 4 件**（`Voronoi` / `DotOrbit` / `SmokeRing` /
`Metaballs` **＋ `Halftone`**）。成本模型已按此更正，见《`N_B` 重估》。
⚠️ 该发现**不改变任何裁定档位**——`randomRG` 是从一张随包纹理里采样的一行代码，
无可归属的第三方著作权人；它改变的**只有落地工时**。

⚠️ 顺带记一条**不是问题**的观察：`halftone-cmyk.ts` 没有 `import rotation2`，而是在
`:175` / `:219-222` 直接内联 `mat2(cos,±sin,∓sin,cos)`。旋转矩阵是事实性构造，
**不产生通知义务**；列在这里只是为了让下一个人知道这一处也查过了。

### ⑥ 逐常量 grep + 逐结构对照（无条件适用，11 件全做）

⚠️ 本条按《第六条轴》与《第六条轴的生效范围》执行：**判据 1（逐常量 grep）无条件适用，
§A / §B 亦不豁免**。并按 #281 的教训**双向**做——既防低估抄袭，也防把事实性算法错绑到
某个来源上。

| # | 件 | 上游函数体 | 逐常量 / 逐结构结果 | 处置 |
|---|---|---|---|---|
| 1 | `GlassOrb` | Inferno `WarpingLoupe.metal` | **零魔数**（只有 `0.0h`/`1.0h`/`2.0h`）⇒ **零命中** | 无新义务 |
| 2 | `StarNest` | Shadertoy `XlfGRj` 全文 | 常量全部是它**自有的 `#define` 参数块**（`iterations 17` / `formuparam .53` / `volsteps 20` / `stepsize .1` / `zoom .8` / `tile .85` / `speed .01` / `brightness .0015` / `darkmatter .3` / `distfading .73` / `saturation .85`）；核心式 `p=abs(p)/dot(p,p)-formuparam` 是作者自己的 kaliset ⇒ **零外部命中** | 无新义务 |
| 3 | `Voronoi` | paper `voronoi.ts` `voronoi()` | ⚠️⚠️ **命中**：`md = 8.` 起手 → `-1..1` 首趟 → `-2..2` 次趟 → `if (dot(mr-r, mr-r) > .00001)` → `md = min(md, dot(.5*(mr+r), normalize(r-mr)))`，**与 iq `ldl3W8` 的 `voronoi()` 逐行同构，且变量名 `ip`/`fp`/`mg`/`mr`/`md`/`g`/`o`/`r`/`d` 全部保留**；`0.00001` 是逐字相同的魔数 | ⇒ **iq MIT 通知义务**（见 ④） |
| 4 | `Swirl` | paper `swirl.ts` + `shader-utils.simplexNoise` + `colorBandingFix` | ⚠️⚠️ **命中 Ashima 常量组**（见下方专段）。`swirl.ts` **本体**：特征行 `float offset = pow(l, -twist) + angle_norm;` 与 `ceil(u_bandCount) * atan(...)` 的 code search 命中 **31 / 29 条，全部是 paper 自身与其下游拷贝** ⇒ 本体**未指认到上游** | ⇒ **Ashima/Gustavson MIT 通知义务** |
| 5 | `SimplexNoise` | paper `simplex-noise.ts` + `simplexNoise` | ⚠️⚠️ **命中 Ashima 常量组**。本体是 2 层 snoise 叠加 + 分色阶，无其他命中 | ⇒ **Ashima/Gustavson MIT 通知义务** |
| 6 | **`Water`** | paper `water.ts` + `simplexNoise` | ⚠️⚠️⚠️ **两处命中**：① Ashima 常量组；② `getCausticNoise()` 与 paper **自己标了来源的** `neuro-noise.ts` **是同一个算法**（详见下方专段） | ⇒ ⚠️ **掉出 Apache-2.0 档**，改判 `待追溯` |
| 7 | `ColorPanels` | paper `color-panels.ts` + `colorBandingFix` | 本体零命中（透视板扫描，`getPanel` / `blendColor` 为 paper 自有）；只经 `colorBandingFix` 带 `12.9898/78.233/43758.5453123` | ⇒ 仅 dither 折衷（见下） |
| 8 | `DotOrbit` | paper `dot-orbit.ts` | 零常量命中。`voronoiShape()` 是**通用单趟 F1 Voronoi**（Worley 1996 谱系，事实性算法），**不是** iq 的两趟边界算法；动画项 `.5 + spreading * cos(t + TWO_PI * rand)` 是 iq `0.5+0.5*sin(iTime+6.2831*o)` 的**参数化回声**（常量已符号化） | 署名指向**算法谱系**，不绑具体作品 |
| 9 | `SmokeRing` | paper `smoke-ring.ts` + `colorBandingFix` | `valueNoise()` = 教科书双线性 value noise（`f*f*(3-2f)`），`fbm` 用 lacunarity `1.99` / gain `0.65` ⇒ **事实性算法**（Perlin–Musgrave 谱系），按本表《The Book of Shaders 的许可实查结果》的既定处置：**署名指向算法，不绑教学资源** | 仅 dither 折衷 |
| 10 | `Metaballs` | paper `metaballs.ts` + `colorBandingFix` | 零命中。`getBallShape` 用 `pow(1-clamp(.5*len),p)` ——**不是** Blinn/Wyvill 的任何标准 metaball 落差式 ⇒ paper 自有。`2503.4` 是首帧时间偏移，不是 hash 常量 | 仅 dither 折衷 |
| 11 | `Halftone` | paper `halftone-dots.ts` + `halftone-cmyk.ts` + `shader-utils.proceduralHash21` | ⚠️⚠️ **命中 `19.19` 与 `0.3183099`**（详见下方专段） | ⇒ **Dave Hoskins MIT + iq MIT 通知义务** |

#### ⚠️⚠️ ⑥-A：`shader-utils.simplexNoise` **是 Ashima 的 `noise2D.glsl`，且许可头被整段删除**

**两边都一手读全文**：`paper-design/shaders` `packages/shaders/src/shader-utils.ts:63-91`
对 `ashima/webgl-noise` `src/noise2D.glsl`（与 `stegu/webgl-noise` 的同名文件 `diff` 为**完全一致**）。

- **常量逐字相同**：`0.211324865405187` · `0.366025403784439` · `-0.577350269189626` ·
  `0.024390243902439` · `1.79284291400159` · `0.85373472095314` · `130.0` · `mod(…, 289.0)` · `34.0`
- **结构逐行相同**：`i1 = (x0.x > x0.y) ? vec2(1.0,0.0) : vec2(0.0,1.0);` 的三元式、
  `vec4 x12 = x0.xyxy + C.xxzz;` `x12.xy -= i1;`、`m = m*m; m = m*m;`、
  `g.yz = a0.yz * x12.xz + h.yz * x12.yw;`、`return 130.0 * dot(m, g);` ——**一句不差**
- **paper 侧的改动只有三处**：`mod289()` 内联为 `mod(x, 289.0)`；`permute` 的 `+10.0` 写成
  `+1.0`（等价的通行变体）；**注释与许可头全部删除**
- **上游 LICENSE（一手读全文）**：`ashima/webgl-noise` `LICENSE` =
  `Copyright (C) 2011 by Ashima Arts (Simplex noise)` /
  `Copyright (C) 2011-2016 by Stefan Gustavson (Classic noise and others)`，**MIT**，
  含 "The above copyright notice and this permission notice **shall be included in all copies
  or substantial portions of the Software**."

⇒ **两条结论，方向相反，都必须写：**
1. **许可兼容** —— MIT ⊆ 本仓 MIT 分发 ⇒ **`Swirl` / `SimplexNoise` 不掉档。**
2. ⚠️ **但义务不由 paper 的 Apache-2.0 兑现** —— paper 的 `NOTICE` 只有
   "Powered by Paper Shaders"，**没有 Ashima / Gustavson 的一个字**。我们再分发这段代码时，
   MIT 要求的"上述版权声明"**必须由我们自己补上**。
   ⇒ **新增落地义务**：凡落地引用 `simplexNoise` 的件（`Swirl`、`SimplexNoise`；`Water`
   若日后回档亦同），`ACKNOWLEDGEMENTS.md` 与 `.metal` 头**必须**转载
   Ashima Arts + Stefan Gustavson 的 MIT 版权声明与许可全文。

#### ⚠️⚠️⚠️ ⑥-B：`Water` 与 `NeuroNoise` 是**同一个算法**，而只有后者标了来源

`water.ts` 的 `getCausticNoise()`（一手读全文）：

```glsl
vec2 n = vec2(.1); vec2 N = vec2(.1);
mat2 m = rotate2D(.5);
for (int j = 0; j < 6; j++) {
  uv *= m;  n *= m;
  vec2 q = uv * scale + float(j) + n + (…)*t;
  n += sin(q);
  N += cos(q) / scale;
  scale *= 1.1;
}
return (N.x + N.y + 1.);
```

`neuro-noise.ts` 的 `neuroShape()`（一手读全文，**paper 自己标着**
`Original algorithm: https://x.com/zozuar/status/1625182758745128981/`）：

```glsl
vec2 sine_acc = vec2(0.); vec2 res = vec2(0.); float scale = 8.;
for (int j = 0; j < 15; j++) {
  uv = rotate(uv, 1.);  sine_acc = rotate(sine_acc, 1.);
  vec2 layer = uv * scale + float(j) + sine_acc - t;
  sine_acc += sin(layer);
  res += (.5 + .5 * cos(layer)) / scale;
  scale *= 1.2;
}
return res.x + res.y;
```

**同一循环、同一累加器对（`n`/`N` ↔ `sine_acc`/`res`）、同一 `rotate → q = uv*scale + j +
acc ± t → acc += sin(q) → out += cos(q)/scale → scale *= 1.1~1.2` 五步、同一 `x + y` 归约。**
`water.ts` 还**本地重新定义了一次** `mat2 rotate2D(float r)`——尽管同文件已 `import` 了
`rotation2` 的 `rotate()`；这是**从别处整段搬运**的典型痕迹。

**第三方独立佐证（一手内容 · 归档载体）**：Shadertoy `mlBXRK`
（`{"name": "Wet neural network", "username": "guil", "date": "1676317529"}`）的
`description` 逐字 `Forked from newl shader from Yonatan :
https://twitter.com/zozuar/status/1625182758745128981`，其代码为
`p*=m; n*=m; q=p*S+j+n+t; n+=sin(q); N+=cos(q)/S; S*=1.2;` ——**与上面两份是同一份东西**。
⇒ **两个互相独立的第三方（paper 与 guil）把同一个循环指向同一条 zozuar 推文。**
（`mlBXRK` 自身**无许可头** ⇒ 按 ① 的官方条款，落 Shadertoy 默认 **CC BY-NC-SA 3.0**。）

⇒ **`Water` 与 `NeuroNoise` 的上游是同一条推文，而推文无任何许可声明（默认保留所有权利）。**
本表第 5 轮终审 I4 已按《正向裁定，不证否定》把 `NeuroNoise` 从 Apache-2.0 档移出，
理由逐字是「paper 以 Apache-2.0 再许可**是 paper 的断言，我们无法独立核实**」。
⇒ **同一理由对 `Water` 完全适用，只是 paper 这次连来源都没标。**
**`Water` 改判 `待追溯`。Apache-2.0 档 9 → 8，可落地 11 → 10。**

⚠️ **不得读成 `不落地`**：我们**没有**证据说那条推文的许可与 MIT 不兼容——我们证明的是
**无法正向裁定**。按本表定义这是 `待追溯`，落地前须单独评估（可行的出路：直接联系
@zozuar 取得许可，或用一个已知许可的 caustic 实现替换 `getCausticNoise`）。

#### ⑥-C：`Halftone` 的 hash 追到 Dave Hoskins 与 iq（**两条都 MIT**）

- `shader-utils.proceduralHash21`（`halftone-dots.ts` 引用）：
  `p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1; p += dot(p, p + 19.19); return fract(p.x*p.y);`
- `halftone-cmyk.ts:102-106` `hash23`：
  `vec3 p3 = fract(vec3(p.xyx) * vec3(0.3183099, 0.3678794, 0.3141592)) + 0.1;
  p3 += dot(p3, p3.yzx + 19.19); return fract(vec3(p3.x*p3.y, p3.y*p3.z, p3.z*p3.x));`

**两个常量各自追到（一手 / 一手内容）：**

| 常量 | 追到的 | 载体 | 许可 |
|---|---|---|---|
| `19.19` | **Dave Hoskins**。旁证：`libretro/glsl-shaders` `procedural/bigwings-luminescence.glsl:230-235` 里，BigWings **自己**把 `p3 += dot(p3, p3.yzx + 19.19);` 那段标注为 `// 3 out, 1 in... DAVE HOSKINS`（一手读全文） | 一手 · 实时 | Shadertoy `4djSRW`（`{"name":"Hash without Sine","username":"Dave_Hoskins"}`）源码头逐字 `// Hash without Sine` / `// MIT License...` / `/* Copyright (c)2014 David Hoskins.` + MIT 全文 ⇒ **MIT**（一手内容 · 归档载体，API 转储 2025-05-29） |
| `0.3183099`（= 1/π）与 `fract(… * 0.3183099) + .1` 的形状 | **iq**（其 hash / value-noise 系列的签名式；同一文件 `:155-159` 的 `N3` 用同一形状） | 一手 · 实时 | iq `/articles/` 站级 **MIT**（今天一手复核） |

`hash23` 的三行结构（`p3 = fract(vec3(p.xyx) * vec3(A,B,C)); p3 += dot(p3, p3.yzx + K);
return fract(…);`）与 Dave Hoskins `hash32` 的结构**逐行同构，只换了常量**。
按本表《第六条轴》判据 2 的成文规则「**改常量、改名不构成独立**」，
⇒ **认定为 Hoskins 一族的派生，而非 paper 原创。**

⇒ **许可兼容（MIT），`Halftone` 不掉档**；**新增落地义务**：转载
`Copyright (c) 2014 David Hoskins`（MIT）与 iq 的 MIT 声明。paper 的 `NOTICE` 同样未提这两位。

#### ⑥-D：`colorBandingFix` 的处置（双向校准，防止把事实性算法错绑来源）

`shader-utils.colorBandingFix`（被 11 件中的 `Swirl` / `SimplexNoise` / `ColorPanels` /
`SmokeRing` / `Metaballs` 共 5 件引用）：

```glsl
color += 1. / 256. * (fract(sin(dot(.014 * gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453123) - .5);
```

- `12.9898 / 78.233 / 43758.5453` 三元组是**无从指认单一著作权人的通行"sin-fract" hash**
  ——它在 GLSL 生态里以匿名形态流传了十几年，学术上可上溯至 W. J. J. Rey (1998) 的
  `y = [(a+x)·sin(bx)] mod 1`。
- 对**这一具体写法**（`.014 * gl_FragCoord.xy` 的缩放 + `1/256 * (… - .5)` 的 dither 包裹）
  做 code search：**94 条命中全部是 paper 自身与其下游拷贝** ⇒ 这层包裹是 paper 自有。

⇒ **按本表《The Book of Shaders 的许可实查结果》确立的既定处置：署名指向算法本身
（"通行 sin-fract hash"），不绑到任何一份教学资源或某个人。**
⚠️ **特别写明：不得引 The Book of Shaders**——本表已实查其 LICENSE 为 `All rights reserved`
且"cannot use this Work in any commercial or non-commercial product"。下一个人的第一反应
很可能就是去引那本书，这行字是拦它的。

### #280 的一手实查清单（逐条可复核）

| # | 读了什么（URL） | 载体档 | 读到的关键原文 |
|---|---|---|---|
| 1 | `web.archive.org/web/20250920061115id_/https://www.shadertoy.com/terms` | 一手内容 · 归档 | "…if you don't place a license on a shader, it will be protected by our default license: **Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License**" |
| 2 | `web.archive.org/cdx/…?url=www.shadertoy.com/terms&filter=statuscode:200&from=20250301&to=20251031` | 一手 · 实时 | **18 个 200 快照、三个 digest**（9 × `MPDBE…` / 8 × `VXQDY…` / 1 × `3I42H3S…` = 空载荷 SHA-1，2025-10-11）。⚠️ **上一版写的「7 个 + 单一 digest」不成立，已撤回**（第 6 轮终审 I2）|
| 2′ | `web.archive.org/web/20250920061115id_/…` 与 `…/20251001020819id_/…`（**两个不同 digest** 的快照）| 一手内容 · 归档 | 各 **29202 字节**、MD5 同为 `a2550c88cf19fdad987d8aff09dc5d35` ⇒ **逐字节相同** ⇒ 条款文本该期间未变（digest 差异在存储编码层）|
| 3 | `raw.githubusercontent.com/GabeRundlett/shadertoy-api-shaders/master/shaders/XlfGRj.json` | 一手内容 · 归档（API 响应，刷新 2025-05-29） | `"username":"Kali"`；code 头 `// Star Nest by Pablo Roman Andrioli` / `// License: MIT` |
| 4 | 同上 `shaders/ldl3W8.json` | 同上 | `"username":"iq"`；code 头 `// The MIT License` / `// Copyright © 2013 Inigo Quilez` + MIT 全文 |
| 5 | 同上 `shaders/4djSRW.json` | 同上 | `"username":"Dave_Hoskins"`；`// Hash without Sine` / `/* Copyright (c)2014 David Hoskins.` + MIT 全文 |
| 6 | 同上 `shaders/mlBXRK.json` | 同上 | `"name":"Wet neural network"`, `"username":"guil"`；description 逐字 `Forked from newl shader from Yonatan : https://twitter.com/zozuar/status/1625182758745128981`；**无许可头** |
| 7 | `NatronGitHub/openfx-misc` · `uniVR` · `leadedge/ShaderLoader` 三份 `ldl3W8` 拷贝 | 二手 | 三份逐字一致：`// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.` ⇒ **旧许可**，与 #4 冲突，以 #4 为准 |
| 8 | `iquilezles.org/articles/` | 一手 · 实时 | "all technical code snippets you'll find are under the MIT license…"（复核 #281 第 1 条，一致） |
| 9 | `iquilezles.org/articles/voronoilines/` | 一手 · 实时 | `float voronoiDistance( in vec2 x )` 两趟算法全文 + `dot(0.5*(a+b),normalize(b-a))` |
| 10 | `raw.githubusercontent.com/twostraws/Inferno/main/LICENSE` / `README.md` / `WarpingLoupe.metal` / `SimpleLoupe.metal` + commit API | 一手 · 实时 | LICENSE 移植清单 **6 组**、README 清单 **7 条**（多 `Shimmer`）⇒ **清单非穷尽**；`WarpingLoupe.metal` 零上游标注、零魔数 |
| 11 | `paper-design/shaders` `main`：**本表相关的 14 个** `shaders/*.ts`（该目录今日**共 30 个**，枚举见 ⑤）+ `shader-utils.ts` + `LICENSE` + `NOTICE` | 一手 · 实时 | `LICENSE` = Apache-2.0 全文；`NOTICE` = `Powered by Paper Shaders: https://shaders.paper.design`（**仅此两行，无任何第三方署名**）；**该检查集内**的来源标注 grep 输出只有 `neuro-noise.ts:33` 与 `voronoi.ts:14` 两行（⚠️ **不是全仓全量**）|
| 12 | `ashima/webgl-noise` 与 `stegu/webgl-noise` 的 `src/noise2D.glsl` + `LICENSE` | 一手 · 实时 | 两仓 `noise2D.glsl` `diff` 完全一致；LICENSE = MIT，`Copyright (C) 2011 by Ashima Arts` / `Copyright (C) 2011-2016 by Stefan Gustavson` |
| 13 | `libretro/glsl-shaders` · `procedural/bigwings-luminescence.glsl` | 一手 · 实时 | `:230` `// 3 out, 1 in... DAVE HOSKINS` 紧接 `p3 += dot(p3, p3.yzx + 19.19);`；`:155-159` `fract( p*0.3183099+.1 )` |

**⚠️ 未能直读的（明标，不得当作已核）**：
`shadertoy.com` **全站 403**（Cloudflare 挑战）——`/terms`、`/view/XlfGRj`、`/view/ldl3W8`、
`/embed/*`、`/api/v1/shaders/*` 逐个实测，普通 UA / 桌面浏览器 UA / WebFetch **均 403**。
另：Internet Archive 对 `/view/*` 的快照**只存到 SPA 外壳**（约 194 KB，含 CodeMirror，
但 `formuparam` / `Star Nest` / `Pablo` **零出现**）⇒ **`/view/` 页的归档快照不含 shader
源码，不能用作源码证据**；本节 ②④ 用的是**公开 API 的响应**，不是 `/view/` 快照。
`x.com/zozuar/status/1625182758745128981` **未直读**（该推文的内容与许可**未核**，
本表对它的处置不依赖读到它——依赖的是"它没有任何许可声明"这一点由 paper 自己写着）。

### 须用户人工完成的核验（转交清单）

以下三项**只能由人工在浏览器里完成**，`shadertoy.com` 对本 agent 的一切自动访问返 403。
**这三项都不是"失败"，是载体限制。** 每项都给出确切步骤与「看到什么算通过」。

| # | 步骤 | 通过判据 | 不通过则 |
|---|---|---|---|
| 1 | 浏览器打开 `https://www.shadertoy.com/view/XlfGRj`，展开代码框，看**最上面两行** | 逐字为 `// Star Nest by Pablo Roman Andrioli` 与 `// License: MIT` | `StarNest` 掉出 MIT 档 ⇒ 可落地 −1 |
| 2 | 浏览器打开 `https://www.shadertoy.com/view/ldl3W8`，展开代码框，看**最上面五行** | 含 `// The MIT License` 与 `// Copyright © 2013 Inigo Quilez` | `Voronoi` 掉出可落地 ⇒ 可落地 −1（⚠️ 但仍有 ④(c) 的 iq 站级 MIT 通路，须评审判该通路是否独立成立） |
| 3 | 浏览器打开 `https://www.shadertoy.com/terms`，看 "What license will my Shaders have?" 一节 | 与本表《为什么必须做这件事》所引原文一致 | 全表地基须重做 |

⚠️ **这三项**都可以在**落地 PR 的评审阶段**完成，**不阻断 #282 / #283 开工**——因为
每一项的先验都已从"二手拷贝"升级到"官方 API 响应 / 官方页面快照"，且失败时的代价
（可落地 10 → 9 或 8）**仍高于 `N_B`**（见下方重估）。

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
| `GlassOrb` | [Inferno](https://github.com/twostraws/Inferno) 的 "Warping Loupe"（Paul Hudson）——**不在 Inferno LICENSE 的移植清单内 ⇒ 推论为其原创，不是断言**。⚠️ **#280 下调该推论的前提**：Inferno 的 LICENSE 清单（6 组）与 README 清单（7 条，多 `Shimmer`）**互不一致 ⇒ 清单被自身证明非穷尽**；理由改挂两条并列（整仓 MIT 授权 + 函数体零指纹且自述派生自 Inferno 自有 `SimpleLoupe`），详见《#280 的落地前核验》③ | **MIT**（已读 LICENSE 全文；#280 复核一致） | https://github.com/twostraws/Inferno | **已追到兼容许可 · MIT** |
| `StarNest` | "Star Nest"，Pablo Roman Andrioli（Kali），Shadertoy | **MIT**（作者在源码头声明）。⚠️ **#280 升级证据档次**：读到 **Shadertoy 公开 API 对该 shader 的响应本身**（转储刷新 2025-05-29），`info.username = "Kali"`，code 头逐字 `// Star Nest by Pablo Roman Andrioli` / `// License: MIT` ⇒ **一手内容 · 归档载体**（不再只是五份第三方移植的一致记录）。⚠️ 该头**无版权行、无 MIT 全文**，署名只能写「作者声明 MIT」，不得替其补造版权行。⚠️ shadertoy 仍全站 403 ⇒ **人工目视确认保留为硬 AC，但不阻断开工** | https://www.shadertoy.com/view/XlfGRj | **已追到兼容许可 · MIT** |
| `ChromaticGlass` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `Foil` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `Glitter` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `IntenseBling` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `PolishedAluminum` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun）；ShaderKit 自述视觉参考为 `pokemon-cards-css`，**其自身的更上游未记录** | ShaderKit **MIT**（已核 LICENSE）；其视觉参考 **GPL-3.0** | https://github.com/jamesrochabrun/ShaderKit · https://github.com/simeydotme/pokemon-cards-css | **`待追溯`** |
| `Voronoi` | [paper-design/shaders](https://github.com/paper-design/shaders) 的 `voronoi.ts`；paper 自述 `Original algorithm` 为 iq 的 Shadertoy 作品。⚠️ **#280 逐行比对确认**：paper 的 `voronoi()` 是 iq `ldl3W8` 的**结构性逐行复制**（变量名 `ip`/`fp`/`mg`/`mr`/`md` 与 `0.00001` 守卫全部保留）⇒ **双层来源，不是"参考"** | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）**＋ iq MIT**。⚠️⚠️ **#280 把"许可变过"查实了，且方向对我们有利**：三份旧的第三方拷贝（Natron / uniVR / ShaderLoader）头部逐字 **CC BY-NC-SA 3.0**（二手，2013 vintage）；而 **Shadertoy 公开 API 的现响应**（转储 2025-05-29）头部逐字 `// The MIT License` / `// Copyright © 2013 Inigo Quilez` + MIT 全文 ⇒ **现许可为 MIT**。独立第二通路：同一算法发表于 iq 自己的 `articles/voronoilines/`，其父页 `articles/` 站级声明 "all technical code snippets … are under the MIT license"（今天一手实时读取）。⚠️ **落地义务多一条：转载 iq 的 MIT 版权声明与全文**——paper 的 Apache-2.0 不能替代它 | https://github.com/paper-design/shaders · https://www.shadertoy.com/view/ldl3W8 · https://iquilezles.org/articles/voronoilines/ | **已追到兼容许可 · Apache-2.0 + MIT（双层）** |
| `NeuroNoise` | paper 的 `neuro-noise.ts`；paper 自述 `Original algorithm` 是 **@zozuar 的一条推文，无任何许可声明**（默认保留所有权利） | paper 以 Apache-2.0 再许可**是 paper 的断言，我们无法独立核实** ⇒ 不构成正向裁定 | https://github.com/paper-design/shaders · https://x.com/zozuar/status/1625182758745128981 | **`待追溯`** |
| `Swirl` | paper 的 `swirl.ts`（参数签名逐项对应）。⚠️ **#280 查完「paper 之上还有一层」**：paper 无 `Original algorithm:` 自述；本体特征行 code search 命中的 31 条**全部是 paper 自身与下游拷贝** ⇒ 本体未指认到上游。⚠️⚠️ **但它 `import` 的 `shader-utils.simplexNoise` 是 Ashima 的 `noise2D.glsl`** | paper **Apache-2.0**（LICENSE + `NOTICE`，一手核）**＋ Ashima Arts / Stefan Gustavson MIT**。⚠️ paper 把 Ashima 的许可头**整段删了**，`NOTICE` 里也无一字 ⇒ **MIT 要求的版权声明必须由我们自己补** | https://github.com/paper-design/shaders · https://github.com/ashima/webgl-noise | **已追到兼容许可 · Apache-2.0 + MIT（双层）** |
| `SimplexNoise` | paper 的 `simplex-noise.ts`（参数签名逐项对应）。⚠️ **#280 查完**：无 `Original algorithm:` 自述，本体为 2 层 snoise 叠加 + 分色阶，未指认到上游；**核心 `snoise` 来自 `shader-utils.simplexNoise` = Ashima `noise2D.glsl`（常量与结构逐行相同，许可头被删）** | paper **Apache-2.0**（一手核）**＋ Ashima Arts / Stefan Gustavson MIT**（义务同 `Swirl`） | https://github.com/paper-design/shaders · https://github.com/ashima/webgl-noise | **已追到兼容许可 · Apache-2.0 + MIT（双层）** |
| **`Water`** | paper 的 `water.ts`（参数签名逐项对应）。⚠️⚠️⚠️ **#280 改判**：其 `getCausticNoise()` 与 paper **自己标了来源的** `neuro-noise.ts` 的 `neuroShape()` **是同一个算法**（同一 rotate→`q=uv*scale+j+acc±t`→`acc+=sin(q)`→`out+=cos(q)/scale`→`scale*=1.1~1.2` 五步，同一 `x+y` 归约，且 `water.ts` 明明已 import `rotate()` 却又本地重定义 `rotate2D`——整段搬运的痕迹）。独立佐证：Shadertoy `mlBXRK`（"Wet neural network", `guil`）的同一循环，description 逐字指向**同一条推文** | ⚠️⚠️ 上游 = **@zozuar 的推文 `x.com/zozuar/status/1625182758745128981`，无任何许可声明**（默认保留所有权利）。paper 以 Apache-2.0 再许可**是 paper 的断言，我们无法独立核实**——**与 `NeuroNoise` 被移出 Apache-2.0 档（第 5 轮终审 I4）完全同一理由，且 paper 这次连来源都没标** | https://github.com/paper-design/shaders · https://x.com/zozuar/status/1625182758745128981 · https://www.shadertoy.com/view/mlBXRK | ⚠️⚠️ **`待追溯`**（#280 由 Apache-2.0 档改判）——**不是 `不落地`**：无证据说该推文与 MIT 不兼容，只是**无法正向裁定** |
| `ColorPanels` | paper 的 `color-panels.ts`（参数签名逐项对应）。⚠️ **#280 查完**：无 `Original algorithm:` 自述；透视板扫描 `getPanel` / `blendColor` 逐行读完，**零常量命中、未指认到上游** ⇒ paper 自有 | paper **Apache-2.0**（一手核）。⚠️ 经 `colorBandingFix` 带通行 sin-fract hash（`12.9898/78.233/43758.5453123`）⇒ 署名指向算法谱系，**不得引 The Book of Shaders**（其 LICENSE 为 `All rights reserved`） | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `DotOrbit` | paper 的 `dot-orbit.ts`（参数签名逐项对应）。⚠️ **#280 查完**：无 `Original algorithm:` 自述；`voronoiShape()` 是**通用单趟 F1 Voronoi**（Worley 1996 谱系，事实性算法），**不是** iq 的两趟边界算法；动画项是 iq `0.5+0.5*sin(iTime+6.2831*o)` 的参数化回声（常量已符号化） | paper **Apache-2.0**（一手核）。署名指向**算法谱系**，不绑具体作品 | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `SmokeRing` | paper 的 `smoke-ring.ts`（参数签名逐项对应）。⚠️ **#280 查完**：无 `Original algorithm:` 自述；`valueNoise()` 为教科书双线性 value noise（`f*f*(3-2f)`）、`fbm` 用 lacunarity `1.99` / gain `0.65` ⇒ **事实性算法**（Perlin–Musgrave 谱系），按本表既定处置署名指向算法而非教学资源 | paper **Apache-2.0**（一手核）。`colorBandingFix` 折衷同 `ColorPanels` | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `Metaballs` | paper 的 `metaballs.ts`（参数签名逐项对应）。⚠️ **#280 查完**：无 `Original algorithm:` 自述；`getBallShape` 用 `pow(1-clamp(.5*len),p)`——**不是** Blinn / Wyvill 的任何标准 metaball 落差式 ⇒ paper 自有；`2503.4` 是首帧时间偏移而非 hash 常量 | paper **Apache-2.0**（一手核）。`colorBandingFix` 折衷同上 | https://github.com/paper-design/shaders | **已追到兼容许可 · Apache-2.0** |
| `Halftone` | paper 的 `halftone-dots.ts` + `halftone-cmyk.ts`（两入口一一对应；**ShipSwift 自己在 `SWHalftone.metal:350` 写着 "simplified port"**）。⚠️⚠️ **#280 查完**：两文件无 `Original algorithm:` 自述，**但其 hash 追到两位具名作者**——`19.19` 是 **Dave Hoskins** 的常量（旁证：BigWings 自己在 `bigwings-luminescence.glsl:230` 把该式标为 `// 3 out, 1 in... DAVE HOSKINS`），`0.3183099`(=1/π) + `fract(…)+.1` 的形状是 **iq** 的签名式；`hash23` 与 Hoskins `hash32` **逐行同构、只换常量**，按本表「改常量、改名不构成独立」认定为其派生 | paper **Apache-2.0**（一手核）**＋ Dave Hoskins MIT**（Shadertoy `4djSRW` 源码头 `Copyright (c)2014 David Hoskins` + MIT 全文）**＋ iq MIT**（站级声明）。⚠️ paper 的 `NOTICE` 对这两位**只字未提** ⇒ 通知义务由我们补 | https://github.com/paper-design/shaders · https://www.shadertoy.com/view/4djSRW · https://iquilezles.org/articles/ | **已追到兼容许可 · Apache-2.0 + MIT（双层）** |
| `GrainGradient` | paper 的 `grain-gradient.ts`——**参数仅部分匹配，匹配未确认** | —（paper 为 Apache-2.0，但匹配未确认 ⇒ 不得据此定档） | https://github.com/paper-design/shaders | **`待追溯`** |
| `FractalClouds` | **—**（本体未追到）；FBM 底座可对照 ashima / stegu / glsl-noise，但 **domain-warp 与调色的组合未追到出处**。⚠️ **#281 又追一轮，本体仍未指认到上游** | 参考实现 **MIT**；本体 —；⚠️ **其 domain-warp 所属的 iq 一族已追到 iq 站点级 MIT** | https://github.com/ashima/webgl-noise · https://iquilezles.org/articles/ | **`待追溯（低指纹）`**（#281 分档，不阻断） |
| `InkSmoke` | **—**（本体未追到）；#261 实证：域扭曲的 `q`/`r` 三级级联派生自 **iq《Domain Warping》** | ⚠️⚠️ **改判**：上一版写「iq 页面无许可声明」——**错的，只是没读对页面**。文章父页 `iquilezles.org/articles/` 逐字「**all technical code snippets you'll find are under the MIT license**」（#281 两次独立一手读取）⇒ 该级联 **MIT** | https://iquilezles.org/articles/warp/ · https://iquilezles.org/articles/ | **`待追溯（低指纹）`** —— ⚠️ **强档阻断已解除**（既追到、许可又兼容 ⇒ 义务已兑现，转为署名） |
| `Plasma` | **—**（本体未追到）；#261 实证：四相正弦叠加是 **Lode Vandevenne《Lode's Computer Graphics Tutorial — Plasma》** 的公式 | ⚠️ **改判**：上一版写「本表未核该页面许可」——**#281 核了**。plasma 页页脚确为 `All rights reserved`，但 `lodev.org/cgtutor/legal.html` **把散文与代码分开授权**，代码逐字为 **BSD-2-Clause**（保留版权通知 + 条件 + 免责声明）| https://lodev.org/cgtutor/plasma.html · https://lodev.org/cgtutor/legal.html | **`待追溯（低指纹）`**（该片段已 `已追到兼容许可`；本体其余未指认 ⇒ 低指纹，不阻断） |
| **`Starfield`** | ⚠️⚠️ **#281 追到了**：**Martijn Steinrucken（BigWings / *The Art of Code*）《Starfield Tutorial》(2020)**。⚠️ 上一版写「未追到 / 网格星空模板」是**既漏了具名上游、又过度归因了范围**（`step` 熄灭与 `smoothstep` 圆盘辉光不是他的） | ⚠️⚠️ **CC BY-NC-SA 3.0**——源码头逐字 `// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.`。**与本仓 MIT 分发不兼容**（禁商用 + 传染性 share-alike） | ⚠️ **二手载体、一手读取**：shadertoy 返 403，未直读原页；证据是两份互相独立的 GitHub 拷贝逐字一致（`sentinelweb/processink`、`GalaxyCr8r/solarance-beginnings`）⇒ **人工目视确认 https://www.shadertoy.com/view/ls3Xzn 是硬 AC** | ⚠️⚠️ **`不落地`** —— 兜底的「追到不兼容」分支。✅ **判定已下、撤回已执行**（base commit `807f074` 即那次撤回，整件删除）⇒ **本行不再阻断 `epic → main`**。⚠️ 上一版本行写「撤回未执行 ⇒ 阻断」，与 `:344` / `:430` / `:940` / 收尾勾选框的"已执行"相矛盾，而本表声明"两处冲突时以本表为准" ⇒ 那句假话会赢；第 6 轮终审 I5 已改正 |
| `Dots`（`DotGrid`） | **—**（未追到）；paper 有 `dot-grid.ts` 但描述不同 ⇒ **不是**匹配。⚠️ **#281 又追一轮**：一手读全 paper `dot-grid.ts` 与 Inferno `LightGrid.metal`，**均不匹配**；code search 无候选 | — | https://github.com/paper-design/shaders · https://github.com/twostraws/Inferno | **`待追溯（低指纹）`**（#281 分档，不阻断） |
| `Glass`（`RefractiveGlass`） | **—**（主体未追到）；第 1 版曾引 iq 的 SDF 文章。⚠️⚠️ **#281 证伪了上一版的事实主张**：所谓「2025 年 `layerEffect` "liquid glass" 一族的通行形态」——**逐个读完具名的 SwiftUI-Metal 玻璃库后，没有找到这样一族** | `roundedBoxSDF` ⇒ **iq 站点级 MIT**（已追到）；**主体 ⇒ 仍未指认到具名上游** | https://iquilezles.org/articles/ · 逐候选比对表见《`coreDesignRefractiveGlass` 主体的追溯》 | **`待追溯（低指纹）`** —— ⚠️ **由强指纹改判**（三条强档判据逐条不成立，逐常量 grep 零命中）⇒ **不再阻断**；⚠️ **该改判须 `epic → main` 评审显式确认**，不确认则回落 `不落地` |
| `GlassLogo`（落地名 `GlassSymbol`） | **—**（未追到）；同 `Glass`。⚠️ `GlassSymbol.swift` 里**零 provenance 引用**、改名 `GlassLogo → GlassSymbol` 亦未记录 ⇒ **#281 已补**（源码注释加了 provenance 段并同时写出两个名字，便于交叉引用 grep） | 随 `Glass` | — | **`待追溯（低指纹）`**（无自有 shader，档位完全随 `Glass`） |
| `AnimatedLoop` | **—**（未追到）；`SWAnimatedLoop.metal:5-21` 是四个 **hand-tuned styles**、18 个参数，属**独立作品**（第 1 版"调度器无独立算法"是事实误读） | — | — | **`待追溯`** |
| `LiquidChrome` | **—**（未追到）；`SWLiquidChrome.metal:7-9` 自述 "Three sequential value-noise samples are domain-warped"。⚠️ **#281 又追一轮**：paper `liquid-metal.ts` 与 react-bits `LiquidChrome` 均一手读全文 ⇒ **均不匹配**；shadertoy 403，一条线索**未核实、已丢弃** | — | https://github.com/paper-design/shaders · https://github.com/DavidHDev/react-bits | **`待追溯（低指纹）`**（#281 分档，不阻断） |
| `LiquidMetal` | **—**（未追到）；`SWLiquidMetal.metal:26-28` 用 **Ashima simplex 常量**（线索，非匹配）；paper 有 `liquid-metal.ts` 但描述与参数集**不同** | — | https://github.com/ashima/webgl-noise | **`待追溯`** |

**计数校验**：2（MIT）+ **8**（Apache-2.0）+ **17**（待追溯）+ 0（自研实现）+ **1**（不落地）= **28** ✅
⚠️ **#281 改动了两档**：`Starfield` 由 `待追溯` 改判 **`不落地`** ⇒ 待追溯 17 → 16、不落地 0 → **1**。
⚠️⚠️ **#280 又改动了一档**：`Water` 由 **Apache-2.0 改判 `待追溯`**（上游 = 无许可推文，与 `NeuroNoise` 同因）
⇒ Apache-2.0 9 → **8**、待追溯 16 → **17**。
⚠️ **另有 4 行的档名加了"+ MIT（双层）"后缀**（`Voronoi` / `Swirl` / `SimplexNoise` / `Halftone`）——
**那不是新档位，仍计入 Apache-2.0 档**，后缀只标注「paper 的 Apache-2.0 之外另有一个必须自行兑现的 MIT 通知义务」。
⚠️ **其余 7 个已落地件仍在 `待追溯`，但全部由 #281 分入低指纹档**（见《清偿条款》表 B）⇒ 不阻断；
`Glass` 那一行的低指纹是**由强指纹改判**而来，须评审确认。
——与下方《汇总与闸②判定》逐档一致。

**逐行详情与论证**：§A（#1–#7）· §B（#8–#18）· §C（#19–#28）·
共享原语层（跨 shader）见《共享原语的逐项出处》。

---

## 汇总与闸②判定

| 裁定 | 数量 | 明细 |
|---|---|---|
| **已追到兼容许可 · MIT** | **2** | GlassOrb、StarNest（#280 两条核验均通过）|
| **已追到兼容许可 · Apache-2.0** | **8** | §B 的 #8–17，**减 `NeuroNoise`**（上游是无许可推文，paper 的再许可断言无法独立核实 ⇒ 不构成正向裁定）**，#280 再减 `Water`**（同因：其 `getCausticNoise` 与 `neuro-noise` 是同一算法、同一条无许可推文，而 paper 连来源都没标）。⚠️ 其中 4 行（`Voronoi` / `Swirl` / `SimplexNoise` / `Halftone`）另带一个 paper 未兑现的 **MIT 通知义务**，见《#280 的落地前核验》⑥ |
| ~~**clean-room 重写**~~ | ~~2~~ → **0** | ⚠️ **该档已随本 PR 删除**（第 5 轮终审 C1）：`FractalClouds` / `InkSmoke` 的依据（ashima / stegu / glsl-noise 均 MIT）**已被证明本就不成立**，且《裁定方法：正向裁定，不证否定》自己的规则「`clean-room` 行必须给出 URL + 已核实的许可，否则一律降级为 `待追溯`」本就该触发。两件改判 `待追溯`。**该档亦不在裁定取值表里** ⇒ 正文任何位置都不得再作为裁定值出现（⚠️ 上一版只在本行写了改判，§C 的 #19 / #20 两行仍留着这个已废除的取值 —— **PR #259 review round-1 指出，本轮已同步改掉**）|
| **待追溯** | **17** | ShaderKit 5 + GrainGradient + §C 的 8 个 + FractalClouds / InkSmoke（第 5 轮改判）+ NeuroNoise，**减 `Starfield`**（#281 改判 `不落地`），**加 `Water`**（#280 由 Apache-2.0 改判）。⚠️ **其中 #261 已落地的 7 件全部由 #281 分入低指纹档**（《清偿条款》表 B）⇒ 不阻断 `epic → main`。⚠️ **`Water` 不阻断 `epic → main`**（它从未落地），它阻断的是**自己进 #282 / #283 的成员名单** |
| **不落地** | **1** | ⚠️⚠️ **`Starfield`（#281）** —— 追到 **Martijn Steinrucken / BigWings《Starfield Tutorial》(2020)**，源码头 **CC BY-NC-SA 3.0**，与本仓 MIT 分发不兼容 ⇒ 命中兜底的「追到不兼容」分支。✅ **判定已下、撤回已执行**（base commit `807f074`，整件删除，见《`Starfield` 的追溯》的《执行记录》）⇒ **不再阻断 `epic → main`；当前无任何裁定项阻断 `epic → main`**。⚠️ 上一版写「撤回未执行 ⇒ 唯一阻断项」——第 6 轮终审 I5 改正。<br>（第 1 版判的另 2 个仍维持第 5 轮的 `待追溯` 改判——原理由与 §C 其余项双标）|
| **自研实现** | **0** | ⚠️ 显式写 0——《逐件适用性》左列有 8 个名字，但那是**准入不是结论**；实际落地件经第六条轴复查**无一维持自研** |
| 合计 | **28** | 2 + 8 + 0 + 17 + 1 = 28 ✅ |

⚠️⚠️ **#281 对本表的净效果，一句话**：**阻断项从「1 个强指纹原语 + 10 个未分档的默认强档项」变成「1 个具名不兼容许可的落地件」**。
前者是**没查**造成的阻断，后者是**查出来**的阻断——数字变小了，但严重性变高了，别读反。

### 闸②判定：**通过**（#249 判定 → #281 复核 → ⚠️ **#280 按落地前核验结果重算并维持**）

⚠️ **`NeuroNoise` 从 Apache-2.0 档移出**（第 5 轮终审 I4）：本表 §「paper 之上还有一层」
自己写着它的上游是**一条无任何许可声明的推文**（默认保留所有权利），
「paper 以 Apache-2.0 再许可**是 paper 的断言，我们无法独立核实**」
⇒ 按《裁定方法：正向裁定，不证否定》的「正向裁定」定义，**一个无法独立核实的第三方再许可断言不是正向裁定**。
⇒ Apache-2.0 档 **10 → 9**。这正是第 1 版「判太松」在更正之后的原样复现。

⚠️⚠️ **`Water` 从 Apache-2.0 档移出**（#280）：**同一条规则的第二次触发**——
`water.ts` 的 `getCausticNoise()` 与 `neuro-noise.ts` 的 `neuroShape()` 是**同一个算法**
（详见《#280 的落地前核验》⑥-B），即同源于那条无许可推文，**而 paper 这次连来源都没标**。
⇒ Apache-2.0 档 **9 → 8**。
⚠️ **这条值得记住的地方不是数字，是它怎么被抓到的**：本表上一版对 §B 的比对只做到
"参数签名 + 描述句"，`Water` 的参数签名与描述句**没有任何异常**；抓到它的是
**把函数体读全 + 对特征代码行做 code search**，也就是《第六条轴》判据 1/2。
**又一次证明五轴是必要不充分的——而这一次是在「已正向裁定的移植件」上，不是在「自研声称」上。**

- ⚠️⚠️ **#280 已把上一版列的 6 项落地前核验逐条做完**（见《#280 的落地前核验》）。
  **净效果：可落地 11 → 10**（`Water` 掉档），**其余 10 条的核验全部通过**，
  并额外查出**三个此前完全没记录的上游署名义务**（Ashima/Gustavson · Dave Hoskins · iq）。
- **现可落地数 = 2 + 8 = 10**（⚠️ 上上版写 14、上一版写 11）
- ⚠️ **10 条中「无条件可落地」现为 7**（#280 之后的新口径）：
  `Voronoi` / `Swirl` / `SimplexNoise` / `ColorPanels` / `DotOrbit` / `SmokeRing` /
  `Metaballs` / `Halftone` 里，除 `Voronoi` 之外的 7 条核验已闭合、无剩余待办；
  **剩余 3 条各带一项残留事项，且都不阻断开工**：
  · `GlassOrb` —— 仍是**推论**（且其前提"不在移植清单内"被 #280 证明比上一版说的弱：
    Inferno 的 LICENSE 清单与 README 清单互不一致 ⇒ 清单非穷尽）。**残余风险须接受并记录，
    不是靠再查一轮能消除的**；
  · `StarNest` —— 证据已从「五份二手移植一致」升级为「**Shadertoy 公开 API 响应本身**」，
    但仍非实时 ⇒ 人工目视确认**保留为硬 AC**；
  · `Voronoi` —— 现许可**已查实为 MIT**（API 响应 + iq 站级 MIT 两条独立通路），
    人工目视确认同样保留为硬 AC。
- ⚠️ **`N_B` 已按「移植 + 署名」重估（#280；第 6 轮终审 I1 更正 `Halftone` 后复算）：
  `N_B` ∈ [3.40, 8.75]，点估 5.41 ⇒ 取 `N_B` = 6。**
  推导见下方《`N_B` 的重估》。（旧值 5 由 #248 按「固定成本 8–12h ÷ 边际 2.0–2.5h/shader」
  反推，而那个边际是**按 7 个"颜色写死"难件加权**算的，那 7 个**无一可落地** ⇒ 口径不适用。）
- **10 ≥ 6 ⇒ 闸②仍然通过**，`shipswift-shaders`（#243）可继续；#282 / #283 按下面的
  10 件名单列成员。
- ⚠️ **#281 把 `Starfield` 判成 `不落地`，闸②的分子不受影响**：闸②的谓词是
  **「可落地数 ≥ `N_B`」**，而可落地名单里**从来没有 `Starfield`**
  ——它一直在 `待追溯` 里。
  ⚠️ 但《汇总与闸②判定》上面那条「分子侧触发器」说的是 §A / §B 的核验失败会让分子掉；
  **`Starfield` 属 §C，掉的是"已落地件数"（8 → 7），不是"可落地数"**——两个数不同，别混
- ⚠️⚠️ **分子侧触发器（第 2 轮终审 C-7）已在 #280 实际触发过一次**：
  逐字规则是「**§A / §B 任一落地前核验失败 ⇒ 可落地数 −1；降至 < `N_B` 时闸②须重开**」。
  #280 的 §B 核验里 **`Water` 失败** ⇒ 分子 11 → **10**。
  **10 ≥ `N_B` = 6 ⇒ 未降至阈值以下 ⇒ 该触发器本次不引发重开。**
  （对照：`NeuroNoise` 此前也掉过一次，10 → 9。**这条触发器至此已实际生效两次，
  它不是装饰。**）
- ⚠️ **最坏地板已由 #280 大幅上抬，但仍如实算给你看**：上一版的地板是 **1**（把全部核验判失败）。
  #280 之后，**`Swirl` / `SimplexNoise` / `ColorPanels` / `DotOrbit` / `SmokeRing` /
  `Metaballs` / `Halftone` 共 7 条已核验闭合、无剩余待办**，它们不再进入地板计算。
  剩余 3 条各自的失败面：

  | 件 | 失败要什么条件 | 失败代价 |
  |---|---|---|
  | `GlassOrb` | 评审不接受那条推论（前提已被 #280 证明非穷尽） | −1 |
  | `StarNest` | 人工目视看到的源码头**不是** `// License: MIT`（即 API 转储与官方现页面不一致） | −1 |
  | `Voronoi` | ⚠️ **要两条独立通路同时失败**：人工目视看到的**不是** MIT 头，**并且**评审判定 iq 站级 MIT 不覆盖 `voronoiDistance`（"technical code snippet" vs "shader art"） | −1 |

  ⇒ **现实地板 = 8**（`GlassOrb` + `StarNest` 两条各自独立、都判失败）；
  **绝对地板 = 7**（再叠加 `Voronoi` 的两条通路同时失败——这需要三个互不相干的判断同时反转）。
  ⇒ **7 ≥ `N_B` = 6，闸②即使在绝对地板上仍然通过**（⚠️ 但 **7 < `N_B` 区间上端的 8.75**
  ——按悲观端口径就不通过了。**两个口径都写下，不挑对自己有利的那个。**）
- ⚠️ **注意上面全是"许可侧"的地板**——它不保证工程侧不出问题
  （见《`N_B` 的重估》里 **5** 件依赖噪声纹理的成本项——⚠️ **`Halftone` 是第 5 件**，
  第 6 轮终审 I1 补入，见 ⑤-bis）。
- ⚠️ **口径**：本表的「可落地」= **已正向裁定为兼容许可、落地前尚有具体核验项**。
  #280 之后「无条件可落地」由 **0 变为 7**（见上方逐条），剩 3 条各带一项残留事项。
- **可落地 10 的名单**（#282 / #283 按此列成员）：
  `GlassOrb`、`StarNest`（§A #1–2）+ `Voronoi`、`Swirl`、`SimplexNoise`、
  `ColorPanels`、`DotOrbit`、`SmokeRing`、`Metaballs`、`Halftone`
  （§B #8–17 减 `NeuroNoise`、**减 `Water`**）。
  ⚠️ **`Water` 不在名单里**——上一版在；见《#280 的落地前核验》⑥-B。

### ⚠️⚠️ `N_B` 的重估（按「移植 + 署名」，#280 交付）

**为什么必须重估**：#248 的 `N_B` = 5 由「固定成本 8–12h ÷ 边际 **2.0–2.5h/shader**」反推，
而那个边际逐字是「**可能落地的集合里有 7 个是 `layerEffect` 难件（2–3h）**」加权来的
——**那 7 个（ChromaticGlass / Foil / Glitter / IntenseBling / PolishedAluminum / GlassLogo /
LiquidMetal）在本表里无一可落地，全部是 `待追溯`** ⇒ 分母是按一个**不存在的集合**算的。
且 #248 自己也写着「边际成本须再核一次」，本表又把成本故事改成「移植 + 署名」。⇒ 重估。

**分子（固定成本）**：**9–14 小时**
- 沿用 #248 修正后的 **8–12h**（target/product/`project.yml`/probe/AGENTS 同步 + fail-closed
  加载 + CI 一步 + 画廊/快照排除的脚手架）——**这部分与许可故事无关，不动**；
- **＋1–2h 的新增固定项**（#280 发现）：Apache-2.0 的 LICENSE 全文转载 + `NOTICE` +
  §4(b) 修改标注的**成文机制**，以及 Ashima/Gustavson · Dave Hoskins · iq 三份 MIT 通知的
  样板。**这些是一次性的**，落 1 个还是落 10 个都只写一遍。

**分母（每 shader 边际）**：**1.60–2.65 小时/shader**（按**实际的 10 件**加权，非 28 件）

⚠️ **本表在第 6 轮终审 I1 后改过一次**：`Halftone` 也依赖 `u_noiseTexture`（本地定义的
`randomRG`，见 ⑤-bis），上一版把它漏在纹理组之外 ⇒ 它的单件工时上调。

| 分组 | 件（**逐个列出，不用排除式**）| 件数 | 单件 | 依据 |
|---|---|---|---|---|
| 普通件 | `GlassOrb` · `StarNest` · `Swirl` · `SimplexNoise` · `ColorPanels` | **5** | **1.0–1.5h** | #248 实测「参数化改造 + wrapper + Preview + 文档 ≈ 1–1.5h/个」 |
| **依赖噪声纹理的** | `Voronoi` · `DotOrbit` · `SmokeRing` · `Metaballs` | **4** | **1.5–2.5h** | ⚠️ **#280 发现的成本项**：都从 `u_noiseTexture` 采样（`randomR` / `randomGB`）。移植到 Metal 要么随包发一张预计算噪声纹理（资源 + 加载路径 + bundle 约束），要么换成程序化 hash——**后者会改变观感，是设计决策不只是工程量**。+0.5–1h |
| **难件（且同样依赖噪声纹理）** | `Halftone` | **1** | **2.5–4.0h** | 两个入口（`halftone-dots` + `halftone-cmyk`，合计 ≈26 KB TS）、`layerEffect` over image、CMYK 分色 + 四组网屏角（＝原 2.0–3.0h）**＋纹理依赖附加 0.5–1.0h**（`halftone-cmyk.ts:80/98/171`，见 ⑤-bis）|
| 全部件另加 | —— | 10 | **+0.25–0.5h** | `.metal` 头注明 paper 对应 `.ts` 路径 + Apache-2.0 §4(b) 修改标注 + `ACKNOWLEDGEMENTS.md` 逐条（含 #280 新查出的三份 MIT 通知）|

⚠️ **`Halftone` 只计一次**：它同时属"难件"与"依赖噪声纹理"，纹理附加已并进它那一行的
2.5–4.0h 里，**不在纹理组重复计价**（纹理组仍是 4 件参与算术）。5 + 4 + 1 = **10** ✅

- 低端合计：5×1.0 + 4×1.5 + 1×2.5 + 10×0.25 = 5 + 6 + 2.5 + 2.5 = **16.0h** ⇒ 均 **1.60h/shader**
- 高端合计：5×1.5 + 4×2.5 + 1×4.0 + 10×0.5 = 7.5 + 10 + 4 + 5 = **26.5h** ⇒ 均 **2.65h/shader**

**`N_B` = 分子 ÷ 分母 = 9…14 ÷ 1.60…2.65**
- 区间下端 = **乐观端**（固定成本最低 ÷ 边际最高）：9 ÷ 2.65 = **3.40**
- 区间上端 = **悲观端**（固定成本最高 ÷ 边际最低）：14 ÷ 1.60 = **8.75**
  ⚠️ **方向别读反**：`N_B` 是"落几件才回本"的门槛，**`N_B` 越大对本表的"闸②通过"
  结论越不利** ⇒ 区间**上**端才是悲观端。
- 点估（11.5h ÷ 2.125h）= **5.41**

⇒ **`N_B` ∈ [3.40, 8.75]，点估 5.41 ⇒ 取 `N_B` = 6**（点估上取整）。
⚠️ **分子分母不重叠**：分子是**与件数无关**的一次性项，分母是**逐件**项，
两边没有同一笔工时被算两次（#248 曾在这里犯过重叠错误，本表刻意避开）。
⚠️ **这里刻意没有按 #248 的"取更小更安全"惯例取 4**——#280 的结论是"闸②通过"，
**取一个更高的 `N_B` 是对自己结论更不利的方向**，这样得出的"通过"才有意义。

⚠️⚠️ **必须写下的一条**：区间上端 **`N_B` = 8.75**，而可落地数是 **10** ⇒ **悲观端的
余量是 1.25 件**（上一版按 `N_B` = 9 写的"余量只有 1"——`Halftone` 更正后余量略微变宽，
但**触发器不放松**）。
**⇒ 重开触发器（维持）**：若 `Water` 之外**再有任何一件掉出可落地**（含人工目视核验
不通过），可落地数降到 9，仍 > 8.75 但只剩 0.25；**再掉一件即 8 < 8.75，
须按悲观端口径重开闸②**。
⚠️ 而按**点估** `N_B` = 6，余量是 4——**两个数都记下，不要只记有利的那个。**

⚠️ **#280 之前挂在这里的重开触发器（「B-2 / B-3 分解时按『移植 + 署名』重估 `N_B`；
若重估后 `N_B` > 可落地数，闸②须重开」）：本节即是该重估。
结论 `N_B` = 6 **不**大于可落地数 10 ⇒ **该触发器不成立，闸②不重开。**

### ⚠️ 与第 1 版相比，成本方向**反转了**

第 1 版说「24/26 走 clean-room，比移植贵得多，B-2/B-3 须上调工时」。**本版相反**：

- **8/10 是"带署名的移植"，不是 clean-room**（⚠️ 上上版写 12/14、上一版写 9/11；
  #280 的 `Water` 改判后是 **8/10**） —— 移植**比** clean-room **便宜**；
- 但多了 **Apache-2.0 的署名义务**（LICENSE + NOTICE + 修改标注）；
  ⚠️⚠️ **#280 又多了一层：4 件另带 paper 未兑现的 MIT 通知义务**
  （`Swirl` / `SimplexNoise` → Ashima Arts + Stefan Gustavson；`Voronoi` → iq；
  `Halftone` → Dave Hoskins + iq）。**paper 的 `NOTICE` 只有"Powered by Paper Shaders"
  两行，对这三方只字未提** ⇒ 义务落在我们头上，见《落地义务》。
- 另有 **17 个 `待追溯`**，每个须先追一轮（小时级）才能定档（⚠️ 上上版写 14——那是
  `FractalClouds` / `InkSmoke` 改判与 `NeuroNoise` 降档**之前**的数；#281 后为 16；
  **#280 加 `Water` 后为 17**）。

⇒ **B-2 / B-3 分解时按「移植 + 署名」重估，不是按 clean-room。**
⇒ ⚠️ **该重估已由 #280 交付**，见《`N_B` 的重估》：`N_B` = **6**（区间 [3.40, 8.75]，点估 5.41）。

---

## ⚠️ #261 的落地反馈（本表的第一次实战复查）

`shipswift-shaders` 的 B-1 首批 8 个 shader 落地时（PR #261）跑了**五轮**署名鉴定，
**每一轮我都声称"这次全了"，每一轮都还有**。给本表留下三条可操作的结论：

1. **五轴框架必须加第六条（函数体）** —— 见上文，四次命中全在函数体，而五轴全部满足。
2. **默认档位是「待追溯」不是「自研」** —— 落地件的档位由函数体复查决定，
   本表的「可走自研」左列是**准入**不是**结论**。
3. **逐常量 grep 必须前置** —— 它比五轴便宜一个数量级，六次命中全部来自这一步（#261 四次 + #280 两次），
   而第 1 版把它放在最后。

⚠️ **本表与 #261 的引用关系是双向的**：#261 共 **5 处**引用本文件（`CoreDesignShaders.metal` ×3、`Plasma.swift` ×1、`Starfield.swift` ×1，即 **1 个 metal + 2 个 Swift 文件**）
（⚠️ 上一版写「三个 Swift 文件共四处」，两个数都错——而本表的立身之本正是「逐常量 grep 比五轴便宜一个数量级」，这一段却是没 grep 就写下的，第 2 轮终审 I-b），而本文件的《共享原语的逐项出处》是 #261 写出来的。⇒ **#261 不得先于本 PR 合入**
（该前置已写在 #261 的描述顶部）。

## ⚠️ #283 的落地记录（B-3：`GlassOrb` + `Halftone` 两件）

⚠️ **成员是 2 个不是 3 个。** `283.md` 的任务书写的是 `GlassOrb` / `Water` / `Halftone`，
而 **`Water` 已由 #280 从 Apache-2.0 档改判 `待追溯`**（其 `getCausticNoise()` 与
`neuro-noise.ts` 的 `neuroShape()` 是同一算法、同源于同一条**无许可声明的推文**，
而 paper 这次连来源都没标）⇒ 它**不在可落地名单里**，本 task 未落地它。
本记录的名单是**开工时从本文件《统一裁定表》与《汇总与闸②判定》逐行复核出来的**，
不是照抄任务书。⚠️ 连带作废：`283.md` 里那条「`Water` 的 `colorEffect`/`layerEffect`
归类须在开工时确认」——对象已不在名单内。

### 逐件落地形态与档位

| 件 | 落地入口 | 上游 | 许可地位 | 复制程度 |
|---|---|---|---|---|
| `GlassOrb` | `View.glassOrb(size:magnification:)` · `coreDesignGlassOrb` | Inferno `Sources/Inferno/Shaders/Transformation/WarpingLoupe.metal` | **已追到兼容许可 · MIT** | **较大段落移植**（落地后定案；本表上一版记的是"预期档位"）|
| `Halftone` | `View.halftone(dot:ink:paper:)` · `coreDesignHalftone` | paper `packages/shaders/src/shaders/halftone-dots.ts` | **已追到兼容许可 · Apache-2.0 + MIT（双层）** | **较大段落移植** |

两件**都不作任何原创声称**。署名落在 `ACKNOWLEDGEMENTS.md` 的
《Inferno — Warping Loupe》与《paper-design/shaders》两节（两节 `#283` 由占位改为生效）。

### ⚠️⚠️ `GlassOrb` 的第三条修改标注（PR #303 终审 C-1 补记）

**「照抄上游 = 忠于上游」在本件上不成立，而第一版正是那么做的、并且漏了标注。**

上游 `WarpingLoupe.metal` 的衰减项是 `totalZoom += smoothstep(…) / 2`。那个 `0.5`
**不是一个通用常数**，它与上游自己 `zoomFactor` 的默认值 **2** 配套：
区域内先 `totalZoom = 1 / 2`，再加回 `0.5` ⇒ 边界处恰好回到 **1**，圆内外严丝合缝。

本仓**同时**做了两件破坏该前提的事：把坐标空间从 UV 改成点空间（修改标注 ①），
**并且**自选了 `GlassOrbMagnification` 的三档 **1.6 / 2.4 / 4.0**——**一档都不是 2**。
⇒ 照抄那个常数，边界处的 `totalZoom` 分别是：

| 档 | `1/m` | 边界 `totalZoom` | 后果 |
|---|---|---|---|
| gentle 1.6 | 0.625 | **1.125** | > 1 ⇒ 近边一圈**反向缩小**，边界跳变 0.125 |
| regular 2.4 | 0.417 | 0.917 | 仍在放大 1.09× ⇒ 硬边 |
| strong 4.0 | 0.250 | 0.750 | 仍在放大 1.33× ⇒ 硬边最重 |

200×200 灰阶渐变上实测（焦点 (100,100)、半径 44 ⇒ 边界 x=144，读 y=100 行）：
三档接缝分别约 **4.5 / 6 / 15 px** 源位移。⇒ 「越靠边放得越少、边界处回到 1，
于是没有硬边」这句注释在照抄版下**是假的**。

**修法**：改成向 1.0 插值 `totalZoom += (1 - totalZoom) * smoothstep(…) * saturate(softness)`
——对**任何**倍率都在边界回到 1，代价是与上游那一行不再逐字相同。
**⇒ 这是第三条 §4(b) 式修改标注**，已补进 `coreDesignGlassOrb` 的文档注释与
`ACKNOWLEDGEMENTS.md`《Inferno — Warping Loupe》一节。

**本表要记住的一条**：⚠️ **改了上游常数赖以成立的前提，就必须一起改那个常数——
并且把这件事列进修改标注。**「保留上游表达」的纪律管的是**别偷偷改**，
不是**别改**；照抄一个前提已被自己打破的常数，既不忠于上游、也不正确，
还漏掉了一条通知义务下的修改标注。

**判据**：`RenderProofTests.glassOrbSofteningClosesTheSeam`——三档参数化，
沿过焦点的水平射线读边界内外相邻像素，`softness == 1` 时必须与未变形原图几乎重合，
`softness == 0` 时**反过来**断言接缝存在（那一档要的正是硬边镜片）。
⚠️ 补这条之前，把衰减项换成正确插值 / 换回上游写法，**35 条判据一条都不动**。

### ⚠️ `Halftone` 的 `u_noiseTexture`：处置与代价（本表《⑤-bis》点名要求先定的那条）

《⑤-bis》第 6 轮终审新发现的第 5 件是「`Halftone` 也依赖 `u_noiseTexture`」——
但那条依赖**属于 `halftone-cmyk.ts`**（`:80` 声明 `uniform sampler2D u_noiseTexture`、
`:98` 本地定义 `randomRG()`、`:171` 真的调用），**不属于 `halftone-dots.ts`**
（后者 import 的是**程序化**的 `proceduralHash21`）。

⇒ **本次的处置是：只移植 `halftone-dots.ts` 这一个入口，把 CMYK 那一半整个划出范围。**

⚠️⚠️ **该处置是一次 AC 范围收窄，标为「待用户确认」**（PR #303 终审 I-3）：
`283.md` 的成员表把 `Halftone` 的上游**逐字**写成 `halftone-dots.ts` **+ `halftone-cmyk.ts`**，
本次交付一个。分离在源码层面成立（依据见下一段）、代价已逐条列出、后续建议已写进本节，
**但「任务书点名两个 `.ts`、PR 交付一个」不是一个可以默认通过的工程判断**
——它与本节下方 `GlassOrb` 的 Inferno 许可残余风险**同级**，后者已标「待用户确认」，
本条同等对待，`#283` 的 PR 正文一并点名。
⚠️ 另如实记下：`halftone-dots.ts` 不依赖 `u_noiseTexture` 这条结论核到的是**本文件的二手记录**
（《⑤-bis》），PR #303 终审无网络、未能一手复读上游。
那条纹理依赖因此**结构上不进本仓**——既不需要随包发一张预计算噪声纹理
（省掉包体积与 `resources:` 声明，`moduleBundleOwnership` 那套判据无新对象），
也不需要"换程序化 hash"（没有 hash 可换：`coreDesignHalftone` **一个 hash 都不调用**）。

**代价，如实列出**：
- **CMYK 四色分色那一档没有落地**，连同 `gooey` / `holes` / `soft` 三种点形、
  六边形网格、`inverted`、对比度 sigmoid、三档颗粒（`grainMixer` / `grainOverlay` / `grainSize`）。
  它们不是"不能做"，是本 task 没做。
- ⚠️ **该决定把选择推给了后续 task**：真要落 CMYK 时，那条选择题原样还在。
  **本表的建议是"换程序化 hash"**（本仓已有 `cd::hash21` / `cd::hash22`，
  许可已在《共享原语的逐项出处》清偿），代价是格心抖动的观感与 paper 的纹理采样
  （周期 100 的 tile）不同——那是**设计决策**，不是等价替换。

### ⚠️ 第三方 MIT 通知：给了，且写明了覆盖面

本表《落地义务》第 5 条要求 `Halftone` 转载 **iq** 与 **Dave Hoskins** 两份 MIT 通知
（paper 的 `NOTICE` 对这两位只字未提）。两份已逐字转载在 `ACKNOWLEDGEMENTS.md`。
⚠️ **同时如实记下覆盖面**：本次移植**没有复制那两份 hash**（用 hash 的是 grain 与 CMYK
格心抖动，两者都没移植）⇒ 通知是**宁可多给**，不是"其实不欠"的撤回。

### ⚠️ `GlassOrb` 的残余风险：接受并记录，**待用户确认**

《#280 的落地前核验》③ 把「不在 Inferno 移植清单内 ⇒ 推论为其原创」的**前提下调**了
（两份清单互不一致、且从未声称穷尽——LICENSE 逐字 "**Many** shaders were ported"、
README 逐字 "**Some**"）。本 task **照常落地**，并在 `ACKNOWLEDGEMENTS.md`、
`GlassOrb.swift`、`coreDesignGlassOrb` 与登记表条目**四处**写明该风险。
⚠️ **该风险的"接受"尚未经用户确认**，`#283` 的 PR 正文已点名。
落地过程中**未发现任何指向别的上游的新证据**（一手复读了 `WarpingLoupe.metal` 全文：
函数体零魔数，与《#280 的落地前核验》③ 的记载一致）。

### 本表因本次落地要记住的一条

⚠️ **「任务书里的成员名单」与「裁定表」冲突时以裁定表为准，且必须开工时复核。**
`283.md` 写着 3 件，裁定表只支持 2 件；照任务书做会把一个 `待追溯` 件发出去。
这与本表既有的「两处冲突时以本表为准」是同一条规则，但那条规则此前只写给
**本文件内部**的论证段落，没写给**下游任务书**。此处补记。

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
  - AD-G 补本表结论；⚠️ **`N_B` 填 6**（#280 按「移植 + 署名」重估，区间 [3.40, 8.75]、点估 5.41；
    **旧值 5 的分母口径已作废**——它按 7 个"颜色写死"难件加权，而那 7 个无一可落地）；
    SC 的「可落地数 ≥ `N_B`」标记为**已满足（10 ≥ 6）**
    （⚠️ 历史：第 1 版写 26 ≥ 5、第 2 版写 14 ≥ 5、#281 后写 11 ≥ 5——**前三个数都已被撤回**，
    本行是写进 epic SC 的指令，写错会把撤回的数字固化进闸②验收记录）
  - **B-2 / B-3 的工时按「移植 + 署名」重估**（⚠️ **不是** clean-room——第 1 版结论已反转）
    ⇒ ✅ **#280 已交付该重估**，见《`N_B` 的重估》的分子/分母两张明细
  - ⚠️⚠️ **B-2 / B-3 的成员名单按可落地 10 列，`Water` 不在其中**（#280 改判）
  - 新增：**17 个 `待追溯` 件必须先追一轮**才能进 B-2 / B-3 的任务清单（⚠️ 上上版写 14、
    #281 后写 16、**#280 加 `Water` 后为 17**，已按《统一裁定表》改齐）
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
- ⚠️⚠️ **#280 新增的署名义务（`epic → main` 前必须落地，逐条不可省；与上面四条并列，不重复）**：
  · **Ashima Arts + Stefan Gustavson —— MIT**（`shader-utils.simplexNoise` = `webgl-noise` 的
    2D simplex，常量与结构逐行相同、**许可头被 paper 整段删除**）：影响 `Swirl` / `SimplexNoise`；
    须转载 `Copyright (C) 2011 by Ashima Arts` + `Copyright (C) 2011-2016 by Stefan Gustavson` + MIT 全文；
  · **Inigo Quilez —— MIT**（`Voronoi` 的两趟边界算法逐行同构；`Halftone` 的 `0.3183099` hash 形状）：
    须转载 `// The MIT License / // Copyright © 2013 Inigo Quilez` + MIT 全文
    ——⚠️ **这是在 #281 已记的 iq 两项之外的第三、第四项**，不要以为已经写过了；
  · **David Hoskins —— MIT**（`Halftone` 的 `19.19` / `hash23` 一族，Shadertoy `4djSRW`）：
    须转载 `Copyright (c)2014 David Hoskins` + MIT 全文；
  · **Pablo Roman Andrioli（Kali）**（`StarNest`）：⚠️ 其源码头只有 `// License: MIT`、
    **无版权行、无 MIT 全文** ⇒ 只能写「作者在源码头声明 MIT」，**不得替其补造版权行**；
  · **通行 sin-fract hash**（`colorBandingFix` 的 `12.9898/78.233/43758.5453123`）：
    署名指向**算法本身**，⚠️ **不得引 The Book of Shaders**（其 LICENSE 为 `All rights reserved`）。
  ⚠️ **paper 的 `NOTICE` 全文只有"Powered by Paper Shaders"两行**（#280 一手核）
  ⇒ **上述三份 MIT 通知没有一份被 paper 兑现过，义务全部落在我们头上。**


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

### ⚠️ #280 追加到本清单的条目（**B-2 / B-3 落地 PR** 与 `epic → main` 各查一次）

- [ ] **成员名单按可落地 10**：`Water` **不在** #282 / #283 的清单里
      （若发现它被列入，说明有人读的是 #280 之前的名单 ⇒ 停下来对表）
- [ ] **四份第三方 MIT 通知已转载**（paper 的 `NOTICE` 一份也没给）：
      Ashima Arts + Stefan Gustavson（`Swirl` / `SimplexNoise`）·
      Inigo Quilez（`Voronoi` / `Halftone`）· David Hoskins（`Halftone`）
- [ ] **`StarNest` 的署名写法**：只写「作者在源码头声明 MIT」，**未替作者补造版权行**
- [ ] **`colorBandingFix` 的署名指向算法本身，未引 The Book of Shaders**
- [ ] ⚠️ **三项人工目视核验已完成或已显式记录为未完成**（清单见
      《须用户人工完成的核验》）——`shadertoy.com` 对自动访问全站 403，**这三项只能由人做**
- [ ] ⚠️ **`GlassOrb` 的残余风险已被评审看到并接受**：其可落地性含一条**推论**，
      而该推论的前提（Inferno 的移植清单）已被 #280 证明**非穷尽**（LICENSE 6 组
      vs README 7 条）。**不接受则该件回落 `待追溯`，可落地 10 → 9**
- [ ] ⚠️ **`N_B` 的悲观端余量已被评审看到**：重估区间 3.5–9.0，可落地 10；
      **按上端 9 算，余量只有 1**（点估 6 时余量 4）。**两个数都要看，不能只看有利的**

## 证据强度声明

- **一手核实**：paper-design/shaders 的许可与 NOTICE（GitHub API）· Voronoi 与 NeuroNoise
  的描述句逐字比对（读 paper 源码）· Inferno LICENSE 全文 · ShaderKit LICENSE ·
  webgl-noise / glsl-noise 许可
  - ⚠️ **上上版这一行还列着「Shadertoy 默认许可」——曾移到「二手」**（PR #259 review
    round-4）：当时本表从未直读 Shadertoy 官方条款，唯一依据是一条 Wikipedia 概述。
    ⇒ ✅ **#280 已补齐**，见下方"#280 新增"一档。
- **采信终审 reviewer 的一手比对**：§B 表中标注"终审 reviewer"的 9 行（参数签名比对）
  ⇒ ⚠️ **#280 已把这 9 行全部替换为本人一手读全文**（连同 `shader-utils.ts` 这一层），
  其中 `Water` 一行**因此翻案**。**"采信 reviewer"这一档在 §B 上已不再是承重项。**
- **二手**：三份 `ldl3W8` 的 2013 vintage 拷贝头（Natron / uniVR / ShaderLoader，
  逐字 CC BY-NC-SA 3.0）——**已被 #280 的 API 响应（MIT）取代，仅作"许可变过"的留档**
- **⚠️⚠️ #280 新增的一手核实（12 条，逐条 URL 与原文见《#280 的一手实查清单》）**：
  **Shadertoy 官方条款原文**（IA 快照 2025-09-20 + CDX digest 稳定性核验）·
  Shadertoy 公开 API 对 `XlfGRj` / `ldl3W8` / `4djSRW` / `mlBXRK` 的响应（转储 2025-05-29）·
  iq `/articles/` 与 `/articles/voronoilines/`（今天实时）· Inferno LICENSE/README/
  `WarpingLoupe.metal`/`SimpleLoupe.metal`/commit API（今天实时）·
  paper 的 14 个 `shaders/*.ts` + `shader-utils.ts` + LICENSE + NOTICE（今天实时）·
  `ashima/webgl-noise` 与 `stegu/webgl-noise` 的 `noise2D.glsl` + LICENSE（今天实时）·
  `libretro/glsl-shaders` 的 `bigwings-luminescence.glsl`（今天实时）
- **⚠️ #280 的载体分级**：上述前两项是 **"一手内容 · 归档载体"**（内容出自官方 URL 本身，
  但读的是 IA 快照 / API 转储，**非实时**）；其余是 **"一手 · 实时"**。**两者不得混称。**
- **⚠️ #280 未能直读的（明标）**：`shadertoy.com` **全站 403**（Cloudflare；`/terms`
  `/view/*` `/embed/*` `/api/v1/*` 逐个实测，三种客户端均同）·
  **IA 对 `/view/*` 的快照只存 SPA 外壳、不含 shader 源码**（实测 `formuparam` /
  `Star Nest` / `Pablo` 在快照里零出现）·
  `x.com/zozuar/status/1625182758745128981` **未直读**（该推文内容与许可**未核**；
  本表对它的处置不依赖读到它，依赖的是"它没有任何许可声明"这一点由 paper 自己写着）
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
