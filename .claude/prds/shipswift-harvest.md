---
name: shipswift-harvest
description: 从 ShipSwift(MIT) 收割 46 个 CoreDesign 真空缺的视觉能力——14 个纯 SwiftUI 动画、28 个 Metal shader 背景、4 个 Swift Charts 画不出来的图表——落成两个新 target CoreDesignEffects / CoreDesignCharts
status: backlog
created: 2026-09-02T22:50:16Z
---

# PRD：ShipSwift 组件收割

## Executive Summary

[ShipSwift](https://github.com/signerlabs/ShipSwift)（MIT，SignerLabs）是一个面向 LLM 的
SwiftUI「配方库」，含 30 个动画、10 个图表、19 个 UI 组件、7 个 App 级模块。本 PRD 从中
**只取 CoreDesign 真空缺、且属于设计系统职责范围**的 46 项视觉能力，按 CoreDesign 的
API 公约与色彩地基**重新实现**（不是拷贝文件），落成**两个与核心库解耦的新 target**：

| 新 target | 内容 | 数量 |
|---|---|---|
| `CoreDesignEffects` | 纯 SwiftUI 动画 + Metal shader 程序化背景 | 14 + 28 |
| `CoreDesignCharts` | Swift Charts 原生画不出来的图表 | 4 |

现有 `CoreDesign` target **不改动**（除 `Package.swift` 增加 target 声明外）。

**本 PRD 的核心判断**：ShipSwift 的价值是**点子与算法**，不是可直接消费的代码。它的源码
全部 `internal`、硬编码色（`.cyan` / `.white.opacity(0.18)` / `.gray`）、零 accessibility、
零 `controlSize` / Dynamic Type 适配、零测试。CoreDesign 有四层色彩系统、1410 行 API 公约、
72 条组件登记表、a11y 豁免台账、以及 ~380KB 的自动化守卫测试。**两者不在一个质量层级上，
"落进来"只能意味着按 CoreDesign 的地基重写，工作量的大头不在 SwiftUI 代码而在过守卫。**

## Problem Statement

### 现状

CoreDesign `0.4.0` 已覆盖 72 条组件（按钮、表单、列表、导航、反馈、骨架屏……），视觉地基
在 `0.3.0` 从 GitHub Primer 换成 Apple HIG、第 3 层大多数 token 改指系统语义色。**这是一个
刻意克制的、以"系统原生观感"为纲的设计系统。**

但它有一整块系统性空白：**表达性视觉层（expressive visual layer）**。

- **微交互为零**：`Modifier/` 目录下 9 个 modifier 里只有 `SpinningModifier` 一个是动效。
  `PinCode` 输错、`Form` 校验失败、`AsyncButton` 成功——全部没有任何动效反馈可用。
- **转场为零**：没有任何 `Transition` 实现。调用方只能用 SwiftUI 内建的 `.slide` / `.opacity`。
- **庆祝/处理中反馈为零**：没有 confetti、没有扫描/分析中的视觉隐喻。
- **程序化背景为零**：`Resources.xcassets` 只有 color set，没有任何可动的背景层。
- **图表为零**：CoreDesign 完全没有图表。Swift Charts 覆盖 line / bar / area / point /
  sector，但**雷达图、活动环、贡献热力图、力导向网络图这四类原生画不出来**。

### 为什么现在做

1. **下游正在自己造轮子**。`docs/component-registry.json` 里 `storyui` 那 30 条
   （`AgentMessageList` / `StreamingIndicator` / `SuggestionStream` / `WritingStatusBar`…）
   说明 CoreDesign 已有真实下游，而那些 agent / 流式 UI 场景正是最需要微交互与动效的地方。
2. **ShipSwift 是 MIT**，可合法 vendored + 署名，省掉从零推导算法（力导向布局、confetti
   物理、16 个 mask reveal transition 的 `Shape` 数学）的时间。
3. **Metal shader 打包一次通，后续无限复用**。这道技术闸只需要过一次。

### 不解决这个问题的代价

CoreDesign 停留在「能做出正确的界面，做不出有记忆点的界面」。表达性视觉层缺失时，
每个下游 App 各自实现一套 confetti / 一套 shake，观感不一致，且全部绕过设计系统的
色彩与 a11y 约束。

## User Stories

### US-1：下游 App 开发者需要输入校验的动效反馈

**作为** 使用 CoreDesign 的 App 开发者
**我需要** 在密码输错时让输入框抖动、在点赞时喷出爱心粒子
**以便** 不用为每个 App 手写一遍 `KeyframeAnimator`

**验收标准**
- [ ] `import CoreDesignEffects` 后可写 `PinCode(...).coreShake(trigger: failedAttempts)`
- [ ] 7 个微交互 modifier（shake / jump / spin / ping / spray / rise / shine）全部可用
- [ ] 每个 modifier 都可叠加，同一 trigger 驱动多个效果时互不干扰
- [ ] 所有 modifier 遵守 `accessibilityReduceMotion`——开启时降级为无位移的静态或淡入淡出

### US-2：下游 App 开发者需要庆祝时刻

**作为** 做订阅 / 成就 / 打卡类 App 的开发者
**我需要** 一句 modifier 就能放 confetti
**以便** 不用引入第三方库或写 SpriteKit

**验收标准**
- [ ] `myView.coreConfetti(trigger: purchased)` 即可触发一次 burst
- [ ] 粒子颜色**默认取自调用方 `.tint`**，不自带彩虹色板
- [ ] `accessibilityReduceMotion` 开启时不播放粒子，降级为一次淡入淡出的静态庆祝层
- [ ] 单次 burst 结束后自动清理，无常驻 `Timer` / `DisplayLink` 泄漏

### US-3：下游 App 开发者需要有质感的背景层

**作为** 做 onboarding / paywall / 启动页的开发者
**我需要** 一个能动的程序化背景（液态金属、等离子、星空、噪声流场……）
**以便** 不用打包大体积视频或 Lottie

**验收标准**
- [ ] `CoreSwirl()` 等 28 个 shader 效果可作为任意视图的 `.background { }`
- [ ] **颜色 100% 由调用方传入**，无任何 shader 自带品牌色板（守卫机器可查）
- [ ] 在 iOS 真机与 iOS Simulator 两端都渲染（不是"Simulator 白屏"）
- [ ] 从 SwiftPM 消费方（`scripts/downstream-probe`）能正确加载 metallib

### US-4：下游 App 开发者需要原生画不出来的图表

**作为** 做健康 / 技能评估 / 社交图谱类 App 的开发者
**我需要** 雷达图、活动环、贡献热力图、力导向网络图
**以便** 不用为了这四类图表引入整个第三方图表库

**验收标准**
- [ ] 四个图表各自可用：`CoreRadarChart` / `CoreRingChart` / `CoreActivityHeatmap` / `CoreNetworkGraph`
- [ ] 全部走 CoreDesign 语义色 token 或调用方传入色，**不硬编码色相**
- [ ] 每个图表有 accessibility 表示（`accessibilityChartDescriptor` 或等价的
      `accessibilityElement` + `accessibilityValue` 逐数据点表示）
- [ ] 不引入 `import Charts` 依赖（这四个本来就是自绘的）

### US-5：CoreDesign 维护者需要新 target 不污染核心库的纪律

**作为** CoreDesign 的维护者
**我需要** 新 target 有明确的、机器可查的质量边界
**以便** 表达性视觉层不会变成"什么都能塞"的垃圾抽屉

**验收标准**
- [ ] `swift build` / `swift test` / CI 四条腿全绿
- [ ] `CoreDesign` target 的公开 API 表面**零变化**（`downstream-probe` 可证）
- [ ] Bool 棘轮（J-1）、`ComponentTextParamGuard`、`AccessibilityStringLiteralGuard`、
      `TouchTargetTests` 四道通用守卫**扩展覆盖新 target**
- [ ] 新增 `EffectsColorLiteralGuard`：新 target 内禁止 `Color.<色相字面量>`

## Functional Requirements

### FR-1 ~ FR-3：包结构

- **FR-1** `Package.swift` 新增两个 target：`CoreDesignEffects`、`CoreDesignCharts`，
  各自 `.library` product。两者均可 `dependencies: ["CoreDesign"]`（消费语义色 token 与
  `Core*` 度量常量），但 `CoreDesign` **不得反向依赖**它们。
- **FR-2** `CoreDesignEffects` 的 `.metal` 源随 target 编译，运行时经
  `ShaderLibrary.bundle(.module)` 查找——**不得**用 ShipSwift 原写法
  `ShaderLibrary.swSwirl(...)`（那查的是 main bundle，在库里必然失败）。
- **FR-3** `scripts/downstream-probe` 同步新增对两个新 product 的 import 与符号引用，
  确保 CI 的 `downstream-probe` job 能抓到从外部消费时的打包问题。

### FR-4 ~ FR-7：命名与 API 形态

- **FR-4** 所有落地符号去掉 `SW` 前缀，改用 CoreDesign 惯例：类型用裸名或 `Core` 前缀
  （`CoreRadarChart`），`View` 扩展 modifier 用 `core` 前缀（`.coreShake(trigger:)`）。
  ⚠️ 与 CoreDesign 现有的 `.core` control style 命名同族，不另立体系。
- **FR-5** 所有公开类型、`init`、`body` 显式 `public`（CoreDesign 惯例，漏写会静默导致
  下游编译失败）。
- **FR-6** **Bool 参数走 J-1**：ShipSwift 原 API 里的 `showLabels: Bool` /
  `autoReset: Bool` / `isActive: Binding<Bool>` 等**一律不得直接照搬**。要么改成语义枚举
  （公约第 3 节替代路径 3.1），要么走 `trigger:` 值变化模式，要么申请豁免并抬棘轮基线。
- **FR-7** 所有面向用户的文本（`"Before"` / `"After"` / 图表轴标签）必须是
  `LocalizedStringResource` / `LocalizedStringKey`，不得是裸 `String` 字面量
  （`ComponentTextParamGuard` + `AccessibilityStringLiteralGuard` 强制）。

### FR-8 ~ FR-10：颜色纪律

- **FR-8** 新 target 内**禁止色相字面量**（`.cyan` / `.purple` / `.white.opacity(...)` /
  `Color(red:green:blue:)`）。颜色只有三个合法来源：① 调用方参数；② `TintShapeStyle`
  （`.tint`）；③ CoreDesign 第 3/4 层语义 token。
- **FR-9** 新增守卫 `EffectsColorLiteralGuard`（SwiftSyntax 扫描，与既有
  `BoolParameterScanner` 同形态）落地 FR-8，随 `swift test` 跑。
- **FR-10** Metal shader 的调色板参数化：ShipSwift 多数 shader 把颜色写死在 `.metal` 里，
  必须改成从 Swift 侧以 `.colorArray(...)` / `.color(...)` 传入。

### FR-11 ~ FR-13：动效可访问性

- **FR-11** 每个含位移 / 旋转 / 缩放的效果必须读 `@Environment(\.accessibilityReduceMotion)`，
  开启时降级为无位移形态（淡入淡出或静态）。
- **FR-12** 每个 Metal shader 背景在 Reduce Motion 开启时**冻结在某一帧**，不停止渲染
  （保留视觉，去掉运动）。
- **FR-13** 装饰性效果层一律 `accessibilityHidden(true)`；承载状态语义的效果
  （如 shake 表示"输入错误"）必须由**调用方**提供 a11y 通告，组件文档需明写这一分工。

### FR-14 ~ FR-16：图表

- **FR-14** 四个图表的数据入参用泛型 + `Identifiable`，不绑定具体模型类型。
- **FR-15** `CoreNetworkGraph` 只落布局算法与渲染，**丢弃 ShipSwift 的 4973 行 demo 数据**
  （`SWNetworkGraphData.swift`）。
- **FR-16** 四个图表提供 `#Preview`，并在 `App/` 预览宿主里各加一个展示屏。

### FR-17 ~ FR-18：文档与署名

- **FR-17** 每个落地项在 `docs/components/` 下有对应 `.md`，并在 `docs/README.md` 索引。
- **FR-18** 新增 `ACKNOWLEDGEMENTS.md`（或在现有文档中增节），逐项署名 ShipSwift /
  SignerLabs 与 MIT 许可全文，标注哪些实现衍生自其算法。

## Non-Functional Requirements

- **NFR-1（性能）** 单个 Metal shader 背景在 iPhone 15 上满帧（60fps / ProMotion 120fps）；
  Confetti 默认粒子数下不掉帧。以 Instruments 抽测两个最重的效果为证。
- **NFR-2（包体）** `.metal` 源编译产物（metallib）不得使 `CoreDesignEffects` 的
  resource bundle 超过 2MB。
- **NFR-3（平台）** `CoreDesign` 现为 iOS 26 / macOS 26 双端。新 target **同样双端**；
  确实只能 iOS 的（如依赖 `UIKit` 的效果）用 `#if canImport(UIKit)` 隔离，**不得**降低
  package 的 macOS 支持。
- **NFR-4（并发）** 全部代码过 Swift 6 严格并发（`swiftLanguageModes: [.v6]` +
  `.defaultIsolation(MainActor.self)`），零 `@unchecked Sendable` 逃逸。
- **NFR-5（隔离性）** 任一新 target 编译失败不得阻断 `CoreDesign` 自身的构建与测试。

## Success Criteria

| # | 指标 | 判据 |
|---|---|---|
| SC-1 | 落地数量 | 46 项中至少 42 项可用（允许 Metal 段最多丢 4 个疑难 shader） |
| SC-2 | CI 全绿 | 四条腿（SwiftPM / iOS Simulator / downstream-probe / Bool 棘轮）全绿 |
| SC-3 | 核心库零回归 | `CoreDesign` 公开 API 表面 diff 为空 |
| SC-4 | 颜色纪律 | `EffectsColorLiteralGuard` 零违规 |
| SC-5 | a11y 覆盖 | 含运动的效果 100% 有 Reduce Motion 降级路径，测试可证 |
| SC-6 | Bool 纪律 | Bool 豁免基线净增 ≤ 3 条，每条有书面理由 |
| SC-7 | 预览宿主可跑 | `scripts/run-preview.sh` 能构建并展示全部新增项 |
| SC-8 | 文档完整 | 每个落地项有 `docs/components/*.md` + `#Preview` |

## Constraints & Assumptions

### 硬约束

- **C-1 Metal 打包是未验证的技术闸。** CoreDesign 从未在 SwiftPM 里编译过 `.metal`。
  SwiftPM 支持 target 内 Metal 源，但需验证：① 产物落在 `.module` bundle 的正确位置；
  ② `ShaderLibrary.bundle(.module)` 能查到 `stitchable` 函数；③ iOS Simulator 腿也能跑；
  ④ 从 `downstream-probe` 这种外部 SwiftPM 包消费时同样成立。**Epic 第一个 issue 必须是
  单 shader 的打包 spike，闸门失败则 Metal 段（28 项）整体下线，不连坐其余 18 项。**
- **C-2 manifest 变更会打到预览宿主。** CLAUDE.md 明写：`App/` 是独立 `xcodegen` 工程，
  不受 `swift build` / `swift test` 覆盖，且 manifest 层变更的报错发生在**依赖解析期**，
  不会在库编译期出现。新增 target / product 必须手动验证 `App/project.yml` 与
  `scripts/run-preview.sh` 仍能构建。
- **C-3 在 worktree 里跑 `xcodegen generate` 有坑**（会把 local package 的 `name` 写成
  当前目录名并清空 scheme）。见 `App/project.yml` 顶部注释。
- **C-4 守卫扩展不可绕过。** 四道通用守卫必须真的覆盖新 target，不接受"新 target 先豁免"。
- **C-5 判定法与 component-registry 不扩到新 target。** 见下方假设 A-1 的论证。

### 假设

- **A-1（关键）** 表达性视觉层**不是**公约意义上的"组件"，因此不进 `component-registry.json`、
  不走 1410 行判定法。**理由**：判定法步骤 2 要求为每个候选举出"≥2 个业界真实存在、结构不同
  的替代形态"并给可核验来源。对 `CoreRadarChart` 这类还能论证；对"液态铬金属程序化背景"
  这类，要求论证"业界有两个结构不同的液态铬替代形态"是把公约当仪式跑——公约自陈它回答的是
  「这个组件该长什么样的 API」，而一个 shader 背景的 API 就是"传颜色和速度进去"，没有形态
  选择可言。⚠️ **本假设需要在 epic 阶段由公约维护者确认**；若被推翻，Metal 段的成本会显著
  上升（28 项 × 判定法走查），届时应缩减 Metal 数量而非降低论证质量。
- **A-2** ShipSwift 的算法（力导向布局、confetti 物理、mask reveal 的 `Shape` 数学、
  各 shader 的噪声函数）正确且可直接借鉴，只需替换其色彩与 API 层。
- **A-3** ShipSwift 的 MIT 许可允许衍生实现 + 署名，无需征得额外授权。
- **A-4** iOS 26 / macOS 26 部署目标下，`ShaderLibrary` / `colorEffect` /
  `KeyframeAnimator` / `PhaseAnimator` / `Transition` 协议全部可用，无需可用性回退。

## Out of Scope

以下**明确不做**，各附理由：

| 项 | 理由 |
|---|---|
| ShipSwift 5 个 Swift Charts 换皮图表（Line / Bar / Area / Donut / Scatter） | 全部 `import Charts`，原生已支持。CoreDesign 不重造 Swift Charts 换皮 |
| `SWShimmer` | CoreDesign 已有 `.skeletonShimmer()` |
| `SWShakingIcon` | 被本 PRD 的 `.coreShake(trigger:)` 微交互完全包含 |
| `SWSearchBar` / `SWTabButton` / `SWStatusBadge` / `SWAlert` / `SWLabel` / `SWLoading` / `SWGradientDivider` / `SWStepper` | 分别与 `SearchField` / `SegmentedControl` / `Badge`+`Tag`+`StateLabel` / `Toast` / `CoreLabelStyle` / `ProgressIndicator` / `Separator` / 原生 `Stepper` 重叠 |
| 全部 `SWModule/*`（Auth / Camera / Paywall / Chat / Setting / SubjectLifting / TikTokTracking） | App 级功能模块，含 Amplify / StoreKit / AVFoundation / Vision / VolcEngine ASR 外部依赖。设计系统不承担这些 |
| `SWOnboardingView` / `SWAddSheet` / `SWWallet` / `SWOrderView` / `SWRootTabView` / `SWVideoPlayer` / `SWScrollingFAQ` / `SWFloatingLabels` / `SWRotatingQuote` / `SWKPICard` / `SWMarkdownText` / `SWBulletPointText` / `SWImageThumbnail` | App 级脚手架或业务组合件。**其中 `SWKPICard` 与 `SWMarkdownText` 有独立价值，但属于"UI 组件"轨而非本 PRD 的"表达性视觉层"轨，另开 PRD** |
| `SWUtil/*`（String / Date / View 扩展、`LocationManager`、`DebugLog`） | 与设计系统无关 |
| 视觉设计的重新定调 | 本 PRD 只补能力，不改 CoreDesign 现有的 HIG 系统色地基 |

## Dependencies

### 内部

- **D-1** `CoreDesign` target 的语义色 token（第 3/4 层）与 `Core*` 度量常量——
  两个新 target 都依赖它们，且**只能**从它们取色。
- **D-2** 既有守卫基建：`BoolParameterScanner`（68KB）、`ComponentTextParamGuard`（40KB）、
  `AccessibilityStringLiteralGuard`（16KB）、`TouchTargetTests`（16KB）——需扩展扫描范围
  到新 target，不重写。
- **D-3** `scripts/downstream-probe`（独立 SwiftPM 包）——必须同步。
- **D-4** `App/CoreDesignPreview`（xcodegen 工程）——必须同步 `project.yml` 与展示屏。

### 外部

- **D-5** ShipSwift 仓库（MIT）作为算法来源。**已本地 clone 快照**；实现期间以快照为准，
  不追踪其上游变更。
- **D-6** SwiftPM 对 target 内 `.metal` 源的编译支持——**这是 C-1 要验证的东西本身**，
  不是可假定的既成事实。
- **D-7** Swift 6.3 工具链 + swift-syntax 603.0.2（守卫扩展要用）。

### Epic 分解草案（供 ccpm 参考，非最终）

```
#1  Metal 打包 spike（闸门）        ← 无依赖，必须最先跑
#2  两个新 target 骨架 + 守卫扩展   ← 无依赖，可与 #1 并行
#3  微交互 modifier 簇（7 个）      ← 依赖 #2
#4  转场簇（16 个）                 ← 依赖 #2
#5  庆祝/处理中动画（4 个）         ← 依赖 #2
#6  文本/展示动画（5 个）           ← 依赖 #2
#7  Canvas 3D（3 个）               ← 依赖 #2
#8  Metal shader 批量（28 个）      ← 依赖 #1 + #2，#1 失败则整体下线
#9  四个图表                        ← 依赖 #2
#10 预览宿主 + 文档 + 署名收尾      ← 依赖全部
```

#3~#7、#9 之间无依赖，可并发。
