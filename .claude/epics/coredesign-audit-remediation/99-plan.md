# 可访问性 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐三处 VoiceOver 缺口（D1a/D1b/D1c）——icon-only 按钮补 label、tab 选中态补播报、装饰图标隐藏 / 语义图标补 label。把同仓已有正确做法补到遗漏处，不引入新模式。

**Architecture:** 纯组件改动，只加 accessibility modifier。三处处理原则**不同**（label / hidden / addTraits），逐处按图标性质定，不一律照抄。只碰三个组件文件 + `audit-checklist.md`。

**Tech Stack:** SwiftUI accessibility modifier。不引入 XCTest / UI 测试依赖（a11y 运行时验证靠 VoiceOver 冒烟，代码层靠编译 + grep 核对）。

## Global Constraints

- 四条 SwiftPM 命令绿、零 warning。
- **本轮 a11y 字符串直接写英文字面量**（与全库既有 `"Loading"`/`"Progress"` 一致）；String Catalog 迁移归 #100，不在本任务引入 `.xcstrings`（那会碰 `Package.swift`）。
- 三处处理原则不同（见下表），`DangerIcon` 是最易误判处——它承载语义，补 label 而非隐藏。
- 代码风格：显式 `self.`、中英双语注释与 `// MARK: -`。

| 图标类型 | 处理 | 本任务实例 |
|---|---|---|
| icon-only 可交互控件 | `accessibilityLabel` | BottomInputBar 三按钮、`Form.DangerIcon` |
| 纯装饰、信息已由邻近文本承载 | `accessibilityHidden(true)` | `Form.LabelIcon`、`Form.ChevronRightIcon` |
| 状态需播报 | `accessibilityAddTraits` | `UnderlinedTabItem` |

---

### Task 1: D1a — BottomInputBar 三个 icon-only 按钮补 label

**Files:**
- Modify: `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift`

**当前状态**：全文件 `accessibility` 出现 0 次。三个 icon-only Button 是私有计算属性 `suggestionButton`（`wand.and.sparkles.inverse`）、`sendButton`（`paperplane`）、`stopButton`（`stop.fill`）。#97 拆分 body 后，它们仍是独立计算属性（不是内联在 body 里，故三处各改一行即可）。

- [ ] **Step 1: 三个按钮各补 `.accessibilityLabel`**

`suggestionButton`（现 `.buttonStyle(.circularGlass)` 结尾）：
```swift
    private var suggestionButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                self.isShowingSuggestions.toggle()
            }
        } label: {
            Image(systemName: "wand.and.sparkles.inverse")
                .coreFont(.titleSmall)
        }
        .buttonStyle(.circularGlass)
        .accessibilityLabel("Suggestions")
        .accessibilityAddTraits(self.isShowingSuggestions ? .isSelected : [])
    }
```

`suggestionButton` 是 **toggle**（切 `isShowingSuggestions`）——除 label 外补 `.accessibilityAddTraits(... .isSelected ...)` 播报展开态，否则 VoiceOver 只念「Suggestions, button」、听不出面板开合（与本任务 D1b 的 trait 模式一致）。`sendButton`/`stopButton` 是一次性动作，无状态需播报；`trailingButton:110-111` 的 `.disabled`/`.opacity` 已自动播报「dimmed」，无需额外处理。

`sendButton`：
```swift
        .buttonStyle(.circularGlass)
        .accessibilityLabel("Send")
    }
```

`stopButton`：
```swift
        .buttonStyle(.circularGlass)
        .accessibilityLabel("Stop")
    }
```

label 加在 **Button** 上（整个可交互元素的 label），不加在 `Image` 上——与全库 icon-only 控件惯例一致。

- [ ] **Step 2: 验证 accessibility 出现次数从 0 → 3**

```bash
grep -c 'accessibilityLabel' Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift   # => 3
```
Expected: `3`（DoD 要求「从 0 变为 ≥ 3」）。

- [ ] **Step 3: 提交**

```bash
git add Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift
git commit -m "a11y: BottomInputBar 三个 icon-only 按钮补 accessibilityLabel（D1a）"
```

---

### Task 2: D1b — UnderlinedTabItem 补选中态播报

**Files:**
- Modify: `Sources/CoreDesign/Components/TabBar/UnderlinedTabBar.swift`

**当前状态**：`UnderlinedTabItem`（private struct，`:143`）的 `body` 是一个 `Button`，`self.isSelected` 只驱动字重与下划线，**未暴露给辅助技术**。同仓正确范例：`SegmentedControl.swift:118`、`Sidebar.swift:162` 都用 `.accessibilityAddTraits(isSelected ? .isSelected : [])`。

- [ ] **Step 1: 在 `UnderlinedTabItem` 的 Button 上补 trait**

`body` 的 `Button { ... }` 现以 `.buttonStyle(.plain)` 结尾，在其后补：
```swift
        .buttonStyle(.plain)
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
```
（带 `self.` 与 `Sidebar.swift:162` 写法一致。）

- [ ] **Step 2: 验证写法一致**

```bash
grep -n 'accessibilityAddTraits' Sources/CoreDesign/Components/TabBar/UnderlinedTabBar.swift
```
Expected: 一行 `.accessibilityAddTraits(self.isSelected ? .isSelected : [])`，与 `SegmentedControl.swift:118` / `Sidebar.swift:162` 同形。

- [ ] **Step 3: 提交**

```bash
git add Sources/CoreDesign/Components/TabBar/UnderlinedTabBar.swift
git commit -m "a11y: UnderlinedTabItem 补 .isSelected trait 播报选中态（D1b）"
```

---

### Task 3: D1c — Form 三个图标的语义区分

**Files:**
- Modify: `Sources/CoreDesign/Components/Form/Form.swift`

**当前状态**：三个 public 图标视图。`LabelIcon`（`:55` body）与 `ChevronRightIcon`（`:83` body）在 Form 语境是装饰（信息由邻近 `Label` 的 `Text` / 行标题承载）；`DangerIcon`（`:100` body）**承载语义**（危险状态本身是信息）。**三者处理方式不同，逐一核对。**

> **关于把 `hidden` 烤进 public primitive 的取舍**（评审 Finding 1）：`Sidebar.swift:112-114` 立了「a11y 语义由调用方决定，骨架不代为决定」的约定，在**组合点**（`SidebarRow.body:133`）而非骨架里加 hidden。`LabelIcon` 是 public leaf，`ChevronRightIcon` 也是。区别在确定性：
> - `ChevronRightIcon` **无歧义**——它永远是「进入下一级」的 disclosure 指示符（对齐 `Sidebar.swift:58` 对 chevron 的处理），任何语境下都装饰，烤 hidden 安全。
> - `LabelIcon` 有 systemName 由调用方给，**可能**被单独用作行的唯一内容。故**不无条件烤死**：加 hidden(true) 作 Form 语境默认，但在注释里写明设计契约（icon 槽、信息由配对 Text 承载）与 opt-out 路径 `.accessibilityHidden(false)`，让单独使用的调用方能恢复。

- [ ] **Step 1: `LabelIcon` → hidden（Form 语境默认，可 opt-out）**

`LabelIcon.body` 的根 `Image(systemName: "app.fill")…` 链，在 `.overlay { … }` 之后补：
```swift
            .overlay(alignment: .center) {
                Image(systemName: self.systemName, variableValue: self.variableValue)
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentInverse)
            }
            // LabelIcon 设计为 `Label { Text(...) } icon: { LabelIcon(...) }` 的 icon 槽，
            // 信息由配对的 Text 承载，故默认对 VoiceOver 隐藏。若单独用作行的唯一内容，
            // 调用方以 `.accessibilityHidden(false)` 恢复（骨架给默认、不越俎代庖锁死）。
            .accessibilityHidden(true)
```

- [ ] **Step 2: `ChevronRightIcon` 纯装饰 → hidden**

```swift
    public var body: some View {
        Image(systemName: "chevron.right")
            .accessibilityHidden(true)
    }
```

- [ ] **Step 3: `DangerIcon` 承载语义 → label（不是隐藏）**

```swift
    public var body: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(Color.statusDangerForeground)
            .accessibilityLabel("Alert")
    }
```

> **文案为何是 `"Alert"` 而非 `"Warning"`**（评审 Finding 2）：`DangerIcon` 渲染 `statusDangerForeground`（红，danger 语义）。而 `FunctionalColor.swift` 的 `warning`（橙）与 `danger`（红）是**两个不同的状态语义**（CLAUDE.md 第 4 层 success/info/warning/danger）。给 danger 图标念「Warning」会把屏读用户本该能区分的两个状态混淆。用 `"Alert"`（与 danger「需要注意」语义对齐、不撞 `warning` token）。init 参数化默认 label 属 API 形态改造（#101 范围），本任务用固定字面量。

- [ ] **Step 4: 验证三者处理不同**

```bash
grep -n 'accessibilityHidden\|accessibilityLabel' Sources/CoreDesign/Components/Form/Form.swift
```
Expected: 两处 `.accessibilityHidden(true)`（LabelIcon / ChevronRightIcon）+ 一处 `.accessibilityLabel("Warning")`（DangerIcon）。

- [ ] **Step 5: 提交**

```bash
git add Sources/CoreDesign/Components/Form/Form.swift
git commit -m "a11y: Form 装饰图标 hidden、DangerIcon 补 label（D1c）"
```

---

### Task 4: 验证 + audit-checklist

**Files:**
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`

- [ ] **Step 0: 前置——确认 base 含声明的依赖已落**（评审 Finding 5）

`99.md` front-matter `depends_on: [93,95,97]` 与正文 `002/004/006` 是两套编号；本任务假设它们已在 `epic/coredesign-audit-remediation` 上。落地前显式核实（而非隐式假设）：
```bash
# 002 已迁：Form 用新 statusDangerForeground、无 legacy Color.dangerForeground
grep -n 'dangerForeground' Sources/CoreDesign/Components/Form/Form.swift   # 应见 statusDangerForeground，无裸 Color.dangerForeground
# 006 已拆：BottomInputBar 的三个按钮是独立计算属性
grep -cE 'private var (suggestion|send|stop)Button' Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift  # => 3
```
Expected: Form 用 `statusDangerForeground`；三个按钮计算属性各在。任一不符则停下核对依赖是否真落地。

- [ ] **Step 1: 四条 SwiftPM 命令（clean 冷跑）**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-99"; mkdir -p "$LOGDIR"
swift package clean
swift build                  > "$LOGDIR/b.log"  2>&1; echo "build          EXIT=$?"
swift test                   > "$LOGDIR/t.log"  2>&1; echo "test           EXIT=$?"
swift build --traits Blossom > "$LOGDIR/bb.log" 2>&1; echo "build-blossom  EXIT=$?"
swift test  --traits Blossom > "$LOGDIR/tb.log" 2>&1; echo "test-blossom   EXIT=$?"
for l in b t bb tb; do echo "$l warning: $(grep -c 'warning:' "$LOGDIR/$l.log")"; done
```
Expected: 四条 EXIT=0，warning 全 0。

- [ ] **Step 2: 只碰目标文件自查**

```bash
git diff --name-only epic/coredesign-audit-remediation..HEAD | grep -vE '^(Sources/CoreDesign/Components/(BottomInputBar|TabBar|Form)/|\.claude/)' ; echo "rc=$?"
```
Expected: `rc=1`，无越界输出（改动只在三个组件目录 + `.claude/`）。

- [ ] **Step 2b: 逐处精确核对 label 值 / 元素**（评审 Finding 3——grep 计数只证「存在」，须证「值对、挂对元素」，抓 `stopButton` 误标 "Send" 之类）

```bash
# 每个按钮计算属性块内的 label 值（-A 取上下文，确认 value 挂在对的按钮上）
grep -A6 'private var suggestionButton' Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift | grep -E 'accessibilityLabel|accessibilityAddTraits'  # "Suggestions" + isSelected trait
grep -A6 'private var sendButton'       Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift | grep 'accessibilityLabel'  # "Send"
grep -A6 'private var stopButton'       Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift | grep 'accessibilityLabel'  # "Stop"
# Form 三图标：LabelIcon/ChevronRightIcon hidden、DangerIcon 是 "Alert"（非 "Warning"）
grep -B2 'accessibilityHidden(true)' Sources/CoreDesign/Components/Form/Form.swift   # 命中 LabelIcon / ChevronRightIcon 上下文
grep -n 'accessibilityLabel("Alert")' Sources/CoreDesign/Components/Form/Form.swift  # DangerIcon
grep -c 'accessibilityLabel("Warning")' Sources/CoreDesign/Components/Form/Form.swift  # => 0（不得撞 warning token）
```
Expected: 三按钮各自块内 label 值正确对应（send="Send"/stop="Stop"/suggestion="Suggestions"+trait）；Form 两 hidden + DangerIcon="Alert"、零 "Warning"。**任一值挂错元素即停下修正**——这是 grep 计数抓不到、VoiceOver 才能抓的那类错误的代码层替代核对。

- [ ] **Step 3: 标记 audit-checklist D1a/D1b/D1c + 计数核对**

三项标 `✅ 已修复（GitHub #99）`。**只改状态描述，不增删数据行**，计数须仍 83 / 79：
```bash
cd .claude/epics/coredesign-audit-remediation
echo "计数1: $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))"   # => 83
echo "计数2: $(grep -oE '\| #[0-9]+ \|$' audit-checklist.md | sort | uniq -c | awk '{s+=$1} END{print s}')"  # => 79
```

- [ ] **Step 4: VoiceOver 运行时项——显式 deferred，不用 grep 冒充完成**（评审 Finding 3）

代码层已补齐并经 Step 2b 逐处精确核对（label 值挂对元素、DangerIcon 非 Warning、trait 正确）。但 DoD 末项的**运行时 VoiceOver 冒烟**（开 VoiceOver 听 spoken output）**本任务不自动执行**——ViewInspector 属 Out of Scope，swift test 断言不了 a11y 运行时行为。诚实处理：
- audit-checklist 的 **D1a/D1b/D1c 标 ✅**：这三项审计缺陷是「代码层缺 modifier」，代码已修复且逐处核对，审计项闭合。
- `99.md` DoD 的 **VoiceOver 冒烟项标 `deferred（运行时，待用户 Simulator 复核）`，不勾选**——它是运行时验证，不因代码修复自动满足（Step 3 标记与本项状态不得互相矛盾）。
- `progress.md` 记下代码层核对的 spoken-label 预期：`Suggestions`（+展开态 selected）/ `Send` / `Stop` / tab 选中态 `.isSelected` / `LabelIcon`·`ChevronRightIcon` 不被聚焦 / `DangerIcon` 念 `"Alert"`；并明说运行时 VoiceOver 未自动跑、建议用户手动走一遍。

- [ ] **Step 5: 写 progress.md + 提交**

```bash
mkdir -p .claude/epics/coredesign-audit-remediation/updates/99
git add .claude/epics/coredesign-audit-remediation/
git commit -m "docs(ccpm): 标记 D1a/D1b/D1c + #99 完成记录"
```

---

## 收尾

`verification-before-completion` → `finishing-a-development-branch` Option 2 开 PR（**base = `epic/coredesign-audit-remediation`**）→ Copilot 不可用，降级 `superpowers-reviewer` + PR 顶层评论留痕。

PR 描述须含：三处处理原则不同（label / hidden / addTraits）、DangerIcon 为何补 label 而非隐藏、accessibility 出现次数变化、VoiceOver 冒烟状态。
