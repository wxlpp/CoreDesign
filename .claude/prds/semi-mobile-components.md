---
name: semi-mobile-components
description: 参照 Semi Design 补齐移动端友好的通用组件，对齐 Semi 组件覆盖度中本库缺失且 SwiftUI/既有组件无等价物的 parity 缺口（10 组件 + 1 增强包）
status: backlog
created: 2026-07-25T08:07:53Z
---

# PRD: Semi 移动端通用组件补齐

> **v2 变更（经 superpowers-reviewer PRD 评审）**：原 12 组件清单中，**Typography** 与 **Spin** 按本库「不重造原生/既有」哲学（先例：EmptyState→`ContentUnavailableView`、ProgressBar→`.core`）被裁决为「parity 已达成」——Typography 出局（由 `.coreFont(_:)` + 原生 Text modifier 覆盖），Spin 降级为 `ProgressIndicator` 增强 + `spinning(_:)` modifier。最终交付 **10 个组件 + 1 个增强包**。

## Executive Summary

CoreDesign 目前有 24 个已收录组件 + 3 个 `.core` 控件 style。以 Semi Design 全量组件清单为参照做差集，去掉「SwiftUI 原生已覆盖」与「桌面向、不适合移动端」两类，剩下约 18 个 parity 缺口；再剔除「本库既有组件/原生 modifier 已达 parity」者，取移动端价值最高的 **10 个组件**纳入交付，另以 **1 个增强包**吸收 Spin 能力：

**组件（10）**：Skeleton · Steps · Timeline · Rating · PinCode · Radio · TagInput · Descriptions · FloatButton · Carousel
**增强包（1）**：`ProgressIndicator` 增加可选文案 + 新增 `spinning(_:)` 加载遮罩 modifier（吸收 Semi Spin 能力，不新造组件）

目标是让本库在「移动端通用组件覆盖度」上显著逼近 Semi，**借鉴 Semi 的能力集、实现对齐 Apple HIG / SwiftUI 惯例**，而非移植 Semi 的 Web 视觉；并严格遵守本库既有的分层色彩、token、公开 API、`.core`/style 协议、Swift Testing、`#Preview` 冒烟等房规。

## Problem Statement

**是什么问题**：本库虽已覆盖一批 Apple HIG 对齐组件，但相对 Semi 这类成熟通用库，仍缺少若干移动端高频、且 SwiftUI/既有组件无开箱等价物的组件（骨架屏、步骤条、时间线、评分、OTP 输入、标签输入、描述列表、FAB、走马灯）。下游遇到这些需求只能自行造轮子，脱离设计系统统一 token/色层/交互规范。

**为什么现在做**：库已至 0.6.0，色层地基（Apple HIG 语义色）、token、`.core` style 形态、`FlowLayout`、`StarShape`、glass modifier 等基础设施均已就位，补齐边际成本低、可大量复用地基，且组件彼此独立、适合并行交付。

## User Stories

下游 App 开发者（本库主要使用方）：

1. **加载态** — 用 `Skeleton` 占位、用 `ProgressIndicator`/`spinning(_:)` 表示进行中，给出统一加载体验。
   - 验收：`Skeleton` 以 `.redacted(reason: .placeholder)` 为基座 + shimmer 叠加 modifier，并提供独立 line/rect/circle 形状画廊；`spinning(_:)` modifier 可给任意视图叠加加载遮罩（spinner+可选文案），`ProgressIndicator` 增加可选文案参数。
2. **流程指引** — 用 `Steps` 展示多步流程、用 `Timeline` 展示按时间排列的事件。
   - 验收：`Steps` 支持横向/纵向、点状/数字，完成/当前态走 `.tint`、错误态走状态色层；`Timeline` 支持节点+连线+状态色与自定义节点/内容。
3. **输入类** — `Rating`（评分）、`PinCode`（验证码分格）、`Radio`（单选组）、`TagInput`（标签输入）。
   - 验收：均为受控（值 `Binding`）。`Rating` 用 `Binding<Double>`（半星以 0.5 步进，只读可配，复用 `StarShape`，取色走 `.tint`）；`PinCode` 用 `Binding<String>`，固定格数、安全掩码，iOS 上支持 `.textContentType(.oneTimeCode)` 短信验证码自动填充，填满回调；`Radio` 为单选组 `Binding<Selection>`（与库内既有 `CheckBox` 成对，视觉一致，**刻意提供 iOS 无原生等价的单选控件**，见 Constraints）；`TagInput` 用 `Binding<[String]>`，增删 token，复用 `FlowLayout` 折行。
4. **信息展示** — 用 `Descriptions` 展示键值对详情、用 `Carousel` 轮播内容。
   - 验收：`Descriptions` 以 **`.core` `LabeledContentStyle` + `InsetGroupedSection` 分组**实现（换皮不重造），支持 1/2 列与分隔密度；`Carousel` 支持自动轮播（可关）+ 页点指示 + 手势滑动，双端实现见 FR-11。

## Functional Requirements

**通用要求（FR-通用，每个交付物都必须满足）**：

- **FR-1 公开 API**：类型、`init`、`body` 均显式 `public`；受控组件以 `Binding` 暴露值。
- **FR-2 色彩来源**：仅用第 3/4 层语义 token 与既有 token 文件；**不得**硬编码第 1 层色相或字面 `Color`。占位/连线取色指定复用现成 token（见 FR-13）。
- **FR-3 强调色走 `.tint`**：主强调色表现经 `.tint` 通路，不写死 `Color.accent`。**例外（FR-3a）**：当实现包装系统 `ProgressView` 时，因 `.tint(_:)` 重载解析会落到 SwiftUI 环境 accent 而非本库 accent，**必须**显式写 `.tint(Color.accent)`——此为既有 `ProgressIndicator.swift` 已确立的模式，SC-5 静态核对对「包装 ProgressView 的文件」豁免此规则。
- **FR-4 形态优先级**：能复用系统 style 协议的走协议（`Descriptions`→`.core LabeledContentStyle`）；能用原生 modifier 达成的做成 modifier（`spinning(_:)`、Skeleton shimmer 叠加 `.redacted`）；否则才是独立组件。
- **FR-5 资源加载**：任何资源查找传 `bundle: .module`。
- **FR-6 `#Preview` 冒烟**：每个交付物同文件提供 `#Preview`（含 Light/Dark 或关键状态画廊）。
- **FR-7 测试**：以 Swift Testing 覆盖受控状态/边界/格式化逻辑（每个有可测逻辑者 ≥1 `@Test`）。**判定盲区**：`Tests/` 下 `#if os(iOS)` 的 suite 在 macOS 上是空 suite，`swift test` 通过为假绿——凡涉 iOS-only 行为的测试，以 CI 的 xcodebuild iOS Simulator 腿为准。
- **FR-8 文档**：每个交付物在 `docs/components/<name>.md` 落文档并登记进 `docs/README.md` 索引。**并行冲突规避（FR-8a）**：`docs/README.md` 索引更新与 `App/Sources/Previews.swift` 注册**一律集中到 Phase 3 收尾串行执行**（不采用 Phase 0 占位行方案），并行 Issue 各自只写自己的 `docs/components/<name>.md`，避免连环 merge 冲突。
- **FR-9 目录约定**：组件放 `Sources/CoreDesign/Components/<Name>/`；可复用 modifier 放 `Modifier/`；跨组件辅助放 `Utils/`；单组件辅助与组件同文件。

**各交付物能力集（借鉴 Semi，落地移动端）**：

- **FR-Skeleton**：`.redacted(reason: .placeholder)` 基座 + shimmer 叠加 modifier；line/rect/circle 独立形状可组合；`isLoading` 切换真实内容。
- **FR-Steps**：横/纵；点状/数字；完成/当前/未完成三段视觉，完成+当前走 `.tint`，错误态走 `StatusColors`；可选标题+描述。
- **FR-Timeline**：纵向节点+连线；节点状态色；自定义节点与右侧内容。
- **FR-Rating**：`Binding<Double>`；星数可配；只读；半星（0.5 步进）；复用 `StarShape`；`.tint` 取色；accessibility value/adjustable。
- **FR-PinCode**：`Binding<String>`；固定格数；安全掩码；iOS `.textContentType(.oneTimeCode)` + `.keyboardType(.numberPad)`（iOS-only API 以 `#if os(iOS)` 包裹，macOS 走等价 TextField 无 keyboardType）；填满回调。
- **FR-Radio**：单选组 `Binding<Selection>`；水平/垂直；与既有 `CheckBox` 视觉成对。
- **FR-TagInput**：`Binding<[String]>`；输入新增/删除 token；复用 `FlowLayout`。
- **FR-Descriptions**：`.core LabeledContentStyle` + `InsetGroupedSection` 分组；1/2 列；分隔密度。
- **FR-FloatButton**：图标（+可选文字）；复用 glass 按钮形态；调用方自定位（文档给出与 `.safeAreaBar`/`BottomInputBar` 的取舍边界与推荐 overlay 用法）。
- **FR-11 Carousel 双端**：统一采用 `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` + `scrollPosition(_:)` 的**单一跨端实现**（不做 iOS/macOS 双路径；macOS 无 `.page` style，故不用 `TabView(.page)`），避免单端符号（满足 NFR-2）。自动轮播用 `.task`/异步序列驱动 `scrollPosition`。
- **FR-PinCode 掩码**：安全掩码**可配**（`isSecure` 参数，默认关——OTP 场景常明文便于核对）。
- **FR-Descriptions 密度**：2 列在 accessibility 大字号（Dynamic Type）下塌成 1 列，避免键值挤压。
- **FR-12 增强包**：`ProgressIndicator` **新增一个带可选文案参数的 init/重载，保留现有 `init()`**（源码兼容，downstream-probe 可过）；新增 `Modifier/SpinningModifier.swift` 暴露 `View.spinning(_ isActive:text:)` 加载遮罩。
- **FR-13 共享地基（Phase 0 先行）**：占位底色指定复用 `FillColors`（systemFill 家族，占位标准色）；连线/分隔色指定复用 `BorderColors`/separator；shimmer 高亮色若无现成 token 则在 `FillColors`/`ContentColors` 补一个语义 token。Phase 0 单独 Issue 落地这些共享 token/辅助后，其余组件 Issue 才启动，避免并行抢改色层文件。**Phase 0 另需给 `scripts/run-snapshots.sh` 加保留库内 `#Preview` 副产物的开关**（如 `KEEP_LIBRARY_SNAPSHOTS=1` 跳过 `CoreDesign_*` 的删除行），否则并行阶段（NFR-5.1）逐 Issue 视觉评审拿不到截图。

## Non-Functional Requirements

- **NFR-1 平台**：iOS 26+ / macOS 26+，Swift 6 语言模式，完整严格并发（`Sendable` 干净、无并发告警）。
- **NFR-2 双端编译**：iOS 与 macOS 两端均可编译；平台差异用 `#if canImport(UIKit)`/`AppKit` 或 `#if os(iOS)` 桥接，**不留单端公开符号**（Carousel、PinCode 尤需遵守，见 FR-11/FR-PinCode）。
- **NFR-3 深浅色 + 动态字体**：随系统外观/对比度自动更新；文本相关组件支持 Dynamic Type。
- **NFR-4 无障碍**：交互组件提供合理 accessibility label/trait/value（Rating adjustable、PinCode、Radio、FloatButton 尤其）。
- **NFR-5 验证完备（覆盖本仓库验证盲区）**：除 `swift build`+`swift test` 外——
  1. **视觉评审机制（并行阶段 vs 收尾）**：`run-preview.sh` 只能截到已注册进预览宿主 `App/Sources/Previews.swift` 的组件，而该注册按 FR-8a/NFR-5.4 集中收尾。故**并行阶段**：各组件 Issue 以库内 `#Preview` 的 snapshot 副产物（`scripts/run-snapshots.sh` 生成、暂存不提交）交 ios-visual-reviewer 逐 Issue 评审；**Phase 3 收尾**：统一注册 `Previews.swift` 页并跑 `run-preview.sh` 在真机宿主内批量复查，SC-6 的整体「无 BLOCK」以此为准。`Previews.swift` 与 `docs/README.md` 同属集中串行改动，不在并行 Issue 中各自编辑。
  2. 新增 colorset 后必须 `swift package clean` 再构建/测试（增量构建不拷新目录，静默失败）；
  3. 改/删公开符号需同步 `scripts/downstream-probe` 与 `App/` 预览宿主（本 PRD 纯新增，风险低但仍需确认预览宿主可构建）；
  4. **worktree + xcodegen 盲区**：并行 Issue 各在私有 worktree，若需 `xcodegen generate` 注册新预览页，会把 `App/project.yml` 的 package `name` 按目录名写坏并清空 scheme——按 `App/project.yml` 顶部注释恢复；优先避免在 worktree 内跑 xcodegen，把预览宿主页注册集中到收尾。
- **NFR-6 无破坏性**：纯新增，不改动/移除现有公开符号（`ProgressIndicator` 增强按 FR-12：新增带文案参数的 init/重载、保留现有 `init()`，不改现有签名）；需新增第 3/4 层 token 时补进对应色层文件而非改现有语义。

## Success Criteria

- **SC-1**：10 组件 + 增强包全部实现并 `public` 导出；`swift build` 与 `swift test` 全绿，CI 的 iOS Simulator 腿与 downstream-probe job 均通过。
- **SC-2**：每个交付物 ≥1 个 `#Preview`，且预览宿主可构建并渲染。
- **SC-3（按成员计，不绑总数）**：每个交付物（Skeleton/Steps/Timeline/Rating/PinCode/Radio/TagInput/Descriptions/FloatButton/Carousel/增强包）各自有：源码 + `#Preview` + `docs/components/<name>.md` + `docs/README.md` 索引登记。Typography 以墓碑文档记录「用 `.coreFont` + 原生 Text modifier」的迁移指引。
- **SC-4**：受控/格式化逻辑有 Swift Testing 覆盖（每个有可测逻辑者 ≥1 `@Test`）；iOS-only 行为以 iOS Simulator 腿为准。
- **SC-5**：静态核对——组件源码内无第 1 层色相硬编码、无字面 `Color.accent`（**FR-3a 例外：包装 ProgressView 的文件豁免**）。
- **SC-6**：ios-visual-reviewer 对新组件截图给出「无 BLOCK 级」结论。

## Constraints & Assumptions

- **借鉴而非移植**：对齐 Semi 的能力集，视觉/交互对齐 Apple HIG / SwiftUI；不复制 Web 像素级样式。
- **Radio 的 HIG 取舍**：iOS HIG 无原生 radio（惯例用 checkmark list / `Picker`），但库内已有同样非 HIG 原生的 `CheckBox`——`Radio` 作为其单选对偶提供，视觉与 `CheckBox` 成对，**这是刻意的既有先例延续，非疏漏**；视觉评审据此标准而非「必须 HIG 原生」评判。macOS 原生 `.pickerStyle(.radioGroup)` 因需与 `CheckBox` 跨端视觉成对一致而不采用。
- **复用现有地基**：`StarShape`（Rating）、`FlowLayout`（TagInput）、glass modifier（FloatButton）、`.core`/`LabeledContentStyle`（Descriptions）、`.redacted`（Skeleton）、现有色层/token。
- **并行交付 + Phase 0 先行**：Phase 0 落地共享 token/辅助（FR-13）；之后 10 组件拆并行 Issue；`docs/README.md` 与预览宿主注册集中收尾串行（Phase 3），规避 merge/xcodegen 冲突。
- **假设**：现有色层足够支撑绝大多数取色，预计仅 shimmer 高亮 1 个新增语义 token；此假设在 Phase 0 验证，若不成立则在 Phase 0 补齐。

## Out of Scope

- **本次裁决出局**：Typography（parity 由 `.coreFont` + 原生达成，仅留墓碑文档）；Spin 独立组件（能力并入 ProgressIndicator 增强 + `spinning(_:)`）。
- **Tier 2（本次不做）**：InputNumber、Image、Notification、Pagination、AutoComplete、Upload。
- **Tier 3（排除）**：Breadcrumb、BackTop、Tooltip、Highlight、Calendar、UserGuide。
- **原生已覆盖（不做）**：Layout/Grid/Space、Slider/Switch/Select/ColorPicker/DatePicker/TimePicker、Modal/SideSheet/Popover/Dropdown/Popconfirm/Collapsible、Collapse（`DisclosureGroup .core`）、Empty（`ContentUnavailableView`）。
- **桌面向（排除）**：Table、Cascader、Transfer、TreeSelect、Tree、Anchor、OverflowList、Resizable、Cropper。
- **不做**：主题/多语言 Provider、Web 视觉像素级还原、Semi 图标集移植（iOS 用 SF Symbols）。

## Dependencies

- **现有代码资产**：`Shape/StarShape.swift`、`Layout/FlowLayout.swift`、`Modifier/FloatingGlassModifier.swift` 及各 glass modifier、`Modifier/CoreFontModifier.swift`（Typography 裁决依据）、`Components/ProgressIndicator/ProgressIndicator.swift`（增强目标 + FR-3a 依据）、`Components/InsetGroupedSection/`、`Components/Form/Form.swift`（`LabeledContent` 用法参照）、`Colors/*`（第 3/4 层，含 `FillColors`/`BorderColors`）、`Tokens/*`、`Components/Style/*`（`.core` 形态参照）、`Components/CheckBox/`（Radio 对偶参照）。
- **验证基础设施**：`scripts/run-preview.sh`、`scripts/run-snapshots.sh`、`scripts/downstream-probe`、`App/CoreDesignPreview.xcodeproj`（+ `App/project.yml` worktree 警告）、CI 的 iOS Simulator + downstream-probe job。
- **流程**：ccpm（Epic 分解 → Phase 0 先行 Issue + 10 并行组件 Issue + Phase 3 收尾串行 Issue）、superpowers 内环（每 Issue worktree → plan → TDD → 评审 → PR）、superpowers-reviewer、auto-fix-pr。
- **外部参照**：Semi Design 组件清单与能力集（https://semi.design/zh-CN）——仅作能力参照，不引入其代码/资源。
