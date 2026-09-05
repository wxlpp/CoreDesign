# Acknowledgements

CoreDesign 的部分实现衍生自第三方开源项目。按各自许可的要求，原始版权与许可声明
转载于下。

> **本文件与 [`docs/shader-provenance.md`](docs/shader-provenance.md) 的分工**：
> provenance 表是**裁定过程**（每个 shader 追到哪、许可是什么、判可不可落地）；
> 本文件是**对外的许可声明**。前者判为可落地的行，**在其真正落地时**必须在本文件
> 有对应条目。
>
> ⚠️ **本文件由 #249 建为骨架，逐条由各自落地的 task 填实**——闸②虽已通过，
> 仍不得署名尚未落地的东西。
> **已生效的 shader 条目（`#283`）**：《Inferno — Warping Loupe》（`View.glassOrb`）与
> 《paper-design/shaders》（`View.halftone`，**只对 `Halftone` 一件生效**）。
> 仍为**占位**的：《Star Nest》，以及 paper 那一档里尚未落地的另外 7 个。

## 归属分档

每个条目须标明属于哪一档，各档的义务不同：

| 档 | 含义 | 义务 |
|---|---|---|
| **较大段落移植** | 直接采用了上游的实现（即便重命名、重排、改了参数表） | 转载完整原始许可 + 指明原作者与原始 URL |
| **参考算法思路** | 对照上游或公开文献**重写**，未复制其代码 | 指明参考实现与其许可，说明是重写 |
| **未知（上游未指认）** | ⚠️ **未定档，不是第三种结论**：已判定它有外部谱系（故不作原创声称），但**具体上游尚未指认到**，因而无法判断复制了多少 | **不得作原创声称**；落地前须按 `docs/shader-provenance.md`《方法论教训》追一轮，**追到后必须改判为上面两档之一**；追不到 ⇒ 该件不落地 |

⚠️ **第三档是本文件《`CoreDesignShaders` 的共享原语与公开配方》一节的实际需要**
（`ramp3` 与 `coreDesignRefractiveGlass` 的位移 + 通道色散主体两行）：**「指认不到具体上游」既不是「移植了一大段」、
也不是「对照某个参考实现重写」**——上一版只有前两档，于是这两行在 `复制程度` 列里
不属于本表任何一档（PR #259 review round-2 指出）。⇒ 补设本档并写明它是**待定态**，
而不是把它们硬塞进前两档之一。

⚠️ **本表是「复制程度」这一根轴，回答「我们抄了多少」。**
「抄了合不合法」是**另一根轴**——`许可地位`，取值域由
`docs/shader-provenance.md`《裁定方法：正向裁定，不证否定》的裁定取值表定义。
**逐字取值**（两份文档按同一串字面量互查）：`已追到兼容许可 · MIT` /
`已追到兼容许可 · Apache-2.0` / `自研实现` / `待追溯` / `不落地`；
其中 `待追溯` 按同文《清偿条款》再分 `待追溯（低指纹）` 与
`待追溯（强指纹 · 阻断）` 两档。
⚠️ `clean-room 重写` **不在取值域内**——它已废除，同文对它只保留一节留档说明。
⚠️ **两根轴不得混成一列**——共享原语一节上一版就是这么错的：
把四个许可地位的值塞进「档位」列，于是 10 行里 5 行不属于本表任何一档，
紧接着正文又写「统一登记为『待追溯』」，与那一列直接打架。

---

## ShipSwift

CoreDesign 的表达性视觉层（`CoreDesignEffects`，以及**计划中、尚未合入本仓**的
`CoreDesignShaders`）与图表层（`CoreDesignCharts`）的**点子与算法**来自
[ShipSwift](https://github.com/signerlabs/ShipSwift)（SignerLabs）。
⚠️ **`CoreDesignShaders` 的状态**：本仓 `Package.swift` **有意不预留**该 product/target
（见其 `products:` 处注释），它由 `shipswift-shaders` 在两闸通过后单独引入，
当前只存在于**未合入**的 PR #261。⇒ 本文件凡提到 `CoreDesignShaders` 的小节
（下方《Inferno》《Star Nest》《paper-design/shaders》《`CoreDesignShaders` 的共享原语
与公开配方》）**一律是预登记的占位，不是已生效的对外声明**。

⚠️ **归档义务（不是既成陈述）**：CoreDesign 的实现**须**按自身 API 公约与色彩地基重做；
逐组件属于哪一档见其 `docs/components/*.md`。
⚠️ 第 1 版在此断言"是重写的，不是拷贝"——**当时两个 target 还是空骨架，那是预判**，
已改为义务描述。
⚠️ **更要紧**：`docs/shader-provenance.md` 已证 **ShipSwift 的 MIT 声明不覆盖它内含的
Apache-2.0 衍生物**（provenance 表 §B 追到 **11 个** shader 源自 `paper-design/shaders`，
其中 **9 个**已正向裁定为 Apache-2.0、2 个仍 `待追溯`）⇒ **不得把 ShipSwift
的 MIT 当作全集**，逐项署名以 provenance 表为准。

```
MIT License

Copyright (c) 2026 SignerLabs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### 逐单位归档：`shipswift-effects` 的 40 个 API 单位（`#242`，由 `#256` 补录）

**全部 40 个单位归入「参考算法思路」档**，不涉及「较大段落移植」。

⚠️ **这条分档的依据与它的边界，逐条写清楚（不要读成比实际更强）：**

- **依据 ①（规范）**：epic 的 **AD-A**「上游是配方，不是可消费代码」——ShipSwift 源码
  全部 `internal`、硬编码色、零 accessibility、零 `controlSize` / Dynamic Type 适配、
  零测试 ⇒ **只借算法**（力导向布局、confetti 物理、16 个 mask reveal 的 `Shape` 数学、
  `KeyframeAnimator` 相位序列），API 层与色彩层全部重写。
- **依据 ②（可核实的痕迹）**：各落件 task 在源码里逐处记下了**与上游的有意分歧**，
  这些记录本身就是「重写而非拷贝」的证据。可核对的样本（非穷举）：
  · `SphereField.swift` —— 色板插值改走 `Color.mix(.perceptual)`（Oklab 系），
    上游是 `UIColor.getRed` + 分量 lerp（等价 `.device`）；半透明色板下**结果不同**，
    逐条记在 `docs/components/dot-sphere.md`《与上游的有意分歧》。
  · `SphereField.swift` —— 字形分配改为**确定性散列**，上游是 `Int.random`。
  · `OrbitRing.swift` —— 上游靠 `SKPhysicsBody` 撞开邻居，本仓是解析位移场；
    上游点上写死绿色渐变，本仓走 `.tint` / 语义 token。
  · `MaskReveal.swift` —— 上游用羽化遮罩，本仓走 `clipShape`；**代价（硬边缘）已照录**。
  · `CharSphere.swift` —— 上游默认字表是《道德经》第一章，本仓**不自带任何字表**。
  · `BeforeAfterSlider.swift` —— 上游签名 `showLabels: Bool`，本仓改语义枚举（FR-6 点名）。
  · `NetworkGraph.swift` —— 丢弃上游 4973 行 demo 数据（`SWNetworkGraphData.swift`），
    只落布局与渲染。
- ⚠️ **边界（必须说明）**：`#256` **没有**把本仓实现与上游源码做逐行 diff——本仓树里
  没有 ShipSwift 的源码副本，无法在 CI 或本地做机器比对。⇒ 这条分档建立在
  **上面两条依据 + PR 评审**之上，**不是**一次自动化核验的结论。
  若将来引入上游快照做机器比对，本节应改写为带比对结果的形态。
- ⚠️ **本节不覆盖 shader**：`docs/shader-provenance.md` 已证 ShipSwift 的 MIT 声明
  **不覆盖它内含的 Apache-2.0 衍生物**。那一面归 `shipswift-shaders`，逐项以
  provenance 表为准，与本节无关。

| 组 | 单位 | 档 |
|---|---|---|
| 微交互（8） | shake / jump / spin / ping / spray / rise / haptic / shine | 参考算法思路 |
| 转场（16） | blur / flip / rotate3D / swoosh / boing / skid / move / iris / wipe / blinds / clock / flicker / filmExposure / snapshot / glare / dissolve | 参考算法思路 |
| 庆祝与处理中（4） | Confetti / ScanningOverlay / GlowSweep / LightSweep | 参考算法思路 |
| 文本与展示（4） | TypewriterText / AnimatedMeshGradient / BeforeAfterSlider / ParticleTransition | 参考算法思路 |
| 跨平台改造（4） | OrbitingLogos / DotSphere / CharSphere / FullScreenButton | 参考算法思路 |
| 图表（4） | RadarChart / RingChart / ActivityHeatmap / NetworkGraph | 参考算法思路 |

⚠️ `.haptic(_:trigger:)` 是对 **SwiftUI 自带** `sensoryFeedback` 的薄封装，
其实现与上游无关；列在表里是为了「40 个单位一个不落」，它的归属实际是「自研封装」。

---

## Inferno — Warping Loupe（`View.glassOrb`，**已落地** · `#283`）

⚠️ **本节 `#283` 由占位改为生效**：`View.glassOrb(size:magnification:)` 已落地在
`Sources/CoreDesignShaders/GlassOrb.swift` + `CoreDesignShaders.metal` 的
`coreDesignGlassOrb`。

- **上游**：[Inferno](https://github.com/twostraws/Inferno) 的
  `Sources/Inferno/Shaders/Transformation/WarpingLoupe.metal`（Paul Hudson 等）
- **许可**：**MIT**
- **档位**：**较大段落移植** —— ⚠️ 落地后定案（上一版写的是「预期档位」）。
  保留的是它的算法结构与表达：`totalZoom = 1` → 区域内 `totalZoom /= zoomFactor`
  → `totalZoom += smoothstep(…) / 2` → `newPosition = delta * totalZoom + center`
  → `layer.sample(newPosition)`。
- **我们的修改**（逐条列在 `coreDesignGlassOrb` 的文档注释里，此处摘要）：
  ① 坐标空间由 UV（并用 `dx² + dy²/aspect` 近似圆）改为**点空间**的真圆，
     `radius` 的含义因此与上游的 `maxDistance` 不同；
  ② 新增 `softness` 系数（0…1），供 Reduce Transparency 下取 0，
     那时圆内是常数放大 + 硬边；
  ③ ⚠️⚠️ **衰减项由 `+= smoothstep(…) / 2` 改为「向 1.0 插值」**
     `+= (1 - totalZoom) * smoothstep(…)`。**本条是 PR #303 终审 C-1 补记的**
     ——上一版只列了 ①②，漏了后果最重的这一条。上游那个 `/2` 与它自己 `zoomFactor`
     的默认值 **2** 配套（`1/2 + 1/2 = 1`，边界恰好回到 1）；本仓**同时**改了坐标空间
     **并且**自选了 1.6 / 2.4 / 4.0 三档，**一档都不是 2** ⇒ 照抄那个常数，
     边界处 `totalZoom` 分别是 1.125 / 0.917 / 0.750，三档各留一道接缝
     （gentle 档还会**反向缩小**）。⇒ 那个常数赖以成立的前提已被我们自己打破，
     必须改，而**改了就要列出来**——这正是本节存在的理由。

### 许可全文（MIT）

⚠️ **逐字转载**（`raw.githubusercontent.com/twostraws/Inferno/main/LICENSE`，
含其自带的移植来源清单——**一并转载，不裁剪**）：

```
MIT License

Copyright (c) 2023 Paul Hudson and other authors.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.



Many shaders were ported to Metal from elsewhere then had comments added, and
some were subsequently extended to add extra functionality. The original authors
and sources and linked below. All licenses are MIT. Any mistakes or performance
problems introduced in the porting process are entirely my fault.


Circle, Circle Wave, Diamond, Diamond Wave
---
Based on: https://gl-transitions.com/editor/PolkaDotsCurtain
Original author: bobylito,
Metal port and enhancements: Paul Hudson
License: MIT


Crosswarp
---
Based on: https://gl-transitions.com/editor/crosswarp
Original author: Eke Péter
Metal port: Paul Hudson
License: MIT


Radial
---
Based on: https://gl-transitions.com/editor/Radial
Original author: Xaychru / gre
Metal port: Paul Hudson
License: MIT


Swirl
---
Based on: https://gl-transitions.com/editor/Swirl
Author: Sergey Kosarevsky / gre
Metal port: Paul Hudson
License: MIT


Wind
---
Based on: https://gl-transitions.com/editor/wind
Original author: gre
Metal port: Paul Hudson
License: MIT

Genie
---
Based on: https://www.shadertoy.com/view/flyfRt
Original author: altaha-ansari
Metal port: twodayslate
License: MIT
```

### ⚠️ 一条必须写在明处的残余风险

`docs/shader-provenance.md`《#280 的落地前核验》③ 把「"Warping Loupe" 不在 Inferno 的
移植清单内 ⇒ 推论为其原创」这条推论的**前提下调**了：Inferno 的 LICENSE 清单（**6 组**）
与 README 清单（**7 条**，多一个 `Shimmer`）**互不一致**，且两份清单**从未声称穷尽**
——LICENSE 逐字 "**Many** shaders were ported"，README 逐字 "**Some**"
⇒ **清单不能当穷尽名单用**，"不在清单上"能推出的东西相应变少。

支持不掉档的三条（同为一手）：① Inferno 以 MIT 对**整仓**授权；
② `warpingLoupe` 函数体**零魔数**（全部字面量是 `0.0h` / `1.0h` / `2.0h`）⇒ 无指纹可追，
也无处藏抄袭；③ 其文档自述 "This works identically to the simple loupe shader…"
⇒ 派生自 Inferno **自有**的 `SimpleLoupe`。

⇒ 若 "Warping Loupe" 其实是一个**未登记的、来自非 MIT 来源**的移植，Inferno 对它就是
无权再许可，我们跟着错。**这不是再查一轮能消除的风险**（追不到就是追不到），
是**接受并记录**的；本节即那份记录，`#283` 的 PR 正文亦已点名待用户确认。

---

## Star Nest（待 `StarNest` 落地时启用）

> ⚠️ 占位。落地时（`shipswift-shaders` B-2）填入并转载 MIT 正文。

- 上游：["Star Nest" by Pablo Roman Andrioli（Kali）](https://www.shadertoy.com/view/XlfGRj) — 作者在源码头声明 MIT
- 预期档位：**较大段落移植**（分形"magic formula"与体积步进预计保留）⚠️ 档位待落地时定案
- ⚠️ **落地 task 的硬 AC**：人工目视确认该 Shadertoy 页面源码头的 MIT 声明——自动抓取
  返回 403，现有证据是**五个**独立第三方移植的逐字一致记录，非一手。

---

## paper-design/shaders（Apache-2.0）—— `View.halftone`，**部分落地** · `#283`

⚠️ **本节 `#283` 由占位改为生效，但只对 `Halftone` 生效。**
`docs/shader-provenance.md` 判为 `已追到兼容许可 · Apache-2.0` 的共 **8** 个
（Voronoi / Swirl / SimplexNoise / ColorPanels / DotOrbit / SmokeRing / Metaballs / Halftone），
**本仓今天只落地了 `Halftone` 一个**；其余 7 个尚未落地 ⇒ 按本文件开头那条
「不得署名尚未落地的东西」，本节的**逐件条目**只有 `Halftone` 一行。
⚠️ 上一版把 `Water` 写进名单——**#280 已把它由 Apache-2.0 改判 `待追溯`**
（其 `getCausticNoise()` 与 `neuro-noise.ts` 是同一算法、同源于同一条无许可推文，
而 paper 这次连来源都没标），本版一并删掉。`NeuroNoise` / `GrainGradient` 同样不在名单内。

- **上游**：[paper-design/shaders](https://github.com/paper-design/shaders) — **Apache-2.0**
- **已落地的件**：`View.halftone(dot:ink:paper:)`
  ← `packages/shaders/src/shaders/halftone-dots.ts`
- **档位**：**较大段落移植**

### Apache-2.0 §4 的四条义务，逐条兑现

1. **转载 LICENSE 全文** —— 见下方《许可全文（Apache-2.0）》；
2. **转载 `NOTICE`** —— ⚠️ 一手核，paper 的 `NOTICE` **全文就是这两行**：

   ```
   Powered by Paper Shaders:
   https://shaders.paper.design
   ```

3. **标注修改**（§4(b)）—— 我们改了参数化与色彩层，**且只移植了其中一部分**。
   逐条差异写在 `Sources/CoreDesignShaders/CoreDesignShaders.metal` 的
   `coreDesignHalftone` 文档注释里；摘要：只移植 `classic` 一种点形（`gooey` / `holes` /
   `soft`、六边形网格、`inverted`、对比度 sigmoid、三档颗粒**均未移植**）；
   只移植 `halftone-dots.ts`（**`halftone-cmyk.ts` 未移植**）；新增网屏角度参数化；
   两色输出改由 Swift 侧传入（FR-8：`.metal` 零硬编码色）。
4. **`.metal` 文件头注明对应 `.ts` 路径** —— 见 `coreDesignHalftone` 的 Provenance 段。

### ⚠️⚠️ 第 5 条：paper **之外**的第三方 MIT 通知义务（paper 一个字都没给）

**Apache-2.0 不能替代第三方的 MIT 通知义务。** `docs/shader-provenance.md`《落地义务》
第 5 条点名 `Halftone` 涉及两位权利人 —— 其 hash 一族追到 **Dave Hoskins**（常量 `19.19`；
旁证：BigWings 在 `bigwings-luminescence.glsl:230` 把同一式子标为
`// 3 out, 1 in... DAVE HOSKINS`）与 **Inigo Quilez**（`0.3183099` = 1/π 的签名式）。
两者**都是 MIT**（与本仓兼容，不影响可落地），但 "The above copyright notice … shall be
included in all copies" **必须由我们自己转载**。

⚠️ **一条如实说明**：本次移植的 `coreDesignHalftone` **没有复制那两份 hash**
——它一个 hash 都不调用（上游用 hash 的是 grain 与 CMYK 的格心抖动，两者都没移植）。
通知**仍然照给**：义务跟着 `Halftone` 这个档位走，宁可多给，成本为零。
**不要**把这句读成"其实不欠"——它记录的是覆盖面，不是撤回。

#### Inigo Quilez — MIT

⚠️ **前两行带 `//` 是逐字转载的一部分，不是本文件的排版**：上游把版权头写在
Shadertoy 源码的**注释**里（`// The MIT License` / `// Copyright © 2013 Inigo Quilez`），
其后的许可正文是不带注释前缀的 MIT 标准文本。⇒ 块内混两种形态**是原样，不是拼接**；
**不要**为了观感统一去掉或补上 `//`——那会改动一份逐字转载。（Hoskins 那块同理。）

```
// The MIT License
// Copyright © 2013 Inigo Quilez

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

出处：Shadertoy `ldl3W8` 源码头 · 站点级声明
`https://iquilezles.org/articles/`（逐字「all technical code snippets you'll find are
under the MIT license」）。

#### David Hoskins — MIT

```
// Copyright (c)2014 David Hoskins.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

出处：Shadertoy `4djSRW`（"Hash without Sine"）源码头。

### ⚠️ 一条"不要写"的义务

`colorBandingFix` 里的 `12.9898 / 78.233 / 43758.5453123` 是无从指认著作权人的通行
sin-fract hash ⇒ 署名指向**算法本身**，**不得**引 The Book of Shaders
（本仓已实查其 LICENSE 为 `All rights reserved`，见本文件下方专节）。
⚠️ 该常量组**没有**出现在本仓任何代码里，此条是预防性留痕。

### 许可全文（Apache-2.0）

⚠️ **逐字转载**（`raw.githubusercontent.com/paper-design/shaders/main/LICENSE`）：

```
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```

---

## `CoreDesignShaders` 的共享原语与公开配方

> ⚠️ **占位（与上面三节同一规则）**：本节描述的代码只存在于**未合并**的
> `shaders-plasma` 分支（PR #261）。从 `epic/shipswift-foundation` 的角度看，
> 它描述的东西**还不存在**。⇒ 本节**在 #261 合入时启用**。
>
> ⚠️ **为什么它仍然现在就写下来**：`docs/shader-provenance.md` 与 #261 互为前提
> （#261 的 5 处引用**全部指向 provenance 表**），而本文件是那张表判为可落地行的
> **对外落脚点** ⇒ 本节随表一并预登记。
> ⚠️ **上一版这里写「#261 多处引用本文件」——实查 `git grep ACKNOWLEDGEMENTS` 零命中**
>（第 2 轮终审 I-a）。而这条理由是本节豁免「不得署名尚未落地的东西」的**唯一依据**
> ——依据本身是假的，等于没有豁免。已改为真实的那条。
> 本节是**预登记**，不是已生效的对外声明——这与「逐 shader 条目由各自落地的 task
> 追加」不冲突：那条规则约束的是**逐件**条目，本节是**共享原语**。

⚠️⚠️ **本节取代了第 1 版的「噪声参考实现（clean-room）」一节，因为那一节整个是错的。**

第 1 版写：`FractalClouds` / `InkSmoke` 走 clean-room 重写，参考实现是
ashima / stegu / glsl-noise（均 MIT）。**PR #261 第 2 轮查明：那三个是 simplex +
permutation 表，与实际实现（值噪声 + 整数 hash + iq 级联）没有任何一行对应关系**
——等于引用了一个许可干净但**实际没用到**的来源，而真正的影响源一个没写。
⇒ 该引用**已删除**，不是"改得更准"而是**它本就不成立**。

**实际用到的来源逐项如下**（对应 `docs/shader-provenance.md` 的《共享原语的逐项出处》）：

⚠️⚠️ **下表有两根轴，上一版把它们混成了一列**（第 5 轮终审 C2）：

- **复制程度**（本文件《归属分档》定义的三档：`较大段落移植` / `参考算法思路` /
  `未知（上游未指认）`——第三档是**待定态**，追到上游后须改判为前两档之一）
  ——回答「我们抄了多少」；
- **许可地位**（`docs/shader-provenance.md` 的裁定取值）——回答「抄了合不合法」。

上一版把 `事实性算法常数` / `教科书` / `公开惯用法` / `待追溯` 四个**许可地位**的值
塞进了「档位」列，于是 10 行里有 5 行**不属于本文件定义的任何一档**；
紧接着正文又写「统一登记为『待追溯』」——**与那一列直接打架**。两根轴现已分开。

⚠️ **并且：标为 `较大段落移植` 的行，本文件 §「归属分档」要求「转载完整原始许可
+ 指明原作者与原始 URL」——上一版一条都没给。** 本版补上 URL；
无许可正文可转载的（作者页面本身无声明），**明写"无声明"而不是留白**
——一份自称"我们逐字移植了这段"却既不给来源也不给法律依据的声明，
**比它取代的沉默更糟**：它是一份没有辩护的书面自认。

| 原语 / 片段 | 来源（URL） | 复制程度 | 许可地位 |
|---|---|---|---|
| `wangHash`（`0x27d4eb2d`） | 算法：Thomas Wang《Integer Hash Function》（页面已失效，Wayback 2007 快照）；「公有领域」的说法出自 Bob Jenkins　`http://www.burtleburtle.net/bob/hash/integer.html`。⚠️ **本仓逐字符复制的是 Nathan Reed 的写法**　`https://www.reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/` | **较大段落移植**（逐字符一致；判别点：Wang/Jenkins 写 `a + (a << 3)`，**Reed 与本仓都写 `*= 9`**） | ⚠️⚠️ **上一版「页面无许可声明」是事实错误（#281 实查推翻）**。Jenkins 逐字：「The hashes on this page … are all public domain. **So are the ones on Thomas Wang's page.**」⇒ 算法层 **PD**；而 Reed 站点页脚逐字「**© 2007–2025 by Nathan Reed. Licensed CC-BY-4.0.**」⇒ **本仓实际复制的那一份是 CC-BY-4.0，署名是许可条件** ⇒ `已追到兼容许可`（⚠️ 取值域缺 `CC-BY` 档，见 provenance 表）|
| `hash21`/`hash22` 的素数三元组 | Teschner et al. 2003《Optimized Spatial Hashing for Collision Detection of Deformable Objects》（VMV 2003 论文） | 参考算法思路（三个常数） | **事实性常数** ⇒ 可落地 |
| `valueNoise` | 值噪声的标准形式（嵌套 `mix` 双线性插值 + `smoothstep` 权重） | 参考算法思路 | **教科书算法** ⇒ 可落地 |
| `hash22` 的第四个素数 `50331653` | SGI STL / libstdc++ 的标准哈希表素数梯（`gcc-mirror/gcc` 的 `libstdc++-v3/include/backward/hashtable.h`：`25165843ul, 50331653ul, 100663319ul, …`） | 参考算法思路（1 个常数） | **事实性常数** ⇒ 可落地。⚠️ **上一版本行缺失**——本文件刚宣布「逐常量 grep 无条件适用」，而一个已知落在具名来源之外的常数就漏在表外（#261 自己记下的遗留项，#281 补入）|
| `fbm` | **算法本身**：fBm 标准形式（gain 0.5 / lacunarity 2.0），Mandelbrot–Perlin–Musgrave 谱系，见 Ebert et al.《Texturing & Modeling》 | 参考算法思路 | **事实性算法** ⇒ 可落地。⚠️ **见下方 The Book of Shaders 的许可实查** |
| 域扭曲的 `q`/`r` 三级级联（落地函数 `coreDesignInkSmoke`；组件 `InkSmoke` / `FractalClouds`） | Inigo Quilez《Domain Warping》　`https://iquilezles.org/articles/warp/` | **较大段落移植**（结构 + 变量名保留） | ⚠️⚠️ **上一版「页面无许可声明」是事实错误（#281 实查推翻）**：warp 页本身确无，但其父页 `https://iquilezles.org/articles/` 逐字「**all technical code snippets you'll find are under the MIT license**」⇒ **`已追到兼容许可 · MIT`**。⇒ **强指纹档的阻断义务已兑现**（既追到、许可又兼容），义务转为**转载 MIT 通知 + 具名 iq** |
| `Plasma` 的四相正弦叠加 | Lode Vandevenne《Lode's Computer Graphics Tutorial — Plasma》　`https://lodev.org/cgtutor/plasma.html`；⚠️ **许可在另一页**：`https://lodev.org/cgtutor/legal.html` | **参考算法思路**（⚠️ **由「较大段落移植」下调**：#281 比对后确认他那组具体取值——中心 `(128,128)`/`(64,64)`/`(192,64)`/`(192,100)`、除数 `/8 /8 /7 /8`——**本仓一个都没用**，四项全部参数化且各带不同时间相位） | ⚠️⚠️ **上一版「页面无许可声明」是事实错误（#281 实查推翻）**：plasma 页页脚确为 `All rights reserved`，但 legal.html **把散文与代码分开授权**，代码逐字为 **BSD-2-Clause** ⇒ `已追到兼容许可`。⚠️ **义务：源码中保留版权通知 + 两条条件 + 免责声明全文**，一句「参考自 Lode 的教程」不满足第 1 条 |
| `roundedBoxSDF` | Inigo Quilez —— ⚠️ **精确来源是 3D 页的单半径 `sdRoundBox`**　`https://iquilezles.org/articles/distfunctions/`（2D 页上的 `sdRoundedBox` 是四半径 `vec4` 变体，**不是**本仓这一份） | **较大段落移植**（2 行，标准闭式解的 2D 降维） | ⚠️ **上一版「页面无许可声明」是事实错误**：站点级声明见 `https://iquilezles.org/articles/` ⇒ **`已追到兼容许可 · MIT`**，义务是转载 MIT 通知 + 具名 iq |
| `edgeWidth`（`max(fwidth, ε)` + smoothstep） | ⚠️⚠️ **归属改判：无可归属的上游。** 上一版写「iq 的 distance-AA 惯用法」——**#281 逐页 grep 了 iq 的五篇相关文章，`fwidth` 一次都没出现**。最接近的具名发表是 Stefan Gustavson《2D Shape Rendering by Distance Fields》(OpenGL Insights ch.12, 2011)，其代码自述「This code is in the public domain.」，**但他写的是 `0.7 * length(vec2(dFdx, dFdy))`，不是同一表达** | 参考算法思路（1 行） | **无可归属上游的通用惯用法**（一手读到三份互不相关的独立实现）⇒ `待追溯（低指纹）`，风险低于上一版认定 |
| `ramp3` | **未指认到具体上游** | **未知（上游未指认）** | `待追溯（低指纹）`——⚠️「指认不到」不等于「原创」 |
| `coreDesignRefractiveGlass` 的位移 + 通道色散主体（= 组件侧 `Glass`（`RefractiveGlass`）的主体原语） | ⚠️⚠️ **上一版「SwiftUI `layerEffect` "liquid glass" 一族的通行形态」经 #281 追溯被证伪——逐个读完具名的 SwiftUI-Metal 玻璃库后，没有找到这样一族。** 仍**未指认到具体上游** | **未知（上游未指认）** | ⚠️ `待追溯`，分档由**强指纹改判低指纹**（三条强档判据逐条不成立；逐常量 grep 零命中）⇒ **不再阻断 epic→main**，⚠️ 但该改判须评审确认。详见 provenance 表专节 |

⚠️ **许可地位一列已逐行给出，不再有"统一登记"这句**（上一版那句与表格直接打架）。

⚠️⚠️⚠️ **#281 的实查结论：上一版有 5 行写着「页面无许可声明」，其中 4 行是事实错误。**
本文件当时写下「无许可正文可转载的行，**明写"页面无许可声明"**而不是留白」——
这条规矩本身是对的，**但它被当成了终点**：写下"没找到许可"之后就没有人再去找了。
实查结果是 **iq（MIT）· Lode Vandevenne（BSD-2-Clause）· Nathan Reed（CC-BY-4.0）
三家都有真实许可，而且三家都带署名义务**。
⇒ **规矩补一条：写「页面无许可声明」时必须同时写明"读了哪一页"**
（许可常常不在那篇文章上，而在站点的 `/articles/` 或 `legal.html`）。

### ⚠️⚠️⚠️ #281 追到的**不兼容**许可：`Starfield`（本文件最重的一条，**撤回已执行**）

上表是**共享原语**层。**shader 本体层出了一件更严重的**，记在这里以免只读本文件的人漏掉。
⚠️ **本条保留在文件里是有意的**：`Starfield` 已经不在树上了（见文末的执行记录），
但「为什么这个仓不提供星空 shader」只有这条记录能回答——删掉记录，下一个人会重新写一遍。

> **`Starfield`（`coreDesignStarfield`）的上游是 Martijn Steinrucken（BigWings /
> *The Art of Code*）的《Starfield Tutorial》(2020)，源码头逐字：**
>
> ```
> // Starfield Tutorial by Martijn Steinrucken aka BigWings - 2020
> // License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
> ```
>
> **CC BY-NC-SA 3.0 与 CoreDesign 的 MIT 分发不兼容**（既禁商用，又有传染性 share-alike）。

⚠️ **旁证**：`CoreDesignShaders.metal` 自己的注释记着 `hash21` 第一版是
`fract(p * float2(123.34, 456.21)); p += dot(p, p + 45.32)` ——**那正是同一份文件里
`Hash21` 的常量，逐字符一致** ⇒ 接触与复制均有直接证据，不是巧合。

⇒ **裁定 `不落地`**（`docs/shader-provenance.md`《`Starfield` 的追溯》专节）。
⚠️ **本文件不为 `Starfield` 写署名条目**——署名解决不了 NC 与 share-alike，
**唯一的出路是不分发它**。

#### ✅ 执行记录：撤回已完成

**`Starfield` 已从 `CoreDesignShaders` 整件删除**（`Starfield.swift` 整份 +
`CoreDesignShaders.metal` 的 `coreDesignStarfield` 段 + 两份测试里的对应用例）。
⇒ ⚠️ **本条不再阻断 `epic → main`**。

⚠️ **未走「重写那 5 行以保留它」的替代方案**：那需要 owner 显式承担
"残留对应部分不达独创性门槛"的判断，且重写者已读过原文、独立性存疑。本次是**纯撤回**。

⚠️ **`cd::hash21` / `cd::hash22` / `cd::wangHash` 留下**，理由与撤回时核实的事实：
当前 `hash21` 是 **Wang/Reed 整数构造**（`seed ^ 61`→`*= 9`→`*= 0x27d4eb2d`）+
**Teschner 素数三元组**，`123.34 / 456.21 / 45.32` 那组 CC BY-NC-SA 常量**早已不在代码里**
（只作为历史记录留在注释与本表中）⇒ 撤回 `Starfield` 即清干净了这条污染，
不需要连带撤回原语。`hash22` 因此暂时无调用方，**有意保留**——它自身许可已清偿。

### ⚠️ #281 新增的三条署名义务（`epic → main` 前必须在本文件落地）

| 权利人 | 许可 | 覆盖的原语 | 义务的**具体形态**（不是"提一下" |
|---|---|---|---|
| **Inigo Quilez** | **MIT**（`https://iquilezles.org/articles/` 站点级声明）| `roundedBoxSDF` · 域扭曲 `q`/`r` 三级级联 | 转载 MIT 许可通知全文 + 具名 + 原始 URL |
| **Lode Vandevenne** | **BSD-2-Clause**（`https://lodev.org/cgtutor/legal.html`）| `Plasma` 的四相正弦叠加 | ⚠️ **保留版权通知 + 两条条件 + 免责声明全文**——BSD 第 1 条逐字要求 "retain the above copyright notice, this list of conditions and the following disclaimer" |
| **Nathan Reed** | **CC-BY-4.0**（站点页脚）| `wangHash`（本仓复制的是他的 `seed *= 9` 写法）| 署名 Reed + 链接许可；并注明算法本身出自 Thomas Wang（Jenkins 称其为公有领域）|

⚠️ 另有 **Teschner et al. 2003** 的**学术引用**义务（三个素数是事实，不承载许可义务）。

### ⚠️ The Book of Shaders 的许可实查（本文件最重要的一条）

**实查 `raw.githubusercontent.com/patriciogonzalezvivo/thebookofshaders/master/LICENSE`：**

```
Copyright (c) 2025 Patricio Gonzalez Vivo
All rights reserved.

You cannot host, display, distribute or share this Work in any form…
You cannot use this Work in any commercial or non-commercial product,
website or project.
```

⇒ **比 Shadertoy 的默认 CC BY-NC-SA 还严**（后者至少允许非商业使用）。

⚠️ **`cd::fbm` 曾被标注为与该书 ch.13「逐行同构」** ——若照原样合入，一个
**多 shader 共用的原语**会带着一个比 Shadertoy 更严的来源标注发出去。

⚠️ **但实查同时推翻了另一个方向**：我们的 `fbm` **并非逐行同构**
——多了 `total` 累加与 `sum / total` 归一化（该书没有），`octaves` 是**函数参数**
而非 `#define OCTAVES`。循环体本身就是 fBm 的**定义**（gain 0.5 / lacunarity 2.0），
属 Mandelbrot–Perlin–Musgrave 谱系的**事实性算法**。
⇒ 署名对象是**算法谱系**，**不是**「我在哪里读到它」；本文件**不引用该书作为依据**。

⚠️ **这条同时是一次反向校准**：`docs/shader-provenance.md` 的第六条轴防的是
**低估**抄袭，而本条显示**高估同样有代价**——它会把一个事实性算法错误地绑到一个
`All rights reserved` 的来源上。**两个方向都要查实。**

---

## 图片与其他资源

> ⚠️ 占位。CoreDesign 目前未引入第三方图片资源。若将来引入，须在此逐条声明——
> 特别注意 CC BY-SA 类资源带传染性条款，与本库的 MIT 分发不兼容。
