---
name: shipswift-effects
status: backlog
created: 2026-09-02T23:42:57Z
updated: 2026-09-02T23:42:57Z
progress: 0%
prd: .claude/prds/shipswift-harvest.md
github: (will be set on sync)
---

# Epic: shipswift-effects（效果与图表）

> `shipswift-harvest` PRD 拆出的**第 2 个** epic（共 3 个）。
> **前置：`shipswift-foundation` 的 A0-1 ~ A0-4 全部完成。**
> 姊妹 epic：`shipswift-foundation`（地基与两闸）、`shipswift-shaders`（Metal）。

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
（当前 `maxEntries` 32 / `sourceSites` 35）。**净增 ≤ 3 条，每条有书面理由。**

### AD-D 颜色只有三个合法来源

① 调用方参数；② `TintShapeStyle`（`.tint`）；③ CoreDesign 第 3/4 层语义 token。
由 `EffectsColorLiteralGuard`（A0-3 建）机器判。

### AD-E 三个非纯 SwiftUI 件必须处理，不得降低 macOS 支持

- `OrbitingLogos` — 上游 `import SpriteKit`
- `DotSphere` / `CharSphere` — 上游 `import UIKit`
- `FullScreenButton` — 依赖 `navigationTransition(.zoom)`，iOS-only

处理二选一：重写为跨平台 SwiftUI，或 `#if canImport(UIKit)` 隔离 + 文档标注平台限制。

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
- Confetti 的 burst 结束后驱动它的 `TimelineView` 须停止调度或被移除
  （上游用 `TimelineView(.animation)`，不是 Timer / DisplayLink）。

### CoreDesignCharts

- 数据入参泛型 + `Identifiable`，不绑定具体模型类型。
- 不引入 `import Charts`（这四个本来就是自绘的）。
- accessibility：`AXChartDescriptorRepresentable` 或逐数据点
  `accessibilityElement` + `accessibilityValue`。
  ⚠️ `AXChartDescriptorRepresentable` 属 Accessibility 框架而非 Charts 框架，
  **须在本 epic 早期一次性验证**，避免实现期返工。
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
A-3  庆祝与处理中 4 个 + 后台/低电量可注入 environment ← 同上
A-4  文本与展示 4 个                                  ← 同上
A-5  跨平台改造 4 个（AD-E）                          ← 同上
A-6  四个图表 + 退化输入契约（≥15 条测试）+ 规模上限    ← 同上
A-7  预览宿主 + 快照排除策略 + 文档 + 署名收尾          ← 依赖全部；ComponentData 串行
```

7 个 task，落在本仓历史区间（5–13）内。
⚠️ **A-1（8 个）与 A-2（16 种）仍偏重**，decompose 阶段须按上面标注的分组再拆。

⚠️ **登记表侧改动归 A-6**：若 AD-4 裁定 `CoreDesignCharts` 走 b（进登记表），则
`ComponentRegistryGuard` 扫描根多 target 化 + 4 条登记 + `:449` 的 `47` 改 `51`
+ `readmeIndexReconcilesWithRegistry` 联动**全部在 A-6 内完成**，不留在 A0-3。

## Dependencies

### 上游
- `shipswift-foundation` 的 **A0-1 ~ A0-4**（AD-4 结论 / 两 target 骨架 + CI scheme /
  四条守卫 / probe）
- **不依赖** A0-5（Metal spike）与 A0-6（许可闸）

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
- [ ] `EffectsColorLiteralGuard` 零违规
- [ ] 含运动的效果 **100%** 有 Reduce Motion 降级路径，测试可证
- [ ] Reduce Transparency 下，依赖半透明/折射的效果降级为不透明形态
- [ ] Bool 豁免基线净增 ≤ 3 条，每条有书面理由，按棘轮脚本流程抬基线
- [ ] FR-19 的 9 类退化输入 100% 有测试（**实际 ≥ 15 条**），不 crash / 不 NaN
- [ ] `scripts/run-preview.sh` 能构建并展示全部已落地 API 单位
- [ ] 快照排除策略落地，`run-snapshots.sh` 不因非确定 PNG 而漂移

## Estimated Effort

大。40 个 API 单位是本 PRD 的主体交付。单个效果的 SwiftUI 代码不难，成本集中在
① 逐个过四条守卫；② Reduce Motion / Reduce Transparency / 后台 / 低电量四种降级路径；
③ 四个图表的退化输入契约（≥15 条测试）；④ 画廊与快照的串行化与排除策略。
