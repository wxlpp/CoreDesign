---
name: shipswift-harvest
description: 从 ShipSwift(MIT) 收割 CoreDesign 真空缺的表达性视觉层——35 个纯 SwiftUI 动效 API、28 个 Metal shader、4 个 Swift Charts 画不出来的图表——落成三个新 target，并在 structure 阶段拆为「非 Metal」与「Metal」两个独立 epic
status: backlog
created: 2026-09-02T22:50:16Z
---

# PRD：ShipSwift 表达性视觉层收割

> **修订说明（第 1 轮评审后重写）**：初版的成本模型、CI 验证路径、许可假设与
> 计数单位均被评审证伪。本版逐条改正，改动摘要见文末《评审响应台账》。

## Executive Summary

[ShipSwift](https://github.com/signerlabs/ShipSwift)（MIT，SignerLabs）是一个面向 LLM 的
SwiftUI「配方库」。本 PRD 从中**只取 CoreDesign 真空缺、且属于设计系统职责范围**的
表达性视觉能力，按 CoreDesign 的 API 公约与色彩地基**重新实现**（不是拷贝文件）。

### 计数单位（先定义，避免分母漂移）

全文统一用 **「API 单位」= 一个调用方可独立使用的公开入口**（一个 `View` 类型、
一个 `Transition` 静态成员、一个 `View` 扩展 modifier）。文件数**不作为**任何指标的分母。

| 落地轨 | 新 target | 文件数 | **API 单位** |
|---|---|---|---|
| 纯 SwiftUI 动效 | `CoreDesignEffects` | 14 | **35** |
| Metal shader | `CoreDesignShaders` | 28 wrapper / 34 `.metal` | **28** |
| 原生画不出的图表 | `CoreDesignCharts` | 4 | **4** |
| | | | **合计 67** |

### 三个 target，不是两个

初版方案（`CoreDesignEffects` 一个 target 装下 SwiftUI 动效 + Metal）已否决。**Metal 段
有三项独立于 SwiftUI 动效的约束**：① 依赖非默认构建系统（见 C-1）；② 独立的
resource 体积预算（NFR-2）；③ 独立的许可核验闸（C-6）与整体下线开关。把它与
`.shake(trigger:)` 绑进同一个 target，意味着只想要微交互的消费者要背 metallib 与
构建系统限制。⇒ **Metal 单独成 `CoreDesignShaders`。**

### 两个 epic

本 PRD 在 **structure 阶段拆为两个独立 epic**（先例：`coredesign-native-refresh.md:3,16`
同样是「一 PRD → 两 epic」）：

- **Epic A「非 Metal」** = 三 target 骨架 + 守卫扩展 + 公约裁决 + 35 个 SwiftUI 动效 + 4 个图表
- **Epic B「Metal」** = 28 个 shader。**前置**：Epic A 的 D-1 spike 与 C-6 许可核验双双通过。
  两个前置任一不过，Epic B 整体不启动，Epic A 不受影响。

⚠️ **不拆成两个 PRD 的理由**：三 target 拓扑、守卫扩展方案、公约裁决 AD-4 是两个 epic
**共享的地基决策**，拆 PRD 会导致这三项要么重复写、要么跨 PRD 引用。epic 级拆分已经
完整满足「可独立下线」与「密度可控」两个诉求。

### 本 PRD 的核心判断

ShipSwift 的价值是**点子与算法**，不是可直接消费的代码。它的源码全部 `internal`、
硬编码色、零 accessibility、零 `controlSize` / Dynamic Type 适配、零测试。CoreDesign 有
四层色彩系统、1410 行 API 公约、47 条本仓组件登记（跨仓表共 72 条，另 25 条属 StoryUI）、
a11y 豁免台账、~380KB 自动化守卫。**工作量的大头不在 SwiftUI 代码，在过守卫与过许可。**

## Problem Statement

### 现状

CoreDesign `0.4.0` 已覆盖 47 条本仓登记组件，视觉地基在 `0.3.0` 从 GitHub Primer 换成
Apple HIG。**这是一个刻意克制的、以"系统原生观感"为纲的设计系统。** 但它有一整块
系统性空白：**表达性视觉层**。

- **微交互为零**。`Modifier/` 下 9 个 modifier 中唯一的动效是 `Skeleton.swift:236-255`
  的 `.skeletonShimmer()`（`TimelineView` 扫光）——且它只服务骨架屏。
  ⚠️ `SpinningModifier` **不是**动效，它是「material 遮罩 + 居中 `ProgressIndicator`」的
  加载遮罩（登记表 notes 原文）。`PinCode` 输错、`Form` 校验失败、`AsyncButton` 成功，
  全部没有动效反馈可用。
- **转场为零**。没有任何 `Transition` 实现。
- **庆祝 / 处理中反馈为零**。
- **程序化背景为零**。`Resources.xcassets` 只有 color set。
- **图表为零**。Swift Charts 覆盖 line / bar / area / point / sector，但**雷达图、活动环、
  贡献热力图、力导向网络图原生画不出来**。

### 为什么现在做

1. **下游正在自己造轮子**。登记表里 25 条属 `storyui`（`AgentMessageList` /
   `StreamingIndicator` / `SuggestionStream` / `WritingStatusBar`…），那些 agent / 流式 UI
   场景正是最需要微交互与动效的地方。
2. **ShipSwift 是 MIT**，可合法衍生 + 署名（⚠️ 但只对来源清晰的部分成立，见 C-6），
   省掉从零推导力导向布局、confetti 物理、16 个 mask reveal 的 `Shape` 数学。
3. **Metal 打包一次通，后续无限复用**。

## User Stories

### US-1：输入校验的动效反馈

**作为** 使用 CoreDesign 的 App 开发者
**我需要** 在密码输错时让输入框抖动、在点赞时喷出爱心粒子

**验收标准**
- [ ] `import CoreDesignEffects` 后可写 `PinCode(...).shake(trigger: failedAttempts)`
- [ ] **8 个**微交互 API 全部可用：shake / jump / spin / ping / spray / rise / haptic / shine
      （⚠️ 上游 `SWChangeEffect.swift:10-17` 逐字列了 8 个，含 `swHaptic`）
- [ ] 每个可叠加，同一 trigger 驱动多个效果时互不干扰
- [ ] 全部遵守 `accessibilityReduceMotion`——开启时降级为无位移形态

### US-2：庆祝时刻

**验收标准**
- [ ] `myView.confetti(trigger: purchased)` 触发一次 burst
- [ ] 粒子颜色**默认取自调用方 `.tint`**，不自带彩虹色板
- [ ] `accessibilityReduceMotion` 开启时不播放粒子，降级为一次淡入淡出的静态庆祝层
- [ ] burst 结束后驱动它的 `TimelineView` **停止调度或被移除**
      （⚠️ 上游用 `TimelineView(.animation)`（`SWConfetti.swift:171,435`），不是 Timer /
      DisplayLink——初版 AC 写的"无常驻 Timer 泄漏"对着一个不存在的泄漏源）

### US-3：有质感的背景层与内容层效果

⚠️ **28 个 shader 分两类，能力不同**（`grep -l colorEffect/layerEffect` 可证）：
- **17 个 `colorEffect`**——真程序化背景，可 `.background { }`：AnimatedLoop / ColorPanels /
  DotOrbit / Dots / FractalClouds / GrainGradient / InkSmoke / LiquidChrome / Metaballs /
  NeuroNoise / Plasma / SimplexNoise / SmokeRing / Starfield / StarNest / Swirl / Voronoi
- **11 个 `layerEffect`**——作用于**内容层**（箔片卡片、玻璃放大镜、半调网屏…），
  是 `.background{}` **画不了**的东西：ChromaticGlass / Foil / Glass / GlassLogo /
  GlassOrb / Glitter / Halftone / IntenseBling / LiquidMetal / PolishedAluminum / Water

**验收标准**
- [ ] 17 个 `colorEffect` 可作为任意视图的 `.background { }`
- [ ] 11 个 `layerEffect` 以 `View` 扩展 modifier 形式作用于内容（形态与 `.background` 不同，
      文档需明写这个分野）
- [ ] **颜色 100% 由调用方传入**，无 shader 自带品牌色板（`EffectsColorLiteralGuard` 可查）
- [ ] 在 iOS 真机与 iOS Simulator 两端都渲染
- [ ] metallib 加载在 **`--build-system swiftbuild` 与 `xcodebuild` 两条路径**下均可证
      （⚠️ 原生 `swift build` 不编译 `.metal`，见 C-1）

### US-4：原生画不出来的图表

**验收标准**
- [ ] `RadarChart` / `RingChart` / `ActivityHeatmap` / `NetworkGraph` 各自可用
- [ ] 全部走 CoreDesign 语义色 token 或调用方传入色，不硬编码色相
- [ ] 每个图表有 accessibility 表示（`AXChartDescriptorRepresentable` 或逐数据点
      `accessibilityElement` + `accessibilityValue`）
- [ ] 不引入 `import Charts`
- [ ] **退化输入不 crash、不产生 NaN**（见 FR-19）

### US-5：新 target 有机器可查的质量边界

**验收标准**——⚠️ 逐守卫写明，不再笼统说"四道守卫扩展覆盖"：

| 守卫 | 能否扩到新 target | 本 PRD 的要求 |
|---|---|---|
| `BoolExemptionGuard` / `BoolParameterScanner` | **能**（改扫描根 + 台账键加 target 前缀） | 必须扩；SC-6 |
| `AccessibilityStringLiteralGuard` | **能**（`:189` 改根；需按 target 分辨各自的 `.module`） | 必须扩 |
| `ComponentTextParamGuard` | **仅在新 target 进登记表的前提下能**——其定义域是登记表条目（`:228-242` 按 `repo == "coredesign"` 取 `textParams` 并硬断言 `== 31`），公约 G-8 逐字「FR-4 判据以**登记表条目**为定义域」 | **取决于 AD-4 的裁决结果**（见 C-5）；裁决前不写死 |
| `TouchTargetTests` | **结构上不适用**——它是手写的交互组件实例化清单且整 suite `#if os(iOS)`；新 target 里真交互件只有 BeforeAfterSlider / GlassOrb 两个 | **不列为验收项**；只把这两个真交互件加进清单 |
| `EffectsColorLiteralGuard`（新增） | — | 必须新建；SC-4 |

- [ ] `CoreDesign` target 的公开 API 表面**零变化**（`downstream-probe` 可证）
- [ ] CI 四条腿全绿

## Functional Requirements

### FR-1 ~ FR-4：包结构

- **FR-1** `Package.swift` 新增三个 target + 三个 `.library` product：`CoreDesignEffects`、
  `CoreDesignShaders`、`CoreDesignCharts`。三者均可 `dependencies: ["CoreDesign"]`；
  `CoreDesign` **不得反向依赖**任一。`CoreDesignShaders` 可依赖 `CoreDesignEffects`，反之不可。
- **FR-2** ⚠️ **改写**：`.metal` 的落地形态**由 D-1 spike 的结论决定**，二选一：
  - **路径 α（源码随 target 编译）**：`.metal` 作为 target 源，运行时经
    `ShaderLibrary.bundle(.module)` 查找。**前提是 CI 与消费方都不用原生 `swift build`**。
  - **路径 β（预编译 metallib 作为二进制资源）**：仓库内提交 `default.metallib`，
    以 `.copy(...)` 进 bundle，配一条 `scripts/build-metallib.sh` 与一条校验其与 `.metal`
    源同步的守卫。**绕开构建系统差异**，代价是仓库多一个二进制产物。
  - **一律不得**沿用上游写法 `ShaderLibrary.swSwirl(...)`（查 main bundle，在库里必然失败）。
- **FR-3** `scripts/downstream-probe` 同步扩展。⚠️ **不是**加几行 import 就够：该 probe
  自陈存在理由是「从 **nonisolated 上下文**使用 CoreDesign 的公开值类型……本 probe 是
  唯一能看见该问题的地方」（`scripts/downstream-probe/Package.swift:2-8`）。因此必须
  **新增 nonisolated 上下文的调用点**，覆盖三个新 target 的公开值类型，否则 NFR-4 的
  MainActor 隔离契约在新 target 上无人验证。
- **FR-4** 命名去掉 `SW` 前缀，**用裸名**（与本仓 `Badge` / `Card` / `Sidebar` /
  `.surface(_:)` / `.skeletonShimmer()` 一致）。`Core*` 前缀在本仓专用于度量与 style
  （`CoreSpacing` / `CoreLabelStyle`），不外扩。⇒ `RadarChart`、`Confetti`、`.shake(trigger:)`。

### FR-5 ~ FR-8：API 纪律

- **FR-5** 所有公开类型、`init`、`body` 显式 `public`。
- **FR-6** **Bool 参数走 J-1**：上游的 `showLabels: Bool` / `autoReset: Bool` /
  `isActive: Binding<Bool>` **一律不得照搬**。改语义枚举、或走 `trigger:` 值变化模式、
  或申请豁免并按 `scripts/bool-exemptions-ratchet.sh` 流程抬 `docs/bool-exemptions-baseline.json`
  的 `maxEntries`(32) / `sourceSites`(35)。
- **FR-7** 组件**自带**的 UI 文案（空态提示、Before/After 标签、轴标题默认值）必须是
  `LocalizedStringResource` / `LocalizedStringKey`。
  ⚠️ **边界声明**：**调用方传入的数据文案**（网络图节点名、热力图日期标签、雷达图轴名
  来自调用方模型）**是内容不是 UI 文案**，不强制本地化类型，其类型签名不受
  `ComponentTextParamGuard` 约束。此边界须在扩展该守卫时显式编码，否则会误伤 FR-14 的
  图表数据入参。
- **FR-8** 三个新 target 内**禁止色相字面量**（`.cyan` / `.purple` / `.white.opacity(...)` /
  `Color(red:green:blue:)`）。合法来源仅三个：① 调用方参数；② `TintShapeStyle`；
  ③ CoreDesign 第 3/4 层语义 token。

### FR-9 ~ FR-10：守卫

- **FR-9** 新增 `EffectsColorLiteralGuard`（SwiftSyntax 扫描，与 `BoolParameterScanner` 同形态）
  落地 FR-8。
- **FR-10** 把 `BoolExemptionGuard.coreDesignSources`（`:43`）与
  `AccessibilityStringLiteralGuard`（`:189`）的**单一硬编码扫描根改为多 target 根列表**，
  并保持既有 CoreDesign 判据字面不变（不得因重构放松现有断言）。

### FR-11 ~ FR-13：动效可访问性与能耗

- **FR-11** 每个含位移 / 旋转 / 缩放的效果读 `@Environment(\.accessibilityReduceMotion)`，
  开启时降级为无位移形态。
- **FR-12** Reduce Motion 开启时：
  - `colorEffect` 背景类 → **冻结在某一帧**（保留视觉，去掉运动）。
  - `layerEffect` 内容层类 → **冻结其时间输入，但保留由用户手势/倾斜驱动的空间输入**
    （放大镜跟手是交互不是动效，冻结它会让组件不可用）。
- **FR-13** 装饰性效果层一律 `accessibilityHidden(true)`；承载状态语义的效果
  （如 shake 表示"输入错误"）由**调用方**提供 a11y 通告，文档明写这一分工。

### FR-14 ~ FR-20：图表

- **FR-14** 数据入参用泛型 + `Identifiable`，不绑定具体模型类型。
- **FR-15** `NetworkGraph` 只落布局算法与渲染，**丢弃上游 4973 行 demo 数据**。
- **FR-16** ⚠️ **改写**：预览宿主 `App/` 覆盖范围 = **全部 67 个 API 单位**（与 SC-7 对齐；
  初版 FR-16 只写 4 个图表、SC-7 却写"全部新增项"，两者互斥）。展示屏需登记进
  `App/Sources/ComponentData.swift`。
- **FR-17** 文档：每个 API 单位有 `docs/components/*.md`。
  ⚠️ **索引落点须避开 `readmeIndexReconcilesWithRegistry`**：`ComponentRegistryGuard.swift:591-636`
  要求 `docs/README.md` 的 `## 组件索引` 到 `## 生成预览图` 之间每行第一列都落到
  登记表/墓碑/排除/聚合映射之一。⇒ 新 target 的索引**另起一个位于 `## 生成预览图` 之后的
  小节**，或（若 AD-4 裁定进登记表）正常进主索引。二选一由 AD-4 决定。
- **FR-18** ⚠️ **重写**：署名必须**逐 shader 追到原始作者**，不能只署 ShipSwift。
  上游 `ACKNOWLEDGEMENTS.md` 已标出 7 个二次衍生：Foil / Glitter / IntenseBling /
  ChromaticGlass / PolishedAluminum ← ShaderKit（James Rochabrun, MIT）；StarNest ←
  Pablo Roman Andrioli（Shadertoy，作者声明 MIT）；GlassOrb ← Inferno（Paul Hudson, MIT）。
  本仓 `ACKNOWLEDGEMENTS.md` 须完整转载这些原始许可，并区分"参考算法思路"与
  "较大段落移植"两档。
- **FR-19（新增）** **退化输入契约**。四个图表对以下输入必须有定义好的行为
  （渲染空态 / 忽略该数据点 / 而非 crash 或 NaN），且每条有测试：
  - 空数组；单点数据
  - `RadarChart`：所有轴值相等（归一化除零）、轴数 < 3
  - `RingChart`：total = 0
  - `ActivityHeatmap`：日期区间为空、全零值
  - `NetworkGraph`：零边、所有节点初始位置重合（力导向除零 → NaN）
- **FR-20（新增）** `NetworkGraph` 须声明**规模上限**与超限行为。力导向布局通常是每帧
  O(n²)；文档需给出实测的建议节点上限，超限时的行为（降级为静态布局 / 抛断言）须定义。

## Non-Functional Requirements

- **NFR-1（性能）** 单个 `colorEffect` 背景在 iPhone 15 上满帧；Confetti 默认粒子数下
  不掉帧；`NetworkGraph` 在 FR-20 声明的节点上限内不掉帧。
  ⚠️ **须是可重复的回归闸而非一次性人工抽测**：约定一个基准脚本（简化的 frame-time
  断言即可）随 CI 或至少随 epic 收尾复跑。
- **NFR-2（包体）** `CoreDesignShaders` 的 resource bundle ≤ 2MB。
- **NFR-3（平台）** ⚠️ **改写**：新 target 默认双端（iOS 26 / macOS 26），但**下列四项
  上游即非纯 SwiftUI，须逐项处理**：`OrbitingLogos`（`import SpriteKit`）、
  `DotSphere` / `CharSphere`（`import UIKit`）、`FullScreenButton`（依赖
  `navigationTransition(.zoom)`，iOS-only）。处理方式二选一：重写为跨平台 SwiftUI，
  或 `#if canImport(UIKit)` 隔离并在文档标注平台限制。**不得降低 package 的 macOS 支持。**
- **NFR-4（并发）** 全部过 Swift 6 严格并发 + `.defaultIsolation(MainActor.self)`，
  零 `@unchecked Sendable` 逃逸。由 FR-3 的 probe 扩展验证。
- **NFR-5（隔离性）** ⚠️ **改写**：初版写的"任一新 target 编译失败不得阻断 CoreDesign 的
  构建与测试"**在本仓 CI 形态下不可能成立**——CI SwiftPM 腿跑的是不带 `--target` 的
  `swift build` / `swift test`，SwiftPM 在包根构建全部 target。改为可达成形态：
  **`swift build --target CoreDesign` 与 `swift test --filter CoreDesignTests` 独立可绿**，
  即核心库的正确性不依赖新 target 的编译状态。
- **NFR-6（新增，测试拓扑）** 新 target 的测试**必须能被 CI 真正执行**。
  ⚠️ 两条路都有坑，须在 FR 层选定并同步 CI：
  - 放进现有 `CoreDesignTests` ⇒ 需 `@testable import CoreDesignEffects`，与 NFR-5 张力；
  - 新建 `CoreDesignEffectsTests` 等 ⇒ CI 的 iOS Simulator 腿用
    `xcodebuild test -scheme CoreDesign`（产品级 scheme），新测试 target **不在其中，
    静默不跑**——正是 CLAUDE.md 反复警告的"假绿"。需改 `-scheme CoreDesign-Package`
    或逐 scheme 列出，且该改动本身要验证。
- **NFR-7（新增，能耗与生命周期）** 常驻渲染的效果（`colorEffect` 背景、Confetti、
  ScanningOverlay）必须定义 App 进入**后台**、**低电量模式**、`Reduce Transparency`
  下的行为（暂停渲染 / 降帧 / 不变），并各有一条测试或文档声明。

## Success Criteria

⚠️ **"可用"的定义（SC-1 的判据，机器可查的 AND 条件）**：
① 编译通过；② 过 `EffectsColorLiteralGuard` + Bool 棘轮 + a11y 字面量守卫；
③ 有 `#Preview` 且进 `App/` 画廊；④ 有 `docs/components/*.md`。四条全中才计入。

| # | 指标 | 判据 |
|---|---|---|
| SC-1 | Epic A 落地量 | 39 个 API 单位（35 动效 + 4 图表）中 ≥ 36 项"可用" |
| SC-2 | Epic B 落地量 | 28 个 shader 中，**通过 C-6 许可核验的那部分**全部"可用"（分母由核验结果决定，不预设） |
| SC-3 | CI 全绿 | 四条腿全绿，且 NFR-6 的 scheme 改动经实测确认新测试真的在跑 |
| SC-4 | 核心库零回归 | `CoreDesign` 公开 API 表面 diff 为空；`swift build --target CoreDesign` 独立绿 |
| SC-5 | 颜色纪律 | `EffectsColorLiteralGuard` 零违规 |
| SC-6 | a11y 覆盖 | 含运动的效果 100% 有 Reduce Motion 降级路径，测试可证 |
| SC-7 | Bool 纪律 | Bool 豁免基线净增 ≤ 3 条，每条有书面理由，按棘轮脚本流程抬基线 |
| SC-8 | 退化输入 | FR-19 列举的 9 类退化输入 100% 有测试且不 crash / 不 NaN |
| SC-9 | 许可 | `ACKNOWLEDGEMENTS.md` 覆盖每一个落地的 shader，无来源不明项被落地 |
| SC-10 | 预览宿主 | `scripts/run-preview.sh` 能构建并展示全部已落地 API 单位 |

## Constraints & Assumptions

### 硬约束

- **C-1 Metal 打包的决定性变量是「构建系统」，不只是 bundle 定位。**
  评审阶段已做最小 SwiftPM spike（Swift 6.3 / swift-driver 1.148.6，与 CI 同世代），实测：
  - **原生 `swift build`**（**CI SwiftPM 腿与 `downstream-probe` job 用的就是它**）对 target
    内 `.metal` 报 `warning: found 1 file(s) which are unhandled`，**不产生 metallib**，
    也不合成 `Bundle.module`。声明成 `.process(...)` 资源后，原生构建只做
    `Copying Probe.metal`——**拷贝源码，不编译**。
  - `swift build --build-system swiftbuild` 与 `xcodebuild` 才产出
    `.../default.metallib`。

  ⇒ **连带后果，PRD 必须覆盖**：
  1. `downstream-probe` 是 build-only 且走原生构建系统，**它永远看不到 metallib 有没有**
     ——不能用它验证 US-3 的 metallib 加载。
  2. macOS 上的 `swift test` 无法执行任何 shader 查找 ⇒ shader 相关测试只在 iOS 腿作数。
  3. **D-1 spike 必须先回答"用哪个构建系统"**，并给出 CI 改法（切
     `--build-system swiftbuild`？双系统都跑？还是走 FR-2 路径 β 的预编译 metallib？）。
- **C-2 D-1 spike 的范围必须覆盖参数化，不只是打包。** FR-8 要求每个 shader 的颜色从
  `.metal` 里改成 Swift 侧传入。打包能过不代表任意 uniform 参数化都能过。
  ⇒ spike 至少覆盖：**一个多色参数化 `colorEffect` + 一个需要 layer 输入的 `layerEffect`**。
  否则 Epic B 撞到参数化障碍时 spike 已"通过"，闸门形同虚设。
  ⚠️ 顺带纠正初版一处失实：FR-10 初版写"多数 shader 把颜色写死在 `.metal` 里"——实测
  28 个 wrapper 里 **23 个已在 Swift 侧接 `Color`**，写死的恰是 ShaderKit 那 5 个。
- **C-3 manifest 变更会打到预览宿主。** `App/` 是独立 `xcodegen` 工程，不受
  `swift build` / `swift test` 覆盖，manifest 层报错发生在**依赖解析期**。
  且 `App/project.yml:36` 的 `dependencies: - package: CoreDesign` **未指定 `product:`**，
  默认只链 `CoreDesign` 产品 ⇒ 新 product 需逐条补 `product: CoreDesignEffects` 等。
- **C-4 在 worktree 里跑 `xcodegen generate` 有坑**（见 `App/project.yml` 顶部注释）。
- **C-5 公约裁决 AD-4 是 Epic A 的第一个交付物，不是假设。**
  ⚠️ 初版把"新 target 不进 `component-registry.json`"当作假设 A-1，**该论证已被证伪**：
  - 公约 AD-2（`docs/component-contract.md:1254-1274`）逐字裁定「登记单位是『有 public
    类型的 API 表面』……public 的 `ViewModifier` 类型**照常登记，判定法同样适用**」，
    且**没有按 target 划定作用域**。
  - `SpinningModifier` / `FloatingGlassModifier` / `TelegramGlassButtonModifier` 三个纯视觉件
    都在登记表里，其中 `FloatingGlassModifier` 的 notes 就是「视觉即含义，步骤 3 规定性」
    ——**公约对"没有形态选择的视觉件"已有一段话的现成出口**，初版"把公约当仪式跑"的
    论证不成立。
  - 守卫今天扫不到新 target（`ComponentRegistryGuard.swift:366` 硬编码
    `Sources/CoreDesign`），但公约 **G-7 行已把「加第二个 source target」白纸黑字登记为
    "仍未守住、只是登记了的"逃逸通道** ⇒ 初版方案是在借公约自认的洞省成本。

  ⇒ **本 PRD 的处置**：Epic A 的第一个 issue 是**提交公约裁决 AD-4**，二选一：
  - **AD-4-a（默认走向）**：把登记表作用域**明确钉在 `Sources/CoreDesign`**，同时为三个
    新 target 建立一份**独立的、更轻但显式的"表达性视觉层公约"** + 对应守卫。
    ——不能只钉作用域而不补公约，那会造出一块无守卫的空白地带，与 US-5 意图矛盾。
  - **AD-4-b（fallback）**：按 AD-2 原样执行，public `View` 类型批量以步骤 3 登记
    prescriptive，扫描根改为多 target。
  ⚠️ **诚实的成本重估**：`Transition` 静态成员不是 `View`/`ViewModifier`，扫描器结构上
  看不见；按 `SurfaceModifier` 写法（internal struct + `public extension View`）的 modifier
  按 AD-2 明文排除登记。⇒ 真正会撞登记表的只有 **public View struct**：28 个 shader 视图、
  4 个图表、Confetti / ScanningOverlay / Sphere 等约 8 个，**共约 40 个**——初版
  "28 项 × 判定法"的恐慌数字被高估，而 FR-17 索引联动守卫的成本被低估。
- **C-6（新增）许可核验是 Epic B 的前置闸，与 D-1 spike 并列。**
  上游 `ACKNOWLEDGEMENTS.md` 只标出 7 个 shader 的来源（ShaderKit 5 个 + StarNest +
  GlassOrb，均 MIT）。**其余 21 个零来源标注**，而 Plasma / Voronoi / SimplexNoise /
  Metaballs / Water / FractalClouds / Swirl / InkSmoke / SmokeRing / Starfield /
  NeuroNoise 这类经典 shader 的常见出处 Shadertoy **默认许可是 CC BY-NC-SA**
  （非商用 + 传染性 share-alike），与 MIT 分发的设计系统**不兼容**。
  ⇒ **逐 shader 做来源核验；来源不明或许可不兼容者一律不落地。** SC-2 的分母由核验
  结果决定，不预设。

### 假设

- **A-1** ShipSwift 的算法（力导向布局、confetti 物理、mask reveal 的 `Shape` 数学、
  各 shader 的噪声函数）正确且可借鉴，只需替换其色彩与 API 层。
- **A-2** iOS 26 / macOS 26 下 `ShaderLibrary` / `colorEffect` / `layerEffect` /
  `KeyframeAnimator` / `PhaseAnimator` / `Transition` 协议全部可用，无需可用性回退。
- **A-3** `AXChartDescriptorRepresentable` 属 Accessibility 框架而非 Charts 框架，
  可在不 `import Charts` 的前提下使用。⚠️ **须在 Epic A 早期一次性验证**，避免实现期返工。
  ⚠️ 初版的旧 A-3（"MIT 允许衍生 + 署名，无需额外授权"）**已被 C-6 证伪并删除**。

## Out of Scope

| 项 | 理由 |
|---|---|
| ShipSwift 5 个 Swift Charts 换皮图表（Line / Bar / Area / Donut / Scatter） | 全部 `import Charts`，原生已支持 |
| `SWShimmer` | 已有 `.skeletonShimmer()` |
| `SWShakingIcon` | 被本 PRD 的 `.shake(trigger:)` 完全包含 |
| `SWSearchBar` / `SWTabButton` / `SWStatusBadge` / `SWAlert` / `SWLabel` / `SWLoading` / `SWGradientDivider` / `SWStepper` | 分别与 `SearchField` / `SegmentedControl` / `Badge`+`Tag`+`StateLabel` / `Toast` / `CoreLabelStyle` / `ProgressIndicator` / `Separator` / 原生 `Stepper` 重叠 |
| 全部 `SWModule/*` | App 级功能模块，含 Amplify / StoreKit / AVFoundation / Vision / VolcEngine ASR 外部依赖 |
| `SWOnboardingView` / `SWAddSheet` / `SWWallet` / `SWOrderView` / `SWRootTabView` / `SWVideoPlayer` / `SWScrollingFAQ` / `SWFloatingLabels` / `SWRotatingQuote` / `SWImageThumbnail` / `SWBulletPointText` | App 级脚手架或业务组合件 |
| `SWKPICard` / `SWMarkdownText` | **有独立价值**，但属"UI 组件"轨而非本 PRD 的"表达性视觉层"轨，另开 PRD |
| `SWUtil/*` | 与设计系统无关 |
| 视觉设计的重新定调 | 本 PRD 只补能力，不改 CoreDesign 现有的 HIG 系统色地基 |

## Dependencies

### 内部

- **D-1（Epic B 前置闸）Metal 打包 spike**。范围见 C-1 + C-2：必须回答构建系统选型、
  CI 改法、metallib 定位、多色参数化、layer 输入五项。**失败则 Epic B 整体不启动。**
- **D-2** `CoreDesign` 的语义色 token 与 `Core*` 度量常量。
- **D-3 既有守卫基建**：`BoolParameterScanner`(68KB) / `ComponentTextParamGuard`(40KB) /
  `AccessibilityStringLiteralGuard`(16KB) —— 扩展而非重写。
- **D-4 `scripts/downstream-probe`** —— 按 FR-3 扩展 nonisolated 调用点。
- **D-5 `App/CoreDesignPreview`** —— `project.yml` 逐 product 声明（C-3）+
  `App/Sources/ComponentData.swift`（32.8K 画廊 registry）+ `Previews.swift`。
  ⚠️ **`ComponentData.swift` 是并行冲突面**：`semi-mobile-components` epic 已把它与
  `Previews.swift` 列为冲突面并专设 Phase 0/3 串行。本 PRD 的并发 issue 必须同样串行化
  对它的写入。

### 连带影响清单（`Package.swift` 新增 target/product 会打到的地方）

⚠️ 初版只列了 `downstream-probe` 与 `App/project.yml`，以下为补全项：

| # | 落点 | 影响 |
|---|---|---|
| 1 | `AgentGuideSyncGuard`（`Tests/CoreDesignTests/`） | CLAUDE.md 架构节要写新 target，AGENTS.md 不同步即红（先例：native-refresh PRD:225） |
| 2 | `App/project.yml:36` | 未指定 `product:`，需逐条补 |
| 3 | `App/Sources/ComponentData.swift` + `Previews.swift` | 画廊 registry，并行冲突面 |
| 4 | `scripts/run-snapshots.sh` + `App/Tests/SnapshotTests.swift` | 渲染**所有链入模块的 `#Preview`**；Metal / confetti 的 preview 产出**非确定 PNG**，且默认模式会 `rm -rf docs/snapshots` 重生成 ⇒ 必须定排除策略 |
| 5 | `ComponentRegistryGuard.swift:449-451` | 硬编码 `coredesign == 47` / `storyui == 25`，AD-4-b 走向下需同步 |
| 6 | `docs/bool-exemptions-baseline.json`（`maxEntries` 32 / `sourceSites` 35）+ `scripts/bool-exemptions-ratchet.sh` | SC-7 抬基线须走该流程 |
| 7 | `ColorAssetGuardTests` | 若新 target 带自己的 `Resources`，需明确是否纳入 |
| 8 | `docs/README.md` 索引 | 见 FR-17，受 `readmeIndexReconcilesWithRegistry` 约束 |
| 9 | `ReachableTypeRegistryGuard` / `docs/reachable-type-registry.json` | 新增可达 public 类型时的登记义务 |

### 外部

- **D-6** ShipSwift 仓库（MIT）作为算法来源。已本地 clone 快照；以快照为准，不追踪上游变更。
- **D-7** ShipSwift 的上游来源（ShaderKit / Inferno / Shadertoy 各作者）—— C-6 的核验对象。
- **D-8** SwiftPM / swiftbuild / xcodebuild 三种构建系统对 `.metal` 的差异行为 —— D-1 的验证对象。
- **D-9** Swift 6.3 工具链 + swift-syntax 603.0.2。

### Epic 分解草案（供 ccpm 参考，非最终）

**Epic A「非 Metal」**（39 个 API 单位）

```
A1  公约裁决 AD-4（登记表作用域）        ← 无依赖，阻塞 A2 之后全部
A2  三 target 骨架 + Package.swift + CI  ← 依赖 A1（决定守卫形态）
A3  守卫扩展（Bool / a11y / 新增颜色守卫）← 依赖 A2
A4  微交互 8 个                          ← 依赖 A3
A5  转场 16 个                           ← 依赖 A3
A6  庆祝/处理中 4 个（Confetti/Scanning/Glow/Light）← 依赖 A3
A7  文本与展示 4 个（Typewriter/MeshGradient/BeforeAfter/ParticleTransition）← 依赖 A3
A8  跨平台改造 3 个（OrbitingLogos/DotSphere/CharSphere）+ FullScreenButton ← 依赖 A3，NFR-3
A9  四个图表 + 退化输入契约（FR-19/FR-20）← 依赖 A3
A10 预览宿主 + 快照排除策略 + 文档 + 署名  ← 依赖全部；ComponentData.swift 串行
```

**Epic B「Metal」**（28 个 shader，前置 = D-1 spike ∧ C-6 许可核验）

```
B1  Metal 打包 spike（构建系统 + 参数化）  ← 前置闸
B2  逐 shader 许可来源核验                 ← 前置闸，可与 B1 并行
B3  17 个 colorEffect 背景（分批）          ← 依赖 B1+B2
B4  11 个 layerEffect 内容层效果            ← 依赖 B1+B2
B5  署名 + 文档 + 预览宿主收尾              ← 依赖 B3+B4
```

⚠️ **密度校正**：本仓历史 epic 为 5–13 task、约 1 交付物/task。A4（8 个）与 A5（16 个）
仍偏重，ccpm 分解阶段应按需再拆；B3/B4 明确标注"分批"。

---

## 评审响应台账（第 1 轮）

| 评审项 | 处置 |
|---|---|
| superpowers-reviewer C-1（A-1 与 AD-2 冲突） | **接受**。删除假设 A-1，改为 C-5 + Epic A 首个 issue「公约裁决 AD-4」，给出 a/b 两个走向与重估后的成本 |
| C-2（US-5 四道守卫有一道结构上不可能扩） | **接受**。US-5 改为逐守卫表格，TextParam 挂 AD-4、TouchTarget 移出验收项 |
| C-3（NFR-5 不成立） | **接受**。改为 `swift build --target CoreDesign` 独立绿；新增 NFR-6 定测试拓扑与 CI scheme |
| C-4（`swift build` 不编译 `.metal`） | **接受**。改写 C-1 加构建系统维度，FR-2 给出 α/β 两条路径，US-3 AC 改为双构建路径可证 |
| I-1（README 索引触发守卫） | **接受**，落 FR-17 |
| I-2（连带影响清单不全） | **接受**，落《连带影响清单》9 项 |
| I-3（许可链断裂） | **接受**。旧 A-3 删除，新增 C-6 许可核验闸 + FR-18 重写 + SC-9 |
| I-4（计数错误） | **接受**。统一"API 单位"分母；11 个 layerEffect 单列；SpriteKit/UIKit 三项落 NFR-3；ChangeEffect 改 8 个 |
| I-5（拆两个 PRD） | **部分接受**。拆为**两个独立 epic** 而非两个 PRD——理由见 Executive Summary（三项地基决策为两 epic 共享）。"可独立下线"与"密度可控"两个诉求已由 epic 拆分满足 |
| I-6（三 target 优于两 target） | **接受**，落 Executive Summary + FR-1 |
| I-7（FR-16 与 SC-7 互斥） | **接受**，FR-16 扩到全部 67 项 |
| Suggestion（storyui 25 / skeletonShimmer / Confetti TimelineView / FR-12 layerEffect） | **全部接受**，逐处改正 |
| Preference（命名 `Core*` vs 裸名） | **选裸名**，落 FR-4，理由=与本仓 `Badge`/`Card`/`.surface(_:)` 一致；`Core*` 在本仓专用于度量与 style。⚠️ 留给用户裁量 |
| Copilot 🔴1（registry 深耦合） | 与 C-1/C-2 同题，同处置 |
| Copilot 🔴2（probe 真实用途） | **接受**，FR-3 重写 |
| Copilot 🔴3（图表退化数据） | **接受**，新增 FR-19 + SC-8 |
| Copilot 🟡4（spike 范围不足） | **接受**，落 C-2 |
| Copilot 🟡5（后台/低电量） | **接受**，新增 NFR-7 |
| Copilot 🟡6（SC-1"可用"未定义） | **接受**，Success Criteria 开头定义四条 AND |
| Copilot 🟡8（NetworkGraph 规模） | **接受**，新增 FR-20 |
| Copilot 🟡9（性能非回归闸） | **接受**，NFR-1 加可重复基准要求 |
| Copilot 🟡10（数据文案 vs UI 文案边界） | **接受**，FR-7 加边界声明 |
| Copilot 🟢（AXChartDescriptor 早验 / shader 按复杂度分级 / 署名分档） | **接受**，分别落 A-3、B3-B4"分批"、FR-18 |
