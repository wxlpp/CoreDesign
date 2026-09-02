---
name: coredesign-leftover-closeout
status: backlog
created: 2026-09-02T14:57:15Z
updated: 2026-09-02T15:28:35Z
progress: 0%
prd: .claude/prds/coredesign-leftover-closeout.md
github: https://github.com/wxlpp/CoreDesign/issues/219
---

# Epic: coredesign-leftover-closeout

## Overview

清算 CoreDesign 的三个 open 遗留 issue（#115 / #136 / #139），使 `gh issue list --state open` 归零。

PRD 已完成实测对账：8 个子项里 **3 项已被 #117 / #118 作废**、**1 项是纯记账**、**4 项仍成立**。本 epic 只做仍成立的部分，作废项在关闭说明里如实注销。

**本 epic 的特殊性**：PRD 阶段经历了 **4 轮 superpowers-reviewer + 1 轮 Copilot 交叉复核**，其中 3 轮 BLOCK 全部命中同一类错误——*在验收条款里写下未经推演的精确数字或钉错断言层*。这段病史直接决定了下面 ADR-1 与 ADR-4 的形态：**本 epic 的验收判据本身，比它要改的代码更容易出错。**

## Architecture Decisions

### ADR-1 · `SurfaceKind` 走「分类别取 token」，且数字必须出自推演表

底层容器用 `SurfaceColors`（不透明背景族），叠加层用 `FillColors`（半透明）——这是 #122 为 Badge bug 立下的裁决（`Badge.swift:143`：「任何单一 surface token 都修不好这个问题，问题出在**种类**选错」）的直接适用。

只改**三个 token 别名**，不改 `SurfaceKind.background` 的 switch（承 #140 先例：可测 + 修掉公开 token 名实相悖）：

| token | → | 服务的 kind |
|---|---|---|
| `surfaceSidebar` | `.surfaceElevated` | `.sidebar` |
| `surfaceOverlay` | `.secondaryFill` | `.floating` |
| `surfacePanel` | `.quaternaryFill` | `.overlay` / `.panel` |

**distinct 数：iOS 深色 6 / iOS 浅色 5 / macOS 5**——这三个数**必须、且只能**出自 PRD FR-1 的推演表。v1 写「6」、v2 写「7」，两次都是在散文里推理丢了跳（v1 丢了背景族取值上限，v2 丢了 `.overlay`/`.panel` 共享 token）。**任何新数字都要先把 `kind → token → 终值` 全表跑出来。**

### ADR-2 · 断言分三层，各有各的执行载体，不得混用

| 层 | 用于 | 载体 | 依据 |
|---|---|---|---|
| `Color.Resolved` 逐位 | iOS 深色 / 浅色 | `SurfaceContrastTests`（`#if os(iOS)`），**必须 `xcodebuild` iOS Simulator** | `swift test` 对它空跑假绿 |
| **token 身份** | macOS | `SystemBackgroundColorsMacOSTests`，`swift test` | `SystemBackgroundColorsMacOSTests.swift:15-21`——无 WindowServer 时 RGBA 会塌成同一 fallback，故该 suite **刻意不解析** |
| 观感「可辨」 | 全部 | **只有 FR-9 的截图评审** | 光栅/数值判据都证不了 |

第 3 轮 BLOCK 正是把 macOS 钉在了第 1 层。**测试与文档一律只说「解析值/token 不同」，「可辨」二字只许出现在视觉复核里。**

### ADR-3 · `BottomInputBar` 提 public 是一次「推翻成文裁决」，独立成 task

`docs/component-contract.md:1278-1291` 的终审 C1 裁决明确把它排除出登记表，理由是「struct 无 public 修饰符」——提 public 恰是该裁决自己给出的两条出路之一，**方向合法，但裁决文本、判定法走查、`placeholder` 分类都要一并改写**。外加 `docs/bool-exemptions.json:27-68` 的 7 条 Bool 豁免（其中 `:28` 的 reason 直接引用该前提、会失真）与 `oh-my-story#50` 的跨仓移交通知。

这不是「守卫报错后顺手改绿」，故独立成 task/PR。

### ADR-4 · 每个新守卫都要变异自证，且靶点不得打在恒等档上

本仓有「护栏结构性失明」病史。三个新守卫（`SurfaceKind` 分化 / a11y 字面量 / `AGENTS.md` 分歧）各自附「改坏 → 跑 → 贴失败输出 → 改回」。

⚠️ 两个具体陷阱：
- `SurfaceKind` 的变异靶点**必须**打在 `surfaceOverlay`（`.floating` 的唯一来源），**不得**打在 `{.overlay,.panel}` 这种本来就该相等的档位——那样的变异不会红，会造成守住了的假象。
- a11y 守卫的变异**要打在插值内层**（`SearchField.swift:116` 的 `"search"` fallback），那是按行扫描最容易失明的形态。

### ADR-5 · 关闭说明逐条写，禁止全称句

三个 issue 的关闭说明里，**每个子项各有独立结论**；作废项写明作废来源（#117 / #118）。**不得出现「已全部处理」这类笼统全称句**——本仓的失真高发地正是 commit message 与 issue 回复，它们不在任何自动校验射程内。

## Technical Approach

### 颜色与守卫层（`Colors/` + `Tests/`）

三个别名改写 + 两个 suite 扩展。

**同 commit 清洗被写假的旧论述——共 5 段，分两类**：

*A 类 · 「别名指向」类*（PRD FR-1 已列）：
- `SurfaceColors.swift:21-26`（文件头：`surfaceSidebar` 走 `surfaceCanvasSubtle`）
- `SurfaceColors.swift:85-91`（`surfacePanel` doc：与 `surfaceCanvasSubtle` 同值 / 层级差异改由边框表达 / 收敛为 3 个 distinct）
- `SurfaceColors.swift:96-99`（`surfaceSidebar` doc）

*B 类 · **「`surfaceElevated` 零消费」类***（评审 Important-1 + 本轮自查追加，**PRD 未列**）：
- `Tests/CoreDesignTests/SystemBackgroundColorsMacOSTests.swift:50-60`——`:57` 写「零消费的是 tertiary（`surfaceElevated` / `surfaceGroupedElevated`，**组件层 0 引用**）」，`:60` 写「受益方还是个零消费 token」，整段「故不硬塞系统色给 tertiary」的论证以此为前提。
- `Sources/CoreDesign/Colors/SystemBackgroundColors.swift:83`——「（`surfaceGroupedElevated` / `surfaceElevated` **未被任何组件引用**）」。

⚠️ **B 类是 001 亲手制造的**：`surfaceSidebar → surfaceElevated` 后，`surfaceElevated` 经 `.surface(.sidebar)` 公开通路 + App 三处 `Color.surfaceSidebar` 直接消费点，**首次获得真实消费者**。（实测当前 `surfaceElevated` 在 `Sources/`/`App/` 确为零引用，只有那句 doc 提及。）最刺的是：FR-3 要求扩展的**正是** `SystemBackgroundColorsMacOSTests.swift`——实现者会在一个头顶挂着假前提的文件里加新断言。

**另有一段边界前提须改写**（PRD FR-2 标注「易漏」，epic v1 掉了）：`Tests/CoreDesignTests/SurfaceContrastTests.swift:19-27` 现写「当前代码库里没有任何近似撞色的真实案例可用来标定阈值……现有 token 两两之间都差着几十个色阶」——FR-1 恰好制造**首批 alpha-only 近撞案例**（三个 fill 的 RGB 几乎相同、只靠 α 区分），该前提被写假。

**验收 grep 的关键词必须覆盖两类**（A 类关键词命中不了 B 类，这是结构性失明）：
```
范围：Sources/ Tests/ docs/components/ docs/component-contract.md
A 类：「层级差异改由」「收敛为 3 个」「surfaceCanvasSubtle 同值」
      + 正则「而非.*surfaceGrouped」   ← 命中 :21 与 :96
      + 「侧栏应与画布区隔」            ← 命中 :25
B 类：「零消费」「未被任何组件引用」「组件层 0 引用」
      + 「生产消费点」                  ← 跨行半句
边界：「没有任何近似撞色的真实案例」
```

⚠️ **A 类前三个关键词只命中 `:89` / `:91`——漏掉 A 类自列三段中的两段**（`:21-26` 与 `:96-99` 不含其中任何一个）。追加的两条已实测恰中那两段、无误伤。这与 B 类是同一种结构性失明，只是发生在 A 类内部。

⚠️ **B 类的「生产消费点」是跨行半句**：`SystemBackgroundColors.swift:82-83` 原文为「……无实际⏎生产消费点（`surfaceGroupedElevated` / `surfaceElevated` 未被任何组件引用）」。只改括号内半句则前三个关键词清零而 `:82` 残留为假。实测「生产消费点」在验收范围内只命中 `:83`、无误伤。

⚠️⚠️ **验收 grep 本身会造假绿——必须逐条单跑。** 实测把多个 pattern 与多个路径合并成一条 `grep -rn "A\|B\|C" $VAR` 时**静默返回空**，而「静默为空」与「已清洗干净」在输出上**完全一样**。⇒ 每个关键词**单独一条命令、单独贴输出**；清洗**前**先跑一遍确认它**能命中**（非空），清洗**后**再跑确认清零。**没见过它非空，就不能拿它的空当证据。**


**`docs/BREAKING-CHANGES.md` 条目（PRD NFR-5，epic v1 蒸发）**：FR-1 是同名换值，须补一条视觉变更条目。该文件 `:454-460` 有 #140 改 `surfaceCard` 别名时的现成模板（标题 `:454`、表格行 `:458`、正文 `:460`）（含「对下游编译零感知 / 视觉上哪些 case 在哪些外观下变了 / 落地时库内有无生产消费点」三段式），照其形态写。

⚠️ `SystemBackgroundColorsMacOSTests` **当前完全不覆盖 fill**（`grep -c fill` → 0）——FR-1 首次把 fill 引入 `SurfaceKind` 背景通路，这块是**新增覆盖**。

### 组件公开面（`BottomInputBar` + `App/`）

struct 提 public + demo 宿主从占位文本改为可交互示例 + 注册进 `Previews.swift` 进快照流水线。撞上的守卫族（`ComponentRegistryGuard` / `ComponentContractStructureGuard` / `ComponentExtensionPointGuard` / `ReachableTypeRegistryGuard` / `ComponentTextParamGuard` / `BoolParameterScanner`）均为固定集合断言，会逐个报出要改的点。

### 本地化（`Resources/` + 守卫）

3 处 a11y 串（`SearchField.swift:94` / `:116` 含插值内层 / `ProgressBar.swift:65`）入 `.strings` / `.stringsdict`（`.xcstrings` 在 SwiftPM CLI 下不编译）。新守卫需能看见**插值内层**字面量，豁免机制以 `TagInput.swift:105`（`.accessibilityLabel(Text(self.placeholder))`，调用方传入值）为锚定首例。

⚠️ **豁免台账落新文件 `docs/a11y-exemptions.json`，不得追加进 `docs/bool-exemptions.json`**（评审 Suggestion-1）：后者正被 002 在 `:27-68` 改动，追加进去会直接打破「001–005 完全并发」的前提。PRD FR-6 只说「格式参照 `bool-exemptions.json` 先例」——是**照其格式**，不是**写进该文件**。

### 文档一致性（`AGENTS.md`）

删掉 `:42` 已被 #41 证伪的 `.glassEffect` / `colorScheme` 句，补 `CLAUDE.md:42,44` 的更正段；新守卫做规范化 diff，**允许的差异走显式白名单**，不用宽松正则吃掉一切。

### 视觉复核（模拟器）

runtime 已就位（iOS 26.4 + `iPhone 17 Pro`）。出图走 `KEEP_LIBRARY_SNAPSHOTS=1` keep 模式落 scratch，再**手工拷入恰好一对**（`.png` + 同名 `.json`）BottomInputBar 快照——`docs/snapshots/` 现有 78 文件 = 39 对，成对是既有约定。

⚠️ 合成对照（半透明档位叠在底层档位上）**没有现成载体**，须新增一个合成 `#Preview`。

## Task Breakdown Preview

| # | Task | 覆盖 | 并行 |
|---|---|---|---|
| 001 | `SurfaceKind` 取值分化 + 双平台守卫 + 旧论述清洗 | FR-1/2/3, US-1/2 | ✅ |
| 002 | `BottomInputBar` 提 public + demo 接通 + 裁决/豁免处置 | FR-4, US-3 | ✅ |
| 003 | a11y 串本地化 + 字面量守卫 | FR-5/6, US-4 | ✅ |
| 004 | `AGENTS.md` 同步 + 分歧守卫 | FR-7, US-5 | ✅ |
| 005 | 补两处测试断言（`SegmentedControl` / `StateLabel`） | FR-8 | ✅ |
| 006 | 视觉复核 **+ 新增合成对照 `#Preview`**（含 Sources 内代码改动，非纯截图） | FR-9 | ⛔ 依赖 001, 002, **003** |
| 007 | **`Sidebar.swift` doc comment + `docs/` 定案文** + 三个 issue 关闭 | FR-10/11, US-6 | ⛔ 依赖全部 |

⚠️ **006 依赖 003 的理由**（评审 Important-5）：FR-9 含 VoiceOver 冒烟（`BottomInputBar` / `UnderlinedTabBar` / `Form`），冒的正是 a11y 串的**读出路径**；而 003 把该路径从硬编码改成 `.strings` / `.stringsdict` 加载（含 `%lld%%` 转义这种真能读坏的改动）。006 先跑、003 后合，则 007 关闭 #115-2 时引用的冒烟结论覆盖的是**旧代码**。

⚠️ **006 / 007 的标签曾低报各自的 diff**（评审 Suggestion-3）：006 不是「纯截图」——它必须在 `Sources/` 新增一个合成对照 `#Preview`；007 不是「纯记账」——它背着 FR-10 的 `Sidebar.swift` doc comment 与 `docs/` 定案文。标签已改准，防止这两个 task 的代码 diff 逃过评审注意力。

001–005 五个 task 可完全并发（文件面基本不重叠）。006 是唯一的收束点，007 是终点。

## Dependencies

**内部**：`SurfaceContrastTests` / `SystemBackgroundColorsMacOSTests`（001）；`docs/component-contract.md:1275-1291` 与 `docs/bool-exemptions.json:27-68`（002）；守卫族（002）；`scripts/run-snapshots.sh` + `App/Sources/Previews.swift`（002 / 006）。

**外部**：iOS 模拟器 runtime（**已装**：iOS 26.4 / `iPhone 17 Pro`）+ `xcodebuild`；`ios-visual-reviewer` agent；`gh` CLI；`oh-my-story#50`（002 的跨仓通知对象，**只通知、不代改**）。

## Success Criteria (Technical)

1. `gh issue list --state open` → **0**（当前 3）。
2. `SurfaceKind` distinct 从 **3** → **iOS 深色 6 / iOS 浅色 5 / macOS 5**，全部已知相等项各有显式断言；iOS 组走 `xcodebuild` Simulator、macOS 组走 `swift test` 的 **token 层**。
   ⚠️ **逃生条款**：若 001 在模拟器实测到的 fill α 值与 PRD 推演表不符，按 NFR-2 **重新推演 distinct 数并回改 PRD / US-2 / PRD Success#3 / 本条**——**不得反过来削弱断言去迁就已写好的数字**。本条与它们同在回改名单上。
3. `diff CLAUDE.md AGENTS.md` 实质分歧 **1 → 0**，有守卫锁住。
4. 非 `#if DEBUG` 路径未走 `bundle: .module` 的 a11y 字面量（**含插值内层**）**4 → 0**，有守卫锁住。
5. `docs/snapshots/` 的 BottomInputBar 快照**恰好一对**由占位图更新为可交互 demo（porcelain 显示 `M`，非 `A`——该对本就存在），无其他条目。
6. `swift test` 全绿 + `xcodebuild` iOS 腿全绿；测试数不低于**开工时实测记录的基线**（不引用任何历史数字）。
7. 三个新守卫各附变异自证失败输出；`SurfaceKind` 的靶点是 `surfaceOverlay`，a11y 的靶点在插值内层。
8. 关闭说明逐子项独立结论，作废项写明来源。
9. **（US-1，epic v1 漏）** `SurfaceColors.swift` 中不再有指向已 closed issue 的待办式注释——以 grep 输出为证。
10. **（FR-8 / task 005，epic v1 漏）** `plainStyleOptsOutOfGlass` 与 `customLabelPreservesStyle` 各自**要么有真运行时断言、要么如实改名并注明只能做到什么**。⚠️ epic Success #6「`swift test` 全绿」在 005 什么都不做时照样通过，故本条不可省。
11. **（FR-9 / task 006，epic v1 漏）** 视觉评审对「半透明档位是否真的浮起来」给出明确结论（含浅色合成对照）；无法用现有手段证实的项（如 `SegmentedControl` thumb 动画）**如实记为「无法证实」，不得记「已复核」**。

## Kickoff Prerequisite（fork 前必做一次，不属任何 task）

**测试数基线必须在五个 task 并发 fork 之前记录一次**，否则五个 worktree 各记各的、或谁都以为别人记了（评审 Important-6）。

落点：`.claude/epics/coredesign-leftover-closeout/baseline.md`（**已完成**）。

- macOS 腿（`swift test`）：**454 tests / 68 suites / 2 known issues** 全绿，27.878s。
- iOS 腿（`xcodebuild -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`）：**495 tests / 73 suites / 1 known issue**，`** TEST SUCCEEDED **`。详见 `baseline.md` iOS 腿一节。
- ⚠️ **iOS 腿比 macOS 腿多 41 tests / 5 suites**——那就是 `#if os(iOS)` 盲区，task 001 的新断言**全部落在这条腿**。
- ⚠️ 首次跑 iOS 腿时踩到两个环境坑，已记入 `baseline.md`：`xcodebuild -downloadPlatform iOS` 装完后注册的设备**磁盘数据不存在**（`simctl list devices available` 照样列它为可用），需 delete + create 重建；以及 `xcodebuild ... | tail` 的**退出码来自 `tail`**，`** TEST FAILED **` 会伴随 `exit 0`——判绿必须读输出，不能读退出码。

Success #6 的「不低于基线」一律以本文件为准，**不得引用任何 memory 或历史 PR 里的数字**。

## Estimated Effort

7 个 task，其中 001 与 002 是主体（各含守卫处置与文档改写），003–005 较小，006 依赖模拟器与人工审美判断，007 是记账收尾。

**风险集中在验收判据而非实现**：本 epic 的三次 PRD BLOCK 全部发生在「怎么证明它对」这一侧，实现本身（改三个别名、提一个 public、搬三个字符串）是直白的。
