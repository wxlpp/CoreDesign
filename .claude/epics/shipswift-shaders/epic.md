---
name: shipswift-shaders
status: backlog
created: 2026-09-02T23:42:57Z
updated: 2026-09-03T00:35:00Z
progress: 0%
prd: .claude/prds/shipswift-harvest.md
github: (will be set on sync)
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

## Overview

把 ShipSwift 的 **28 个 Metal shader** 落成新 target `CoreDesignShaders`。
28 个分两类，**能力不同，不能混为一谈**：

| 类 | 数量 | 形态 | 名单 |
|---|---|---|---|
| `colorEffect` | **17** | 真程序化背景，可 `.background { }` | AnimatedLoop · ColorPanels · DotOrbit · Dots · FractalClouds · GrainGradient · InkSmoke · LiquidChrome · Metaballs · NeuroNoise · Plasma · SimplexNoise · SmokeRing · Starfield · StarNest · Swirl · Voronoi |
| `layerEffect` | **11** | 作用于**内容层**（箔片卡片 / 玻璃放大镜 / 半调网屏），`.background{}` 画不了 | ChromaticGlass · Foil · Glass · GlassLogo · GlassOrb · Glitter · Halftone · IntenseBling · LiquidMetal · PolishedAluminum · Water |

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

## Architecture Decisions

### AD-A `CoreDesignShaders` target 在本 epic 建，不在 A0 建

若 A0 就建了它而闸没过，仓库里会留下一个**空 product** 及其连带的 `App/project.yml`
条目、probe 调用点、README 索引小节。

### AD-B 路径 β（预编译 metallib）是默认走向

**已实测的硬事实**：原生 `swift build` **不编译 `.metal`**——报
`found N file(s) which are unhandled`，不产 metallib，也不合成 `Bundle.module`；
声明成 `.process(...)` 资源后只做 `Copying`（拷贝源码，不编译）。
只有 `--build-system swiftbuild` 与 `xcodebuild` 会真编。

而 CI SwiftPM 腿、`scripts/downstream-probe`、下游 StoryUI 的 CI **用的都是原生构建**
⇒ 路径 α（源码随 target 编译）等于把构建系统约束转嫁给下游，**失败形态是运行时静默
无渲染**——最坏的一类。⇒ **除非 D-1 证明所有已知消费路径都可切 swiftbuild，否则走 β。**

### AD-C β 的真实形态是 3 份 metallib，不是一个文件

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

### AD-D 验证路径按 α/β 分别定义

⚠️ **写反等于验了一条无人消费的路径。**

| 路径 | 要验什么 |
|---|---|
| α | `--build-system swiftbuild` + `xcodebuild` |
| **β（默认）** | **原生 `swift build`/`swift test`（macOS，加载 `macosx` 份）** + `xcodebuild` iOS Simulator（`iphonesimulator` 份）+ 真机手动（`iphoneos` 份） |

⚠️ β 下 metallib 是 `.copy` 二进制资源，原生构建**会照常把它拷进 bundle** ⇒ macOS
`swift test` 能加载 ⇒ **shader 加载测试拉回 SwiftPM 腿**（这是 β 相对 α 的一项优势）。
⚠️ 该测试必须 **fail-closed**：缺 Metal device 即判红，**不得** `guard let device else
{ return }` 静默跳过。

### AD-E 11 个 layerEffect 的公开形态钉死

落成 `public struct … : ViewModifier` + `public extension View` 便利方法。
⇒ 28 个 shader 全部是 public 类型，AD-4 成本比较里的 P 口径统一。

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

### AD-G 许可：正向裁定 + clean-room 的可核产物条款

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

## Task Breakdown Preview

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

## Dependencies

### `shipswift-foundation`
- **前置 = A0-2 ~ A0-6 全部完成**；**启动条件 = A0-5 ∧ A0-6 双双通过**（两者不同）

### `shipswift-effects`（⚠️ 初版漏了这一整块，第 1 轮 structure 评审 C-3）
- **A-3** —— NFR-7 的可注入 `EnvironmentValues`（`isLowPowerModeEnabled` / `scenePhase`）
  落在 `CoreDesignEffects`，本 epic 的 17 个 `colorEffect` **import 复用它，不另造一套**
  （这正是 FR-1 允许 `CoreDesignShaders` → `CoreDesignEffects` 单向依赖的用途）。
  ⇒ **B-2 依赖 A-3**。
- **A-7** —— ① `App/Sources/ComponentData.swift` 是**跨 epic 的并行冲突面**，其串行写入
  窗口由 A-7 定义，B-4 必须在该窗口之外写；② **NFR-1 的性能基准脚本**由 A-7 建，
  B-4 **复用同一脚本**，不重造；③ `ACKNOWLEDGEMENTS.md` 的骨架由 **A0-6** 建（非 A-7），
  B-4 只**追加**逐 shader 条目。

### 外部
- ShipSwift 快照 + **其上游**（ShaderKit / Inferno / Shadertoy 各作者）—— AD-G 的核验对象
- 三种构建系统对 `.metal` 的差异行为 —— D-1 的验证对象

## Success Criteria (Technical)

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

## Estimated Effort

不确定——**取决于两闸**。最坏情况本 epic 不启动（成本 0，已由 A0 的 spike 与核验吸收）；
最好情况 28 个全落地。B-1 的一次性基建（构建系统 + 3 份 metallib + 同步守卫）是固定成本，
也正是 `N_B` 下限要衡量的那笔。
