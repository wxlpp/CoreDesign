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

## 裁定方法：正向裁定，不证否定

⚠️ **"证明来源不明"是要证一个否定，做不到。** 本表用**正向裁定**——每个 shader 只有
拿到下列三种结论之一才算裁定完成：

| 裁定 | 含义 | 落地方式 |
|---|---|---|
| `已追到兼容许可` | 追到原始实现，且其许可为 MIT / BSD / PD / CC0 | 可移植；须在 `ACKNOWLEDGEMENTS.md` 转载原始许可 |
| `clean-room 重写` | 属公开算法，且**存在具名的、许可兼容的参考实现** | **对照参考实现重写，不看 ShipSwift 的 `.metal`** |
| `不落地` | 追不到兼容许可，也不属可 clean-room 的公开算法 | 不进 `CoreDesignShaders` |

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
| 1 | `GlassOrb` | [Inferno](https://github.com/twostraws/Inferno) 的 "Warping Loupe"（Paul Hudson） | **MIT**（已核实读取 LICENSE 全文） | ✅ **链条闭合**。Inferno 的 LICENSE 附有逐 shader 的移植来源清单，仅含 5 项（Crosswarp / Radial / Swirl / Wind / Genie，均来自 gl-transitions）；**"Warping Loupe" 不在其中** ⇒ 它是 Inferno 的**原创**，由其 MIT 覆盖，无进一步传递问题 | **已追到兼容许可** |
| 2 | `StarNest` | ["Star Nest" by Pablo Roman Andrioli（Kali）](https://www.shadertoy.com/view/XlfGRj) | **MIT**（作者在源码头声明，覆盖 Shadertoy 默认许可） | ✅ 多个独立移植各自记录其为 MIT（[a-frame 组件](https://github.com/urish/aframe-starnest-component)、[Godot Shaders](https://godotshaders.com/shader/star-nest-2/)、[NatronGitHub/openfx-misc](https://github.com/NatronGitHub/openfx-misc/blob/master/Shadertoy/presets/default/star%20nest-natron.frag.glsl)）。⚠️ shadertoy.com 对自动抓取返回 403，**未能直读源码头**——证据是多个独立第三方的一致记录，非一手 | **已追到兼容许可**（⚠️ 落地前建议人工打开该页面目视确认源码头的 MIT 声明） |
| 3 | `ChromaticGlass` | [ShaderKit](https://github.com/jamesrochabrun/ShaderKit)（James Rochabrun） | **MIT**（GitHub 识别 + 已核 LICENSE） | ⚠️ **传递来源未闭合**——ShaderKit 的 LICENSE **只有 21 行纯 MIT 正文，没有任何移植来源说明**（对比：Inferno 有）。这 5 个的更上游是原创还是移植自 Shadertoy，**ShaderKit 自身未记录** | **clean-room 重写**（见下方裁断） |
| 4 | `Foil` | 同上 | 同上 | 同上 | **clean-room 重写** |
| 5 | `Glitter` | 同上 | 同上 | 同上 | **clean-room 重写** |
| 6 | `IntenseBling` | 同上 | 同上 | 同上 | **clean-room 重写** |
| 7 | `PolishedAluminum` | 同上 | 同上 | 同上 | **clean-room 重写** |

### 对 ShaderKit 那 5 个的裁断说明

**MIT 在 ShaderKit 那一层是真的**，问题在于**它上面还有没有一层**。ShaderKit 没有记录，
我也无法证明它有或没有。两个选项：

- **按"上游声明 MIT 即可"接受** —— 风险：若 ShaderKit 自己移植自 CC BY-NC-SA 的
  Shadertoy 作品，它无权以 MIT 再许可，我们跟着错。
- **走 clean-room** —— 这五个的效果（箔片彩虹、闪片、色散玻璃、金属拉丝、强烈 bling）
  都是**公开的图形学配方**（fresnel 边缘 + 相位偏移的彩虹 ramp + 高次幂 sparkle 项），
  有充分的公开文献可依。

⇒ **裁定走 clean-room**：成本增量不大（本来就要把它们的调色板从 `.metal` 提到 Swift 侧，
见 spike #248 交付 B：这 7 个"颜色写死"件本就 ≈2–3h/个），换掉一个**无法闭合的法律不确定性**。
⚠️ 这不是说 ShaderKit 有问题——是说**我们无法核实**，而无法核实的东西不该进以 MIT 分发的库。

---

## B. 零标注的 21 个 —— 按"是否有具名的、许可兼容的参考实现"裁定

⚠️ **本节的裁定不是对"它们来自哪里"的断言**——那我无法确立。裁定的依据是
**「这个效果是不是公开算法，且存在一个我能具名、许可兼容的参考实现可供重写」**。

### B-1 噪声派生（参考实现：MIT）

参考实现均已核实许可：
[ashima/webgl-noise](https://github.com/ashima/webgl-noise) **MIT** ·
[stegu/webgl-noise](https://github.com/stegu/webgl-noise) **MIT** ·
[hughsk/glsl-noise](https://github.com/hughsk/glsl-noise) **MIT**

| # | shader | 算法 | 裁定 |
|---|---|---|---|
| 8 | `SimplexNoise` | Simplex noise（Ken Perlin），事实标准实现是 Ashima/Gustavson | **clean-room 重写** |
| 9 | `FractalClouds` | FBM over noise + domain warp | **clean-room 重写** |
| 10 | `InkSmoke` | domain-warped FBM | **clean-room 重写** |
| 11 | `SmokeRing` | value-noise FBM 扭曲环 | **clean-room 重写** |
| 12 | `NeuroNoise` | domain-warped noise | **clean-room 重写** |
| 13 | `GrainGradient` | noise + 渐变 | **clean-room 重写** |
| 14 | `Water` | noise 驱动的水面扰动 | **clean-room 重写** |

### B-2 教科书级程序化图形（参考：公开文献 / 教科书）

| # | shader | 算法与公开出处 | 裁定 |
|---|---|---|---|
| 15 | `Voronoi` | 元胞/Voronoi 距离场，标准教科书内容 | **clean-room 重写** |
| 16 | `Metaballs` | Blinn 的 blobby model（1982），标准教科书内容 | **clean-room 重写** |
| 17 | `Plasma` | 经典 demoscene 正弦叠加，公有领域级别的老配方 | **clean-room 重写** |
| 18 | `Starfield` | 网格 hash + 亮度衰减，程序化星空标准做法 | **clean-room 重写** |
| 19 | `Halftone` | 半调网屏（印刷术数学），标准做法 | **clean-room 重写** |
| 20 | `Dots` | 网格 + 三角函数 | **clean-room 重写** |
| 21 | `DotOrbit` | 网格 + 极坐标轨道 | **clean-room 重写** |
| 22 | `Swirl` | 极坐标扭转 | **clean-room 重写** |
| 23 | `ColorPanels` | 网格/Voronoi 分区 + 调色板映射 | **clean-room 重写** |

### B-3 复合 / 特征性强的 —— 逐个判，不搭便车

| # | shader | 判断 | 裁定 |
|---|---|---|---|
| 24 | `AnimatedLoop` | 它是**调度器**，按名字分派到上面那些效果（`.metal` 头自述「use a single argument list and dispatch by name」），本身无独立算法 | **clean-room 重写**（随被它调度的效果一起） |
| 25 | `Glass` | SDF 定义区域 + 折射 + 边缘 mask 交叉淡入。SDF 与折射都是公开配方（iq 的 SDF 文章为公认参考） | **clean-room 重写** |
| 26 | `GlassLogo` | `Glass` 的变体 + 硬编码调色板（`SWGlassLogoStyle`）。算法同 25；调色板本就要重做（FR-8 禁硬编码色） | **clean-room 重写** |
| 27 | `LiquidChrome` | ⚠️ **特征性很强的观感**，非通用配方。无法具名一个许可兼容的参考实现；很可能对应某个具体的 Shadertoy 作品 | **不落地** |
| 28 | `LiquidMetal` | ⚠️ 同上。且它是 7 个"颜色写死"件之一（`coolTint` 是 `Float`），复杂度也最高 | **不落地** |

⚠️ **27 / 28 判"不落地"的理由不是"它们一定有问题"**，而是**我无法为它们具名一个
许可兼容的参考实现**——而 clean-room 出口的成立**依赖于能具名参考实现**。
若将来有人追到其原始出处且许可兼容，可改判。

---

## 汇总与闸②判定

| 裁定 | 数量 | 明细 |
|---|---|---|
| **已追到兼容许可** | **2** | GlassOrb（Inferno MIT，链条闭合）、StarNest（作者声明 MIT） |
| **clean-room 重写** | **24** | ShaderKit 5 + 噪声派生 7 + 教科书 9 + 复合 3 |
| **不落地** | **2** | LiquidChrome、LiquidMetal |
| 合计 | **28** | 无空裁定 ✅ |

### 闸②判定：**通过**

- **可落地数 = 2 + 24 = 26**
- **`N_B` = 5**（由 #248 spike 按「固定成本 8–12h ÷ 边际 2.0–2.5h/shader」反推）
  ⚠️ #248 初稿曾给 **10**（按 10–16h ÷ 1.5h），该推导有分子分母重叠等三处问题，**已作废**
- **26 ≥ 5 ⇒ 闸②通过，`shipswift-shaders`（#243）可启动**
  ⚠️ 按作废前的 10 算同样通过（26 ≥ 10）⇒ **go/no-go 结论不受该修正影响**

⚠️ **但落地形态与 epic 的假设很不一样**：**24/26 走 clean-room 重写，只有 2 个是移植**。
这对 Epic B 的成本有实质影响——clean-room 比"改调色板 + 包 wrapper"贵，
因为要**对照参考实现从头写 `.metal`**。#248 交付 B 给的 ≈1.5h/shader 边际成本
**是按「难件 + 逐 shader 文档」估的，不是按 clean-room 估的** ⇒ **B-2 / B-3 分解时必须按 clean-room 重估工时**（#248 的回改清单已点名此项，两边一致）。

### 需要回改的文档

- `.claude/epics/shipswift-shaders/epic.md`：
  - AD-G 补本表结论；`N_B` 填 **5**（⚠️ **不是 10**——10 是 #248 初稿的作废值）；
    SC 的「可落地数 ≥ `N_B`」标记为**已满足（26 ≥ 5）**
  - **B-2 / B-3 的工时按 clean-room 重估**（不是移植）
  - 明确 `LiquidChrome` / `LiquidMetal` **不在范围内**（28 → 26）
- `.claude/epics/shipswift-foundation/epic.md`：A0-6 的 SC 勾选
- `ACKNOWLEDGEMENTS.md`：本 task 建骨架（表头 + 说明 + 上游许可全文转载）；
  **逐 shader 条目由各自落地的 task 追加**——闸②虽通过，仍不得署名尚未落地的 shader

## 本表的证据强度声明

⚠️ **诚实说明本表能证什么、不能证什么**：

- **能证**：GlassOrb 与 StarNest 的许可链（一手读取 Inferno LICENSE 全文；
  StarNest 是多个独立第三方的一致记录，**非一手**——shadertoy.com 返回 403）。
  ShaderKit / Inferno / webgl-noise / glsl-noise 的仓库许可（一手，GitHub API）。
  Shadertoy 默认许可为 CC BY-NC-SA 3.0（公开来源）。
- **不能证**：那 21 个零标注 shader 的**实际出处**。本表**没有**声称知道它们来自哪里；
  它们的可落地性**完全建立在 clean-room 重写这条出口上**，而不是建立在对其来源的判断上。
- ⇒ **若有人日后追到某个 shader 的原始出处且不兼容，本表的裁定不受影响**——
  因为我们本来就不打算移植它，而是对照独立的、具名的、许可兼容的参考实现重写。
