# Acknowledgements

CoreDesign 的部分实现衍生自第三方开源项目。按各自许可的要求，原始版权与许可声明
转载于下。

> **本文件与 [`docs/shader-provenance.md`](docs/shader-provenance.md) 的分工**：
> provenance 表是**裁定过程**（每个 shader 追到哪、许可是什么、判可不可落地）；
> 本文件是**对外的许可声明**。前者判为可落地的行，**在其真正落地时**必须在本文件
> 有对应条目。
>
> ⚠️ **本文件目前只有骨架**（#249 建）。**逐组件 / 逐 shader 的条目由各自落地的 task
> 追加**——闸②虽已通过，仍不得署名尚未落地的东西。

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

## Inferno — Warping Loupe（待 `GlassOrb` 落地时启用）

> ⚠️ 占位。`CoreDesignShaders` 的 `GlassOrb` 落地时（`shipswift-shaders` B-3）填入，
> 并转载 Inferno 的完整 MIT 正文。

裁定依据（`docs/shader-provenance.md`《统一裁定表》的 `GlassOrb` 行，论证见同文
《A. 有上游标注的 7 个》的 `GlassOrb` 行）：**已追到兼容许可 · MIT，链条闭合**。
Inferno 的 LICENSE 附逐 shader 移植来源清单（**6 组**：Circle/Circle Wave/Diamond/
Diamond Wave ← PolkaDotsCurtain、Crosswarp、Radial、Swirl、Wind、Genie），
**"Warping Loupe" 不在其中** ⇒ **推论**为 Inferno 原创，由其 MIT 覆盖。

- 上游：[Inferno](https://github.com/twostraws/Inferno) by Paul Hudson — MIT
- 预期档位：**较大段落移植**（折射数学预计保留自原实现）⚠️ 代码尚未落地，**档位待落地时定案**

---

## Star Nest（待 `StarNest` 落地时启用）

> ⚠️ 占位。落地时（`shipswift-shaders` B-2）填入并转载 MIT 正文。

- 上游：["Star Nest" by Pablo Roman Andrioli（Kali）](https://www.shadertoy.com/view/XlfGRj) — 作者在源码头声明 MIT
- 预期档位：**较大段落移植**（分形"magic formula"与体积步进预计保留）⚠️ 档位待落地时定案
- ⚠️ **落地 task 的硬 AC**：人工目视确认该 Shadertoy 页面源码头的 MIT 声明——自动抓取
  返回 403，现有证据是**五个**独立第三方移植的逐字一致记录，非一手。

---

## paper-design/shaders（Apache-2.0，待相应 shader 落地时启用）

> ⚠️ 占位。`docs/shader-provenance.md` 裁定为 **`已追到兼容许可 · Apache-2.0` 的 9 个**
> shader（Voronoi / Swirl / SimplexNoise / Water / ColorPanels / DotOrbit / SmokeRing /
> Metaballs / Halftone）落地时填入。
>
> ⚠️ **`NeuroNoise` 与 `GrainGradient` 不在本名单内**：两者同样追到 paper，但裁定是
> **`待追溯`**——前者的上游是一条无许可声明的推文、paper 的再许可断言无法独立核实；
> 后者参数仅部分匹配、匹配未确认。⇒ 追完一轮改判为 Apache-2.0 之前，
> **不得随本节署名落地**（上一版把 `NeuroNoise` 写进名单、且写作「10 个」，
> 与 provenance 表的 Apache-2.0 档 = 9 打架，PR #259 review round-2 指出）。

- 上游：[paper-design/shaders](https://github.com/paper-design/shaders) — **Apache-2.0**
- 档位：**较大段落移植**
- ⚠️ **Apache-2.0 的义务比 MIT 多，三条缺一不可**：
  1. 转载 **LICENSE 全文**；
  2. 转载其 **`NOTICE`**：`Powered by Paper Shaders: https://shaders.paper.design`（§4(d)）；
  3. **标注修改**（§4(b)）——我们改了参数化与色彩层。
- ⚠️ **paper 之上还有一层**，落地前须直读确认：`voronoi.ts` 指向 iq 的 Shadertoy
  `ldl3W8`（该 shader 许可**变过**：旧拷贝头 CC BY-NC-SA 3.0、新拷贝头 MIT）；
  `neuro-noise.ts` 指向一条**无许可声明的推文**——**这正是 `NeuroNoise` 被排除在上面
  9 个名单之外的原因**（provenance 表《汇总与闸②判定》第 5 轮终审 I4）。

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
