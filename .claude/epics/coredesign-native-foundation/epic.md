---
name: coredesign-native-foundation
status: backlog
created: 2026-07-21T15:23:19Z
progress: 0%
prd: .claude/prds/coredesign-native-refresh.md
github: (will be set on sync)
---

# Epic: coredesign-native-foundation

> `coredesign-native-refresh` PRD 的 **Phase 1（地基）**，覆盖 FR-1 ~ FR-9 与 FR-13 的 `0.3.0` 部分，交付 `0.3.0`。
> Phase 2（FR-10 ~ FR-12，新组件，`0.4.0`）在本 epic 合入 main 并通过视觉评审后另立 epic。

## Overview

把 CoreDesign 的 token 地基从 GitHub Primer 换成 Apple HIG，并在换之前先把不需要迁移的东西删掉。

本 epic 的核心工程判断是**顺序**：先删（6 个 GitHub 专用组件、Blossom trait、CoreGradient），再铸（字体 / 圆角 / 尺寸 / 阴影 / 语义色），最后迁（保留组件逐调用点迁到新 token）。倒过来做要多迁 6 个组件、多处理 10 处 `#if Blossom` 分流，且这些工作全部会被随后的删除动作作废。

交付物是一个观感原生、token 命名与 Apple 文档一致、源码注释不含内部流程编号的 `0.3.0`。

## Architecture Decisions

### ADR-1 · 字体层不再自建缩放机制，交还给系统

现 `CoreTypography` 用 `Font.system(size:)` 固定字号 + `@ScaledMetric` + 手算 `lineSpacing` 模拟 Dynamic Type。改为直接取 SF 文本样式（`Font.system(.body)` 等）后，缩放、行高、字重全部由系统负责，`@ScaledMetric` 包装、`*LineSpacing` / `*Tracking` 常量、`Spec.scales` 开关、`Token.fixedFont` 一并删除。

`.coreFont(_:)` 的调用形态保留——它是全库统一的文字入口，改掉会波及每个组件文件，而它本身与地基更换无关。

### ADR-2 · 圆角改为经 shape helper 统一出口，禁止裸 `RoundedRectangle`

只把 `CoreRadius` 数值改掉不足以拿到 Apple 观感，因为 `.continuous` 角样式必须在每个 `RoundedRectangle` 构造点显式指定，漏一处就是一个圆角风格不一致的元素。因此引入统一 shape helper，内部固定 `style: .continuous`，并以「grep 裸 `RoundedRectangle` 为 0」作为验收判据（PRD Success Criteria #3）。

嵌套在已知容器内的元素改用 `ConcentricRectangle`（iOS 26+）。

### ADR-3 · `accent` 改指宿主强调色，衍生态改用明度调制

`accent` 从 `brand5` 改为 `Color.accentColor`（宿主 app 的 `AccentColor`）。衍生族 `accentHover` / `accentPressed` / `accentDisabled` / `accentSubtleBackground` 原本取 `brand6` / `brand7` / `brand2` / `brand1` 固定色阶，动态强调色下无从推导，改为对 `accent` 做明度 / 不透明度调制。

**`accentPressed` 是加深**，实现必须用压暗 overlay 或明度调制，不能降 alpha（降 alpha 只会变浅）。

本层不承诺跟随每视图 `.tint(_:)`——那需要把组件配色整体改成 `ShapeStyle` 通路，属 API 形态变更，不在本 epic。

### ADR-4 · macOS 侧必须显式降级，不能照搬 iOS 映射

AppKit 无 grouped background 系列，现桥接层把 `surfaceCanvas` 与 `surfaceRaised` 都落到 `.controlBackgroundColor`（`SystemBackgroundColors.swift:47-53`、`58-64`）。照搬 iOS 映射会让 macOS 上卡片与画布同色、raised 层隐形。macOS 侧取 `windowBackgroundColor`（canvas）/ `controlBackgroundColor`（raised），并在浅色与深色下各验证一次二者确有可见差异。

### ADR-5 · 改名走弃用别名过渡，不做硬切

旧字体 token 名在 `Tokens/` 之外有 63 处引用，删 `CoreRadius.mediumPlus` 直接打断 `Sidebar.swift:157,411`。若 Task 003 硬改名，`swift build` 会从 003 一直红到迁移完成（约 36 小时），期间 CI 与每个 checkpoint 评审全部失去把关能力，且 003∥004 的并行声明失效——两者之一注定落在红树上无法独立验证。

因此 003 采用 `@available(*, deprecated, renamed:)` 别名过渡：新旧名并存，全程 build 绿。迁移由 deprecation warning 驱动，比编译错误清单更完整（warning 能逐点列全且不阻塞构建）。别名在 Task 005 末尾删除。

**注意别名兜不住同名换值**（见 ADR-6）——`CoreRadius.small` 3 → 6 这类改动既不报错也不产生 warning。两类风险的处置手段不同，故拆成 005（改名，编译器驱动）与 006（换值，人工逐点）两个任务。

### ADR-6 · 「同名换值」按逐调用点迁移，不靠自动继承

`CoreRadius.small` 3 → 6、`medium` 6 → 10、`CoreControlMetrics.height(.regular)` 32 → 44 等属同名换值：下游与库内调用点**编译零感知**，但视觉全变。尤其新 `small = 6` 恰等于旧 `medium`，所有按旧语义选 `small` 的调用点圆角静默翻倍。

因此 Task 006 的产出不只是「改完能编译」，而是一份「旧档位 → 新档位」的逐调用点迁移映射表，逐点确认新档位是有意选择。

### ADR-7 · 删除先于重铸

见 Overview。Task 001 / 002 无前置依赖且可并行；其余任务在其之后。

## Technical Approach

### Token 层（`Sources/CoreDesign/Tokens/`、`Colors/`）

- `CoreTypography`：12 档改为 Apple 文本样式语义（`largeTitle` / `title` / `title2` / `title3` / `headline` / `body` / `callout` / `subheadline` / `footnote` / `caption` / `captionMono` / `caption2`）。
- `CoreRadius`：`none 0 / small 6 / medium 10 / large 16 / xLarge 22`；`smallPlus` / `mediumPlus` 先标 deprecated、Task 005 删除；新增 shape helper。
- `CoreControlMetrics`：高度 `28 / 32 / 44 / 50 / 56`；`primerVerticalPadding` 逃生口先标 deprecated、Task 005 删除。
- `CoreElevation`：resting 档保持近乎平坦，层级交给 material + separator。
- `SurfaceColors` / `ContentColors` / `BorderColors` / `InteractionColors` / `FillColors`：产出第 3 层**完整**映射表，改指系统色，保持现值的显式标注（PRD FR-4 明确该表非穷尽，`surfaceCanvasInset` / `surfaceCard` / `contentOnEmphasis` 等未列出的必须一并定案）。
- `ColorGrade`：保留为内部原料，取值不动。

### 组件层（`Sources/CoreDesign/Components/`、`Modifier/`）

保留组件（Avatar / AvatarGroup / Badge / Banner / Tag / ListRow / Form / SearchField / SegmentedControl / Sidebar / TabBar / Toast / ProgressBar / ProgressIndicator / CheckBox / StateLabel / BottomInputBar / Button styles / FlowLayout）逐个迁到新 token。`ButtonRoleStyleRole` 的三属性调色板按 ADR-3 重写。

### 宿主与 CI（`App/`、`.github/workflows/ci.yml`、`scripts/`）

`App/` 不在 `Sources`/`Tests`/`docs` 之内，是最容易漏的一块，而视觉评审依赖它能构建：`project.yml:13` 的 `traits: ["Blossom"]`、`Previews.swift`（24 处）与 `ComponentData.swift`（4 处）对被删组件的引用、pbxproj 重生成。CI 需摘掉 `matrix: mode: [default, blossom]` 及其 if/else 骨架、以及 `-skip-testing:CoreDesignTests/BlossomAssetTests`。

### 文档

`docs/PRIMER_VERSION.md` → `docs/DESIGN-FOUNDATION.md`；`docs/BREAKING-CHANGES.md` 补删除符号 / 改名 token / **同名换值**三节；`docs/README.md` 组件索引与快照重生成；`CLAUDE.md` 与 `AGENTS.md` 的主题系统、CoreGradient、双 trait 构建段落重写。

## Implementation Strategy

三段式，顺序不可交换：

1. **削面积**（001 ∥ 002）——删掉不需要迁移的东西，把后续迁移面缩到最小。
2. **铸地基**（003 ∥ 004）——token 定义层重写，此时不动组件；靠弃用别名保持 build 绿（ADR-5）。
3. **迁调用与收尾**（005 → 006 → 007 → 008 → 009 → 010）——机械改名、逐点重审、可访问性验证、注释清理、视觉终审、文档发版。

风险控制：

- 第 3 段全程串行，因为这些任务会大面积触及同一批组件文件，并行只会制造冲突。
- **005 与 006 必须分开**：前者是编译器驱动的机械替换，后者是人工的逐点视觉判断。合在一起执行，结果通常是机械替换做完了而设计判断被跳过。
- **视觉终审（009）排在文档发版（010）之前**：009 允许回改 token 值，若文档先定稿，「同名换值」表与取值理由会当场失真。009 的评审看的是模拟器截图，不需要 `docs/snapshots/` 就绪，所以这个顺序没有代价。
- 009 设 2 轮复审上限，超出则升级给用户裁决——「处置→复审」是无界循环，且允许回卷 003/004 的定案。

## Task Breakdown Preview

| # | 任务 | 依赖 | 并行 |
|---|---|---|---|
| 001 | 删除 6 个 GitHub 专用组件（Sources / Tests / docs / App） | — | ✅ 与 002 |
| 002 | 删除 Blossom trait 与 CoreGradient（Sources / Tests / CI / App 宿主配置） | — | ✅ 与 001 |
| 003 | 重铸字体 / 圆角 / 尺寸 / 阴影 token，引入 shape helper，留弃用别名 | 002 | ✅ 与 004 |
| 004 | 重铸语义色层：完整映射表 + macOS 降级 + accent 衍生族 + `ButtonRoleStyleRole` | 002 | ✅ 与 003 |
| 005 | 组件机械改名扫尾并删除弃用别名（编译器驱动） | 003, 004 | ❌ |
| 006 | 同名换值逐点重审与迁移映射表（人工判断） | 005 | ❌ |
| 007 | 触控目标与 Dynamic Type 验证 | 006 | ❌ |
| 008 | 清理注释：删内部流程编号、统一中文、去 Primer 考据 | 007 | ❌ |
| 009 | 视觉终审：截图 → `ios-visual-reviewer` → 修（2 轮上限） | 008 | ❌ |
| 010 | 文档 / CI / 版本：DESIGN-FOUNDATION、BREAKING-CHANGES、CLAUDE.md、AGENTS.md、组件索引、快照、`0.3.0` 发版 | 009 | ❌ |

共 10 个任务。

## Dependencies

### 内部

- 003 / 004 依赖 002：`CoreGradient` 在 `Tokens/`，`#if Blossom` 分流在 `SurfaceColors` / `InteractionColors` / `ColorGrade`，先删可避免在将被删除的分支上做迁移。
- 005 依赖 003 + 004：组件迁移需要新 token 与别名都已就位。
- 006 依赖 005：改名扫干净、树是绿的，才能专注做视觉判断。
- 009 的实际可运行性依赖 001 / 002 修好 `App/`（宿主 trait 配置与被删组件引用）。
- 010 依赖 009：文档必须以视觉终审后的终态数值写就。
- 001 与 002 无文件冲突：001 改 `App/Sources/*.swift`，002 改 `App/project.yml` 与 pbxproj（xcodegen 按 glob 收文件，001 不改变文件身份，无需重生成工程）。
- 004 与 005 均触及 `Components/Button/`：`ButtonRoleStyleRole` 归 004，其余 Button style 归 005，需在 005 启动前确认 004 已合入。

### 外部

- SwiftUI iOS 26 / macOS 26 SDK：`ConcentricRectangle`、`Edge.Corner.Style.concentric`、`.glassEffect()`、`@Entry`。
- `ios-visual-reviewer` agent：Task 009 的判定方。
- 下游 any-writer：不阻塞本 epic，但 010 须产出供其迁移的完整破坏清单。

## Success Criteria (Technical)

对齐 PRD Success Criteria，本 epic 负责其中第 1–9 条（第 10 条属 Phase 2）：

1. CI **全部**命令全绿，含 xcodebuild iOS Simulator 腿（`DynamicTypeLayoutTests` 只在该腿执行）。
2. `grep -rE "审计项|Issue #[0-9]+|epic ADR|per epic|PR description" Sources` = 0 行（基线 23 个源文件）。
3. `Sources` 中裸 `RoundedRectangle(...)` 调用 = 0。
4. `CoreControlMetrics.height(for: .regular) >= 44`，且交互组件实测可点击高度 ≥ 44pt（测试覆盖，跑在 iOS 腿）。
5. `CoreTypography` 中无 `Font.system(size:)` 固定字号调用。
6. `Sources` / `Tests` / `App` 中 `#if Blossom` = 0（基线 8 + 2 = 10 处），`CoreGradient` 符号 0 引用，CI 无 `--traits Blossom` 与 `-skip-testing:CoreDesignTests/BlossomAssetTests`。
7. 6 个被删组件在 `Sources` / `Tests` / `docs` / `App` 中 0 残留引用。
8. `ios-visual-reviewer` 视觉评审通过，无「像网页控件 / 非原生」类阻断项。
9. 下游编译探针跑通，且 `BREAKING-CHANGES.md` 含独立的「同名换值」一节（探针对此失明）。

## Estimated Effort

- 001 / 002：各半天，纯删除 + 连带清理，机械但覆盖面广（易漏 `App/`、CI matrix 与快照 JSON）。
- 003 / 004：各 1 天。004 更重——完整映射表 + macOS 降级验证 + accent 衍生族推导 + `ButtonRoleStyleRole` 重写。
- 005：半天到 1 天，编译器驱动，63 处改名 + 删别名。
- 006：1 天，本 epic 判断密度最高的一段，逐调用点确认换值。
- 007：半天到 1 天，触控与 Dynamic Type 断言。
- 008：半天到 1 天，23 个源文件的注释清理。
- 009：1 天，含最多 2 轮复审与修复。
- 010：1 天，文档、CI 复核、发版。

合计约 8–10 天。关键路径 002 → 004 → 005 → 006 → 007 → 008 → 009 → 010；001 与 003 搭车并行，不在关键路径上。

## Tasks Created

- [ ] 001.md - 删除 6 个 GitHub 专用组件 (parallel: true)
- [ ] 002.md - 删除 Blossom trait 与 CoreGradient (parallel: true)
- [ ] 003.md - 重铸字体 / 圆角 / 尺寸 / 阴影 token (parallel: true, depends_on: 002)
- [ ] 004.md - 重铸语义色层与 accent 衍生族 (parallel: true, depends_on: 002)
- [ ] 005.md - 组件机械改名扫尾并删除弃用别名 (parallel: false, depends_on: 003, 004)
- [ ] 006.md - 同名换值逐点重审与迁移映射表 (parallel: false, depends_on: 005)
- [ ] 007.md - 触控目标与 Dynamic Type 验证 (parallel: false, depends_on: 006)
- [ ] 008.md - 清理注释 (parallel: false, depends_on: 007)
- [ ] 009.md - 视觉终审与修复 (parallel: false, depends_on: 008)
- [ ] 010.md - 文档、CI 与版本收尾 (parallel: false, depends_on: 009)

Total tasks: 10
Parallel tasks: 4（001∥002，随后 003∥004）
Sequential tasks: 6（005 → 006 → 007 → 008 → 009 → 010）
Estimated total effort: 66 hours
