---
name: semi-mobile-components
description: 参照 Semi Design 补齐 12 个移动端友好的通用组件，对齐 Semi 组件覆盖度中本库缺失且 SwiftUI 无原生等价物的 parity 缺口
status: backlog
created: 2026-07-25T08:07:53Z
---

# PRD: Semi 移动端通用组件补齐（Tier 1 · 12 组件）

## Executive Summary

CoreDesign 目前有 24 个已收录组件 + 3 个 `.core` 控件 style。以 Semi Design 全量组件清单为参照做差集后，去掉「SwiftUI 原生已覆盖」（Layout/Grid/Slider/Switch/DatePicker/Modal/Popover 等）与「桌面向、不适合移动端」（Table/Cascader/Transfer/Tree/Resizable 等）两类，剩下约 18 个真正的 parity 缺口。本 PRD 取其中移动端价值最高、无原生等价物的 **12 个**（Tier 1）纳入交付：

Typography · Skeleton · Steps · Timeline · Rating · PinCode · Radio · TagInput · Descriptions · FloatButton · Carousel · Spin

目标是让本库在「移动端通用组件覆盖度」上显著逼近 Semi，同时严格遵守本库既有的分层色彩、token、公开 API、`.core`/style 协议、Swift Testing、`#Preview` 冒烟等房规——即「借鉴 Semi 的组件形态与能力集，实现方式对齐 Apple HIG / SwiftUI 惯例」，而非移植 Semi 的 Web 视觉。

## Problem Statement

**是什么问题**：本库虽已覆盖 Apple HIG 对齐的一批组件，但相对 Semi 这类成熟通用组件库，仍缺少若干移动端高频、且 SwiftUI 无开箱即用等价物的通用组件（加载态骨架/Spin、步骤条、时间线、评分、OTP 输入、标签输入、描述列表、FAB、走马灯、文本排版系统）。下游使用方遇到这些需求时只能自行造轮子，脱离设计系统的统一 token / 色层 / 交互规范。

**为什么现在做**：库已进入 0.6.0，色层地基（Apple HIG 语义色）、token（间距/圆角/字号/描边/高度）、`.core` style 形态、FlowLayout、StarShape 等基础设施均已就位，补齐这批组件的边际成本低、可大量复用现有地基，且彼此独立、适合并行交付。

## User Stories

下游 App 开发者（本库的主要使用方）：

1. **加载态** — 作为开发者，我希望在数据未就绪时用 `Skeleton` 占位、用 `Spin` 表示进行中，从而给出统一的加载体验。
   - 验收：`Skeleton` 提供行/块/圆形等基本形状与 shimmer 动画；`Spin` 支持内联与遮罩（包裹内容）两种形态，可附文案。
2. **流程指引** — 作为开发者，我希望用 `Steps` 展示多步流程进度、用 `Timeline` 展示按时间排列的事件。
   - 验收：`Steps` 支持横向/纵向、点状/数字、已完成/当前/未完成三态配色；`Timeline` 支持节点+连线+状态色与自定义节点内容。
3. **输入类** — 作为开发者，我希望有 `Rating`（评分）、`PinCode`（验证码分格）、`Radio`（单选组）、`TagInput`（标签输入）这些 Semi 有而 SwiftUI 无成品的输入控件。
   - 验收：均为受控组件（值 `Binding`）；`Rating` 支持只读/半星/自定义数量并复用 `StarShape`；`PinCode` 支持固定格数、键盘类型、安全模式；`Radio` 为 Semi 风格单选组（区别于原生 `Picker`）；`TagInput` 支持增删 token。
4. **信息展示** — 作为开发者，我希望用 `Descriptions` 展示键值对详情、用 `Carousel` 轮播内容、用 `Typography` 统一文本排版。
   - 验收：`Descriptions` 成组渲染 label/value，支持列数/分隔；`Carousel` 支持自动轮播+页点指示；`Typography` 提供标题/正文/文本变体 + 尺寸/字重/省略(ellipsis)/可复制/链接能力。
5. **主操作** — 作为开发者，我希望用 `FloatButton`（FAB）承载页面主操作，符合 iOS 26 glass 观感。
   - 验收：`FloatButton` 复用现有 glass modifier / 按钮形态，支持定位与图标+可选文字。

## Functional Requirements

每个组件必须满足的通用功能要求（FR-通用）：

- **FR-1 公开 API**：类型、`init`、`body` 均显式 `public`；受控组件以 `Binding` 暴露值。
- **FR-2 色彩来源**：仅使用第 3/4 层语义 token（`SurfaceColors`/`ContentColors`/`BorderColors`/`FillColors`/`StatusColors`/`FunctionalColor` 等）与既有 token 文件（`CoreSpacing`/`CoreRadius`/`CoreTypography`/`CoreBorderWidth`/`CoreElevation`），**不得**在组件中硬编码第 1 层色相或字面 `Color`。
- **FR-3 强调色走 `.tint`**：任何「主强调色」表现必须经 `.tint`/`InteractionColors.accent` 通路，不写死 `Color.accent`，以便调用方 `.tint(_:)` 生效。
- **FR-4 style 形态**：若组件有多外观诉求，优先复用系统 style 协议形态（如 `Rating` 之于原生无对应则自定义；能挂 `.core` 的走 `.core`）；否则以 `View` 扩展 modifier 暴露入口，不要求调用方写 `.modifier(...)`。
- **FR-5 资源加载**：任何资源查找传 `bundle: .module`。
- **FR-6 `#Preview` 冒烟**：每个组件同文件提供 `#Preview`（含 Light/Dark 或关键状态画廊），作为视觉冒烟。
- **FR-7 测试**：以 Apple Swift Testing（`import Testing`/`@Test`/`#expect`）为逻辑可测部分（受控状态、边界、格式化）补测；纯视觉部分以 Preview 覆盖。
- **FR-8 文档**：每个组件在 `docs/components/<name>.md` 落一份文档并登记进 `docs/README.md` 组件索引对应分类。
- **FR-9 目录约定**：组件放 `Sources/CoreDesign/Components/<Name>/<Name>.swift`；可复用 modifier 放 `Modifier/`，跨组件辅助放 `Utils/`，单组件辅助与组件同文件。

各组件的能力集（借鉴 Semi，落到移动端）：

- **Typography**：文本变体（标题/正文/次要文本）× 尺寸/字重；`.ellipsis`（截断）、`copyable`（可复制）、`link`、`mark/强调`。
- **Skeleton**：line / rect / circle 基本形状 + 组合；shimmer 动画；`isLoading` 切换真实内容。
- **Steps**：横向/纵向；点状/数字；三态（完成/当前/未完成）配色（状态色层）；可选标题+描述。
- **Timeline**：纵向节点+连线；节点状态色；自定义节点内容与右侧内容。
- **Rating**：`Binding<Double/Int>`；星数可配；只读；半星；复用 `StarShape`；`.tint` 取色。
- **PinCode**：`Binding<String>`；固定格数；键盘类型；安全（掩码）模式；填满回调。
- **Radio**：单选组 `Binding<Selection>`；水平/垂直排列；Semi 风格圆点（区别于原生 `Picker`）。
- **TagInput**：`Binding<[String]>`；输入新增、删除已有 token；复用 `FlowLayout` 折行。
- **Descriptions**：数据驱动 label/value 组；列数（1/2）；行/无分隔；紧凑/常规密度。
- **FloatButton**：图标（+可选文字）；复用现有 glass 按钮形态；调用方自行定位（提供推荐 overlay 用法）。
- **Carousel**：分页内容；自动轮播（可关）+ 间隔；页点指示器；手势滑动。
- **Spin**：内联 spinner + 可选文案；`spinning(_:)` modifier 遮罩包裹任意内容（加载蒙层）。

## Non-Functional Requirements

- **NFR-1 平台**：iOS 26+ / macOS 26+，Swift 6 语言模式，完整严格并发（`Sendable` 干净、无并发告警）。
- **NFR-2 双端编译**：所有组件在 iOS 与 macOS 两端均可编译（平台差异用 `#if canImport(UIKit)`/`AppKit` 桥接，不留单端符号）。
- **NFR-3 深浅色 + 动态字体**：随系统外观自动更新（源于 FR-2 的系统语义色）；文本组件支持 Dynamic Type。
- **NFR-4 无障碍**：交互组件提供合理的 accessibility label/trait（Rating/PinCode/Radio/FloatButton 尤其）。
- **NFR-5 验证完备**：交付需覆盖本仓库验证盲区——`swift build`+`swift test` 之外，UI/视觉改动跑预览宿主截图交视觉评审；新增 colorset 需 `swift package clean`；改公开符号需同步 `scripts/downstream-probe` 与 `App/` 预览宿主。
- **NFR-6 无破坏性**：纯新增，不改动/移除现有公开符号；若需新增第 3/4 层 token 则补进对应色层文件而非改现有语义。

## Success Criteria

- **SC-1**：12 个组件全部实现并 `public` 导出；`swift build` 与 `swift test` 全绿，CI 的 iOS Simulator 腿与 downstream-probe job 均通过。
- **SC-2**：每个组件至少 1 个 `#Preview`，且预览宿主（`scripts/run-preview.sh`）可构建并渲染。
- **SC-3**：每个组件一份 `docs/components/<name>.md` 且登记进 `docs/README.md` 索引；组件总数由 24 → 36。
- **SC-4**：受控/格式化逻辑有 Swift Testing 覆盖（每个有可测逻辑的组件 ≥1 个 `@Test`）。
- **SC-5**：静态核对——组件源码内无第 1 层色相硬编码、无字面 `Color.accent`（强调色走 `.tint`）。
- **SC-6**：视觉评审（ios-visual-reviewer）对新组件截图给出「无 BLOCK 级」结论。

## Constraints & Assumptions

- **借鉴而非移植**：对齐的是 Semi 的「组件形态与能力集」，视觉与交互对齐 Apple HIG / SwiftUI 惯例；不复制 Semi 的 Web 像素级样式。
- **复用现有地基**：优先复用 `StarShape`（Rating）、`FlowLayout`（TagInput）、glass modifier（FloatButton）、`.core` style 形态、现有色层/token；缺 token 时补进对应色层文件。
- **并行交付**：12 个组件彼此独立，可拆为并行 Issue；共享地基（若需新增 token/modifier）先行落地以免相互阻塞。
- **假设**：现有色层已足够支撑绝大多数取色；预计仅少量新增语义 token（如 Skeleton 占位底色、Steps/Timeline 连线色）。

## Out of Scope

- **Tier 2（本次不做）**：InputNumber、Image、Notification、Pagination、AutoComplete、Upload。
- **Tier 3（排除）**：Breadcrumb、BackTop、Tooltip、Highlight、Calendar、UserGuide。
- **原生已覆盖（不做）**：Layout/Grid/Space、Slider/Switch/Select/ColorPicker/DatePicker/TimePicker、Modal/SideSheet/Popover/Dropdown/Popconfirm/Collapsible、Collapse（DisclosureGroup `.core`）、Empty（`ContentUnavailableView`）。
- **桌面向（排除）**：Table、Cascader、Transfer、TreeSelect、Tree、Anchor、OverflowList、Resizable、Cropper。
- **不做**：主题/多语言 Provider、Semi 的 Web 视觉像素级还原、Semi 图标集移植（iOS 用 SF Symbols）。

## Dependencies

- **现有代码资产**：`Shape/StarShape.swift`、`Layout/FlowLayout.swift`、`Modifier/FloatingGlassModifier.swift` 及各 glass modifier、`Colors/*`（第 3/4 层）、`Tokens/*`、`Components/Style/*`（`.core` 形态参照）。
- **验证基础设施**：`scripts/run-preview.sh`、`scripts/run-snapshots.sh`、`scripts/downstream-probe`、`App/CoreDesignPreview.xcodeproj`、CI 的 iOS Simulator + downstream-probe job。
- **流程**：ccpm（Epic 分解 → GitHub Issues）、superpowers 内环（每 Issue worktree → plan → TDD → 评审 → PR）、superpowers-reviewer 评审、auto-fix-pr。
- **外部参照**：Semi Design 组件清单与能力集（https://semi.design/zh-CN）——仅作能力参照，不引入其代码/资源。
