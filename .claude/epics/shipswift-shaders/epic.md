---
name: shipswift-shaders
status: in-progress
created: 2026-09-02T23:42:57Z
updated: 2026-09-05T00:00:00Z
progress: 43%
prd: .claude/prds/shipswift-harvest.md
github: https://github.com/wxlpp/CoreDesign/issues/243
---

# Epic: shipswift-shaders（Metal）

> `shipswift-harvest` PRD 拆出的**第 3 个** epic（共 3 个）。
> ⚠️ **本 epic 是有条件的**——见下方《启动条件》。在两闸出结论前**不得 decompose、
> 不得 sync 到 GitHub**：它的 task 数量与内容都由闸的结论决定，提前分解就是编造。
> **⚠️ 但"不分解"不等于"草案可以不自洽"**——本 epic 的 SC 与依赖图与闸的结论无关，
> 第 1 轮 structure 评审在这两处判了 BLOCK，本版已修。
>
> **decompose 的触发条件**：A0-5 ∧ A0-6 两个 issue 都关闭，且 A0-6 的关闭评论已记录
> `N_B` 与可落地 shader 名单。**届时必须重核**：B-1 按 α/β 结论重写；B-2 / B-3 按
> provenance 裁定表重列成员（可落地的才留）；B-2 / B-3 按 D-1 的复杂度分级拆成多个 task。
>
> ---
>
> ## ✅ 两闸已出结论，本 epic 已于 2026-09-04 完成 decompose
>
> | 闸 | 结论 | 对本 epic 的影响 |
> |---|---|---|
> | **闸①（#248）** | **改判路径 α**（`.metal` 源随 target 编译），草案默认的 β 被实测推翻 | **AD-B / AD-C 整节作废**（照录见下）；AD-D 走 α 那一行；B-1 的 β 交付物整批作废 |
> | **闸②（#249）** | **可落地 11**（2 MIT + 9 Apache-2.0），**17 个 `待追溯`**，初版声称的 26 已整体撤回；`N_B` = 5 ⇒ 11 ≥ 5，**通过** | 草案 B-2 的「17 个」与 B-3 的「11 个」**两个数字都不成立**，成员按《统一裁定表》重列 |
>
> ⚠️ **重核的三条实质发现**（不在两闸的结论句里，是分解时逐项比对出来的）：
> ① **B-1 已由 PR #261 落地，但当时没有 issue 承载**（它错标了 #254 的关闭关键字——那是
> `shipswift-effects` 的 task）⇒ 补建 **#278** 并即刻关闭；
> ② **#261 落的 8 个 shader，与可落地 11 无一交集**——8 个全部裁定为 `待追溯`
> （`Starfield` ≠ `StarNest`，两个名字很像但一个 `待追溯`、一个 MIT 可落地）
> ⇒ **11 个可落地件一个都还没落**，同时 8 个已落地件欠着 provenance 债（**#281**）；
> ③ **B-1 的「把 Shaders 根加进全部根列表」未交付**，而 #246 的
> `libraryTargetsAreCoveredByScanRoots` 与 `Package.swift` 做双向差集
> ⇒ 两条 epic 分支整合时该判据当场红（**#279**）。

## Overview

把 ShipSwift 的 **28 个 Metal shader** 落成新 target `CoreDesignShaders`。
28 个分两类，**能力不同，不能混为一谈**：

⚠️ **下表是 28 个的原始分类，不是本 epic 的落地范围** —— 闸②裁定**可落地 11**、
`待追溯` 17。落地范围见下方《Task Breakdown》。

| 类 | 数量 | 形态 | 名单 |
|---|---|---|---|
| `colorEffect` | **17** | 真程序化背景，可 `.background { }` | AnimatedLoop · ColorPanels · DotOrbit · Dots · FractalClouds · GrainGradient · InkSmoke · LiquidChrome · Metaballs · NeuroNoise · Plasma · SimplexNoise · SmokeRing · Starfield · StarNest · Swirl · Voronoi |
| `layerEffect` | **11** | 作用于**内容层**（箔片卡片 / 玻璃放大镜 / 半调网屏），`.background{}` 画不了 | ChromaticGlass · Foil · Glass · GlassLogo · GlassOrb · Glitter · Halftone · IntenseBling · LiquidMetal · PolishedAluminum · Water |

⚠️⚠️ **本表是上游清单，不是"可落地清单"**：`Starfield` 经 #281 追溯判 **`不落地`**
（上游 Martijn Steinrucken《Starfield Tutorial》，**CC BY-NC-SA 3.0**，与本仓 MIT 分发不兼容），
**已从 `CoreDesignShaders` 撤回删除**。⇒ B-1 首批由 8 件变为 **7 件**，
`Estimated Effort` 的「最好情况 28 个全落地」上限相应变为 **27**。
逐件裁定见 `docs/shader-provenance.md`。

## 启动条件与前置（两者不同，别混）

### 启动条件 = `shipswift-foundation` 的两闸双双通过

| 闸 | 通过定义 |
|---|---|
| **A0-5（D-1 Metal 打包 spike）** | 六问全部有书面结论，且 α/β 已选定并实测可行 |
| **A0-6（C-6 许可核验）** | `docs/shader-provenance.md` 覆盖全部 28 个无空裁定 **且** 裁定为可落地者 ≥ `N_B` |

⚠️ 任一不过 ⇒ **本 epic 整体不启动**，`shipswift-foundation` 与 `shipswift-effects`
不受影响（这正是三 epic 拆分的目的）。

### 前置：**逐 task 不同**（⚠️ 第 2 轮评审 I-4——初版写"前置 = A0-2~A0-6 全部完成"
已不是完整前置集，读者会以为闸过就能跑完整个 epic）

⚠️ **下表是草案的 B-1~B-4 口径，已被实际分解取代**——实际前置见《Task Breakdown》与
各 task 文件的 `depends_on`。照录于此是因为它的**两条论证仍然成立**（B-2/B-3 依赖 B-1
是 epic 内部边；B 的收尾被 A 的收尾阻塞）。

| task | 前置 |
|---|---|
| **B-1** | A0-2 ~ A0-6 |
| **B-2** | A0-2 ~ A0-6 **+ B-1**（target 与 metallib 构建链）**+ `shipswift-effects` 的 A-3**（NFR-7 可注入 environment 键） |
| **B-3** | A0-2 ~ A0-6 **+ B-1**（同上） |
| **B-4** | 上述全部 **+ `shipswift-effects` 的 A-7**（ComponentData 串行窗口 / 性能基准脚本） |

⚠️ **B-2 / B-3 依赖 B-1 是 epic 内部边**（第 3 轮评审 Important-2）：初版表只列了跨 epic
前置，并断言"B-1 / B-3 闸过即可开工"——**那句是错的**，B-3 的 11 个 layerEffect 要落进
B-1 才建的 `CoreDesignShaders` target 与 metallib 构建链，B-1 不完 B-3 无处落。
⇒ **B-1 闸过即可开工；B-2 / B-3 等 B-1；B-2 另等 A-3。**

⇒ **B 的启动不被 Epic A 阻塞**（B-1 闸过即开工，B-2 只等 A-3 这个 A 的早期并行 task）；
但 **B 的收尾被 A 的收尾阻塞**（B-4 等 A-7 = Epic A 全部完成）。这句话此前三个 epic
都没明说。

⚠️ **三重耦合已解掉两重**（评审 I-4）：`ACKNOWLEDGEMENTS.md` 的**骨架改由 A0-6 建**
（许可裁定与 ACK 条目本就是同一份工作），B-4 只追加逐 shader 条目；性能基准脚本仍在
A-7，但**若 B-2 先于 A-7 完成，应把 harness 提前到 A-3**（Confetti 落地处），
避免 17 个 colorEffect 全落完才第一次跑性能闸。剩下**只有 `ComponentData.swift` 串行
是结构性的**。

### ⚠️ 分解时复核：跨 epic 边的实际现状（2026-09-04）

| 边 | 草案 | 实际 | 后果 |
|---|---|---|---|
| **A-3（#252）** | B-2 依赖它拿 NFR-7 可注入 environment 键 | **已交付并关闭**。⚠️ 但键**没有**落在 `CoreDesignEffects`——用户裁决把它**下沉到 `CoreDesign`**（`Sources/CoreDesign/Environment/EnergySignalEnvironment.swift`，`lowPowerModeOverride` / `scenePhaseOverride`，两者均显式 `public`），理由逐字是「别让只想要 shader 的消费者链上整个 `CoreDesignEffects` product」 | **#282 只需 `import CoreDesign`**（本 target 本就依赖它）⇒ 这条跨 epic 边**实际已消失** |
| **A-3 的残余（#271，open）** | 草案没有 | **只有原始信号下沉了**。被 `EffectsEnergy.swift` 自己标为「**通用**」的那半张策略表（`drawsAnything` / `minimumInterval`，以及 `scenePhase != .active ⇒ 停摆`、`lowPower ⇒ 降帧` 这条映射）与三个类型仍在 `CoreDesignEffects` | **#282 只有两条路，都不好**：(a) `import CoreDesignEffects` ⇒ 推翻下沉的全部理由；(b) 自行再写一遍同一条映射 ⇒ 必漂。⚠️ **#271 自己写着「B-2 开工前裁决最便宜，一旦 B-2 落件并 `import`，搬动就是破坏性变更」** ⇒ 列为 #282 的 `depends_on` |
| **A-7（#256）** | B-4 依赖它（ComponentData 串行窗口 + 性能基准脚本） | **未开工（open）**，且它自己依赖 #250~#255；其中 #251 已拆成 #266 / #267 / #268，三个均 open | **#284 仍被阻塞**，这是本 epic 与 Epic A 之间**唯一剩下的结构性耦合** |
| **A0-3（#246）的扫描根** | B-1 交付 | **B-1（#261）未做**。`GuardScanRoots.swift` 逐字写着「该根由 `shipswift-shaders` 的 B-1 在 target 真的落地时加入」 | ⇒ **#279**。⚠️ 两条分支现在**各自都绿**（shaders 分支没有 #246；effects 分支的 `Package.swift` 没有 Shaders），**一整合就红** |

## Architecture Decisions

### AD-A `CoreDesignShaders` target 在本 epic 建，不在 A0 建

若 A0 就建了它而闸没过，仓库里会留下一个**空 product** 及其连带的 `App/project.yml`
条目、probe 调用点、README 索引小节。

### ~~AD-B 路径 β（预编译 metallib）是默认走向~~ —— **已被闸①（#248）改判为 α，整节作废**

> ⚠️ **原文照录**（本仓要求错误与决策过程留痕，不删）。**下面这一整节的结论已被
> #248 的实测推翻**：它的立论是「CI SwiftPM 腿 / `downstream-probe` / 下游 StoryUI
> 用的都是原生构建 ⇒ 切不到 swiftbuild ⇒ 只能走 β」，而 #248 实测
> `swift test --build-system swiftbuild` 在本仓**切得动**
> （`CoreDesignEffects` / `CoreDesignCharts` 两个 smoke 测试均 passed）。
>
> **改判后的结论**：走 **α**（`.metal` 源随 target 编译，`.process("…metal")` 声明为资源）。
> 分平台产物由构建系统按 destination 自动产出；`.metal` 与产物同一次构建，**不可能失步**。
>
> ⚠️ **改判不是无代价的**——α 的失败形态是**运行时静默无渲染**，触发条件收窄为**同时满足**：
> ① 下游 import 的是 `CoreDesignShaders`（不是 `CoreDesign`）；② 下游用**原生
> `swift build` / `swift test`** 构建。真实消费者（Xcode 里的 App）**不命中**；
> 命中的是「用 SwiftPM 命令行跑测试、且测试触到 shader」的下游（例如 StoryUI 的 CI）。
> **三条缓解（B-1 已落地，缺一不可）**：首次使用时跑 fail-closed 检查并
> `precondition` / throw（**不用 `assertionFailure`**，release 下是 no-op）·
> README 与 CLAUDE.md 明写「用原生 `swift build` 消费本 product 时须加
> `--build-system swiftbuild`」· `docs/components/` 里每个 shader 的文档带同一句话。
>
> ⚠️⚠️ **闸①还有一条比结论更重要的发现**：**整腿切 swiftbuild 会让
> `ColorAssetGuardTests` 的 colorset 存在性守卫从 passed 变成 skipped**（不是 failed，
> CI 照常绿）——swiftbuild 调 `actool` 把 `.xcassets` 编成 `Assets.car`，而该 suite 的启用
> 条件是 `Resources.xcassets/` **以目录形式**存在。⇒ **改法是 SwiftPM 腿保留 native，
> 另起一步只跑 `CoreDesignShadersTests` 的 swiftbuild**，已在 PR #261 落地。
>
> ⚠️ 另有一条 PRD 层的裁决变更待 PRD owner 拍板：FR-2 把 α 的可选条件写死为「**所有**
> 已知消费路径都能切 swiftbuild」并点名 StoryUI CI，而 #248 证明的只是**本仓的 CI 能切**
> ——StoryUI 的包能否在 swiftbuild 下构建**没有测**。#248 实际建议的是把该条件改成
> 「Xcode 消费者不命中 + CLI 消费者按文档自担并有响亮失败兜底」。

<details>
<summary>照录：AD-B 原文（已作废）</summary>


**已实测的硬事实**：原生 `swift build` **不编译 `.metal`**——报
`found N file(s) which are unhandled`，不产 metallib，也不合成 `Bundle.module`；
声明成 `.process(...)` 资源后只做 `Copying`（拷贝源码，不编译）。
只有 `--build-system swiftbuild` 与 `xcodebuild` 会真编。

而 CI SwiftPM 腿、`scripts/downstream-probe`、下游 StoryUI 的 CI **用的都是原生构建**
⇒ 路径 α（源码随 target 编译）等于把构建系统约束转嫁给下游，**失败形态是运行时静默
无渲染**——最坏的一类。⇒ **除非 D-1 证明所有已知消费路径都可切 swiftbuild，否则走 β。**

</details>

### ~~AD-C β 的真实形态是 3 份 metallib，不是一个文件~~ —— **α 下整节不存在，作废**

> ⚠️ **原文照录**。本节及其**四个可预见失败模式**（工具链耦合 / Mac Catalyst 误选 /
> 仓库体积 / 构建产物冗余）**全部是 β 独有的**，α 下逐条消失：
>
> | 本节的规定 | α 下 |
> |---|---|
> | 提交 3 份 metallib（`iphoneos` / `iphonesimulator` / `macosx`） | **不存在** —— 构建系统按 destination 自动产出 |
> | `.copy(...)` 进 bundle + 运行时 `#if` 选份 | **不存在** |
> | `.metal` 必须从 target sources `exclude:`（防冗余） | **不存在** —— #248 实测：swiftbuild 下 bundle 里**只有** `default.metallib`，`.metal` 源不会被同时拷进去 |
> | `scripts/build-metallib.sh` + `metallib.manifest.json` + sha256 同步守卫 | **不存在** —— `.metal` 与产物同一次构建，不可能失步。#248 已显式声明该 DoD 项**随 α 一并作废，不是遗漏** |
> | 工具链耦合：钉 `-std=` / `-mios-version-min=26.0` | **不存在**（耦合方向变了：从「我们编的产物在旧运行时加载」换成「消费者的 Metal 编译器编我们的 MSL」——失败形态是**下游编译失败**，fail-loud，比 β 的静默好） |
> | Mac Catalyst 误选（`#if os(macOS)` 在 Catalyst 下为假） | **不存在** —— 构建系统自己处理 |
> | 仓库体积（每次改 shader 最多提交 6MB 二进制，考虑 LFS） | **不存在** —— 仓库里零二进制 |
>
> ⚠️ **`.process("X.metal")` 在 α 下是强制项，不是可选项**：swiftbuild 不声明也会编，
> 但 **native 不声明 ⇒ `Bundle.module` 不合成 ⇒ `downstream-probe` 与 StoryUI 直接编译失败**。
> 副作用：native + `.process` 会把 `.metal` 源随 bundle 分发。
>
> ⚠️ **另一条只有 α 有的坑**：**只含 `.metal` 的 target 被 SwiftPM 判为 empty**
> （`error: target 'X' referenced in product 'X' is empty`）—— `.metal` 既不算源也不算资源，
> target 里必须至少有一个 `.swift` 文件。

<details>
<summary>照录：AD-C 原文（已作废）</summary>


metallib 按 SDK 编译。β 意味着：
① 提交 **3 份**（`iphoneos` / `iphonesimulator` / `macosx`）；
② `.copy(...)` 进 bundle，运行时按 `#if targetEnvironment(simulator)` / `os(macOS)` 选；
③ `.metal` 源必须从 target sources `exclude:`（否则 xcodebuild 会另编一份同名产物，
**冗余**——不是冲突，但运行时加载哪一份不确定）；
④ `scripts/build-metallib.sh` + **sha256 manifest 守卫**（`metallib.manifest.json`
记每个 `.metal` 的 sha256 + 工具链版本）。
⚠️ **同步守卫不得用"重编再比对二进制"**——metallib 产物跨 Xcode 版本不保证逐字节稳定。

**四个可预见失败模式**（D-1 须一并回答）：工具链耦合（须钉 `-std=` 与
`-mios-version-min=26.0`，否则新 Xcode 编的产物在旧运行时加载失败=静默无渲染）·
**Mac Catalyst 误选**（`#if os(macOS)` 在 Catalyst 下为假、又非 simulator ⇒ 会选到
`iphoneos` 份；package 未声明 Catalyst ⇒ 明写不支持）· 仓库体积（每次改 shader 最多提交
6MB 二进制，考虑 LFS）· 构建产物冗余（见③）。

</details>

### AD-D 验证路径按 α/β 分别定义 —— **已定案走 α 那一行**

⚠️ **写反等于验了一条无人消费的路径。**

| 路径 | 要验什么 |
|---|---|
| **α（定案）** | `--build-system swiftbuild` + `xcodebuild` |
| ~~β~~ | ~~原生 `swift build`/`swift test`（macOS，加载 `macosx` 份）+ `xcodebuild` iOS Simulator + 真机手动~~ —— 作废 |

⚠️ **β 那一行连带作废的还有它的"优势"论述**（照录：「β 下 metallib 是 `.copy` 二进制资源，
原生构建会照常把它拷进 bundle ⇒ macOS `swift test` 能加载 ⇒ shader 加载测试拉回 SwiftPM
腿」）—— α 下原生构建**不产 metallib** ⇒ 加载测试**不能**留在 native 腿。
**实际改法**（#261 已落地）：SwiftPM 腿保留 native（`--skip CoreDesignShadersTests`，
显式跳过 + 留痕，不是静默放过），**另起一步** `swift test --build-system swiftbuild
--filter CoreDesignShadersTests`。

⚠️ **fail-closed 的要求原样保留、且在 α 下更重要**：缺 Metal device 即判红，
**不得** `guard let device else { return }` 静默跳过。
⚠️ **检查必须走 Metal API**（`device.makeDefaultLibrary(bundle: .module)`），
**不得**用 `ShaderLibrary`——后者是 SwiftUI 的惰性入口，查不到时不报错、只是不渲染，
那正是 α 最坏的失败形态。
⚠️ **「能加载」不等于「能画」**（#261 血的教训）：metallib 加载通过 + 函数解析通过，
**每个采样像素仍可能一模一样** —— `Float` 精度：`timeIntervalSinceReferenceDate` ≈ 8.1e8
在 `Float` 下只剩约 16 个单位精度，把 0…11 的空间项整个吞掉。失败形态是「效果看起来是
静态的」，四条腿全绿。⇒ **像素采样的 render proof 是每一批 shader 的必备项**。
⚠️ **`macos-26` runner 有没有可用 Metal device** —— #248 未解，转由 B-1 的一次性 CI 探针
回答（`MTLCreateSystemDefaultDevice() != nil`）。

### AD-E 11 个 layerEffect 的公开形态钉死

落成 `public struct … : ViewModifier` + `public extension View` 便利方法。
⇒ 28 个 shader 全部是 public 类型，AD-4 成本比较里的 P 口径统一。

⚠️ **「28 个」按闸②改为「实际落地件」**（#261 的 8 个 + #282/#283 的最多 11 个 ≤ 19）。
⚠️ **AD-4 已收敛为「AD-2 原样适用」**（#244 第 6 轮）：三个 target 全走
`component-registry.json`，没有「a vs b」这个待决问题 ⇒ 本条里的「AD-4 成本比较」
已无对象。

### AD-F 颜色纪律分两层，只有一层有机器判据

**Swift wrapper 层**由 `EffectsColorLiteralGuard` 机器判。
**`.metal` 侧该守卫看不见**（它是 SwiftSyntax 扫描，读不了 MSL；且 `SWPlasma.metal` 的
17 处 `float3(`/`half3(` 里颜色与数学常量正则区分不了）⇒ `.metal` 侧的调色板参数化
**由 D-1 的 spike 样本 + 评审覆盖，登记为已知无机器判据**（与公约 G-4 对 A 类文案同构）。

⚠️ **28 个 wrapper 里 21 个已在 Swift 侧接 `Color`，7 个写死**：ShaderKit 那 5 个
（ChromaticGlass / Foil / Glitter / IntenseBling / PolishedAluminum）+ **GlassLogo**
（整套硬编码静态调色板 `SWGlassLogoStyle.coolBlue/orange/deepBlue/stripe/canvas/bloom/
fresnelColor`）+ **LiquidMetal**（`coolTint` 是 `Float` 不是 `Color`）。
**这 7 个全是 `layerEffect`** ⇒ layerEffect 段的参数化难度显著高于 colorEffect 段，
D-1 的 layerEffect 样本须取自这 7 个。

⚠️⚠️ **闸②之后这段推论对本 epic 的落地范围不再成立**：那 7 个**没有一个在可落地 11 里**
（ShaderKit 5 与 `LiquidMetal` 判 `待追溯`；`GlassLogo` 判 `待追溯`，且已由 #261 以
`GlassSymbol` 之名落地）⇒ **#283 的 3 件不含任何调色板搬迁改造**，#248 给的
「2–3 小时/个」难件工时不适用。
⚠️ **连带**：`N_B` = 5 的分母（2.0–2.5h/shader）正是靠「可能落地的集合里有 7 个难件」
加权出来的 ⇒ **分母偏高 ⇒ `N_B` 偏大 ⇒ 闸②门槛被高估**。`N_B` 重估归 #280。
⚠️ **另一侧**：#248 的 layerEffect 样本 `spikeFoil` 是 6 行的条纹 mix，**未按 AC 取自
那 7 个** ⇒ 那个工时估算本就无实测支撑。
⚠️ **`.metal` 侧的 tint 通路有一条 #261 实证的硬约束**：**shader 读不到 `.tint`**——
`TintShapeStyle` 是 `ShapeStyle`，SwiftUI 不提供把它解析成 `Color` 的途径，而 Metal 需要
分量 ⇒ tint 只能以**参数**传入、默认值取第 3 层语义 token。本条与 CLAUDE.md《系统控件
`.core` style 的强调色必须走 `.tint` 通路》**不冲突**：那条管的是 SwiftUI 侧的 style，
shader 侧没有那条通路可走。

### AD-G 许可：正向裁定 + clean-room 的可核产物条款

> ⚠️ **闸②（#249）后本节须连同两条更正一起读**：
> ① **`clean-room 重写` 这个裁定档已被废除**（#249 第 5 轮终审 C1）——它的适用前提是
> 「那 21 个零标注 shader 的实际出处无法确立」，而终审 reviewer 用**参数签名比对 +
> 文件头描述句比对**在一小时内追到了其中 10+ 个的真实上游
> （[paper-design/shaders](https://github.com/paper-design/shaders)，**Apache-2.0** 且带
> `NOTICE`）。按第 1 版裁定重写，产物会是 Paper 作品的**衍生物**而**署名义务落空**。
> ⇒ 正文任何位置都不得再把 `clean-room 重写` 当作裁定值使用。
> ② **`ACKNOWLEDGEMENTS.md` 现需一个 Apache-2.0 + `NOTICE` 段**（LICENSE 全文 +
> `Powered by Paper Shaders: https://shaders.paper.design` + **修改标注**（§4(b)）
> + 逐 shader 的 `.metal` 文件头注明 paper 的对应 `.ts` 路径），与 MIT 档的义务不同，别混。
> ③ 本节警告的「那 7 个已知件的传递来源同样要核」**已兑现且判掉了 5 个**：ShaderKit 5
> 因其自述视觉参考是 **GPL-3.0** 的 `pokemon-cards-css` 而判 `待追溯`。
> ④ ⚠️ **本节引的「Shadertoy 默认许可是 CC BY-NC-SA」已被 #249 降为二手**——依据只有一条
> Wikipedia 概述，**从未直读官方条款原文**。补一手出处是 #280 的第一条 AC。


上游 `ACKNOWLEDGEMENTS.md` 只标注 **7/28** 个来源（ShaderKit 5 + StarNest + GlassOrb，
均 MIT）。**其余 21 个零来源标注**，而 Plasma / Voronoi / SimplexNoise / Metaballs /
Water / FractalClouds / Swirl / InkSmoke / SmokeRing / Starfield / NeuroNoise 这类经典
shader 的常见出处 Shadertoy **默认许可是 CC BY-NC-SA**（非商用 + 传染性 share-alike），
与 MIT 分发**不兼容**。

⚠️ **clean-room 条款写成可核的产物条款**，不写成"不看 ShipSwift 的 `.metal`"——后者
不可执行（本 PRD 的调研本身已 grep 过全部 34 个 `.metal`），且法律风险不在读 ShipSwift
（它是 MIT），在于 ShipSwift 的文件**本身**若是 CC BY-NC-SA 衍生。可核的三条：
① provenance 表的 `证据链接` **指向参考实现**，不得指向 ShipSwift；
② 新 `.metal` 文件头注明参考实现 URL + 其许可；
③ 评审**对照参考实现**核，不对照 ShipSwift。

⚠️ **那 7 个已知件的传递来源同样要核**——ShaderKit 自身的 shader 是否又移植自 Shadertoy，
上游没说，**不得当作预先通过**。

### AD-H Bool 纪律同样适用（Copilot 🟡3，初版完全没提）

28 个 wrapper 大概率带 `isAnimating` / `autoStart` 一类参数，全部撞 J-1。
⚠️ **本 epic 的 Bool 豁免预算是 ≤ 1 条**（PRD 的全局 ≤3 分配为 Effects 2 / Shaders 1）。
即便最终多数走豁免，也必须显式过一遍并入账，否则棘轮基线会在本 epic 收尾时悄悄超标。

## Task Breakdown（2026-09-04 实际分解，共 7 个 task）

> 草案的 B-1 ~ B-4 与实际分解**不是**一一对应。草案原文照录在本节末尾。

| # | task | 状态 | 依赖 | 对应草案 |
|---|---|---|---|---|
| **#278** | `CoreDesignShaders` target + 路径 α 落地 + 首批 8 个 shader | **closed** —— 由 PR #261 交付，本次补建承载记录 | 244–249 | B-1 的**已完成部分** |
| **#279** | 扫描根收口：`CoreDesignShaders` 进 `GuardScanRoots` + 8 个 public 类型登记 | open | 246 · 278（建议排在 #270 后） | B-1 的**未交付部分** |
| **#280** | 11 个可落地件的**落地前核验**（#282 / #283 的硬前置） | open | 249 | 草案没有 |
| **#281** | 已落地 8 件的 **provenance 清偿**：4 个 `TBD` 承接编号 + 强指纹 + 漏分档 | open | 249 · 278 | 草案没有 |
| **#282** | **8 个**可落地 `colorEffect` 背景 | open | 252 · **271（未决）** · 279 · 280 | B-2（草案 17 个） |
| **#283** | **3 个**可落地 `layerEffect` 内容层效果 | open | 279 · 280 | B-3（草案 11 个） |
| **#284** | 收尾——署名 / probe / 文档索引 / 预览宿主 / 性能基准 | open | **256（open，仍阻塞）** · 279 · 281 · 282 · 283 | B-4 |

### 落地范围：可落地 11，与 #261 已落的 8 个**无一交集**

| 类 | 成员 | task |
|---|---|---|
| `colorEffect`（**8**） | `StarNest`（MIT）· `Voronoi` · `Swirl` · `SimplexNoise` · `ColorPanels` · `DotOrbit` · `SmokeRing` · `Metaballs`（后 7 个 Apache-2.0 / paper-design） | **#282** |
| `layerEffect`（**3**） | `GlassOrb`（MIT / Inferno）· `Water` · `Halftone`（后 2 个 Apache-2.0 / paper-design） | **#283** |

⚠️ **`Starfield` ≠ `StarNest`** —— 前者是 #261 已落地的件（裁定 `待追溯`），后者是 #282
的成员（MIT）。两个名字很像，**不要合并、不要以为已经做了**。
⚠️ **`Water` 的分类须在 #283 开工时确认**：本 epic 的分类表把它列为 `layerEffect`
（来自 ShipSwift 快照的实现形态），而它的上游 paper `water.ts` 是**背景**类效果。
若实为 `colorEffect`，成员移到 #282、#283 剩 2 件。

### 为什么是 7 个 task，而不是草案警告的「4 个低于历史区间（5–13）」

草案那句判断是**按 28 个 shader** 做的：「B-2（17 个）与 B-3（11 个）注定要按纯噪声 /
多 pass / 需 SDF 再拆，拆开后才进入区间」。**闸②之后前提没了**：

- **#282 剩 8 个**，边际 1–1.5h/个 ⇒ 8–12h，与 `shipswift-effects` #250（8 个 modifier，
  单 task，L / 12–18h）同量级 ⇒ **再拆是为了凑数，不做**；
- **#283 剩 3 个**，且**不含**任何调色板搬迁难件 ⇒ S / 4–7h ⇒ **不可拆**。

进入区间靠的**不是**把 shader 分批，而是两闸结论逼出来的两个**新** task
（#280 落地前核验闸、#281 provenance 清偿）与一个**未交付项**（#279）。
这三个都有独立可验收的产出，不是拆出来凑数的。

### 17 个 `待追溯` 的处置（写明，不留白）

| 分组 | 件 | 处置 |
|---|---|---|
| **已落地的 8 个**（#261） | `Plasma` · `Starfield` · `Dots`(`DotGrid`) · `FractalClouds` · `InkSmoke` · `LiquidChrome` · `Glass`(`RefractiveGlass`) · `GlassLogo`(`GlassSymbol`) | 走《清偿条款》⇒ **#281**。低指纹档不阻断落地但须填实承接编号；**强指纹档阻断 `epic → main`**（`coreDesignRefractiveGlass` 主体已判强档） |
| **未落地的 9 个** | ShaderKit 5（`ChromaticGlass` / `Foil` / `Glitter` / `IntenseBling` / `PolishedAluminum`）· `NeuroNoise` · `GrainGradient` · `AnimatedLoop` · `LiquidMetal` | **本 epic 不落地，不为它们建 task**。理由：`待追溯` 的定义是「不得据现状落地」，而追一轮的产出是**不确定的**（可能追到不兼容 ⇒ `不落地`）⇒ 现在建 task 等于把一个结果未知的调研写成交付承诺。⚠️ **不是判它们 `不落地`**——`待追溯` ≠ `不落地`，把前者报成后者等于把「未查」谎报成「查过且不兼容」 |

⚠️ **重开触发器**：若日后有人按《方法论教训》的签名 + 散文比对追到其中任何一件的兼容
许可，**可落地数上升 ⇒ 另开 task 落地**，不需要重开闸②（闸②的谓词是「可落地数 ≥ `N_B`」，
只对下降敏感）。

### 四个 `TBD` 承接编号的判断：由 **#281** 承接，不另开

`docs/shader-provenance.md`《清偿条款》的分档表里，`ramp3` / `edgeWidth` / `wangHash` /
Teschner 素数三元组四行的「承接 issue」列现为 `TBD`，文档规定「合入 `main` 前必须换成
真实编号」「`TBD` 一律视为**未清偿**」。

**判断：四个 `TBD` 全部填 #281，不另开四个 issue。** 理由：
① 四项是**同一批次、同一处置**（#261 落地件的低指纹清偿，各需补齐 ①②③ 判据评估 +
追一轮），拆成四个 issue 只会让同一份核验工作被四次上下文切换打断；
② 文档要求的是「**具名**承接 issue」，不是「一项一个 issue」——它明确禁止的是
「后继 issue」「同上」这类**无法机器检出的模糊指代**，一个真实编号即满足；
③ #281 同时承接**强指纹**项与**漏分档**项，三类债在同一份裁定表里，分开做必然互相翻。

⚠️ **#281 顺带修一处两表打架**：Teschner 素数三元组在《共享原语的逐项出处》里判
「论文里的常数 ⇒ **事实性算法，可落地**」，在《清偿条款》分档表里却是**待追溯（低指纹）**。
⚠️ **#281 还补三处漏分档**：`roundedBoxSDF`（原语表自评「待追溯（低指纹）」，分档表无此行）·
**域扭曲的 `q`/`r` 三级级联**（它正是强档判据的**参照物**，自己却不在分档表里）·
`Plasma` 的四相正弦叠加。另有 **7 个已落地 shader 本体**在《统一裁定表》里是 `待追溯` 却
从未被分档 ⇒ 按「分档有争议时一律按强档处理」，它们当前**默认落在强档**。

<details>
<summary>照录：草案的 Task Breakdown Preview（已被上表取代）</summary>


⚠️ **以下是草案，实际 task 由两闸结论决定后才 decompose。**

```
B-1  CoreDesignShaders target + product + FR-2 选定路径落地
     （β 下含 3 份 metallib、metallib.manifest.json、sha256 同步守卫）
     + 把 Shaders 根加进 A0-3 建立的**全部**根列表（⚠️ 第 2 轮评审 I-1：不是"四条守卫"
       ——A0-3 交付的是四条守卫 + **条件差集守卫** + **NFR-4 grep**，最多六个根列表。
       漏掉差集守卫的 Shaders 根 ⇒ 28 个 public 类型落在射程外，正是第 1 轮 C-1 那个洞
       换到 Shaders 重现）
     + App/project.yml 补 product: CoreDesignShaders
       （⚠️ 改完不要在 worktree 里跑 `xcodegen generate`——会写死目录名并清空 scheme，
       见 PRD C-4 与本仓 CLAUDE.md）
     （probe 的实质调用点移到 B-4，见该 task）
     + CLAUDE.md / AGENTS.md 同步（否则 AgentGuideSyncGuard 判红）
B-2  17 个 colorEffect 背景（按 D-1 的复杂度分级分批：纯噪声 / 多 pass / 需 SDF）
B-3  11 个 layerEffect 内容层效果（含 7 个"颜色写死"件的参数化改造，AD-F）
B-4  收尾：
     · ACKNOWLEDGEMENTS.md **追加**逐 shader 条目（骨架由 **A0-6** 建，非 A-7）
     · **probe 补 `CoreDesignShaders` 的 nonisolated 调用点**（⚠️ 从 B-1 移到此处，
       第 3 轮评审 Suggestion 4：B-1 只建 target 骨架，那时没有任何 shader 类型可调，
       与第 1 轮批评 A0-4 的问题同构）
     · docs/components/*.md + docs/README.md 索引（落点按 A0-1 裁决）
     · 预览宿主（⚠️ ComponentData.swift 须在 A-7 定义的串行窗口之外写）+ 快照排除
     · effects-registry.json / reachable-type-registry.json 登记补齐
       （⚠️ 不写"`ReachableTypeRegistryGuard` 绿"——它不扫源码，对新 target 是空真，
       见 `shipswift-effects` SC 里的同款说明）
     · 复用 A-7 的性能基准脚本跑 17 个 colorEffect
```

⚠️ **4 个 task 低于本仓历史区间（5–13）**——B-2（17 个）与 B-3（11 个）注定要按上面
标注的分组再拆，拆开后才进入区间。

</details>

## Dependencies

### `shipswift-foundation`
- **前置 = A0-2 ~ A0-6 全部完成**；**启动条件 = A0-5 ∧ A0-6 双双通过**（两者不同）

### `shipswift-effects`（⚠️ 初版漏了这一整块，第 1 轮 structure 评审 C-3）
- **A-3（#252，已完成）** —— ⚠️ **落点与本行原文不同，照录并更正**：原文写「落在
  `CoreDesignEffects`……这正是 FR-1 允许 `CoreDesignShaders` → `CoreDesignEffects`
  单向依赖的用途」。**实际用户裁决把两个键下沉到 `CoreDesign`**
  （`Sources/CoreDesign/Environment/EnergySignalEnvironment.swift`：`lowPowerModeOverride`
  / `scenePhaseOverride`，两者显式 `public`），理由是「别让只想要 shader 的消费者链上
  整个 `CoreDesignEffects` product」⇒ **#282 只需 `import CoreDesign`**，
  那条单向依赖**没有被用上**。
- **A-3 的残余（#271，open，⚠️ 阻塞 #282）** —— 被 `EffectsEnergy.swift` 自己标为
  「通用」的那半张策略表（`drawsAnything` / `minimumInterval` 与
  「`scenePhase != .active ⇒ 停摆`、`lowPower ⇒ 降帧`」这条映射）以及
  `EffectsEnergyState` / `EffectsRenderPolicy` / `EffectsPowerMode` **仍在
  `CoreDesignEffects`**。#282 只有两条路——(a) `import CoreDesignEffects` ⇒ 推翻下沉的
  全部理由；(b) 自行再写一遍同一条映射 ⇒ 必漂。**开工前须裁决。**

<details>
<summary>照录：A-3 原文（落点已更正）</summary>

- **A-3** —— NFR-7 的可注入 `EnvironmentValues`（`isLowPowerModeEnabled` / `scenePhase`）
  落在 `CoreDesignEffects`，本 epic 的 17 个 `colorEffect` **import 复用它，不另造一套**
  （这正是 FR-1 允许 `CoreDesignShaders` → `CoreDesignEffects` 单向依赖的用途）。
  ⇒ **B-2 依赖 A-3**。

</details>
- **A-7（#256，⚠️ open，仍阻塞 #284）** —— ① `App/Sources/ComponentData.swift` 是**跨 epic
  的并行冲突面**，其串行写入窗口由 A-7 定义，#284 必须在该窗口之外写；② **NFR-1 的性能
  基准脚本**由 A-7 建，#284 **复用同一脚本**，不重造；③ `ACKNOWLEDGEMENTS.md` 的骨架由
  **A0-6** 建（非 A-7），#284 只**追加**逐 shader 条目。
  ⚠️ #256 自己依赖 #250~#255，其中 #251 已拆成 #266 / #267 / #268（均 open）
  ⇒ **这是本 epic 与 Epic A 之间唯一剩下的结构性耦合。**
- **#270（open）** —— 组件登记表扫描根收口的 Effects 侧。#279 是 Shaders 侧的同款收口，
  两者顶动**同一条 AD-4《下游连锁一》判据链** ⇒ 已互标 `conflicts_with`，**建议 #270 先做**。

### 外部
- ShipSwift 快照 + **其上游**（ShaderKit / Inferno / Shadertoy 各作者）—— AD-G 的核验对象
- 三种构建系统对 `.metal` 的差异行为 —— D-1 的验证对象

## Success Criteria (Technical)

> ⚠️ **本节已按闸① α 改判逐条重判**，分三档：**成立** / **改口径后成立** / **作废**。
> 草案原文照录在本节末尾。

### ✅ 成立（原样保留）

- [x] `docs/shader-provenance.md` 覆盖全部 28 个 shader，无空裁定 —— **已满足**（#249）
- [x] 可落地数 **≥ `N_B`** —— **已满足（11 ≥ 5）**。⚠️ 两个方向的重开触发器都挂着：
      **分子** —— 「§A / §B 任一落地前核验失败 ⇒ 可落地数 −1；降至 < `N_B` 时闸②须重开」
      （**最坏地板 = 1**，低于 `N_B`）；**分母** —— `N_B` 须按「移植 + 署名」重估
      （草案的分母是按「7 个难件」加权的，而那 7 个无一可落地 ⇒ **分母偏高**）。两者归 #280
- [ ] 裁定为可落地者 **100%「可用」**（四条 AND：编译 / 过守卫 / 有 Preview 且进画廊 / 有文档）
- [ ] `ACKNOWLEDGEMENTS.md` 覆盖每一个落地的 shader，**无来源不明项被落地**
- [ ] **`CoreDesignEffects` 的反向依赖禁令机器化**：
      `swift package describe --type json | jq '.targets[] | select(.name=="CoreDesignEffects") | .target_dependencies'`
      恰为 `["CoreDesign"]`
- [ ] AD-D 表列出的验证路径全部实测通过；shader 加载测试 **fail-closed**
- [ ] Reduce Motion 下 `colorEffect` 冻结在某一帧；`layerEffect` 冻结时间输入但保留
      手势/倾斜的空间输入
- [ ] **Bool 豁免基线净增 ≤ 1 条**（AD-H），有书面理由，按棘轮脚本流程抬基线
- [ ] **`docs/reachable-type-registry.json`** 已登记本 epic 新增的可达类型
- [ ] **`GlassOrb` 的触控目标测试**在 `CoreDesignShadersTests` 内同形态实现
      （⚠️ **不得**加进 `TouchTargetTests`——会判红 NFR-5②）
- [ ] **NFR-5② 沿用**：`CoreDesignTests` 的 `target_dependencies` 仍恰为 `["CoreDesign"]`
- [ ] **FR-13 分工**：shader 装饰层 100% `accessibilityHidden(true)`
- [ ] CI 四条腿全绿

### 🔧 改口径后成立

- [ ] **`CoreDesignShaders` 的 resource bundle 每平台 ≤ 2MB**
      ⚠️ 「β 下 3 份合计 ≤ 6MB」**作废**：α 下仓库里**没有**提交任何 metallib，被测对象是
      **构建产物**。#248 实测边际 ≈ 9.2 KB/shader ⇒ 19 个 ≈ 175 KB
      ⇒ **本条现在是形式性核对，不是风险项**
- [ ] **NFR-7 后台 / 低电量**：**8 个**（不是 17 个）`colorEffect` 的行为经**注入伪值测试**
      可证。⚠️ 可注入键在 **`CoreDesign`**（不是 `CoreDesignEffects`）⇒ `import CoreDesign`
- [ ] **NFR-1 性能基准闸**：**8 个**（不是 17 个）`colorEffect` 各过基准脚本，
      **脚本断言而非人工抽测**，且**在真机执行**
- [ ] **probe 覆盖本 epic 全部已落地 shader 类型**（不是「28 个」）的 nonisolated 调用点。
      ⚠️ 措辞不写「全部**公开**值类型」——那是自指的。
      ⚠️ **α 下 probe 只能 build-only、不得触发渲染**：probe 用原生 `swift build`，
      而 α 下原生构建不产 metallib
- [ ] Reduce Transparency 下降级为不透明形态 —— ⚠️ 原文点名 `Glass` / `GlassOrb` /
      `ChromaticGlass` 三个，实际：`Glass` 已由 #261 以 `RefractiveGlass` 落地（归 #284 复核）·
      `ChromaticGlass` 判 `待追溯`**不落地** · **只有 `GlassOrb` 归 #283**
- [ ] **`docs/README.md` 索引**已挂 —— ⚠️ 「判据随 AD-4 走向而不同（a / b 两路线）」这段
      **已失效**：AD-4 经六轮终审收敛为「**AD-2 原样适用**」，三个 target 全走
      `component-registry.json`，没有「a vs b」这个待决问题 ⇒ 判据就是 #279 交付的差集守卫

### ❌ 作废（α 下不存在，照录勿再执行）

- ~~**metallib sha256 同步守卫带触发红的 fixture**~~ —— β 独有。α 下 `.metal` 与产物
  **同一次构建，不可能失步**，守卫防的那个失效形态（改了 shader 忘重编 = 静默用旧效果）
  在 α 下不存在。⚠️ #248 已显式声明：该项**随 α 改判一并作废，不是遗漏**
- ~~**NFR-3 明写不支持 Mac Catalyst**（README / CLAUDE.md 已声明）~~ —— β 独有
  （`#if os(macOS)` 在 Catalyst 下为假、又非 simulator ⇒ 会误选 `iphoneos` 份）。
  α 下构建系统自己处理，没有 `#if` 选份这件事

### ➕ α 新增（草案没有）

- [ ] **α 残余风险的三条缓解全部落地**：首次使用时 fail-closed 检查并 `precondition` /
      throw（**不用 `assertionFailure`**，release 下 no-op）· README 与 CLAUDE.md 明写
      「用原生 `swift build` 消费本 product 时须加 `--build-system swiftbuild`」·
      `docs/components/` 里每个 shader 的文档带同一句话（#261 已落前两条，第三条归 #284）
- [ ] **CI SwiftPM 腿保留 native**，另起一步只跑 `CoreDesignShadersTests` 的 swiftbuild
      —— ⚠️ 判据是 `ColorAssetGuardTests` 的「Colorset 资源存在性守卫」suite
      **在 native 腿上仍为 passed（不是 skipped）**
- [ ] **像素采样的 render proof** —— 「metallib 加载通过 + 函数解析通过」**不等于画得出来**
- [ ] **`epic → main` 前：`docs/shader-provenance.md` 零 `TBD`、强指纹项全部追完**（#281）

<details>
<summary>照录：Success Criteria 原文（已被上表分档取代）</summary>


- [ ] `docs/shader-provenance.md` 覆盖全部 28 个 shader，无空裁定
      （⚠️ 该表**由 A0-6 产出**；本条是**启动前核验**，不是重复交付——评审 Suggestion）
- [ ] 裁定为可落地者 **100%** "可用"（四条 AND：编译 / 过守卫 / 有 Preview 且进画廊 / 有文档）
- [ ] 可落地数 **≥ `N_B`**（按 C-6 的经济性方法由 D-1 结论反推，**不取 7**——7 恰好等于
      已知 MIT 来源数，取它是同义反复）
- [ ] `ACKNOWLEDGEMENTS.md` 覆盖每一个落地的 shader，**无来源不明项被落地**
- [ ] `CoreDesignShaders` 的 resource bundle **每平台 ≤ 2MB**（β 下 3 份合计 ≤ 6MB）
- [ ] **metallib sha256 同步守卫带触发红的 fixture**（第 2 轮评审 I-7）：改 `.metal`
      而不重编 ⇒ 判红，有实证。⚠️ 形态同 `shipswift-foundation` AD-E 对新守卫的要求
      ——它防的正是"改了 shader 忘了重编 = 静默用旧效果"，没 fixture 就不知道它真的会响
- [ ] **`CoreDesignEffects` 的反向依赖禁令机器化**（评审 S-4）：
      `swift package describe --type json | jq '.targets[] | select(.name=="CoreDesignEffects") | .target_dependencies'`
      恰为 `["CoreDesign"]`（即 Effects 不得依赖 Shaders）
- [ ] **NFR-3 明写不支持 Mac Catalyst**（评审 S-2）：README / CLAUDE.md 已声明
- [ ] AD-D 表列出的验证路径全部实测通过；shader 加载测试 fail-closed
- [ ] Reduce Motion 下 `colorEffect` 冻结在某一帧；`layerEffect` 冻结时间输入但保留
      手势/倾斜的空间输入（放大镜跟手是交互不是动效）
- [ ] Reduce Transparency 下 Glass / GlassOrb / ChromaticGlass 降级为不透明形态
- [ ] **NFR-7 后台 / 低电量**（评审 C-3，初版遗漏）：17 个 `colorEffect` 的后台与低电量
      行为经**注入伪值测试**可证（复用 A-3 落在 `CoreDesignEffects` 的可注入 environment 键）
- [ ] **NFR-1 性能基准闸**：17 个 `colorEffect` 各过基准脚本，**脚本断言而非人工抽测**，
      且**在真机执行**（Simulator 上的 GPU frame-time 无意义，第 2 轮评审 I-5）
- [ ] **Bool 豁免基线净增 ≤ 1 条**（AD-H），有书面理由，按棘轮脚本流程抬基线
- [ ] **`docs/README.md` 索引**已挂（落点按 A0-1 的 AD-4 裁决）。
      ⚠️ **判据随 AD-4 走向而不同**（第 2 轮评审 S-6）：**b 路线**下引
      `readmeIndexReconcilesWithRegistry`；**a 路线**（本 target 的推荐走向）下该守卫
      **只管主索引到 `## 生成预览图` 之间，对另起的小节是空真** ⇒ 真正的判据是
      A0-3 交付的**差集守卫 / 锚文档守卫**，本条应引那一条
- [ ] **`docs/reachable-type-registry.json`** 已登记本 epic 新增的可达类型
- [ ] **probe 覆盖 28 个 shader 所对应的全部类型**的 nonisolated 调用点
      （A0-4 只做接线，实质在 B-4）。⚠️ 措辞不写"全部**公开**值类型"——那是自指的
      （第 3 轮评审 Suggestion 2，与 `shipswift-effects` 同款修正）
- [ ] **`GlassOrb` 的触控目标测试**在 `CoreDesignShadersTests` 内同形态实现
      （⚠️ **不得**加进 `TouchTargetTests`——会判红 NFR-5②）
- [ ] **NFR-5② 沿用**：`swift package describe … CoreDesignTests … target_dependencies`
      仍恰为 `["CoreDesign"]`
- [ ] **FR-13 分工**：shader 装饰层 100% `accessibilityHidden(true)`
- [ ] CI 四条腿全绿

</details>

## Estimated Effort

**两闸已出结论，不再是「不确定」。**

| task | Size | Hours |
|---|---|---|
| #278（已完成） | — | — |
| #279 扫描根收口 | M | 6–10 |
| #280 落地前核验闸 | M | 6–10 |
| #281 provenance 清偿 | M | 8–14 |
| #282 8 个 colorEffect | L | 10–16 |
| #283 3 个 layerEffect | S | 4–7 |
| #284 收尾 | L | 8–14 |
| **合计（剩余）** | | **42–71 小时** |

⚠️ **两条与草案相反的成本方向**：
① **α 省掉了 B-1 一整块固定成本**——3 份 metallib + 同步守卫 + fixture + 工具链钉版本
（#248 估：β 下 B-1 要**再加 8–14 小时**）；
② **闸②把落地量从 28 砍到 11，但把成本重心从「写 shader」搬到了「核验与署名」**——
#280 / #281 两个纯核验 task 合计 14–24 小时，**超过** #282 + #283 的落件工时（14–23 小时）。

<details>
<summary>照录：Estimated Effort 原文</summary>

不确定——**取决于两闸**。最坏情况本 epic 不启动（成本 0，已由 A0 的 spike 与核验吸收）；
最好情况 **27** 个全落地（`Starfield` 已判 `不落地` 并撤回，见上文表下的说明）。B-1 的一次性基建（构建系统 + 3 份 metallib + 同步守卫）是固定成本，
也正是 `N_B` 下限要衡量的那笔。

</details>
