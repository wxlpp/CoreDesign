---
name: coredesign-audit-remediation
status: backlog
created: 2026-07-18T14:03:55Z
updated: 2026-07-18T14:03:55Z
progress: 0%
prd: .claude/prds/coredesign-audit-remediation.md
github: (will be set on sync)
---

# Epic: coredesign-audit-remediation

## Overview

修复四路审计在 CoreDesign 中核实出的 83 项缺陷（78 修 / 5 记录不修），覆盖四个层面：遮蔽 SwiftUI 内建成员的真 bug、公开 API 断裂、结构性冗余（重复色阶 / typography 层不缩放 / 按钮体系重复），以及缺失的质量保障基建。

用户已确认 breaking change 直接改，不保留 deprecated 兼容层。完整缺陷清单与逐项证据见 `audit-checklist.md`，它同时是本 epic 的验收依据（SC-7）。

## Architecture Decisions

### AD-1 第 4 层色彩职责收窄为「状态功能别名」

删除 `FunctionalColor` 的 `primary`/`secondary`/`tertiary` 三组，交互色统一走第 3 层 `InteractionColors`。这一个动作同时解决四件事：A1 遮蔽 bug、库内外语义分裂、与 `InteractionColors` 逐值重复的色阶、以及一处零效果的 Blossom 分流。

### AD-2 Blossom 跟随靠别名继承，不靠新增分流

`borderFocus` 指向 `.accent` 而非新增 `#if Blossom`，与 `borderSelected` 的既有处理一致，使全库分流点净减（9 → 8）。代价是默认主题下 focus ring 从 Primer 蓝变为品牌蓝，已列入 NFR 视觉例外。

`statusAccent*` 整组删除而非映射——其 alpha 叠加档位无法等价映射到不透明的 accent 别名，且库内零渲染消费点、含 colorset 笔误。

### AD-3 typography 从 `Font` 常量升级为 `.coreFont(_:)` modifier

保住 Primer 精确基准字号（`docs/PRIMER_VERSION.md` 继续有效）的同时恢复 Dynamic Type，并把文档本就建议的「font / lineSpacing / tracking 三件套」收进单一调用点。

连带决策：`CoreControlMetrics.font(for:)` 改为 `fontToken(for:) -> CoreTypography.Token`。`@ScaledMetric` 需要 View 上下文，返回 `Font` 的 API 无法服务于此——不改则按钮文字仍不缩放。

### AD-4 三项经实测确立的技术约束

| 约束 | 实测结论 | 影响 |
|---|---|---|
| SwiftPM 不调用 `actool` | 产出 bundle 只有原始 `.xcassets` 目录，无 `Assets.car` / `Info.plist`；`Color.accent.resolve()` 返回 `(0,0,0,0)` | Blossom 颜色断言走 asset 名 → `Contents.json` 解析，不能用 `Color.resolve` |
| macOS 无 Dynamic Type | `@ScaledMetric` 全 12 档恒返回 wrappedValue；iOS 26 Simulator 正常（16→21→45） | 布局断言 `#if os(iOS)` + `xcodebuild` Simulator，验证命令从 4 条变 5 条 |
| 相邻字号档位可能相等 | iOS 实测 `small` 与 `medium` 同为 15pt | 断言相邻用 `>=`，跨档才用 `>` |

### AD-5 视觉回归不做像素比对

保持快照「只生成」现状，PNG 作为文档插图；视觉把关交 `ios-visual-reviewer` agent。替代安全网是布局断言层，专门覆盖 Dynamic Type 改造的裁切风险。

## Technical Approach

### Token 层（#2、#4）

色彩层重组与 typography 改造是两条独立主线，分属不同文件，但都以**下游组件的批量改写**收尾——这正是本 epic 的冲突根源（见 Implementation Strategy）。

### 组件层（#3、#5、#6、#8、#9、#10、#11）

按关注点切分：公开 API 修复与改名、按钮/Sidebar 结构收敛、死代码清理、可访问性、本地化、API 形态统一、机械清理。每条关注点横切多个组件文件。

### 基建层（#1、#7）

`#1` 含 `defaultIsolation(MainActor.self)`——改变全库编译语义，必须最先合入。CI 部分因 Xcode 26 / iOS 26 Simulator runner 可用性未验证而带四级降级决策树，但不阻塞其它 Issue。

`#7` 重建测试质量：删除恒真断言、补 Blossom 分流断言、补布局断言层。

## Implementation Strategy

### 关键发现：本 epic 近乎全串行，不是并行任务集

按 PRD 要求生成了真实的 owner 矩阵（扫描各 Issue 承载审计项的证据行号 + `CoreTypography` / legacy status token 的实际消费者）：

```
触及文件 51 个，其中 27 个被多个 Issue 触碰，共 29 个冲突对

5方  MenuButton.swift        #3 #5 #9 #10 #11
4方  Banner.swift            #2 #4 #10 #11
4方  BottomInputBar.swift    #4 #6 #8 #11
4方  CommentCard.swift       #4 #6 #10 #11
4方  Toast.swift             #2 #4 #9 #10
3方  AvatarGroup / Badge / BookCover / CheckBox / SegmentedControl /
     Sidebar / StateLabel / StatusRow / TimelineItem
2方  另 13 个文件

冲突最密的对：#4↔#10 共享 11 文件、#10↔#11 与 #4↔#11 与 #4↔#6 各 6 个
```

**`#4` 是串行枢纽**——它与其它 8 个 Issue 冲突，因为 Dynamic Type 改造要触及全部 26 个 `CoreTypography` 消费者，几乎等于每个组件文件。

这否定了「11 个 Issue 并行推进」的模型。PRD 起草期间三次写出「某某可并行」的断言、三次被 grep 证伪，正是同一现象在不同尺度上的反映。本 epic 因此采用**串行为主、两个并行窗口**的执行模型。

### 执行顺序

```
阶段 0（硬前置）
  #1  构建配置        defaultIsolation 改变全库编译语义，须最先合入

阶段 1（token 与 API 基础，顺序执行）
  #2  色彩层重组      StatusColors / Toast / Badge / Banner / Form / CheckBox / StatusRow
                      ├─ 须让 StatusColorsTests 重新编译通过（否则 #2 自身验证不绿）
  #3  公开 API 与改名  CheckBox / BorderlessButtonStyle / ButtonRoleStyleRole / MenuButton
  #5  按钮 + Sidebar   四个 ButtonStyle / MenuButton / Sidebar / TelegramGlassButtonModifier
  #6  死代码清理      EmptyState(整删) / BottomInputBar / CommentCard / RefPill /
                      SegmentedControl / TimelineItem / BookCover / CheckBox

阶段 2（组件横扫，顺序执行）
  #4  Dynamic Type    26 个 CoreTypography 消费者 —— 排在 #6 之后，避免迁移
                      EmptyState 这个即将被整删的文件；排在 #5 之后，避免与按钮
                      font 行收敛撞车
  #10 API 形态统一    与 #4 共享 11 个文件，必须紧随其后

阶段 3（并行窗口，两组无共享文件）
  #8  可访问性        BottomInputBar / UnderlinedTabBar / Form
  #9  本地化          Toast / MenuButton / BookCover
  （矩阵确认 #8 ∩ #9 = ∅，可并发）

阶段 4（收尾）
  #11 机械清理        文档 / 目录 / gitignore / 硬编码数值 / Preview 补全
                      —— CLAUDE.md 被 #2/#6/#11 三方触碰，统一在此改一次
  #7  测试质量重建    代码稳定后再重建断言，避免反复返工
```

### 分支拓扑

epic 集成分支 `epic/coredesign-audit-remediation`（off `main`）。每个 Issue 走私有 worktree + 分支，PR base 指向 epic 分支。**禁止直接合 `main`**；`epic → main` 是唯一硬停点，需用户确认。

### 每个 Issue 的完成定义

1. 四条 SwiftPM 命令绿：`swift build` / `swift test` / 两者的 `--traits Blossom` 版本
2. `#4` 额外需第 5 条：`xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
3. 更新 `audit-checklist.md` 中本 Issue 承载条目的状态（SC-7 判定基础）
4. 新增 colorset 后须 `swift package clean` 再验证

## Task Breakdown Preview

| # | 任务 | 承载项 | 依赖 | 并行 |
|---|---|---|---|---|
| 1 | 构建配置前置：CI + `defaultIsolation` + 预览宿主 trait | 5 | — | 否（硬前置） |
| 2 | 色彩层重组 | 12 | #1 | 否 |
| 3 | 公开 API 修复与改名 | 6 | #2 | 否 |
| 4 | Dynamic Type 改造 | 2 | #5, #6 | 否（串行枢纽） |
| 5 | 按钮体系 + Sidebar 收敛 | 8 | #3 | 否 |
| 6 | 死代码清理与现代化 | 18 | #5 | 否 |
| 7 | 测试质量重建 + Blossom 断言 | 4 | #11 | 否 |
| 8 | 可访问性 | 3 | #10 | 是（与 #9） |
| 9 | 本地化 String Catalog | 1 | #10 | 是（与 #8） |
| 10 | 公开 API 形态统一 | 9 | #4 | 否 |
| 11 | 机械清理 | 10 | #8, #9 | 否 |

任务数 11，超出 ccpm「≤10」的建议一项。保留 11 的理由：第 2 轮评审明确要求把原 #10 二分为「公开 API 形态设计」与「机械清理」——前者是设计决策、后者是文本改动，混在一个 Issue 里会让评审粒度失配。合并回去会牺牲评审质量。

## Dependencies

**外部：**
- Xcode 26 / Swift 6.3 工具链
- GitHub Actions macOS runner + iOS 26 Simulator（**可用性未验证，`#1` 的首要任务**；四级降级树见 PRD Constraints）
- EmergeTools SnapshotPreviews 0.14.0（现状保留，不升级）

**内部：**
- `#1` → 其余全部（`defaultIsolation` 的编译语义变更）
- 阶段链见 Implementation Strategy 的执行顺序
- `#2` → `#7`：`StatusColorsTests` 同时是 `#2` 的破坏对象与 `#7` 的改写对象，由 `#2` 负责让它编译通过

**跨 artifact：**
- `App/` 预览宿主随 `#3` 的改名、`#2` 的 token 删除同步更新
- `docs/components/` 四个文件引用将被删的 token，随 `#2` 更新；`docs/superpowers/plans/` 是归档，不改

## Success Criteria (Technical)

1. 下游消费包能编译使用全部文档所述 public API（0 个 `inaccessible` / `cannot find in scope`）
2. `grep -rn "#if Blossom" Sources/ | wc -l` 从 9 降至 8
3. 10 个 typography token 全部支持缩放；`CoreControlMetrics` 不再暴露返回 `Font` 的 API
4. CI workflow ≥1，覆盖五条命令（runner 受限时降级为本地 pre-push 闸门）
5. 恒真断言归零，判定依据是 `#7` 产出的逐文件处置清单
6. ≥1 个测试能区分默认与 Blossom 的实际颜色值（light `#0077FA` vs `#FF6F8E`）
7. `audit-checklist.md` 83 项全部标记「已修复」或「记录不修 + 理由」
8. `Sidebar` row 代码量从约 120 行降至约 50 行

## Estimated Effort

**11 个 Issue，近乎全串行**——关键路径几乎等于总工作量，只有阶段 3 的 `#8`/`#9` 能并发。

按承载项数与波及面，工作量最重的三个：
- `#6`（18 项，8 个文件，含整文件删除）
- `#4`（2 项但波及 26 个文件 / 94 处，是全 epic 改动面最大的单项）
- `#2`（12 项，含三处 A1 型静默重解析，必须逐处显式改写而非依赖编译器）

最轻的是 `#9`（1 项）与 `#4` 的项数——注意**项数不等于工作量**，`#4` 是典型反例。

**首要风险**：`#1` 的 CI runner 可用性未验证。若 hosted runner 不支持 Xcode 26 + iOS 26 Simulator，CI 降级为本地 pre-push 脚本；这不阻塞其它 Issue（验证以本地命令为准），但会使 `#4` 的布局断言层失去自动化守护。
