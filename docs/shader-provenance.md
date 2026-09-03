# Shader 许可来源裁定表（#249 / `shipswift-foundation` 闸②）

> 覆盖 ShipSwift 的全部 **28** 个 Metal shader。**每一行都有裁定，没有空行。**
> 本表是**裁定过程**；对外的许可声明在 `ACKNOWLEDGEMENTS.md`，前者判为可落地的行
> 必须在后者有对应条目。

## 为什么必须做这件事

**Shadertoy 的默认许可是 CC BY-NC-SA 3.0——完全禁止商用**，除非 shader 源码开头有注释
声明了别的许可（[已核实](https://en.wikipedia.org/wiki/Shadertoy)）。CoreDesign 以 MIT
分发，**与 CC BY-NC-SA 不兼容**（既禁商用，又有传染性 share-alike）。

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
拿到下列三种结论之一才算裁定完成：

| 裁定 | 含义 | 落地义务 |
|---|---|---|
| `已追到兼容许可 · MIT` | 追到原始实现，许可为 MIT / BSD / PD / CC0 | 可移植；`ACKNOWLEDGEMENTS.md` 转载原始许可 |
| `已追到兼容许可 · Apache-2.0` | 追到原始实现，许可为 Apache-2.0 | 可移植；**须转载 LICENSE + `NOTICE`，并标注修改**（§4(a)(b)(d)） |
| `clean-room 重写` | 属公开算法，**且本表已在该行具名一个许可已核实的参考实现** | 对照该参考实现重写 |
| `待追溯` | 尚未用上面《方法论教训》的方法追过 | **不得据现状落地**；先追一轮 |
| `不落地` | 追过且追不到兼容来源，也无具名参考实现 | 不进 `CoreDesignShaders` |

⚠️ **`Apache-2.0` 是第 1 版遗漏的档位**（第 1 版只列 MIT / BSD / PD / CC0）。它与 MIT
分发兼容，但**义务更多**：保留 LICENSE、保留 NOTICE、标注修改。

⚠️ **`clean-room` 的成立条件在第 1 版形同虚设**：第 1 版判 24 行 clean-room，其中
**17 行没有具名任何参考实现**——只写了「标准教科书内容」「Blinn 1982」「公开的图形学配方」。
**没有具名参考实现，"不看 ShipSwift" 就退化成"看 Shadertoy"**，而 Shadertoy 默认许可
正是 CC BY-NC-SA。⇒ **本版规定：`clean-room` 行必须给出 URL + 已核实的许可，
否则一律降级为 `待追溯`。**

### `clean-room 重写` 的可核产物条款

**不写成"不看 ShipSwift 的 `.metal`"**——那既不可执行（本次调研本身已 grep 过全部
34 个 `.metal`），法律风险也不在读 ShipSwift（它是 MIT），**而在于 ShipSwift 的文件
本身若是 CC BY-NC-SA 衍生**。可核的三条：

1. 本表的 `参考实现` 列**必须指向参考实现**，不得指向 ShipSwift；
2. 新 `.metal` 文件头注明参考实现 URL + 其许可；
3. 评审**对照参考实现**核，不对照 ShipSwift。

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
**没有具名参考实现**（按本版 clean-room 成立条件直接降级）；**且 clean-room 在这里本就
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

## §B 追到 `paper-design/shaders`（Apache-2.0）的 11 个

上游：**[paper-design/shaders](https://github.com/paper-design/shaders)，Apache-2.0，
3414 stars，带 `LICENSE` 与 `NOTICE`**（一手核，GitHub API）。

| # | shader | paper 对应文件 | 匹配依据 | 核验者 |
|---|---|---|---|---|
| 8 | `Voronoi` | `voronoi.ts` | 描述句**近逐字** + 参数集全对应 + `randomGB`↔`textureRandomizerGB` | **本人一手** |
| 9 | `NeuroNoise` | `neuro-noise.ts` | 描述句**逐字** + `brightness/contrast/colorFront/colorMid/colorBack` | **本人一手** |
| 10 | `Swirl` | `swirl.ts` | `bandCount/twist/center/proportion/softness/noise` | 终审 reviewer |
| 11 | `SimplexNoise` | `simplex-noise.ts` | `stepsPerColor/softness/10 colors`；双层 simplex 叠加 | 终审 reviewer |
| 12 | `Water` | `water.ts` | `highlights/layering/edges/waves/caustic/size/colorBack/colorHighlight` | 终审 reviewer |
| 13 | `ColorPanels` | `color-panels.ts` | `density/angle1/angle2/length/edges/blur` | 终审 reviewer |
| 14 | `DotOrbit` | `dot-orbit.ts` | `size/sizeRange/spreading/stepsPerColor` | 终审 reviewer |
| 15 | `SmokeRing` | `smoke-ring.ts` | `thickness/radius/innerShape/noiseScale/noiseIterations/colorBack` | 终审 reviewer |
| 16 | `Metaballs` | `metaballs.ts` | `count/size/colors` | 终审 reviewer |
| 17 | `Halftone` | `halftone-dots.ts` + `halftone-cmyk.ts` | 两入口一一对应；`classic/gooey/holes/soft`、`originalColors`、`colorC/M/Y/K`。**ShipSwift 自己在 `SWHalftone.metal:350` 写着 "simplified port"** | 终审 reviewer |
| 18 | `GrainGradient` | `grain-gradient.ts` | 参数**部分**匹配 | 终审 reviewer（**存疑**） |

**裁定：#8–17 为 `已追到兼容许可 · Apache-2.0`；#18 `GrainGradient` 为 `待追溯`**（匹配未确认）。

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
| 19 | `FractalClouds` | clean-room | **`clean-room 重写`** | 参考实现已具名且许可已核：[ashima](https://github.com/ashima/webgl-noise) / [stegu](https://github.com/stegu/webgl-noise) / [glsl-noise](https://github.com/hughsk/glsl-noise) 均 **MIT**。⚠️ 噪声原语只覆盖 FBM 底座，**domain-warp 与调色的组合仍须先追一轮** |
| 20 | `InkSmoke` | clean-room | **`clean-room 重写`** | 同上 |
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

## 汇总与闸②判定

| 裁定 | 数量 | 明细 |
|---|---|---|
| **已追到兼容许可 · MIT** | **2** | GlassOrb、StarNest |
| **已追到兼容许可 · Apache-2.0** | **10** | §B 的 #8–17 |
| **clean-room 重写**（已具名参考实现） | **2** | FractalClouds、InkSmoke |
| **待追溯** | **14** | ShaderKit 5 + GrainGradient + §C 的 8 个 |
| **不落地** | **0** | ⚠️ 第 1 版判的 2 个已改判 `待追溯`——原理由与 §C 其余项双标 |
| 合计 | **28** | 无空裁定 ✅ |

### 闸②判定：**通过**

- **现可落地数 = 2 + 10 + 2 = 14**
- **`N_B` = 5**（由 #248 spike 按「固定成本 8–12h ÷ 边际 2.0–2.5h/shader」反推）
  ⚠️ #248 初稿曾给 10（按 10–16h ÷ 1.5h），该推导有分子分母重叠等三处问题，**已作废**
- **14 ≥ 5 ⇒ 闸②通过，`shipswift-shaders`（#243）可启动**

### ⚠️ 与第 1 版相比，成本方向**反转了**

第 1 版说「24/26 走 clean-room，比移植贵得多，B-2/B-3 须上调工时」。**本版相反**：

- **12/14 是"带署名的移植"，不是 clean-room** —— 移植**比** clean-room **便宜**；
- 但多了 **Apache-2.0 的署名义务**（LICENSE + NOTICE + 修改标注）；
- 另有 **14 个 `待追溯`**，每个须先追一轮（小时级）才能定档。

⇒ **B-2 / B-3 分解时按「移植 + 署名」重估，不是按 clean-room。**

---

## 需要回改的文档

- `.claude/epics/shipswift-shaders/epic.md`：
  - AD-G 补本表结论；`N_B` 填 **5**；SC 的「可落地数 ≥ `N_B`」标记为**已满足（14 ≥ 5）**
  - **B-2 / B-3 的工时按「移植 + 署名」重估**（⚠️ **不是** clean-room——第 1 版结论已反转）
  - 新增：**14 个 `待追溯` 件必须先追一轮**才能进 B-2 / B-3 的任务清单
  - 删除「`LiquidChrome` / `LiquidMetal` 不在范围内」——已改判 `待追溯`
- `.claude/epics/shipswift-foundation/epic.md`：A0-6 的 SC 勾选
- `ACKNOWLEDGEMENTS.md`：**预留 Apache-2.0 + NOTICE 段**（paper-design/shaders）

## 证据强度声明

- **一手核实**：paper-design/shaders 的许可与 NOTICE（GitHub API）· Voronoi 与 NeuroNoise
  的描述句逐字比对（读 paper 源码）· Inferno LICENSE 全文 · ShaderKit LICENSE ·
  webgl-noise / glsl-noise 许可 · Shadertoy 默认许可
- **采信终审 reviewer 的一手比对**：§B 表中标注"终审 reviewer"的 9 行（参数签名比对）
- **二手**：StarNest 的 MIT（五个独立来源逐字一致，但未直读 shadertoy 原页面）
- **未证**：§C 里 8 个 `待追溯` 的实际出处 —— 故判 `待追溯` 而非 clean-room

⚠️ **第 1 版在此处写「本表没有声称知道那 21 个来自哪里，故日后有人追到也不受影响」——
该辩护随本版作废**：它建立在"追不到"的前提上，而那个前提被一小时的比对推翻了。
