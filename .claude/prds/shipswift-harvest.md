---
name: shipswift-harvest
description: 从 ShipSwift(MIT) 收割 CoreDesign 真空缺的表达性视觉层——36 个纯 SwiftUI 动效 API、28 个 Metal shader、4 个 Swift Charts 画不出来的图表——落成三个新 target，并在 structure 阶段拆为「非 Metal」与「Metal」两个独立 epic
status: backlog
created: 2026-09-02T22:50:16Z
---

# PRD：ShipSwift 表达性视觉层收割

> **修订说明**：第 1 轮评审（BLOCK）证伪了初版的成本模型、CI 验证路径、许可假设与
> 计数单位；第 2 轮评审（REVISE）又在测试隔离、scheme 拓扑、API 计数、许可闸判据与
> AD-4 内容上各挖出一层。两轮改动逐条见文末《评审响应台账》。

## Executive Summary

[ShipSwift](https://github.com/signerlabs/ShipSwift)（MIT，SignerLabs）是一个面向 LLM 的
SwiftUI「配方库」。本 PRD 从中**只取 CoreDesign 真空缺、且属于设计系统职责范围**的
表达性视觉能力，按 CoreDesign 的 API 公约与色彩地基**重新实现**（不是拷贝文件）。

### 计数单位（先定义，避免分母漂移）

全文统一用 **「API 单位」= 一个调用方可独立使用的公开入口**（一个 `View` 类型、
一种 `Transition`（含参重载算同一种）、一个 `View` 扩展 modifier）。文件数**不作为**任何指标的分母。

| 落地轨 | 新 target | 文件数 | **API 单位** |
|---|---|---|---|
| 纯 SwiftUI 动效 | `CoreDesignEffects` | 14 | **36** |
| Metal shader | `CoreDesignShaders` | 28 wrapper / 34 `.metal` | **28** |
| 原生画不出的图表 | `CoreDesignCharts` | 4 | **4** |
| | | | **合计 68** |

### 三个 target，不是两个

初版方案（`CoreDesignEffects` 一个 target 装下 SwiftUI 动效 + Metal）已否决。**Metal 段
有三项独立于 SwiftUI 动效的约束**：① 依赖非默认构建系统（见 C-1）；② 独立的
resource 体积预算（NFR-2）；③ 独立的许可核验闸（C-6）与整体下线开关。把它与
`.shake(trigger:)` 绑进同一个 target，意味着只想要微交互的消费者要背 metallib 与
构建系统限制。⇒ **Metal 单独成 `CoreDesignShaders`。**

### 三个 epic

本 PRD 在 **structure 阶段拆为三个独立 epic**（先例：`coredesign-native-refresh.md:3,16`
同样是「一 PRD → 多 epic」）：

- **Epic A0「地基与两闸」** = 公约裁决 AD-4 + `CoreDesignEffects` / `CoreDesignCharts`
  两个 target 骨架 + CI scheme 切换（NFR-6）+ 守卫扩展与新建 + probe 扩展
  + **D-1 Metal spike** + **C-6 许可核验**。
- **Epic A「效果与图表」** = 36 个 SwiftUI 动效 + 4 个图表。依赖 A0。
- **Epic B「Metal」** = `CoreDesignShaders` target + 28 个 shader。
  **前置 = A0 的 D-1 ∧ C-6 双双通过**；任一不过，Epic B 整体不启动，A0 / A 不受影响。

⚠️ **两闸放 A0 而不放 A 或 B**（第 2 轮评审 I-5）：闸挂在 Epic B 内的话，"B 未启动"就
没有操作定义（闸本身是 B 的第一个 task，B 不启动闸也不会跑）；挂在 Epic A 内则让
A 的完成度取决于一件与它无关的事。⇒ 两闸都是 A0 的交付物，B 读 A0 的结论决定启不启动。

⚠️ **`CoreDesignShaders` target 归 Epic B，不在 A0 建**（第 2 轮评审 I-5）：A0 若建了它，
而 D-1 / C-6 任一失败，仓库里就留下一个**空 product**，连带 `App/project.yml` 的
`product:` 条目、probe 的 nonisolated 调用点、README 索引小节全是空壳。

⚠️ **不拆成多个 PRD 的理由**：三 target 拓扑、守卫方案、AD-4 是三个 epic **共享的地基
决策**，拆 PRD 会导致它们要么重复写、要么跨 PRD 引用。A0 的抽出同时解决了第 2 轮评审
指出的密度问题——原 Epic A 的 10 个 task 里有 4 个是地基，抽走后各 epic 都落回本仓
历史的 5–13 task 区间。

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
| `ComponentTextParamGuard` | **只能守 B 类（public init 的裸文本参数）**，且需新 target 进登记表——其定义域是登记表条目（`:228-242` 按 `repo == "coredesign"` 取 `textParams` 并硬断言 `== 31`），公约 G-8 逐字「FR-4 判据以**登记表条目**为定义域」 | 覆盖面**仅限 B 类**；是否扩取决于 AD-4（见 C-5）。⚠️ **它守不到 FR-7**——见下方 A 类说明 |
| `ChromeTextLiteralGuard`（新增，落 FR-7） | — | ⚠️ **FR-7 要求本地化的"组件自带 UI 文案"是公约的 A 类（chrome 文案），不是 B 类**。公约 G-4 行（`docs/component-contract.md:1017`）逐字「A 类文案不经任何一路进入 FR-4 的机器视野……评审（无机器判据）」——**连 CoreDesign 自己都没守住 A 类**。⇒ 不扩 `ComponentTextParamGuard` 就想守 FR-7 是空的。本 PRD 新建一条与 `AccessibilityStringLiteralGuard` 同形态的扫描（扫 `Text("…")` / `Label("…"` 的裸字面量），**射程只覆盖三个新 target**，不回溯 CoreDesign 现状 |
| `TouchTargetTests` | **结构上不适用**——它是手写的交互组件实例化清单且整 suite `#if os(iOS)`；新 target 里真交互件只有 BeforeAfterSlider / GlassOrb 两个 | **不列为验收项**；只把这两个真交互件加进清单 |
| `EffectsColorLiteralGuard`（新增） | — | 必须新建；SC-4 |

- [ ] `CoreDesign` target 的公开 API 表面**零变化**（`downstream-probe` 可证）
- [ ] CI 四条腿全绿

## Functional Requirements

### FR-1 ~ FR-4：包结构

- **FR-1** `Package.swift` 新增三个 target + 三个 `.library` product：`CoreDesignEffects`、
  `CoreDesignShaders`、`CoreDesignCharts`。三者均可 `dependencies: ["CoreDesign"]`；
  `CoreDesign` **不得反向依赖**任一。`CoreDesignShaders` 可依赖 `CoreDesignEffects`，反之不可。
- **FR-2** `.metal` 的落地形态二选一。⚠️ **裁决判据写死在此，不留给 spike 自由发挥**：
  - **路径 α（源码随 target 编译）**：`.metal` 作为 target 源，运行时经
    `ShaderLibrary.bundle(.module)` 查找。
    **可选条件：所有已知消费路径都能切到 `--build-system swiftbuild`。**
    ⚠️ 该条件**今天已知为假**：`downstream-probe` job 是原生 `swift build`
    （`.github/workflows/ci.yml`），真实下游 StoryUI 的 CI 也是 SwiftPM `swift test`
    （公约 G-8 行）。α 等于把构建系统约束转嫁给下游，且**失败形态是运行时静默无渲染**
    ——最坏的一类失败。⇒ **除非 D-1 证明这些路径都可切，否则不选 α。**
  - **路径 β（预编译 metallib 作为二进制资源）—— 默认走向**：
    ⚠️ **metallib 按 SDK 分平台编译，不是一个文件**。β 的真实形态是：
    ① 提交 **3 份** metallib（`iphoneos` / `iphonesimulator` / `macosx`）；
    ② `.copy(...)` 进 bundle，运行时按 `#if targetEnvironment(simulator)` / `os(macOS)` 选文件；
    ③ `.metal` 源必须从 target sources 里 **`exclude:`**，否则 swiftbuild / xcodebuild 会
    再编一份与 `.copy` 的产物冲突；
    ④ 配 `scripts/build-metallib.sh` + 一条校验 metallib 与 `.metal` 源同步的守卫
    （否则改了 shader 忘了重编 = 静默用旧效果）。
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

- **FR-9** 新增两条守卫（均 SwiftSyntax 扫描，与 `BoolParameterScanner` / `AccessibilityStringLiteralGuard` 同形态，射程仅三个新 target）：
  - `EffectsColorLiteralGuard` —— 落地 FR-8（禁色相字面量）。
  - `ChromeTextLiteralGuard` —— 落地 FR-7 的 **A 类** chrome 文案（`Text("…")` 裸字面量）。
    ⚠️ 这是本仓**新开的守卫面**：公约 G-4 明载 A 类今天无机器判据、靠评审。本 PRD 只为
    新 target 补上，**不回溯改造 CoreDesign 现状**（那是独立的一件事）。
- **FR-10** 把 `BoolExemptionGuard.coreDesignSources`（`:43`）与
  `AccessibilityStringLiteralGuard`（`:189`）的**单一硬编码扫描根改为多 target 根列表**，
  并保持既有 CoreDesign 判据字面不变（不得因重构放松现有断言）。

### FR-11 ~ FR-13：动效可访问性与能耗

- **FR-11** 每个含位移 / 旋转 / 缩放的效果读 `@Environment(\.accessibilityReduceMotion)`，
  开启时降级为无位移形态。
- **FR-12** Reduce Motion 开启时（`Reduce Transparency` 的处置一并在此，它是 a11y 不是能耗）：
  - `colorEffect` 背景类 → **冻结在某一帧**（保留视觉，去掉运动）。
  - `layerEffect` 内容层类 → **冻结其时间输入，但保留由用户手势/倾斜驱动的空间输入**
    （放大镜跟手是交互不是动效，冻结它会让组件不可用）。
  - `accessibilityReduceTransparency` 开启时：依赖半透明/折射的效果
    （Glass / GlassOrb / ChromaticGlass）须降级为不透明形态。
- **FR-13** 装饰性效果层一律 `accessibilityHidden(true)`；承载状态语义的效果
  （如 shake 表示"输入错误"）由**调用方**提供 a11y 通告，文档明写这一分工。

### FR-14 ~ FR-20：图表

- **FR-14** 数据入参用泛型 + `Identifiable`，不绑定具体模型类型。
- **FR-15** `NetworkGraph` 只落布局算法与渲染，**丢弃上游 4973 行 demo 数据**。
- **FR-16** ⚠️ **改写**：预览宿主 `App/` 覆盖范围 = **全部 68 个 API 单位**（与 SC-7 对齐；
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
  ⚠️ 本仓**目前没有** `ACKNOWLEDGEMENTS.md`（只有 MIT `LICENSE`）⇒ 本 PRD 要**新建**它，
  完整转载这些原始许可，并区分"参考算法思路"与"较大段落移植"两档。
  该文件与 C-6 的 `docs/shader-provenance.md` 分工：provenance 表是**裁定过程**，
  ACKNOWLEDGEMENTS 是**对外的许可声明**，前者的"可落地"行必须在后者有对应条目。
- **FR-19（新增）** **退化输入契约**。四个图表对以下输入必须有定义好的行为
  （渲染空态 / 忽略该数据点 / 而非 crash 或 NaN），且每条有测试：
  - 空数组；单点数据
  - `RadarChart`：所有轴值相等（归一化除零）、轴数 < 3
  - `RingChart`：total = 0
  - `ActivityHeatmap`：日期区间为空、全零值
  - `NetworkGraph`：零边、所有节点初始位置重合（力导向除零 → NaN）
- **FR-20（新增）** `NetworkGraph` 须声明**规模上限**与超限行为。力导向布局通常是每帧
  O(n²)；文档需给出实测的建议节点上限。**超限行为固定为「截断 + 降级为静态布局 + 文档
  标注」**——⚠️ 不得用 `precondition` / `fatalError` 抛断言：库代码对数据规模抛断言就是让
  宿主 App crash，与 US-4「不 crash」直接相悖（第 2 轮评审 Suggestion）。

## Non-Functional Requirements

- **NFR-1（性能）** 单个 `colorEffect` 背景在 iPhone 15 上满帧；Confetti 默认粒子数下
  不掉帧；`NetworkGraph` 在 FR-20 声明的节点上限内不掉帧。
  ⚠️ **须是可重复的回归闸而非一次性人工抽测**：约定一个基准脚本（简化的 frame-time
  断言即可）随 CI 或至少随 epic 收尾复跑。
- **NFR-2（包体）** `CoreDesignShaders` 的 resource bundle **每平台 ≤ 2MB**
  （FR-2 路径 β 下仓库里有 3 份 metallib，合计上限 6MB；α 下只有一份编译产物）。
  ⚠️ 初版没区分"每平台还是合计"，在 β 下会差 3 倍。
- **NFR-3（平台）** ⚠️ **改写**：新 target 默认双端（iOS 26 / macOS 26），但**下列四项
  上游即非纯 SwiftUI，须逐项处理**：`OrbitingLogos`（`import SpriteKit`）、
  `DotSphere` / `CharSphere`（`import UIKit`）、`FullScreenButton`（依赖
  `navigationTransition(.zoom)`，iOS-only）。处理方式二选一：重写为跨平台 SwiftUI，
  或 `#if canImport(UIKit)` 隔离并在文档标注平台限制。**不得降低 package 的 macOS 支持。**
- **NFR-4（并发）** 全部过 Swift 6 严格并发 + `.defaultIsolation(MainActor.self)`，
  零 `@unchecked Sendable` 逃逸。由 FR-3 的 probe 扩展验证。
- **NFR-5（隔离性）** ⚠️ **改写**：初版写的"任一新 target 编译失败不得阻断 CoreDesign 的
  构建与测试"**在本仓 CI 形态下不可能成立**——CI SwiftPM 腿跑的是不带 `--target` 的
  `swift build` / `swift test`，SwiftPM 在包根构建全部 target。改为可达成形态，**两条**：
  ① **`swift build --target CoreDesign` 独立可绿**；
  ② **`CoreDesignTests` 的依赖图不含任何新 target**（`swift package describe` 可证）。
  ⚠️ 初版这里写的 `swift test --filter CoreDesignTests` **实测不成立**——`--filter` 只在
  运行期筛选，SwiftPM 仍把整包所有 target 编进同一个 `PackageTests.xctest`；坏掉的新
  target 会在 `Compiling` 阶段直接让 `swift test --filter` 失败。⇒ 隔离性只能靠
  ②「依赖图不含」这种结构性判据，不能靠 `--filter`。
- **NFR-6（新增，测试拓扑）⚠️ 已拍板，不留给实现期选**：新 target 各建**独立测试
  target**（`CoreDesignEffectsTests` / `CoreDesignShadersTests` / `CoreDesignChartsTests`），
  CI 的 iOS Simulator 腿改用 **`-scheme CoreDesign-Package`**。
  - **为什么不并入 `CoreDesignTests`**：那需要 `@testable import` 三个新 target，
    使 `CoreDesignTests` 的依赖图包含它们，与 NFR-5 ② 直接矛盾。⇒ 独立测试 target 是
    唯一自洽解。
  - **⚠️ 切 scheme 不是可选优化，是 FR-1 落地那个 commit 的硬前置。** 实测：本仓当前
    `xcodebuild -list` **只有一个 scheme `CoreDesign`**（单 product 时 Xcode 把包 scheme
    合并进去，所以 CI 现在的 `-scheme CoreDesign` 能跑测试）。新增 product 后 scheme
    列表变成 `CoreDesign` / `CoreDesign-Package` / `CoreDesignEffects` / …，而
    `xcodebuild test -scheme CoreDesign` 会**直接硬红**：
    `error: Scheme CoreDesign is not currently configured for the test action`。
    ⇒ 失效形态是**硬红不是静默不跑**（初版描述有误）。`ci.yml` 现有的
    `-skip-testing:CoreDesignTests/ToastHostTests` 在包 scheme 下仍有效。
  - 该 scheme 改动写进 A0 的验收：`xcodebuild -list` 输出与 `xcodebuild test` 实跑均需留证。
- **NFR-7（新增，能耗与生命周期）** 常驻渲染的效果（`colorEffect` 背景、Confetti、
  ScanningOverlay）必须定义 App 进入**后台**与**低电量模式**下的行为（暂停渲染 / 降帧）。
  ⚠️ **必须可测，不接受"或文档声明"**（第 2 轮评审 Suggestion——"或文档"会让这条退化成
  文档要求）：`ProcessInfo.isLowPowerModeEnabled` 与 `scenePhase` 在测试里都不可直接切换
  ⇒ 实现须把这两个信号做成**可注入的 `EnvironmentValues`**（默认从系统读），测试注入
  伪值断言渲染行为。`Reduce Transparency` 是 a11y 不是能耗，已移到 FR-12。

## Success Criteria

⚠️ **"可用"的定义（SC-1 的判据，机器可查的 AND 条件）**：
① 编译通过；② 过 `EffectsColorLiteralGuard` + Bool 棘轮 + a11y 字面量守卫；
③ 有 `#Preview` 且进 `App/` 画廊；④ 有 `docs/components/*.md`。四条全中才计入。

| # | 指标 | 判据 |
|---|---|---|
| SC-1 | Epic A 落地量 | 40 个 API 单位（36 动效 + 4 图表）中 ≥ 37 项"可用" |
| SC-2 | Epic B 落地量 | ① `docs/shader-provenance.md` 覆盖全部 28 个 shader，无空裁定；② 裁定为可落地者 **100%** "可用"；③ 可落地数 **≥ 7**（低于此闸判不过，Epic B 不启动）。⚠️ 三条 AND——初版只写②，核验通过 0 个时会自动满足，是空真判据 |
| SC-3 | CI 全绿 | 四条腿全绿，且 NFR-6 的 scheme 改动经实测确认新测试真的在跑 |
| SC-4 | 核心库零回归 | `CoreDesign` 公开 API 表面 diff 为空；`swift build --target CoreDesign` 独立绿 |
| SC-5 | 颜色纪律 | `EffectsColorLiteralGuard` 零违规 |
| SC-6 | a11y 覆盖 | 含运动的效果 100% 有 Reduce Motion 降级路径，测试可证 |
| SC-7 | Bool 纪律 | Bool 豁免基线净增 ≤ 3 条，每条有书面理由，按棘轮脚本流程抬基线 |
| SC-8 | 退化输入 | FR-19 列举的 9 类退化输入 100% 有测试且不 crash / 不 NaN。⚠️ 「空数组 / 单点」两类对四个图表各要一条 ⇒ **实际测试条数 ≥ 15，不是 9**（structure 阶段据此估工） |
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
  28 个 wrapper 里 **21 个已在 Swift 侧接 `Color`**，**7 个写死**——除 ShaderKit 那 5 个
  （ChromaticGlass / Foil / Glitter / IntenseBling / PolishedAluminum）外，还有
  **`GlassLogo`**（整套硬编码静态调色板 `SWGlassLogoStyle.coolBlue/orange/deepBlue/stripe/canvas/bloom/fresnelColor`，
  `SWGlassLogo.swift:95-122`）与 **`LiquidMetal`**（`coolTint` 是 `Float` 不是 `Color`；
  文件内唯一的 `Color` 是 Preview 里的 `Color.black`）。这 7 个全是 `layerEffect`
  ⇒ **layerEffect 段的参数化难度显著高于 colorEffect 段**，spike 必须覆盖其中一个。
- **C-3 manifest 变更会打到预览宿主。** `App/` 是独立 `xcodegen` 工程，不受
  `swift build` / `swift test` 覆盖，manifest 层报错发生在**依赖解析期**。
  且 `App/project.yml:34` 的 `dependencies: - package: CoreDesign` **未指定 `product:`**，
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
  - 守卫今天扫不到新 target——证据是 `ComponentRegistryGuard.swift:366` 把扫描根硬编码为
    `repoRoot/"Sources/CoreDesign"`。⇒ 初版方案是在借一个**实现层的盲区**省成本，
    而不是取得了公约层的许可。
    ⚠️ 初版这里引了公约 G-7 行，**引用不准**：G-7 是 StoryUI 侧
    `ComponentRosterSourceAnchorTests` 的盲区台账，其列出的逃逸项是「加第二个 source
    target 时的 `package` 访问级」，不是"第二个 target 不被扫描"。直接引
    `ComponentRegistryGuard.swift:366` 即可，不必借道 G-7。

  ⇒ **本 PRD 的处置**：Epic A0 的第一个 issue 是**提交公约裁决 AD-4**。
  ⚠️ **AD-4 必须允许按 target 分别裁决，不得三 target 一刀切**（第 2 轮评审 I-7）：
  `RadarChart` / `RingChart` / `ActivityHeatmap` / `NetworkGraph` 是**普通意义上的组件**
  ——public View struct、有数据入参、且**真有形态选择**（雷达图的轴/网格画法正是判定法
  步骤 2 该问的问题）。把它们和 `.shake(trigger:)` 一起划进"轻公约"，恰恰是在**最需要
  判定法的地方绕开它**。

  **本 PRD 的推荐裁决（AD-4 的输入，非既成结论）**：

  | target | 走向 | 理由 |
  |---|---|---|
  | `CoreDesignCharts` | **b：进登记表** | 4 个都是有形态选择的常规组件；`ComponentRegistryGuard.swift:449` 的 `coredesign == 47` 改 **51** |
  | `CoreDesignEffects` | **a：轻公约** | 微交互 / 转场没有"该长什么样"的 API 形态问题，只有"触发时机"；扩展点为负债 |
  | `CoreDesignShaders` | **a：轻公约** | 同上，且其存在与否取决于 D-1 / C-6 |

  **AD-4-a（轻公约）的内容骨架**——⚠️ 初版只写了"更轻但显式"四个字、零内容，
  本轮补齐最小可交付形态（第 2 轮评审 I-7）：
  1. **继承**公约的 J-1（禁未豁免 Bool 参数）与 FR-4 文本参数纪律；
  2. **不继承**判定法（步骤 1–4）与扩展点判据（J-2）——理由须逐 target 写明；
  3. **新增**两条本 PRD 已定义的守卫：`EffectsColorLiteralGuard`、`ChromeTextLiteralGuard`；
  4. **登记形态**：不进 `component-registry.json`，改为一份独立的
     `docs/effects-registry.json`（字段仅 `name` / `target` / `kind: colorEffect|layerEffect|modifier|transition|view` / `platform` / `provenance`），配一条与源码双向差集的守卫
     ——**作用域钉死后必须补守卫，否则就是无守卫空白地带**，与 US-5 意图矛盾。
  **成本量级**：轻公约本体预计 150–250 行（对照公约本体 1410 行），加两条守卫与一条
  差集守卫。⚠️ **本仓从无"另立一份公约"的先例**，且公约本体受
  `ComponentContractStructureGuard` 等机器守护——**可行但绝不轻**，这是 AD-4 要权衡的
  真实成本。

  **AD-4-b（fallback）**：按 AD-2 原样执行，public `View` 类型批量以步骤 3 登记
  prescriptive，扫描根改为多 target。

  **裁决判据（什么条件下选 a）**：轻公约本体 + 三条守卫的落地成本 **<** 约 40 个 public
  View struct 走完整判定法（含步骤 2 的"≥3 具名业界候选或穷尽四家基线"举证义务）
  + 逐条 notes 的成本。⚠️ 该比较须在 AD-4 issue 里**各给一个抽样估算**（各取 2 个样本
  实做），不接受凭感觉。
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
  ⇒ **处置（⚠️ 用正向裁定，不用"证明来源不明"——那是要证一个否定，做不到）**：
  逐 shader 落一行裁定表（`docs/shader-provenance.md`），字段固定为
  **`shader | 原始出处 | 许可 | 证据链接 | 裁定`**，裁定取值仅三种：
  - **`已追到兼容许可`**（MIT / BSD / PD / CC0 的原始实现）⇒ 可移植落地，须转载原始许可；
  - **`clean-room 重写`** ⇒ 该效果是**教科书算法**（Simplex noise 有 Ashima/Gustavson 的
    MIT/PD 参考实现；Voronoi / Plasma / Metaballs 同属公开算法），**从已知许可的参考实现
    重写，不看 ShipSwift 的 `.metal`**。⚠️ 这与 Executive Summary「重新实现（不是拷贝
    文件）」是同一件事，本条**明确给它一个出口**——初版 C-6 的措辞把这条路堵死了；
  - **`不落地`** ⇒ 追不到兼容许可、也不属于可 clean-room 的公开算法。
  ⚠️ **闸的"通过"定义**：裁定表覆盖全部 28 个 shader（无空行）**且**裁定为可落地
  （前两类）的数量 **≥ 7**（即至少覆盖已知 MIT 来源的那 7 个）。低于该下限，
  Epic B 的固定基建成本（切构建系统、3 份 metallib、新 target、CI 改动）不值得
  ⇒ **闸判不过，Epic B 不启动。**

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

- **D-1（前置闸）Metal 打包 spike**。范围见 C-1 + C-2 + FR-2，必须回答**六问**：
  ① 构建系统选型（α/β，按 FR-2 判据）；② CI 改法；③ metallib 定位；
  ④ 多色参数化（一个 `colorEffect`）；⑤ layer 输入（一个 `layerEffect`，且应取
  FR-4 点名的 7 个"颜色写死"件之一，难度最高）；
  ⑥ **分平台 metallib**：3 份产物的生成、选择与体积实测。
  **失败则 Epic B 整体不启动。**
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
| 2 | `App/project.yml:34` | 未指定 `product:`，需逐条补 |
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

**Epic A0「地基与两闸」**

```
A0-1  公约裁决 AD-4（按 target 分别裁决；含 a/b 各 2 个样本的成本抽样估算）
A0-2  Package.swift 新增 CoreDesignEffects / CoreDesignCharts 两 target 两 product
      ⚠️ 同 commit 必须切 CI 的 -scheme CoreDesign-Package（NFR-6），否则 iOS 腿硬红
A0-3  守卫：Bool / a11y 扫描根多 target 化 + 新建 EffectsColorLiteralGuard、ChromeTextLiteralGuard
A0-4  downstream-probe 扩展 nonisolated 调用点（FR-3）
A0-5  D-1 Metal 打包 spike（六问，见 D-1）                    ← Epic B 前置闸①
A0-6  C-6 逐 shader 许可裁定表 docs/shader-provenance.md      ← Epic B 前置闸②
```
A0-5 / A0-6 可与 A0-1~A0-4 并行（它们不依赖 target 骨架）。

**Epic A「效果与图表」**（40 个 API 单位 = 36 动效 + 4 图表）。依赖 A0-1~A0-4。

```
A-1  微交互 8 个（shake/jump/spin/ping/spray/rise/haptic/shine）
A-2  转场 16 种（按 mask reveal / 3D / 弹性三组分批）
A-3  庆祝与处理中 4 个（Confetti / ScanningOverlay / GlowSweep / LightSweep）
A-4  文本与展示 4 个（TypewriterText / AnimatedMeshGradient / BeforeAfterSlider / ParticleTransition）
A-5  跨平台改造 4 个（OrbitingLogos←SpriteKit / DotSphere / CharSphere←UIKit / FullScreenButton←iOS-only），见 NFR-3
A-6  四个图表 + 退化输入契约（FR-19 ≥15 条测试）+ NetworkGraph 规模上限（FR-20）
A-7  预览宿主 + 快照排除策略 + 文档 + 署名收尾（ComponentData.swift 串行）
```
A-1~A-6 之间无依赖，可并发；A-7 依赖全部，且对 `App/Sources/ComponentData.swift` 的写入
必须串行化（见 D-5）。

**Epic B「Metal」**（28 个 shader）。**前置 = A0-5 ∧ A0-6 双双通过。**

```
B-1  CoreDesignShaders target + product + FR-2 选定路径落地（β 下含 3 份 metallib 与同步守卫）
B-2  17 个 colorEffect 背景（按 D-1 的复杂度分级分批：纯噪声 / 多 pass / 需 SDF）
B-3  11 个 layerEffect 内容层效果（含 FR-4 点名的 7 个"颜色写死"件的参数化改造）
B-4  署名（ACKNOWLEDGEMENTS.md）+ 文档 + 预览宿主 + 快照排除
```

⚠️ **密度校正**：本仓历史 epic 为 5–13 task、约 1 交付物/task。抽出 A0 后三个 epic 均落回
该区间。A-1（8 个）、A-2（16 种）、B-2（17 个）、B-3（11 个）在 ccpm 分解阶段仍须按上面
标注的分组再拆成多个 task。

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

## 评审响应台账（第 2 轮）

第 2 轮结论 REVISE（无阻断项）。以下逐条处置；所有被点名的事实断言我都独立复核过。

| 评审项 | 处置 |
|---|---|
| I-1（`swift test --filter` 不提供隔离） | **接受**。实测复现：`--filter` 只在运行期筛，SwiftPM 仍把整包编进一个 `PackageTests.xctest`。NFR-5 删掉该半句，改为「`CoreDesignTests` 依赖图不含新 target，`swift package describe` 可证」 |
| I-2（多 product 后 `-scheme CoreDesign` 硬红，非静默） | **接受**，且已本地复核：本仓当前 `xcodebuild -list` 只有一个 scheme `CoreDesign`（单 product 合并态）。NFR-6 由"两条路都有坑"改为**拍板选项②**（独立测试 target + `-scheme CoreDesign-Package`），并把切 scheme 写进 A0-2 的**同 commit 硬前置** |
| I-3（API 单位 35 应为 36） | **接受**。14 文件 = ChangeEffect 8 + Transition 16 + 其余 12 × 1 = 36；合计 68，SC-1 分母 40。单位定义改为「一**种** transition（含参重载算同一种）」 |
| I-4（23/5 应为 21/7） | **接受**，且实际比评审说的更糟：`GlassLogo` 有整套硬编码静态调色板（`SWGlassLogo.swift:95-122` 的 `coolBlue`/`orange`/`deepBlue`/`stripe`/`canvas`/`bloom`/`fresnelColor`），`LiquidMetal` 文件内唯一的 `Color` 是 Preview 里的 `Color.black`。7 个写死件**全是 `layerEffect`** ⇒ 已写进 D-1 第⑤问：spike 的 layerEffect 样本须取自这 7 个 |
| I-5（空 target + 闸归属 + 密度） | **接受**。拆为**三个 epic**：A0 地基与两闸 / A 效果与图表 / B Metal。`CoreDesignShaders` target 移入 B-1，A0 不建空 product；D-1 与 C-6 两闸都归 A0，B 读其结论决定启动 |
| I-6（C-6 无通过定义、SC-2 空真、堵死 clean-room） | **接受**。C-6 改**正向裁定表** `docs/shader-provenance.md`（5 字段 / 3 种裁定），显式给 clean-room 重写一个出口（Simplex/Voronoi/Plasma/Metaballs 属公开算法）；闸的通过 = 表覆盖 28 个无空行 ∧ 可落地 ≥ 7。SC-2 改为三条 AND |
| I-7（AD-4-a 内容为空 + 三 target 一刀切） | **接受**。AD-4 改为**按 target 分别裁决**，推荐 Charts 走 b（进登记表，47→51）、Effects/Shaders 走 a；补齐 AD-4-a 的四点内容骨架（继承什么/不继承什么/两条新守卫/独立 `docs/effects-registry.json` + 差集守卫）、成本量级（150–250 行）与裁决判据（两条路各取 2 样本实做估算） |
| I-8（TextParam 守不到 FR-7 的 A 类） | **接受**，且这是本轮最有价值的一条：公约 G-4 明载 A 类 chrome 文案**连 CoreDesign 自己都无机器判据**。US-5 该行改为「只守 B 类」，并新增 `ChromeTextLiteralGuard`（射程仅三个新 target，不回溯 CoreDesign） |
| I-9（metallib 分平台） | **接受**。FR-2 路径 β 改为 3 份 metallib + 平台选择 + `.metal` 源 `exclude:` + 同步守卫；NFR-2 明确「每平台 ≤ 2MB」；D-1 增第⑥问 |
| I-10（α/β 无裁决判据） | **接受**。FR-2 写死判据，并指出 α 的前提今天已知为假（`downstream-probe` 与下游 StoryUI CI 都是原生 `swift build`），α 的失败形态是运行时静默无渲染 ⇒ **β 为默认走向** |
| Sug（FR-20 抛断言 / NFR-7 "或文档" / Reduce Transparency 归属 / G-7 引用不准 / project.yml:34 / 本仓无 ACKNOWLEDGEMENTS / FR-19 实为 ≥15 条） | **全部接受**，逐处改正。G-7 那条我复核后确认引用确实不准，已改为直接引 `ComponentRegistryGuard.swift:366` |
| Preference（Transition 计数措辞） | **接受**（这是清晰性修正而非风格偏好） |
