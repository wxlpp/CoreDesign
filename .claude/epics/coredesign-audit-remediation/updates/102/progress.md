# Issue #102 机械清理 — 完成记录

分支 `issue-102-cleanup`（base `epic/coredesign-audit-remediation`）。承载 **10 项**：C6b/C10a/C10c/C10d/D9/D12/D15/D16a/D16b/D18。epic 最后一个 Issue、依赖面最广（#92–#101 全部前置已合入）。

## 10 项做了什么

| 项 | 改动 |
|---|---|
| C10a | 新增 `LICENSE`（MIT，Copyright 2026 Evan Wang，用户确认） |
| C10c | `.gitignore` 去重（`.superpowers/` 从两次改为一次） |
| C10d | `.agents/` 加 `.gitignore`；`AGENTS.md` 纳入版本控制并修正 broken 内容（见下）；`.claude/prds`+`epics` 早已 tracked |
| C6b | README 组件数 `15 documented components` → **24**（与 `docs/README.md` Component Index 对齐） |
| D9 | `Banner.swift` `git mv` 入 `Components/Banner/Banner.swift`（历史保留；`StatusLevel.swift` 留 Components 根不动；活文件零路径引用） |
| D12 | 3 处机械替换（`CoreMenuButton` spacing 8→`CoreSpacing.sm`、0.94→`CoreButtonMetrics.pressedScale`、`TimelineItem` spacing 0→`CoreSpacing.none`）+ 4 处判断（见下） |
| D15 | `FillColors` 四处平台分支 `#if/#else/#endif`（对齐 `SystemBackgroundColors`/`SystemLabelColors`，返回值不变） |
| D16a | **已由 #101 顺带 resolved**（StateLabel 泛型化后 6 case 各带注释、旧「只列 4」文档已删）——核对标 ✅ |
| D16b | **已由 #97 顺带 resolved**（`.focusedExternally` 在 CLAUDE.md 已描述为 BottomInputBar private ext）——核对标 ✅ |
| D18 | `Sidebar`（6 public 组件各可辨识场景）/ `FloatingGlassModifier` / `TelegramGlassButtonModifier` 补 `#Preview` |

## 需判断的 4 处数值（均值零变化）

- **`44`（BottomInputBar glass shape 阈值）**：全 Sources 树穷举确认仅此一处 → 提为 `minimumHitTargetSide`，注释写明是 HIG 值（≠ metrics 的 48，防误替换）。
- **`1`（CommentCard:59 padding）**：保留裸值 + hairline 注释（snap 到 xxs=2 会改布局；单点使用提常量属 YAGNI）。
- **TimelineItem dotSize 32/20**：提文件级 caseless enum `TimelineDotDiameter`（`TimelineItem<Icon,Content>` 是泛型、不能有 static stored property——plan 原写 struct 内 static let 编译报错，改此形态，值零变化）。
- **AvatarGroup ramp**：仅加澄清注释（负交叠量无负 token、20pt 不在刻度、直径非间距），值零变化。

## AGENTS.md 的 checkpoint Critical 处置（用户裁决）

subagent 首次实现时把 `AGENTS.md` 从父 checkout 纳入 tracked，但它是 **pre-audit 快照且 broken**——机械 Claude→Codex find/replace 把 `.claude/`→`.Codex/`（指向不存在的目录）、header 成 `Codex.ai/code`，且含本 epic 已移除的 API（`Color.primary/secondary/tertiary` #93、`.getSize` #97、D16b misinfo）与旧名/旧路径。plan Step 5 本有「内容过期就停下向用户确认」的 gate，被 bypass。

**checkpoint 终审判 Critical → 路由用户裁决 → 用户选「修 broken + banner，完整刷新留 follow-up」。** 处置：把 `AGENTS.md` 逐行对齐当前 `CLAUDE.md`（修正全部 broken 处，正文与 CLAUDE.md diff 仅 banner + 首行 Codex/Claude 定位）+ 顶部加「`CLAUDE.md` 为 source of truth」banner。**持续 follow-up**：未来 `CLAUDE.md` 更新时须同步 `AGENTS.md`（已记入 audit-checklist C10d）。

## 验证（全独立复核）

- 四条 SwiftPM 命令 clean 冷跑全 **EXIT=0**，两侧 **95 tests / 30 suites**，warning 0。
- **第 5 条 iOS Simulator**（带 CI skip 列表）**TEST SUCCEEDED**——`Dynamic Type 布局` suite 真跑到（未被 skip），守护 D18 补 Preview 触及的 Sidebar `#if os(iOS)` 布局断言层。
- Banner `git mv` 历史保留（`--follow` 10 commit）；越界反向自查 rc=1（改动落在 Sources/README/.gitignore/LICENSE/AGENTS.md/.claude，无 CLAUDE.md/docs/Package.swift）；计数 83/79 未漂移。

## 给下游的交接

- **三个新增 Preview 编译过 ≠ 渲染正常**：Preview 是本仓库主要视觉冒烟手段，建议用户在 Xcode 打开 `Sidebar.swift`/`FloatingGlassModifier.swift`/`TelegramGlassButtonModifier.swift` 实际渲染确认。
- **AGENTS.md 同步义务**：它现在是 CLAUDE.md 的准确镜像；CLAUDE.md 未来更新须同步。
- 本 Issue 是 epic 最后一个——合入后 epic→main 是唯一硬停点。
