---
name: coredesign-v2-components-existing
status: backlog
created: 2026-05-09T22:32:29Z
updated: 2026-05-09T23:21:43Z
progress: 0%
prd: .claude/prds/coredesign-v2-components.md
github: https://github.com/wxlpp/CoreDesign/issues/20
---

# Epic: coredesign-v2-components-existing

## Overview

把 PRD 中 Phase A（FR-A-1 ~ FR-A-9）的 13 个现有 component swift 文件全部按 v2-tokens 重构、按 Primer 视觉语言收齐。**唯一例外**：FR-A-6 顺手修 `MenuButton.swift` 在 iOS 上的 `UIImpactFeedbackGenerator` main-actor build 错误（v2-tokens issue #9 agent 留下的 pre-existing 问题）。

本 epic 与 `coredesign-v2-components-new` epic **完全独立**——两者触碰文件集互不重叠（既有 `Components/Button/` 等子树 vs 即将新建的 `Components/Badge/` 等子树），可并行启动。本 epic 推荐先做 FR-A-1 (Button styles) 作为 canary，验证 v2-tokens 在真实组件中的可用性，再 fan out 其余任务。

## Architecture Decisions

PRD 已固定的关键决策，epic 阶段补实施细节：

1. **Per-task PR → main 模型**（继承 v2-tokens 的成熟做法）：每个任务一个独立 PR，避免一次性 batch refactor 的 review 压力；分支命名 `task/<N>-<slug>`。
2. **公开 API 严格非破坏**：参数可加默认值、可补 overload，**不**删除既有 init / public func 签名。视觉差异可接受（重构必然产生），API 差异不接受。
3. **Glass 策略严格按 PRD §US-3 + SC#7 白名单**（修正归属）：
   - 保留 `.glassEffect` 的文件 + 具体位置：
     - `BottomInputBar.swift` —— 输入栏 pill 自身（line 131 附近）+ suggestion chip pill（`BottomInputBarSuggestionsView` 内 line 259-267 附近）+ shuffle 浮按钮（`BottomInputBarModifier.body` 内 line 334-342 附近）
     - `MenuButton.swift` —— 自身的 menu/circular 浮按钮（line 91, 105 附近）
     - `CircularGlassButtonStyle.swift` —— 整个 style
   - 必须去除 `.glassEffect`：
     - `SolidButtonStyle.swift`（per PRD FR-A-1 "去 glass，按 Primer 实色按钮"）
     - `LightButtonStyle.swift`（亮色 colorScheme 去 glass，统一柔和阴影或纯色；暗色保留——这是 PRD §US-3 明确允许的"漂浮在内容上方"暗色场景）
4. **`ButtonRoleStyleRole.swift` 不是独立任务**：它是 enum 支撑类型，不计入 13 文件组件清单。FR-A-1（Button styles）实施时**顺带审视**它的颜色映射，与 v2-tokens 的 `Color.borderFocus` / 语义色对齐；但不为它单独起任务、不要求 Preview。
5. **iOS build 错误在 FR-A-6 内必修**（PRD US-4 / FR-A-6 / SC#5 硬交付，**不是可降级**）：`MenuButton.swift` 的 `UIImpactFeedbackGenerator` main-actor 错误是单一 actor isolation 问题（不是仓库级 concurrency 重构）；scope 是该文件内 `init / prepare / impactOccurred` 整段（line 168-173 附近的 helper），不是只包 `impactOccurred()` 一行。PRD 列了 3 条修复路径择一即可：(a) helper 整体 `@MainActor` 隔离、(b) 调用处 `Task { @MainActor in generator.impactOccurred() }` 异步派发、(c) **直接移除 feedback 调用**（如果不是关键交互；最低风险路径）。同 PR 内修，PR 必须通过 `swift build --triple arm64-apple-ios26.0-simulator`。
6. **每 PR description 固定字段**（不是建议、是门禁要求；reviewer 缺哪一项均可拒绝 merge）：
   - **Light preview**：light colorScheme `#Preview` 截图 / 详细文字描述
   - **Dark preview**：dark colorScheme `#Preview` 截图 / 详细文字描述
   - **视觉变化摘要**：与 main 主分支对比的视觉差异（譬如 "圆角 9 → 6（CoreRadius.medium），padding 6/12 → CoreControlMetrics 表"）
   - **Glass 变化**：是否去除 / 保留 `.glassEffect`、原因；如违白名单需 reviewer 显式确认
   - **public API diff**：必须列出本 PR 改动的 public 签名清单（参数加默认值 / 加 overload OK，删既有签名 NOT OK）
7. **iOS + macOS 双平台 build 必须都通过**：`swift build -Xswiftc -warnings-as-errors` (macOS) + `swift build -Xswiftc -warnings-as-errors --triple arm64-apple-ios26.0-simulator` (iOS) 双绿才算 PR done。
8. **本 epic 不新增 token**（与 PRD §Out of Scope 一致）：实施过程中如发现 v2-tokens 缺漏，先记录到 PR description 的 follow-up 段，不在本 epic 内补 token；这是"全部任务可并行"假设的前提条件——若中途允许补 token，并行假设立即被打破。
9. **doc-comment 治理**（PRD §NFR）：每个被重构的现有组件的 public API 表面（公开 struct / enum / extension View func）的 doc-comment 必须覆盖：使用场景、关键参数语义、与 Primer 概念对应、light/dark 行为差异（如有）。这是 task 级 deliverable，不是软目标——PR description "doc-comment 完整性" 字段必须打勾。

## Technical Approach

本 epic 没有传统 frontend / backend / infrastructure 分层。按重构组别组织：

### Button 子系统（FR-A-1，1 个 task 内部 4 个文件）

| 文件 | 关键改动 |
|---|---|
| `SolidButtonStyle.swift` | EdgeInsets 表 → `CoreControlMetrics.{horizontalPadding,verticalPadding}(for:)`；font → `CoreControlMetrics.font(for:)`；cornerRadius → `CoreRadius.full`（Capsule）；**去 glass**；阴影按 Primer 实色按钮配 `CoreElevation.small` 或不带阴影 |
| `LightButtonStyle.swift` | 同上；**亮色 colorScheme 去 glass**（暗色保留 glass per PRD §US-3）；阴影继续用 token |
| `BorderlessButtonStyle.swift` | EdgeInsets 表 token 化；无视觉容器 |
| `CircularGlassButtonStyle.swift` | EdgeInsets / size token 化；**保留 `.glassEffect`** |

`ButtonRoleStyleRole.swift` 在本 task 内复审颜色映射（如 `accent` / `borderFocus` 等是否与 v2-tokens 语义色对齐），但不重写。

### Banner / 信息组件（FR-A-2, FR-A-5）

- `Banner.swift`：`PlainBannerStyle` / `BorderedBannerStyle` 走 token；`.padding()` → `CoreSpacing.*`；不用 `.glassEffect`；可视情况切换为 `View.surface(.canvas)` + 颜色按 `MessageLevel` 走 status color
- `Form/Form.swift`：`LabelIcon` 内 `font(.system(size: 26))` → `CoreControlMetrics.iconSize(for: .extraLarge)` 或 `CoreSpacing.xxl` / `xxxl`；间距走 `CoreSpacing.*`

### 控件 chrome（FR-A-3, FR-A-4）

- `SegmentedControl.swift`：外框 `CoreRadius.medium` + thumb `CoreRadius.small` + 高度 `CoreControlMetrics.height(for:)`；thumb 阴影 `CoreElevation.small`；不用 `.glassEffect`
- `UnderlinedTabBar.swift`：字号 / underline 厚度 / spacing 全部 token 化（underline 厚度建议 `CoreBorderWidth.thick`）

### 输入栏 + 修 build 错（FR-A-6）

`BottomInputBar.swift` + `MenuButton.swift`：

- 输入栏 pill 自身保留 `.glassEffect`（视觉特点）
- suggestion pill / shuffle 浮按钮保留 `.glassEffect`（浮层 UI）
- 所有 padding / spacing / cornerRadius token 化（≥ 15 处带-edge padding 字面量需归零）
- **额外 deliverable**：修 `MenuButton.swift` 在 iOS 上的 `UIImpactFeedbackGenerator` main-actor 错误（建议 `Task { @MainActor in generator.impactOccurred() }` 或类似隔离）

### 容器 / 内容显示（FR-A-7, FR-A-8, FR-A-9）

- `BookCover.swift`：cornerRadius → `CoreRadius.large`（书籍封面圆角较大）；`lineWidth: 0.5` → `CoreBorderWidth.hairline`；阴影 → `CoreElevation.medium`
- `Avatar.swift` + `CheckBox.swift`：合并为 1 个 task（两者都很小、互不依赖）；圆角 / 字号 / icon 尺寸 / 间距 token 化

## Implementation Strategy

**8 个任务，文件级互不重叠**；功能上 `depends_on: []` 全部为空（每个 PR 都能在当前 main 上独立 build/test/merge）。但 **Task 6 与 Task 1 之间存在 soft 视觉 contract**——`BottomInputBar.swift:143-167` 用 `.buttonStyle(.circularGlass)` 渲染 suggestion / send / stop 按钮，而 `CircularGlassButtonStyle` 由 Task 1 owns。**含义**：

- 功能 build/test 上：Task 6 不"等"Task 1，可任意并行
- **视觉验收上**：Task 6 的 `.circularGlass` 按钮表现取决于当前 main 上的 `CircularGlassButtonStyle` 实现。若 Task 1 还没合，Task 6 PR 视觉测的是旧 button style；若 Task 1 在 Task 6 之后合且改了视觉，Task 6 自动继承新视觉但**应重抽**（因为 Task 6 PR 期间的视觉验收已失效）

```
功能并行 (depends_on: 全部为空):
  ├─ Task 1: Button styles (4 files + ButtonRoleStyleRole 顺带复审)
  ├─ Task 2: Banner
  ├─ Task 3: SegmentedControl
  ├─ Task 4: UnderlinedTabBar
  ├─ Task 5: Form
  ├─ Task 6: BottomInputBar + MenuButton + iOS build fix（spike）
  │            ↳ Soft sequencing：Task 1 baseline 稳定后再做最终视觉验收
  ├─ Task 7: BookCover
  └─ Task 8: Avatar + CheckBox（合并理由：两文件各 ~50 行；纯 small-file bundling，不是技术耦合）
```

**单 agent 执行顺序建议**：先做 Task 1（Button styles）作为 **canary**——它是组件库使用最广的一组，验证 v2-tokens 在真实组件中的人体工程学；canary 合入后 fan out 其余 7 个任务。Task 6 在 fan-out 阶段最佳放在 Task 1 之后（避免视觉重抽），但功能上不强制。

**多 agent 并行策略**：8 个任务可同时 dispatch；预算 8 PR × ~2 round Copilot review × premium request ≈ 16 premium。Task 6 因含 iOS build fix spike，估时上限单独偏高。

**关键风险**：

- **Task 6 (BottomInputBar)** 是 spike：除了 token 化重构，还要修 iOS main-actor 错误（PRD 硬交付，**没有降级出口**）。修复路径见 §Architecture Decisions #5 的 3 条（@MainActor 隔离 / Task wrap / 移除 feedback）。如 (a)(b) 两条都失败，path (c) 是兜底（移除 feedback 不是设计回退而是 PRD 允许的修复方式之一）。
- **Task 6 ↔ Task 1 视觉 contract**（已在依赖图中标 soft sequencing）：Task 6 PR 内若发现 `.circularGlass` 表现因 Task 1 改动而漂移，需要在 Task 1 落 main 后重抽视觉，但 Task 6 自身代码不必再改（自动继承）。
- **Task 1 (Button styles)** 包含 4 文件，diff 较大；Copilot review 可能在视觉等价性 + glass 去除合理性上多轮要求说明。

## Task Breakdown Preview

按 PRD § Estimated Effort & Epic Split 的 8 task 计数：

1. **Button styles 重构**（canary）— 4 个 ButtonStyle 文件 + 顺带复审 `ButtonRoleStyleRole.swift` 的颜色映射（不为后者单独起 task）；最大也是最复杂的 token 化任务
2. **Banner 重构**
3. **SegmentedControl 重构**
4. **UnderlinedTabBar 重构**
5. **Form 重构**（Form.swift + 内嵌 LabelIcon / ChevronRightIcon / DangerIcon）
6. **BottomInputBar + MenuButton 重构 + iOS build fix**（spike，估时上限偏高）
7. **BookCover 重构**
8. **Avatar + CheckBox 重构**（合并：两者各 ~50 行，独立 task 浪费）

## Dependencies

**前置（必须满足）**：
- v2-tokens epic 全部 9 个 issue 已 merged（**已满足**：commit `abd0da4` archive 完成）
- main 上有 6 类 token + 14 语义色 + `View.surface(_:)` + `View.coreShadow(_:)` + `View.focusRing(_:...)` 等

**任务间**：无 depends_on，全部 parallel。

**下游**：
- `coredesign-v2-components-new` epic 与本 epic **彼此独立**，可并行（不在本 epic 的 dependency 内）
- `any-writer` 切换到 v2-components 是更下游的独立 epic

## Success Criteria (Technical)

PRD §Success Criteria 中与 Phase A 直接相关的项，本 epic 全数兑现：

| PRD SC | 由本 epic 哪部分保证 |
|---|---|
| #1 现有组件魔法数字归零（13 文件 × 3 grep 全部 = 0） | 8 个 task 各自的目标文件 |
| #3 build 洁净（macOS + iOS 双绿）| 每 PR 门禁 |
| #4 swift test 退出 0（不破坏 stub）| 每 PR 门禁 |
| #5 iOS 编译通过 | 每 PR 跑 `swift build --triple arm64-apple-ios26.0-simulator` |
| #6 部分（13 现有组件全部 #Preview）| 重构时如组件已有 Preview 则保留更新；如缺失则补 |
| #7 glass 命中文件白名单合规 | 每 PR 跑 `grep -rln glassEffect Sources/CoreDesign/Components/`，命中文件必须 ⊆ 白名单 |

epic 层补充门禁：

1. **每 PR 编译 + 测试双绿**：`swift build -Xswiftc -warnings-as-errors && swift test`（macOS）+ `swift build --triple arm64-apple-ios26.0-simulator` (iOS) 全部通过
2. **公开 API 非破坏**：`grep -E '(public init\(|public (struct|enum|class|func)\s+\w+)' Sources/CoreDesign/Components/<target>.swift` 在 PR 前后对比 ≥ 原数量（参数可加默认值，签名不能减）
3. **PR description 5 字段固定模板**（per ADR #6）：Light preview / Dark preview / 视觉变化摘要 / Glass 变化 / public API diff
4. **doc-comment 治理**（per PRD §NFR + ADR #9）：每个被重构组件的 public API 表面 doc-comment 完整（使用场景 + 关键参数 + Primer 概念对应 + light/dark 行为），PR description 须打勾确认
5. **本 epic 不新增 token**：PR 不包 v2-tokens 范围内的 token 增改；任何 token 缺漏记入 follow-up，留给独立 epic

## Estimated Effort

总体：1.5 – 2 人周（专注实施）。按任务粗估：

| Task | 估时 | 备注 |
|---|---|---|
| 1. Button styles（4 file） | 1.5 – 2 天 | canary；最大复杂度；glass 去除决策 |
| 2. Banner | 0.5 天 | 1 文件，2 styles |
| 3. SegmentedControl | 0.5 天 | 1 文件 |
| 4. UnderlinedTabBar | 0.5 天 | 1 文件 |
| 5. Form | 0.5 天 | 含 3 个内嵌 icon view |
| 6. BottomInputBar + MenuButton + iOS fix | 1.5 – 2.5 天 | spike，含 build fix 不确定性 |
| 7. BookCover | 0.5 天 | 1 文件 |
| 8. Avatar + CheckBox | 0.5 天 | 2 小文件合并 |

**关键路径**（多 agent 并行）：Task 6（最长 2.5d）。

**关键路径**（单 agent 顺序）：Task 1 → 其余 fan out（Task 1 0.5d 内可见 canary 反馈即可启动剩余）。

## Tasks Created

- [ ] #21 - Button styles 重构（canary） (parallel: true)
- [ ] #22 - Banner 重构 (parallel: true)
- [ ] #23 - SegmentedControl 重构 (parallel: true)
- [ ] #24 - UnderlinedTabBar 重构 (parallel: true)
- [ ] #25 - Form 重构（含 LabelIcon / ChevronRightIcon / DangerIcon） (parallel: true)
- [ ] #26 - BottomInputBar + MenuButton 重构 + iOS build fix（spike） (parallel: true, soft sequencing on Task 1)
- [ ] #27 - BookCover 重构 (parallel: true)
- [ ] #28 - Avatar + CheckBox 重构（合并） (parallel: true)

Total tasks: 8
Parallel tasks: 8（全部 `parallel: true`；Task 6 视觉验收建议在 Task 1 后但功能上无硬依赖）
Sequential tasks: 0
Estimated total effort: 60 hours（4 + 4 + 4 + 4 + 16 + 4 + 4 + 20）
