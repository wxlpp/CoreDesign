---
name: shipswift-shaders
status: backlog
created: 2026-09-02T23:42:57Z
updated: 2026-09-02T23:42:57Z
progress: 0%
prd: .claude/prds/shipswift-harvest.md
github: (will be set on sync)
---

# Epic: shipswift-shaders（Metal）

> `shipswift-harvest` PRD 拆出的**第 3 个** epic（共 3 个）。
> ⚠️ **本 epic 是有条件的**——见下方《启动条件》。在两闸出结论前**不得 decompose、
> 不得 sync 到 GitHub**：它的 task 数量与内容都由闸的结论决定，提前分解就是编造。

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

### 前置 = `shipswift-foundation` 的 **A0-2 ~ A0-6 全部完成**

两闸只是**启动条件**。B-1 另有隐式依赖：A0-2（CI scheme 已切、`CoreDesignShaders` 要能
依赖 `CoreDesignEffects`）、A0-3（守卫根列表，本 epic 负责把 Shaders 根加进去）、
A0-4（probe 形态）。

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

## Task Breakdown Preview

⚠️ **以下是草案，实际 task 由两闸结论决定后才 decompose。**

```
B-1  CoreDesignShaders target + product + FR-2 选定路径落地
     （β 下含 3 份 metallib、metallib.manifest.json、sha256 同步守卫）
     + 把 Shaders 根加进四条守卫（承接 A0-3 的 fail-closed 根列表）
     + App/project.yml 补 product: CoreDesignShaders
     + probe 补 CoreDesignShaders 的 nonisolated 调用点
     + CLAUDE.md / AGENTS.md 同步（否则 AgentGuideSyncGuard 判红）
B-2  17 个 colorEffect 背景（按 D-1 的复杂度分级分批：纯噪声 / 多 pass / 需 SDF）
B-3  11 个 layerEffect 内容层效果（含 7 个"颜色写死"件的参数化改造，AD-F）
B-4  ACKNOWLEDGEMENTS.md 署名（含 7 个已知件的传递来源核验）+ 文档 + 预览宿主
     + 快照排除 + effects-registry.json / reachable-type 登记补齐
```

⚠️ **4 个 task 低于本仓历史区间（5–13）**——B-2（17 个）与 B-3（11 个）注定要按上面
标注的分组再拆，拆开后才进入区间。

## Dependencies

- `shipswift-foundation` A0-2 ~ A0-6（前置）；A0-5 ∧ A0-6（启动条件）
- ShipSwift 快照 + **其上游**（ShaderKit / Inferno / Shadertoy 各作者）—— AD-G 的核验对象
- 三种构建系统对 `.metal` 的差异行为 —— D-1 的验证对象

## Success Criteria (Technical)

- [ ] `docs/shader-provenance.md` 覆盖全部 28 个 shader，无空裁定
- [ ] 裁定为可落地者 **100%** "可用"（四条 AND：编译 / 过守卫 / 有 Preview 且进画廊 / 有文档）
- [ ] 可落地数 **≥ `N_B`**（按 C-6 的经济性方法由 D-1 结论反推，**不取 7**——7 恰好等于
      已知 MIT 来源数，取它是同义反复）
- [ ] `ACKNOWLEDGEMENTS.md` 覆盖每一个落地的 shader，**无来源不明项被落地**
- [ ] `CoreDesignShaders` 的 resource bundle **每平台 ≤ 2MB**（β 下 3 份合计 ≤ 6MB）
- [ ] AD-D 表列出的验证路径全部实测通过；shader 加载测试 fail-closed
- [ ] Reduce Motion 下 `colorEffect` 冻结在某一帧；`layerEffect` 冻结时间输入但保留
      手势/倾斜的空间输入（放大镜跟手是交互不是动效）
- [ ] Reduce Transparency 下 Glass / GlassOrb / ChromaticGlass 降级为不透明形态
- [ ] CI 四条腿全绿

## Estimated Effort

不确定——**取决于两闸**。最坏情况本 epic 不启动（成本 0，已由 A0 的 spike 与核验吸收）；
最好情况 28 个全落地。B-1 的一次性基建（构建系统 + 3 份 metallib + 同步守卫）是固定成本，
也正是 `N_B` 下限要衡量的那笔。
