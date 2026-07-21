---
name: coredesign-native-refresh
description: 把 CoreDesign 的设计地基从 GitHub Primer 重铸为 Apple HIG（SF 文本样式 / 连续与同心圆角 / 44pt 触控 / 系统语义色），删除 6 个 GitHub 专用组件与 Blossom 主题，补齐 iOS 分组设置行、基础容器与系统组件 style 套件，并清理源码中的内部审计注释；本 PRD 在 structure 阶段拆为 2 个独立 epic
status: backlog
created: 2026-07-21T14:43:48Z
---

# CoreDesign 原生化改造 / Native Refresh

## Executive Summary

CoreDesign 是一个面向 iOS 26+ / macOS 26+ 的 SwiftUI 设计系统库。它当前的 token 地基是 **GitHub Primer**——web 血统的字号阶（40/32/20/16/14/12 固定 pt）、web 尺度的圆角（3/4/6/8/12）、桌面尺度的控件高度（regular = 32pt）。这套地基让基于它构建的 iOS 界面呈现出稳定的"网页控件"观感，无法与 iOS 系统 UI 融为一体。

本次改造把地基整体换成 Apple HIG：字体改用 SF 文本样式（原生 Dynamic Type）、圆角改用 Apple 尺度并引入 iOS 26 的 `ConcentricRectangle` 同心圆角、控件高度对齐 44pt 触控下限、语义色重新指向系统色。同时清理三类历史包袱：6 个只服务于「GitHub Issue 时间线」场景的专用组件、与原生观感相冲突的 Blossom 珊瑚粉主题、以及散落在 15+ 源文件中的内部审计编号注释。地基稳定后，补齐 iOS 应用真正高频需要而系统未直接提供的组件：分组设置行体系、基础容器与分隔件、以及给系统控件（`Toggle` / `TextField` / `ProgressView` / `Label` / `DisclosureGroup`）配套的 CoreDesign style。

交付分两个阶段，各对应一个 epic：Phase 1「地基」发 `0.3.0`，Phase 2「新组件」发 `0.4.0`。

## Problem Statement

### 观感问题的根因在 token 层，不在组件层

调用方反馈"用 CoreDesign 搭出来的界面不像 iOS app"。逐个组件调外观解决不了这个问题，因为偏差是系统性的、来自共享的 token 定义：

- **字体**：`CoreTypography` 逐项对齐 Primer 的 `text.*` 标度，用 `Font.system(size:)` 固定字号 + 手工推导的 `lineSpacing` 补偿（`fontSize * (lineHeightMultiplier - 1)`）。iOS 原生文字是 SF 文本样式，自带正确 leading 与 Dynamic Type 斜率。当前实现为了在固定字号下模拟 Dynamic Type，引入了 `@ScaledMetric` 包装、`scales: Bool` 开关与 `fixedFont` 逃生口——一整套仅存在于"绕开 Primer"这个目的的脚手架。
- **圆角**：`CoreRadius.medium = 6pt` 是按钮与输入框的默认值。iOS 同类控件在 10–14pt 区间。6pt 圆角是"网页感"最直接的来源。此外 `smallPlus = 4` / `mediumPlus = 8` 两档是为填补 Primer 标度空隙而设，在 Apple 尺度下没有对应语义。
- **控件高度**：`CoreControlMetrics.height(for: .regular) = 32pt`，注释明写"对应 Primer `control.medium.size`，是 GitHub 桌面 UI 默认按钮高度"。**低于 HIG 规定的 44pt 最小触控目标**，这既是观感问题也是可用性问题。
- **颜色**：语义层（`SurfaceColors` / `ContentColors` / `BorderColors`）基于自有的 17 色相 × 10 色阶调色板，而非系统语义色。用户在系统层调整外观时，界面不跟随。

### 组件清单里有一整组不通用的专用件

`BookCover`（书籍封面）、`RefPill`（git 分支 / commit 引用）、`StatusRow`（CI 检查结果，"Passed"/"Failed" 文案写死）、`EventRow`（活动流条目）、`CommentCard` + `TimelineItem`（Issue 评论时间线）——这 6 个组件共同服务于「GitHub Issue 页面」这一个场景。它们在通用设计系统里是死重，且其实现本身是 Primer 观感的集中体现（低圆角、无材质、web 密度），留着会持续拖慢原生化。

### Blossom 主题与"与系统融为一体"的目标相冲突

`Blossom` package trait 提供珊瑚粉糖果渐变主题，靠 8 处 `#if Blossom` 分流 + 独立色板实现。"强品牌色渐变皮肤"与"跟随系统外观"是两个方向的产品目标；同时维护双主题会让每个新组件的工作量与验证矩阵翻倍。

### 源码注释里混入了不该进源码的内容

15+ 个源文件的注释携带内部流程编号：`（审计项 B7a）`、`Issue #93`、`epic ADR #9`、`per epic ADR #16，PR description 必填字段`。这些是 git 历史与项目管理制品，读者（含库的下游使用者，因为 `///` 会进 Xcode Quick Help）无从理解。此外文档注释中英混排——同一段注释前半英文后半中文，且英文段落多是 Primer 时期的遗留描述（如 `Native Primer comment card.`）。

## User Stories

### US-1 · 应用开发者：搭出来的界面与系统一致

**作为**使用 CoreDesign 构建 iOS 应用的开发者，
**我希望**用库里的组件搭出的界面在字号、圆角、触控尺寸、配色上与系统 app 一致，
**以便**用户感觉不到第三方 UI 库的存在。

验收标准：
- 库中所有文字通过 SF 文本样式渲染，随用户 Dynamic Type 设置缩放，无需库侧额外缩放逻辑。
- 所有交互控件在 `.regular` 控件尺寸下的可点击高度 ≥ 44pt。
- 所有圆角矩形使用 `.continuous` 角样式；嵌套在容器中的元素使用 `ConcentricRectangle` 与容器同心。
- 语义色 token 在系统外观（浅色/深色、增强对比度）变化时自动跟随，无需调用方介入。
- 视觉评审（`ios-visual-reviewer` 基于真机/模拟器截图）判定整体观感为"原生"。

### US-2 · 应用开发者：不用手搓 iOS 设置页

**作为**需要做设置页 / 个人资料页 / 偏好面板的开发者，
**我希望**库直接提供 iOS 分组列表的行与分组容器，
**以便**不必每个项目重写一遍圆角分组、分隔线 leading 对齐、图标方块着色这些细节。

验收标准：
- `InsetGroupedSection` 提供带页眉/页脚的圆角分组容器，视觉与 iOS 设置一致。
- `SettingsRow` 支持：图标方块（可着色）、标题、可选副标题，尾部可挂 value 文本 / chevron / `Toggle` / 任意自定义视图。
- 同一分组内相邻行之间的分隔线自动从图标右缘起始（leading inset 对齐），无需调用方计算。
- 行高在默认 Dynamic Type 下 ≥ 44pt，并随字号增大而增高（不裁切）。

### US-3 · 应用开发者：系统控件也有统一外观

**作为**开发者，
**我希望**在用 SwiftUI 原生 `Toggle` / `TextField` / `ProgressView` / `Label` / `DisclosureGroup` 时也能套上 CoreDesign 的外观，
**以便**不必在"用系统控件但外观不统一"和"重造一个组件"之间二选一。

验收标准：
- 提供 `.toggleStyle(.core)` / `.textFieldStyle(.core)` / `.progressViewStyle(.core)` / `.labelStyle(.core)` / `.disclosureGroupStyle(.core)`。
- 这些 style 保留系统控件的全部原生行为（可访问性、键盘、状态绑定），只改视觉。
- 库不重新实现这些控件本身。

### US-4 · 库维护者：源码只讲代码的事

**作为**维护或阅读这个库源码的人，
**我希望**注释解释代码为什么这么写，而不是引用我看不到的审计编号和 epic 决策记录，
**以便**不用翻项目管理系统就能读懂源码。

验收标准：
- 源码中不存在 `审计项`、`Issue #<n>`、`epic ADR #<n>`、`PR description` 等内部流程引用。
- `///` 文档注释统一中文，技术术语保留英文原词（Dynamic Type、Liquid Glass、`ConcentricRectangle` 等不硬译）。
- 解释"为何这么写"的设计说明予以保留（如 `strokeBorder` vs `stroke` 的取舍、`BottomInputBar.autoFocus` 的时序说明）。

### US-5 · 下游 any-writer：破坏性变更可控

**作为** CoreDesign 的下游使用者，
**我希望**破坏性变更被完整记录且一次性发生，
**以便**能在一次升级中完成跟进，而不是分散在多个版本里反复改。

验收标准：
- 所有删除的公开符号与改名的 token 在 `docs/BREAKING-CHANGES.md` 中列出，每项给出替代方案。
- 提供下游编译探针结果，确认破坏面已被完整识别。

## Functional Requirements

### FR-1 · 字体 token 重铸

`CoreTypography` 的 token 语义改为 Apple 文本样式，实现改为 `Font.system(_:)` 直接取系统文本样式：

| 现 token | 新 token | 映射 |
|---|---|---|
| `displayLarge` (40 medium) | `largeTitle` | `.largeTitle` (34) |
| `titleLarge` (32 semibold) | `title` | `.title` (28) |
| `titleMedium` (20 semibold) | `title2` | `.title2` (22) |
| `subtitle` (20 regular) | `title3` | `.title3` (20) |
| `titleSmall` (16 semibold) | `headline` | `.headline` (17 semibold) |
| `bodyLarge` (16) | `body` | `.body` (17) |
| `bodyMedium` (14) | `callout` | `.callout` (16) |
| — | `subheadline` | `.subheadline` (15) |
| `bodySmall` (12) | `footnote` | `.footnote` (13) |
| `caption` (12) | `caption` | `.caption` (12) |
| `captionMono` (12 mono) | `captionMono` | `.caption` monospaced |
| `captionSmall` (9, 不缩放) | `caption2` | `.caption2` (11) |

连带移除：`@ScaledMetric` 缩放机制、`lineSpacing` 推导与全部 `*LineSpacing` / `*Tracking` 常量、`Spec.scales` 开关、`Token.fixedFont`。`.coreFont(_:)` 调用形态保留。

### FR-2 · 圆角 token 重铸

`CoreRadius` 改为 `none 0 / small 6 / medium 10 / large 16 / xLarge 22`；删除 `smallPlus` (4) 与 `mediumPlus` (8)。

库内所有 `RoundedRectangle` 显式使用 `style: .continuous`。嵌套在已知容器内的元素改用 `ConcentricRectangle`（iOS 26+，`Edge.Corner.Style.concentric`），使内层圆角与外层容器同心；容器侧按需声明 `.containerShape(_:)`。

### FR-3 · 控件尺寸 token 重铸

`CoreControlMetrics.height(for:)` 改为 `mini 28 / small 32 / regular 44 / large 50 / extraLarge 56`，`.regular` 满足 HIG 44pt 触控下限。纵横 padding 相应调整。删除 `primerVerticalPadding(for:)` 逃生口。

### FR-4 · 语义色重新指向系统色

第 3 层语义 token 在存在 Apple 对应物时改为指向系统色：

- `surfaceCanvas` → `systemGroupedBackground`
- `surfaceRaised` → `secondarySystemGroupedBackground`
- `borderDefault` / `borderSubtle` → `separator` / `opaqueSeparator`
- `contentPrimary` / `contentSecondary` / `contentTertiary` → `label` / `secondaryLabel` / `tertiaryLabel`
- `accent` → 系统强调色（`tint`），可被调用方 `.tint(_:)` 覆盖

第 1 层 `ColorGrade` 调色板保留作内部构造原料，继续为 `StatusColors` 等无系统对应物的 token 供色。

### FR-5 · 阴影层级

`CoreElevation` 保持 resting 档近乎平坦，层级主要由 material（`.regularMaterial` 等）与 separator 表达，与 iOS 惯例一致。`.large` 档保留给真正的浮层（popover / 菜单 / toast）。

### FR-6 · 删除 GitHub 专用组件

删除 `BookCover`、`RefPill`、`StatusRow`、`EventRow`、`CommentCard`、`TimelineItem` 六个组件，及其测试、文档页、快照与组件索引条目。`StatusResult` / `StatusLevel` 等仅服务于这些组件的附属类型一并评估删除。

### FR-7 · 删除 Blossom 主题

删除 `Package.swift` 的 `traits:` 声明、8 处 `#if Blossom` 分流、`Resources.xcassets/blossom-brand/*` 与 `blossom-canvas/*` 色板、`BlossomColorDivergenceTests`，以及 CI 中的 `--traits Blossom` 双构建。

### FR-8 · 删除 CoreGradient

`CoreGradient.brand / cta / canvas` 存在的唯一理由是让 Blossom 拥有渐变而默认主题退化为纯色。Blossom 移除后，三个 token 退化为"纯色包一层 `AnyShapeStyle`"，构成净负担。删除 `CoreGradient.swift` 与 `CoreGradient+Preview.swift`，调用点改为直接使用语义色。

### FR-9 · 注释清理

- 删除全部内部流程引用：`（审计项 X）`、`Issue #<n>`、`epic ADR #<n>`、`per epic ...`、`PR description 必填字段` 等。
- `///` 文档注释统一中文；技术术语保留英文原词。
- 文件头去除 `Source of truth: docs/PRIMER_VERSION.md`。
- 删除 Primer 考据段落（token 数值出处、`lineSpacing` 推导公式、Primer 标度对照），替换为 Apple HIG 依据。
- 保留解释设计取舍与非显然约束的注释。

### FR-10 · 新增分组设置行体系

`InsetGroupedSection`（圆角分组容器，可选页眉/页脚）+ `SettingsRow`（图标方块 + 标题 + 可选副标题 + 尾部 accessory）。尾部 accessory 至少支持：value 文本、chevron、`Toggle`、任意自定义视图。分隔线自动按图标右缘做 leading inset。

### FR-11 · 新增基础容器与分隔件

`Card`（统一卡片容器）、`Separator(inset:)`（可控 inset 的分隔线）、`SectionHeader` / `SectionFooter`。

### FR-12 · 新增系统控件 style 套件

为 `Toggle` / `TextField` / `ProgressView` / `Label` / `DisclosureGroup` 各提供一个 CoreDesign style，按 SwiftUI 惯例经对应 style 协议上的静态成员 `.core` 暴露（`.toggleStyle(.core)` 等）。不重新实现控件本身。

### FR-13 · 文档与版本

- `docs/PRIMER_VERSION.md` 替换为 `docs/DESIGN-FOUNDATION.md`（记录 Apple HIG 依据与 token 取值理由）。
- `docs/README.md` 组件索引与快照同步更新。
- `docs/BREAKING-CHANGES.md` 记录全部删除符号与改名 token，每项给出替代方案。
- Phase 1 发 `0.3.0`，Phase 2 发 `0.4.0`；README 的版本 pin 同步。

## Non-Functional Requirements

- **平台与语言**：维持 iOS 26+ / macOS 26+、Swift 6 语言模式与完整严格并发检查；`swiftSettings: [.defaultIsolation(MainActor.self)]` 不变。
- **可访问性**：所有文字随 Dynamic Type 缩放（`caption2` 不再例外）；交互元素满足 44pt 触控下限；在最大辅助功能字号下布局不裁切、不重叠。库内现有的 `DynamicTypeLayoutTests` 需覆盖新 token。
- **测试**：继续使用 Swift Testing（`import Testing` / `@Test` / `#expect`），不引入 XCTest。删除组件的测试一并删除；新增组件配套测试。
- **预览**：每个组件保留同文件内的 `#Preview`，作为视觉冒烟检查。
- **资源加载**：所有资源查找继续传 `bundle: .module`。
- **公开 API 表面**：新增类型、init、`body` 显式标 `public`。
- **构建**：`swift build` 与 `swift test` 均需通过；Blossom 移除后不再需要双 trait 构建。

## Success Criteria

1. `swift build` 与 `swift test` 全绿（两阶段各自收尾时）。
2. `grep -rE "审计项|Issue #[0-9]+|epic ADR" Sources` 返回 0 行。
3. `grep -rn "RoundedRectangle(cornerRadius:" Sources` 的每一处都带 `style: .continuous`（或已改用 `ConcentricRectangle`）。
4. `CoreControlMetrics.height(for: .regular) >= 44`，且库内所有交互组件在 `.regular` 下实测可点击高度 ≥ 44pt（测试覆盖）。
5. `CoreTypography` 中不存在 `Font.system(size:)` 固定字号调用（`Canvas` 等命令式绘制场景若确需，单独记录理由）。
6. `Sources` 中 `#if Blossom` 出现 0 次，`CoreGradient` 符号 0 引用。
7. 库中删除的 6 个组件在 `Sources` / `Tests` / `docs` 中 0 残留引用。
8. `ios-visual-reviewer` 基于模拟器截图的视觉评审结论为通过（无"看起来像网页控件 / 非原生"类阻断项）。
9. 下游 any-writer 编译探针跑通，破坏面已全部落入 `docs/BREAKING-CHANGES.md`。
10. Phase 2 交付后，`InsetGroupedSection` + `SettingsRow` 能在不写任何 CoreDesign 之外样式代码的前提下复刻一屏 iOS 设置页（以 preview 为证）。

## Constraints & Assumptions

### 约束

- **交付分两阶段，顺序不可交换**：Phase 2 的新组件必须建立在 Phase 1 重铸后的 token 上，否则要写两遍。本 PRD 在 structure 阶段拆为 2 个独立 epic：
  - **Epic 1 · 地基**（FR-1 ~ FR-9 + FR-13 的 0.3.0 部分）→ 发 `0.3.0`
  - **Epic 2 · 新组件**（FR-10 ~ FR-12 + FR-13 的 0.4.0 部分）→ 发 `0.4.0`
  - Epic 2 在 Epic 1 合入 main 并完成视觉评审之后才启动。
- **这是破坏性改造**，且破坏面很大（token 改名、6 个组件删除、trait 删除）。库当前版本 `0.2.0`，处于 1.0 之前，接受破坏性变更；但必须完整记录。
- **不重造系统控件**：`Toggle` / `Slider` / `Stepper` / `List` / `Form` / `ContentUnavailableView` 等 SwiftUI 已提供的控件一律不重新实现，只提供 style。
- **不做不相关重构**：与本次原生化无关的代码改动不纳入范围。

### 假设

- `ConcentricRectangle` 与 `Edge.Corner.Style.concentric` 在 iOS 26 / macOS 26 可用（已核对 Apple 官方文档）。若在 macOS 上行为与 iOS 有出入，以 iOS 为准并在 macOS 侧做最小兼容。
- 下游使用者目前只有 any-writer，且已知其会跟随升级。
- 现有的 preview app（`scripts/run-preview.sh`）与快照脚本（`scripts/run-snapshots.sh`）可用于产出视觉评审所需截图。
- 现有 `ios-visual-reviewer` agent 可对截图给出可执行的视觉结论。

## Out of Scope

- **Telegram 聊天组件族**（`MessageBubble` / `DateSeparator` / `TypingIndicator`）。本次借鉴 Telegram 的是其"贴合系统"的克制观感，不是它的 IM 界面；聊天泡泡对通用库而言通用性不足。既有的 `BottomInputBar` 保留不动。
- **加载与占位态**（Skeleton / Shimmer / 下拉刷新样式）。有价值但本次不做。
- **重建 Blossom 或任何替代主题机制**。主题能力本次整体移除，不提供迁移路径。
- **多语言化库内文案**。删除的 `StatusRow` 曾内嵌英文文案；保留组件不引入新的内嵌文案，本地化不在本次范围。
- **macOS 专属观感打磨**。库继续同时编译 iOS / macOS，但本次视觉基准以 iOS 为准。
- **`ColorGrade` 调色板重做**。它降级为内部原料，取值不动。
- **性能优化**。除非重铸本身引入了回归。

## Dependencies

### 内部依赖

- Epic 2 依赖 Epic 1 完成并合入 main。
- 视觉评审依赖 preview app 与快照脚本可跑通（若 Phase 1 的删除动作打断它们，需在同一 epic 内修复）。
- `docs/BREAKING-CHANGES.md` 的完整性依赖下游编译探针（`scripts/downstream-probe`）跑通。

### 外部依赖

- **SwiftUI iOS 26 / macOS 26 SDK**：`ConcentricRectangle`、`Edge.Corner.Style.concentric`、`.glassEffect()`、`@Entry`、`.safeAreaBar`。
- **下游 any-writer**：需在 `0.3.0` 发布后跟进迁移；本 PRD 不含其迁移工作，但含向其提供的破坏性变更清单。
- **`ios-visual-reviewer` agent**：Success Criteria #8 的判定方。
