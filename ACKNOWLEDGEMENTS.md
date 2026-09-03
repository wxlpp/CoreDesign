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

每个条目须标明属于哪一档，两者的义务不同：

| 档 | 含义 | 义务 |
|---|---|---|
| **较大段落移植** | 直接采用了上游的实现（即便重命名、重排、改了参数表） | 转载完整原始许可 + 指明原作者与原始 URL |
| **参考算法思路** | 对照上游或公开文献**重写**，未复制其代码 | 指明参考实现与其许可，说明是重写 |

---

## ShipSwift

CoreDesign 的表达性视觉层（`CoreDesignEffects` / `CoreDesignShaders`）与图表层
（`CoreDesignCharts`）的**点子与算法**来自
[ShipSwift](https://github.com/signerlabs/ShipSwift)（SignerLabs）。

⚠️ **归档义务（不是既成陈述）**：CoreDesign 的实现**须**按自身 API 公约与色彩地基重做；
逐组件属于哪一档见其 `docs/components/*.md`。
⚠️ 第 1 版在此断言"是重写的，不是拷贝"——**当时两个 target 还是空骨架，那是预判**，
已改为义务描述。
⚠️ **更要紧**：`docs/shader-provenance.md` 已证 **ShipSwift 的 MIT 声明不覆盖它内含的
Apache-2.0 衍生物**（至少 10 个 shader 来自 `paper-design/shaders`）⇒ **不得把 ShipSwift
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

---

## Inferno — Warping Loupe（待 `GlassOrb` 落地时启用）

> ⚠️ 占位。`CoreDesignShaders` 的 `GlassOrb` 落地时（`shipswift-shaders` B-3）填入，
> 并转载 Inferno 的完整 MIT 正文。

裁定依据（`docs/shader-provenance.md` 第 1 行）：**已追到兼容许可，链条闭合**。
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

> ⚠️ 占位。`docs/shader-provenance.md` §B 裁定的 10 个 shader（Voronoi / NeuroNoise /
> Swirl / SimplexNoise / Water / ColorPanels / DotOrbit / SmokeRing / Metaballs /
> Halftone）落地时填入。

- 上游：[paper-design/shaders](https://github.com/paper-design/shaders) — **Apache-2.0**
- 档位：**较大段落移植**
- ⚠️ **Apache-2.0 的义务比 MIT 多，三条缺一不可**：
  1. 转载 **LICENSE 全文**；
  2. 转载其 **`NOTICE`**：`Powered by Paper Shaders: https://shaders.paper.design`（§4(d)）；
  3. **标注修改**（§4(b)）——我们改了参数化与色彩层。
- ⚠️ **paper 之上还有一层**，落地前须直读确认：`voronoi.ts` 指向 iq 的 Shadertoy
  `ldl3W8`（该 shader 许可**变过**：旧拷贝头 CC BY-NC-SA 3.0、新拷贝头 MIT）；
  `neuro-noise.ts` 指向一条**无许可声明的推文**。

---

## 噪声参考实现（待相应 shader 落地时启用）

> ⚠️ 占位。**仅 `FractalClouds` / `InkSmoke` 两个**落地时填入。
>
> ⚠️ **第 1 版这里还列了 `SimplexNoise` / `SmokeRing` / `NeuroNoise` / `Water` /
> `GrainGradient`——它们已改判**：前四个追到 `paper-design/shaders`（Apache-2.0，见上一节），
> `GrainGradient` 匹配存疑判 `待追溯`。**它们不走 clean-room，走带署名的移植。**

这两个 shader 走 **clean-room 重写**——对照下列许可兼容的参考实现重写，**不复制其代码**：

- [ashima/webgl-noise](https://github.com/ashima/webgl-noise) — MIT
- [stegu/webgl-noise](https://github.com/stegu/webgl-noise) — MIT
- [hughsk/glsl-noise](https://github.com/hughsk/glsl-noise) — MIT

- 档位：**参考算法思路**
- ⚠️ 噪声原语只覆盖 FBM 的底座；**domain-warp 与调色的组合仍须先按 provenance 表
  《方法论教训》追一轮**，不得直接认定为原创。

---

## 图片与其他资源

> ⚠️ 占位。CoreDesign 目前未引入第三方图片资源。若将来引入，须在此逐条声明——
> 特别注意 CC BY-SA 类资源带传染性条款，与本库的 MIT 分发不兼容。
