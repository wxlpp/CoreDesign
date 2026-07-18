---
name: coredesign-audit-remediation
status: backlog
created: 2026-07-18T14:03:55Z
updated: 2026-07-18T22:43:01Z
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

`#7` 重建测试质量：删除恒真断言、补 Blossom 分流断言。**布局断言层不在 `#7`，由 `#4` 随 Dynamic Type 改造一并落地**——安全网必须与它守护的改动同批合入。

## Implementation Strategy

### 关键发现：本 epic 以串行为主，并行窗口有限且须逐对验算

按 PRD 要求生成了真实的 owner 矩阵（扫描各 Issue 承载审计项的证据行号 + `CoreTypography` / legacy status token 的实际消费者）：

```
触及文件 51 个，其中 28 个被多个 Issue 触碰，共 30 个冲突对

5方  MenuButton.swift        #3 #5 #9 #10 #11
4方  Banner.swift            #2 #4 #10 #11
4方  BottomInputBar.swift    #4 #6 #8 #11
4方  CommentCard.swift       #4 #6 #10 #11
4方  Sidebar.swift           #4 #5 #10 #11
4方  Toast.swift             #2 #4 #9 #10
3方  AvatarGroup / Badge / BookCover / ButtonRoleStyleRole / CheckBox /
     SegmentedControl / StateLabel / StatusRow / TimelineItem
2方  另 13 个文件

（计数口径：**仅 Sources / Tests / App 下的 .swift 文件**，不含 docs、资源目录、
 CLAUDE.md、Package.swift 等非源码触碰点。1×5方 + 5×4方 + 9×3方 + 13×2方 = 28）

冲突最密的对：#4↔#10 共享 12 文件、#10↔#11 共享 7、#4↔#11 共享 6、#4↔#6 共享 5
```

**`#4` 是串行枢纽**——它与其它 **7** 个 Issue（`#2` `#5` `#6` `#8` `#9` `#10` `#11`）冲突，因为 Dynamic Type 改造要触及全部 `CoreTypography` 消费者，几乎等于每个组件文件。不冲突的是 `#1`（构建配置）、`#3`（`CheckBox`/`MenuButton` 均零 `CoreTypography` 引用）、`#7`（仅测试文件）。

`#4` 的触及集 = 24 个 `CoreTypography.` 消费者（94 处，与 PRD FR-3 一致）+ `RefPill`（D3 的 `.caption.monospaced()`）+ `AvatarGroup`（D3 的 `:59` `.caption2`，该文件零 `CoreTypography` 引用故不在 24 之内）+ `SolidButtonStyle`/`LightButtonStyle`（`font(for:)` → `fontToken(for:)`），共 **28 文件**；排除 `#6` 将整删的 `EmptyState.swift` 后实际改动 **27 文件**。

其中 `Sidebar.swift` 有 16 处 `CoreTypography.` 引用，是全库最高的单文件消费者——`#5` 的 B5 骨架收敛完成后会缩到约 6 处，这是把 `#4` 排在 `#5` 之后的又一收益。

这否定了「11 个 Issue 自由并行推进」的模型。PRD 起草期间三次写出「某某可并行」的断言、三次被 grep 证伪，正是同一现象在不同尺度上的反映。

但**反过来过度串行同样是成本**。逐对验算全部 55 个 Issue 组合后，找到三组交集为空、可真正并发的窗口（见下）。规则是一致的：**并行必须由矩阵逐对证明，不能靠直觉断言**。

### 执行顺序（三个并行窗口）

矩阵逐对验算后，有三组交集为空、可真正并发：

```
#5 ∩ #6  = ∅      #10 ∩ #8 = ∅      #11 ∩ #7 = ∅
```

据此的推荐调度（各 Issue 后的文件清单是**主要触及点，非穷举**；穷举以任务拆解时生成的 owner 矩阵为准）：

```
阶段 0（硬前置）
  #1  构建配置        defaultIsolation 改变全库编译语义，须最先合入

阶段 1（token 与 API 基础）
  #2  色彩层重组      FunctionalColor / InteractionColors / BorderColors / StatusColors /
                      Toast / Badge / Banner / Form / CheckBox / StatusRow /
                      CoreGradient+Preview / StatusColorsTests / App Previews
                      （13 个 swift + 4 个 colorset 目录 + 4 个 docs）
                      ├─ 须让 StatusColorsTests 重新编译通过（否则 #2 自身验证不绿）
                      └─ 用「毒丸 commit」让编译器穷举遮蔽符号的残留引用（见下）
  #3  公开 API 与改名  CheckBox / BorderlessButtonStyle / ButtonRoleStyleRole / MenuButton
  （#2 与 #3 共享 CheckBox.swift，阶段 1 内部**串行**，不是并行组）

阶段 2（并行窗口 1）
  #5  按钮 + Sidebar   四个 ButtonStyle / MenuButton / Sidebar / TelegramGlassButtonModifier
  #6  死代码清理      EmptyState / View+SizeReader / KeyboardHandling（三者整删）+
                      BottomInputBar / CommentCard / RefPill / SegmentedControl /
                      TimelineItem / BookCover / CheckBox / CoreGradient / BorderModifier
  （#5 ∩ #6 = ∅。#6 是承载项最多的 Issue（18 项），与 #5 并行直接缩短最长的一段关键路径）

阶段 3（串行枢纽）
  #4  Dynamic Type    28 文件（排除 #6 整删的 EmptyState 后改 27）—— 排在 #6 之后避免
                      迁移即将被删的文件；排在 #5 之后，等 B5 把 Sidebar 的 16 处
                      CoreTypography 引用收敛到约 6 处、B3d 把四个 ButtonStyle 的
                      font 行收敛成单一 modifier
                      └─ 布局断言层在此编写（见 DoD 说明）

阶段 4（并行窗口 2）
  #10 API 形态统一    与 #4 共享 12 个文件，必须紧随其后
  #8  可访问性        BottomInputBar / UnderlinedTabBar / Form
  （#10 ∩ #8 = ∅）

阶段 5
  #9  本地化          Toast / MenuButton / BookCover（与 #10 共享 MenuButton/Toast，须在其后）

阶段 6（并行窗口 3）
  #11 机械清理        文档 / 目录 / gitignore / 硬编码数值 / Preview 补全
                      —— CLAUDE.md 被 #2/#6/#11 三方触碰，统一在此改一次
  #7  测试质量重建    恒真断言清理（C2）+ Blossom 分流断言（C4a/C4b）+ C5 覆盖缺口处置
                      └─ **C5 的处置口径**：C5 列的约 15 个零测试目标（CheckBox / Form /
                         MenuButton / 四个 ButtonStyle / ButtonRoleStyleRole / token 层 /
                         全部 modifier / StarShape / ColorExtension）**不要求全部补测**。
                         #7 产出的逐文件处置清单同时覆盖 C2 与 C5 名单，每项标
                         「本轮补测」或「记录不补 + 理由」。否则 #7 做完也无法在
                         audit-checklist 里标记 C5，SC-7 对账会卡住
  （#11 ∩ #7 = ∅。#11 是机械清理，不改测试所依赖的行为，无需等它）
```

**对 PRD 分解规则的有意修订**：PRD Dependencies 写「`#4` 应整体排在结构性收敛（`#5`/`#6`/`#10`）之前或之后统一定序，不可与它们交错」，而本 epic 把 `#4` 插在 `#6` 与 `#10` 之间。这是刻意偏离——`#10` 的 API 形态重塑应当在字体迁移后的代码上做，否则同一批 12 个文件要改两遍。此处记录以免 SC-7 对账时被当成文档矛盾。

### A1 型静默重解析的编译器兜底（`#2` 必做）

三处被遮蔽符号的引用（`CheckBox.swift:31`、`StatusRow.swift:80`、`CoreGradient+Preview.swift:17`）在符号删除后**不报错**，只会静默改解析到 SwiftUI 内建成员。仅靠「逐处显式改写」是过程纪律，不是机制保障。

**改用编译器强制枚举**：先不删，而是给 `FunctionalColor` 的 12 个遮蔽符号加一个中间 commit——

```swift
@available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin; use contentPrimary or an explicit token")
```

编译一次，编译器会精确报出全部残留使用点（含任何审计未发现的）。逐处改写至零诊断后，再删符号。

**必须用 `deprecated`，不能用 `unavailable`**——这一点已实测确认，四种方案的结果：

| 方案 | 结果 |
|---|---|
| `@available(*, unavailable)` | **零诊断**，静默通过。重载决议会把 unavailable 候选**排除**出候选集，于是直接落到 SwiftUI 内建成员 |
| 改名（`primary` → `__a1_primary`） | 零诊断，同样静默落到 SwiftUI |
| 移出 `Color` 扩展到独立命名空间 | 零诊断，同上 |
| **`@available(*, deprecated)`** | **精确报出每个使用点**：`warning: 'primary' is deprecated: A1 probe` |

差别在于 `deprecated` 候选**仍参与重载决议并胜出**，只是附带诊断；`unavailable` 候选则被踢出决议。这恰好意味着：越是"强"的标记，对本场景越无效。

配合 `-warnings-as-errors` 可把它变成硬闸门（实测输出 `error:` 而非 `warning:`），确保不会有残留点被忽略。

验证脚本（`#2` 执行时用）：

```bash
swiftc -typecheck -warnings-as-errors ...   # 或临时给 target 加 .unsafeFlags(["-warnings-as-errors"])
```

### 分支拓扑

epic 集成分支 `epic/coredesign-audit-remediation`（off `main`）。每个 Issue 走私有 worktree + 分支，PR base 指向 epic 分支。**禁止直接合 `main`**；`epic → main` 是唯一硬停点，需用户确认。

### 每个 Issue 的完成定义

1. 四条 SwiftPM 命令绿：`swift build` / `swift test` / 两者的 `--traits Blossom` 版本
2. `#4` 额外需第 5 条：`xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`。**布局断言层由 `#4` 自己编写**，不放在 `#7`——否则 `#4` 完成时该命令下无任何 `#if os(iOS)` 测试可跑，等于空转，而 Dynamic Type + Sidebar 裁切正是全 epic 风险最高的改动，其安全网必须与改动同批落地。`#7` 只负责恒真断言清理与 Blossom 分流断言。这也与 PRD US-2 把布局断言写在 Dynamic Type 名下的归属一致
3. 更新 `audit-checklist.md` 中本 Issue 承载条目的状态（SC-7 判定基础）
4. **凡触及布局断言覆盖文件的 Issue（至少 `Sidebar.swift`）同样跑第 5 条**——`#10` 的 D6b 重塑 Sidebar row init 形态、`#11` 的 D18 给 Sidebar 补 Preview，都在 `#4` 之后动该文件；而布局断言 `#if os(iOS)` 包住，四条 SwiftPM 命令下不可见。若 CI 降级，弄破断言将无人发现
5. **新增或删除** colorset 后须 `swift package clean` 再验证——`#2` 要删 4 个 `status-accent-*.colorset`，不 clean 时 `.build` 里的陈旧拷贝会让「孤儿资产已清除」类验证假绿

## Task Breakdown Preview

「依赖」列写的是**真实文件级前置**（共享文件才算依赖），不是阶段链——阶段链另见上方推荐调度。两者分开，是为了让后续重排或 agent 自主调度不被假依赖锁死。

| # | 任务 | 承载项 | 真实依赖（共享文件） | 可与之并行 |
|---|---|---|---|---|
| 1 | 构建配置前置：CI + `defaultIsolation` + 预览宿主 trait | 5 | — | 无（硬前置，须最先合入） |
| 2 | 色彩层重组 | 12 | #1 | — |
| 3 | 公开 API 修复与改名 | 6 | #2（CheckBox） | #4 |
| 4 | Dynamic Type 改造 | 2 | #2, #5, #6 | #3 |
| 5 | 按钮体系 + Sidebar 收敛 | 8 | #3（BorderlessButtonStyle、MenuButton） | **#6** |
| 6 | 死代码清理与现代化 | 18 | #2, #3（CheckBox） | **#5** |
| 7 | 测试质量重建 + Blossom 断言 | 4 | #2（StatusColorsTests）；#4 为**语义依赖**（等布局断言层落地后再定测试边界），无共享文件 | **#11** |
| 8 | 可访问性 | 3 | #2（Form）, #4, #6（BottomInputBar） | **#9, #10** |
| 9 | 本地化 String Catalog | 1 | #1（Package.swift 加 `defaultLocalization`）, #3（MenuButton 改名）, #4, #6（BookCover）, #10（MenuButton、Toast） | #8 |
| 10 | 公开 API 形态统一 | 9 | #3, #4 | **#8** |
| 11 | 机械清理 | 10 | #2（Banner）, #3（MenuButton）, #4, #5, #6, #8（BottomInputBar）, #9, #10 | **#7** |

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

标注每条的**可机械判定程度**——这是 SC 能否作为自动闸门的前提：

| # | 标准 | 判定 |
|---|---|---|
| 1 | 下游消费包能编译使用全部文档所述 public API（0 个 `inaccessible` / `cannot find in scope`） | 机械（probe 包进 CI）。**若 CI 降级，本条随之降级为本地执行**——与 SC-4 同一降级路径 |
| 2 | `grep -rn "#if Blossom" Sources/ \| wc -l` 从 9 降至 8 | 机械 |
| 3 | 10 个 typography token 全部支持缩放；`CoreControlMetrics` 不再暴露返回 `Font` 的 API | 后半机械（grep 返回类型）；前半靠 `#4` 的 iOS 布局断言兜底 |
| 4 | CI workflow ≥1，覆盖五条命令（runner 受限时降级为本地 pre-push 闸门） | 机械 |
| 5 | 恒真断言归零 | `#7` 附录落盘后机械 |
| 6 | ≥1 个测试能区分默认与 Blossom 的实际颜色值（light `#0077FA` vs `#FF6F8E`） | 机械 |
| 7 | `audit-checklist.md` 83 项全部标记「已修复」或「记录不修 + 理由」 | 机械（核对命令已实测输出 83 / 78） |
| 8 | `Sidebar` 四种 row 的实现代码 **≤ 60 行**。测量边界：`SidebarNavigationRow` / `SidebarUtilityRow` / `SidebarDocumentRow` / `SidebarTagRow` 四个类型声明的首行到末行之和，**含**共享骨架类型与薄封装 init，**不含** `#Preview` 与文档注释 | 机械（原表述「约 120 → 约 50」不可判定，改为硬上限 + 测量边界） |

## Estimated Effort

**11 个 Issue，以串行为主，三个并行窗口**（`#5∥#6`、`#10∥#8`、`#11∥#7`）。关键路径仍接近总工作量，但比全串行方案明显缩短——尤其 `#6`（承载项最多）与 `#5` 并行的那一段。

按承载项数与波及面，工作量最重的四个：

| Issue | 项数 | 触及文件 | 说明 |
|---|---|---|---|
| `#6` | 18 | 约 16 个 swift + CLAUDE.md + 3 个 docs | 含 `EmptyState` / `View+SizeReader` / `KeyboardHandling` 三个整文件删除及其测试 |
| `#4` | 2 | 28（改动 27） | 全 epic 改动面最大的单项，`Sidebar` 一文件就有 16 处 |
| `#10` | 9 | 约 16 | 全是设计级改动（`StatusLevel` 合并、style 协议化、`@ViewBuilder` init），按文件数与 `#6` 同量级 |
| `#2` | 12 | 11 + 4 个 colorset + 4 个 docs | 含三处 A1 型静默重解析，须用毒丸 commit 让编译器穷举 |

**项数不等于工作量**——`#4` 只有 2 项却是最大改动面，`#10` 项数中等但每项都是设计决策，两者都是反例。最轻的是 `#9`（1 项 / 3 文件）。

**首要风险**：`#1` 的 CI runner 可用性未验证。若 hosted runner 不支持 Xcode 26 + iOS 26 Simulator，CI 降级为本地 pre-push 脚本；这不阻塞其它 Issue（验证以本地命令为准），但会使 `#4` 的布局断言层失去自动化守护。

**其余需在任务定义中钉死的风险点：**

- **`#1` 的 `defaultIsolation` fallout 未建模**：全库默认隔离翻转可能在任意组件或测试冒出并发诊断，届时 `#1` 被迫改组件文件，而矩阵没建模这一点，还可能白改 `#6` 即将删除的 `KeyboardHandling.swift`。约束：诊断修复最小化、只加注解不重构、落在 `#6` 删除名单内的文件不做任何整理、诊断量超出预期则停下回报而非硬修。
- **`#6` 的 B7a「至少一处组件真实消费 `CoreGradient`」是矩阵盲点**：消费点文件未指定，若选中 `#5` 的文件（如某个 ButtonStyle）会静默破坏 `#5 ∩ #6 = ∅` 的并行前提。约束：消费点必须钉在 `#6` 自有文件内（`BookCover` 或 `CommentCard`）。
- **`#9` 会触碰 `Package.swift`**：SPM 对含 `.xcstrings` 的 target 强制要求 `defaultLocalization`。这是一处未建模的跨 Issue 触碰（`Package.swift` 属 `#1`）。时序上无冲突（`#9` 在后），但须写进 `#9` 范围并要求四条 trait 命令复验。
