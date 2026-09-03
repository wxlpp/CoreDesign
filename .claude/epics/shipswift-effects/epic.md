---
name: shipswift-effects
status: in-progress
created: 2026-09-02T23:42:57Z
updated: 2026-09-03T23:19:50Z
progress: 43%
prd: .claude/prds/shipswift-harvest.md
github: https://github.com/wxlpp/CoreDesign/issues/242
---

# Epic: shipswift-effects（效果与图表）

> `shipswift-harvest` PRD 拆出的**第 2 个** epic（共 3 个）。
> **前置：`shipswift-foundation` 的 A0-1 ~ A0-4 全部完成。**
> 姊妹 epic：`shipswift-foundation`（地基与两闸）、`shipswift-shaders`（Metal）。
> **修订**：第 1 轮 structure 评审判 BLOCK，本版逐条处置（台账在 `shipswift-foundation/epic.md` 文末）。

## Overview

按 CoreDesign 的公约与色彩地基**重新实现** ShipSwift 的 40 个 API 单位：
**36 个纯 SwiftUI 动效**（落 `CoreDesignEffects`）+ **4 个 Swift Charts 画不出来的图表**
（落 `CoreDesignCharts`）。

⚠️ **本 epic 与 Metal 完全无关**，不依赖 `shipswift-foundation` 的两闸结论。
D-1 / C-6 任一失败都不影响本 epic 交付。

### 40 个 API 单位的构成

| 组 | 数量 | 内容 |
|---|---|---|
| 微交互 modifier | 8 | shake / jump / spin / ping / spray / rise / haptic / shine |
| 转场 | 16 | blur / flip / rotate3D / swoosh / boing / skid / move / iris / wipe / blinds / clock / flicker / filmExposure / snapshot / glare / dissolve |
| 庆祝与处理中 | 4 | Confetti / ScanningOverlay / GlowSweep / LightSweep |
| 文本与展示 | 4 | TypewriterText / AnimatedMeshGradient / BeforeAfterSlider / ParticleTransition |
| 跨平台改造 | 4 | OrbitingLogos / DotSphere / CharSphere / FullScreenButton |
| 图表 | 4 | RadarChart / RingChart / ActivityHeatmap / NetworkGraph |

## Architecture Decisions

### AD-A 上游是配方，不是可消费代码

ShipSwift 源码全部 `internal`、硬编码色、零 accessibility、零 `controlSize` / Dynamic Type
适配、零测试。**只借算法**（力导向布局、confetti 物理、16 个 mask reveal 的 `Shape` 数学、
`KeyframeAnimator` 相位序列），API 层与色彩层全部重写。

### AD-B 命名用裸名

与本仓 `Badge` / `Card` / `Sidebar` / `.surface(_:)` / `.skeletonShimmer()` 一致。
`Core*` 前缀在本仓专用于度量与 style（`CoreSpacing` / `CoreLabelStyle`），不外扩。
⇒ `RadarChart`、`Confetti`、`.shake(trigger:)`。

### AD-C Bool 参数一律不照搬

上游的 `showLabels: Bool` / `autoReset: Bool` / `isActive: Binding<Bool>` 全部撞 J-1。
改语义枚举、或走 `trigger:` 值变化模式、或按 `scripts/bool-exemptions-ratchet.sh` 抬基线
（当前 `maxEntries` 32 / `sourceSites` 35）。
⚠️ **PRD 的「净增 ≤ 3」是三个 target 的全局预算**，本 epic 分得 **≤ 2**、
`shipswift-shaders` 分得 **≤ 1**。每条有书面理由。

### AD-D 颜色只有三个合法来源

① 调用方参数；② `TintShapeStyle`（`.tint`）；③ CoreDesign 第 3/4 层语义 token。
由 `EffectsColorLiteralGuard`（A0-3 建）机器判。

### AD-E 三个非纯 SwiftUI 件必须处理，不得降低 macOS 支持

- `OrbitingLogos` — 上游 `import SpriteKit`
- `DotSphere` / `CharSphere` — 上游 `import UIKit`
- `FullScreenButton` — 依赖 `navigationTransition(.zoom)`，iOS-only

处理二选一：重写为跨平台 SwiftUI，或 `#if canImport(UIKit)` 隔离 + 文档标注平台限制。
⚠️ **"文档标注平台限制"须进 A-5 的验收项**（第 2 轮评审 S-2），否则四件的平台限制
只存在于代码的 `#if` 里，调用方看不到。

### AD-F 图表的退化输入是一等契约，不是边角

力导向布局节点重合会 NaN、雷达图轴值全等会除零——这是图表类组件最常见的 crash 源。
9 类退化输入各有定义好的行为（渲染空态 / 忽略该点），**实际测试条数 ≥ 15**
（"空数组 / 单点"两类对四个图表各要一条）。

⚠️ `NetworkGraph` 超出规模上限时**固定为「截断 + 降级静态布局 + 文档标注」**，
**不得** `precondition` / `fatalError` —— 库代码对数据规模抛断言就是让宿主 App crash。

## Technical Approach

### CoreDesignEffects

- 微交互与转场以 `View` 扩展 modifier 暴露（内部 struct + `public extension View`，
  与本仓 `SurfaceModifier` 同形态）。
- 每个含位移/旋转/缩放的效果读 `@Environment(\.accessibilityReduceMotion)`，
  开启时降级为无位移形态。
- 常驻渲染件（Confetti / ScanningOverlay）的**后台**与**低电量**行为必须**可测**：
  `ProcessInfo.isLowPowerModeEnabled` 与 `scenePhase` 在测试里不可直接切换 ⇒ 做成
  **可注入的 `EnvironmentValues`**（默认从系统读），测试注入伪值断言渲染行为。
  ⚠️ 不接受"或文档声明"——那会让这条退化成文档要求。
  ⚠️ **这两个键必须 `public`**（第 2 轮评审 I-3）：`shipswift-shaders` 的 17 个
  `colorEffect` 要 `import CoreDesignEffects` 复用它们，而 `@Entry` 默认 internal
  ⇒ 不显式 `public`，B-2 用不了，跨 epic 契约断掉。
- Confetti 的 burst 结束后驱动它的 `TimelineView` 须停止调度或被移除
  （上游用 `TimelineView(.animation)`，不是 Timer / DisplayLink）。
- **FR-13 的 a11y 分工必须落到代码与文档**（评审 I-6，初版三个 epic 都没接）：
  纯装饰效果层一律 `accessibilityHidden(true)`；**承载状态语义的效果**（如 `.shake` 表示
  "输入错误"）**由调用方**提供 a11y 通告——每个这类 modifier 的 `docs/components/*.md`
  必须写明这一分工，否则调用方会以为组件自己会播报。

### CoreDesignCharts

- 数据入参泛型 + `Identifiable`，不绑定具体模型类型。
- 不引入 `import Charts`（这四个本来就是自绘的）。
- accessibility：`AXChartDescriptorRepresentable` 或逐数据点
  `accessibilityElement` + `accessibilityValue`。
  ⚠️ `AXChartDescriptorRepresentable` 属 Accessibility 框架而非 Charts 框架。
  **钉为 A-6 的第一个 checkpoint**（评审 Suggestion）：在写任何图表代码前先一次性验证
  它能在不 `import Charts` 的前提下用，避免四个图表都写完才发现要返工。
- `NetworkGraph` 丢弃上游 4973 行 demo 数据（`SWNetworkGraphData.swift`），只落布局与渲染。

### 文本纪律

组件**自带**的 UI 文案（空态提示、Before/After 标签、轴标题默认值）必须是
`LocalizedStringResource` / `LocalizedStringKey`，由 `ChromeTextLiteralGuard`（A0-3 建）判。
⚠️ **调用方传入的数据文案**（网络图节点名、热力图日期标签、雷达图轴名来自调用方模型）
**是内容不是 UI 文案**，不强制本地化类型。

## Implementation Strategy

A-1 ~ A-6 之间**无依赖，可六路并发**；A-7 依赖全部。
⚠️ **`App/Sources/ComponentData.swift`（32.8K 画廊 registry）是并行冲突面**——
`semi-mobile-components` epic 已把它与 `Previews.swift` 列为冲突面并专设串行阶段。
本 epic 对它的写入**必须串行化**（收在 A-7，或各 task 只产出片段由 A-7 合并）。

## Task Breakdown Preview

```
A-1  微交互 8 个                                     ← 依赖 A0-1~A0-4
A-2  转场 16 种（按 mask reveal / 3D / 弹性三组分批）  ← 同上
A-3  庆祝与处理中 4 个 + 后台/低电量可注入 environment（须 public，Shaders 复用）← 同上
     · 可选：若 Shaders 的 B-2 先到，NFR-1 性能 harness 在此落地而非 A-7
A-4  文本与展示 4 个                                  ← 同上
A-5  跨平台改造 4 个（AD-E）                          ← 同上
A-6  四个图表 + 退化输入契约（≥15 条测试）+ 规模上限    ← 同上
A-7  收尾（依赖全部；ComponentData.swift 串行）：
     · 预览宿主 + 快照排除策略（run-snapshots.sh 会渲染所有 #Preview，Confetti /
       ParticleTransition 产出非确定 PNG）
     · **性能基准脚本**（NFR-1，一次性基建，Shaders 的 B-4 复用同一脚本）
       ⚠️ **若 `shipswift-shaders` 的 B-2 先于本 task 完成，harness 应提前到 A-3 落地**
       （Confetti 处），避免 17 个 colorEffect 全落完才第一次跑性能闸——该可选项
       在 `shipswift-shaders` 也写了，两边须同步（第 3 轮评审 Suggestion 1）
     · **probe 补 Effects/Charts 全部公开值类型的 nonisolated 调用点**（A0-4 只做接线）
     · **`ACKNOWLEDGEMENTS.md` 追加 ShipSwift 条目**（区分"参考思路"/"较大段落移植"）
       ⚠️ **文件骨架由 A0-6 建**，本 task 不新建（第 2 轮评审 I-4 已把骨架提前到许可裁定处）
     · **`docs/README.md` 索引**（落点按 A0-1 的 AD-4 裁决）+ `docs/components/*.md`
     · **`docs/reachable-type-registry.json` 登记**新增可达类型（图表数据模型的深度 ≥1
       文本参数正是它的定义域）
```

7 个 task，落在本仓历史区间（5–13）内。
⚠️ **A-1（8 个）与 A-2（16 种）仍偏重**，decompose 阶段须按上面标注的分组再拆。

⚠️ **登记表侧改动归 A-6**：**AD-4 已裁 `CoreDesignCharts` 走 b**（进登记表），因此
`ComponentRegistryGuard` 扫描根多 target 化 + 4 条登记 + `:449` 的 `47` 改 `51`
+ `readmeIndexReconcilesWithRegistry` 联动**全部在 A-6 内完成**，不留在 A0-3。
⚠️ **同一处还要接 `ComponentTextParamGuard`**（评审 I-8）：4 个图表进登记表后，
它们的 `textParams`（轴标题默认值属 UI 文案）会改变
`ComponentTextParamGuard.swift:236-241` 硬断言的 `== 31`；且 **FR-7 的边界
「调用方传入的数据文案是内容不是 UI 文案」必须在扩展该守卫时显式编码**，
否则会误伤 `NetworkGraph` 节点名 / `ActivityHeatmap` 日期标签这类数据入参的类型签名。

## Dependencies

### 上游
- `shipswift-foundation` 的 **A0-1 ~ A0-4**（AD-4 结论 / 两 target 骨架 + CI scheme /
  四条守卫 / probe 接线）
- **不依赖** A0-5（Metal spike）与 A0-6（许可闸）⇒ 两闸任一失败都不影响本 epic 交付

### 下游（本 epic 阻塞谁）
- `shipswift-shaders` 对本 epic 有**两条真实依赖**（评审 C-3，初版漏了）：
  - **A-3** —— NFR-7 的可注入 `EnvironmentValues`（`isLowPowerModeEnabled` / `scenePhase`）
    落在 `CoreDesignEffects`，由 Shaders `import` 复用（这正是 FR-1 允许 Shaders→Effects
    单向依赖的用途）；B-2 的 17 个 `colorEffect` 依赖它
  - **A-7** —— `App/Sources/ComponentData.swift` 的串行写入窗口；B-4 同样要写这个文件，
    跨 epic 的串行由本 epic 的 A-7 定义窗口

### 内部
- CoreDesign 第 3/4 层语义色 token 与 `Core*` 度量常量
- `App/CoreDesignPreview`（`project.yml` + `ComponentData.swift` + `Previews.swift`）
- `scripts/run-snapshots.sh` + `App/Tests/SnapshotTests.swift` —— ⚠️ 会渲染**所有链入模块的
  `#Preview`**，Confetti / ParticleTransition 等产出**非确定 PNG**，且默认模式会
  `rm -rf docs/snapshots` 重生成 ⇒ **必须定排除策略**（A-7）

## Success Criteria (Technical)

"可用"的定义（四条 AND）：① 编译通过；② 过 `EffectsColorLiteralGuard` + Bool 棘轮
+ a11y 字面量守卫；③ 有 `#Preview` 且进 `App/` 画廊；④ 有 `docs/components/*.md`。

- [ ] 40 个 API 单位中 **≥ 37** 项"可用"
- [ ] CI 四条腿全绿；`CoreDesign` 公开 API 表面 diff 为空
      （工具同 A0-2 所钉：`swift-api-digester` 或 symbol dump diff）
- [ ] `EffectsColorLiteralGuard` 零违规
- [ ] 含运动的效果 **100%** 有 Reduce Motion 降级路径，测试可证
- [ ] Reduce Transparency 下，依赖半透明/折射的效果降级为不透明形态
- [ ] Bool 豁免基线净增 **≤ 2 条**（⚠️ PRD 的 ≤3 是**三个 target 的全局预算**，
      本 epic 分得 2、`shipswift-shaders` 分得 1；评审 Suggestion），每条有书面理由，
      按 `scripts/bool-exemptions-ratchet.sh` 流程抬基线
- [ ] FR-19 的 9 类退化输入 100% 有测试（**实际 ≥ 15 条**），不 crash / 不 NaN
- [ ] **FR-20 超限输入有测试**（第 2 轮评审 I-9，与 FR-19 同一 crash 类别）：
      `NetworkGraph` 超过声明节点上限时**截断 + 降级静态布局**，不 crash / 不 NaN
- [ ] **NFR-7 后台与低电量**（第 2 轮评审 I-3，此前只在技术路线、SC 缺席）：
      Confetti / ScanningOverlay 的行为经**注入伪值测试**可证；
      `isLowPowerModeEnabled` / `scenePhase` 两个可注入键为 **`public`**（Shaders 复用）
- [ ] `scripts/run-preview.sh` 能构建并展示全部已落地 API 单位
- [ ] 快照排除策略落地，`run-snapshots.sh` 不因非确定 PNG 而漂移
- [ ] **NFR-1 性能基准闸**：基准脚本落地且可重复跑；Confetti 默认粒子数不掉帧、
      `NetworkGraph` 在 FR-20 声明的节点上限内不掉帧，**均由脚本断言而非人工抽测**。
      ⚠️ **须钉运行环境**（第 2 轮评审 I-5）：PRD NFR-1 钉的是"iPhone 15 满帧"，
      而 CI 只有 macOS runner 与 iOS Simulator——**Simulator 上的 GPU frame-time 无意义**，
      在 CI 上绿不等于 NFR-1 过。⇒ **脚本须在真机（iPhone 15 或钉死的替代机型）执行，
      至少随 epic 收尾跑一次并留证**；CI 上的数值只作趋势参考，不作验收依据。
- [ ] **NFR-5② 沿用**（评审 Suggestion，Epic A 加测试时最容易破坏它）：
      `swift package describe … CoreDesignTests … target_dependencies` 仍恰为 `["CoreDesign"]`
- [ ] **probe 覆盖 Effects / Charts 的 40 个 API 单位所对应的全部类型**（实质调用点，非仅 import）
      ⚠️ **分流规则见 `EffectsNonisolatedUsage.swift` 文件头**（#260 终审 Important-2）：**值类型 / 配置类型 / 数据入参**进 `*NonisolatedUsage.swift`；**View / modifier / style 类**进 `PublicVisibility.swift`（`@MainActor`）——本包开了 `.defaultIsolation(MainActor.self)`，View 的 `init` 与 modifier 函数**天然是 MainActor 隔离的**，从 `nonisolated func` 里构造必然编译失败。「按 API 单位清单点名」= **每个单位在这两处之一必有引用**，不是全部塞进 nonisolated 文件。⇒ NFR-4 的 MainActor 隔离契约在这两个 target 上真的被验证。
      ⚠️ 措辞刻意不写"全部**公开**值类型"（第 2 轮评审 S-1）——那是自指的：漏写 `public`
      的类型压根不算"公开"，probe 自然不覆盖它，FR-5 就没人查。**按 API 单位清单点名**，
      漏 `public` 会在 probe 编译期直接炸出来
- [ ] **`ACKNOWLEDGEMENTS.md` 含 ShipSwift 条目**（骨架由 A0-6 建，本 epic 追加自己的条目）
- [ ] **`docs/reachable-type-registry.json`** 已登记新增可达类型。
      ⚠️ **不写"`ReachableTypeRegistryGuard` 绿"——那对新 target 是空真**（第 2 轮评审 I-8）：
      实测该守卫只查 schema / 与登记表不相交 / 参数名唯一 / 全 C 四条，**不扫源码**；
      深度扫描在 `ComponentExtensionPointGuard.swift:20` 走
      `ComponentRegistryGuard.coreDesignSources` = `Sources/CoreDesign`
      ⇒ Charts 数据模型少登记一条，守卫照样绿。**处置**：A-6 为了 `== 31` 那条本来就要
      扩 `ComponentJudgeSources.scan` 的根，**顺带让本条引用扩根后的扫描结果**；
      若最终不扩根，则诚实写明"登记完整性靠人工 + PR 评审，守卫只查 schema"
- [ ] **FR-13 分工**：装饰层 100% `accessibilityHidden(true)`；承载状态语义的 modifier
      在文档中写明"a11y 通告由调用方提供"。
      ⚠️ **验证机制二选一**（第 2 轮评审 S-8）：每个效果一条 a11y 断言测试，
      **或**明确承认这条是评审项而非机器判据——不得留在"看起来可查、实际没人查"的状态
- [ ] **US-1 叠加互不干扰**：同一 trigger 驱动 ≥3 个微交互时行为可预期，有测试
- [ ] **US-4 图表 a11y**：4 个图表各有 accessibility 表示，有测试
- [ ] **AD-E 四件的平台限制已写进 `docs/components/*.md`**（第 3 轮评审 Suggestion 3
      ——此前只写在 AD-E 里，SC 是扁平的、decompose 未必会把 AD 的话提成验收项）
- [ ] **`BeforeAfterSlider` 的触控目标测试**在 `CoreDesignEffectsTests` 内同形态实现
      （⚠️ **不得**加进 `TouchTargetTests`——那会让 `CoreDesignTests` 依赖新 target，
      判红 NFR-5②，评审 I-4）

## Estimated Effort

大。40 个 API 单位是本 PRD 的主体交付。单个效果的 SwiftUI 代码不难，成本集中在
① 逐个过四条守卫；② Reduce Motion / Reduce Transparency / 后台 / 低电量四种降级路径；
③ 四个图表的退化输入契约（≥15 条测试）；④ 画廊与快照的串行化与排除策略。
