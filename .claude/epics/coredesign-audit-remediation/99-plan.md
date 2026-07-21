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
    }
```

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

**当前状态**：三个 public 图标视图。`LabelIcon`（`:55` body）与 `ChevronRightIcon`（`:83` body）纯装饰（信息由邻近 `Label` 的 `Text` / 行标题承载）；`DangerIcon`（`:100` body）**承载语义**（危险状态本身是信息）。**三者处理方式不同，逐一核对。**

- [ ] **Step 1: `LabelIcon` 纯装饰 → hidden**

`LabelIcon.body` 的根 `Image(systemName: "app.fill")…` 链，在 `.overlay { … }` 之后补：
```swift
            .overlay(alignment: .center) {
                Image(systemName: self.systemName, variableValue: self.variableValue)
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentInverse)
            }
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
            .accessibilityLabel("Warning")
    }
```

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

- [ ] **Step 3: 标记 audit-checklist D1a/D1b/D1c + 计数核对**

三项标 `✅ 已修复（GitHub #99）`。**只改状态描述，不增删数据行**，计数须仍 83 / 79：
```bash
cd .claude/epics/coredesign-audit-remediation
echo "计数1: $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))"   # => 83
echo "计数2: $(grep -oE '\| #[0-9]+ \|$' audit-checklist.md | sort | uniq -c | awk '{s+=$1} END{print s}')"  # => 79
```

- [ ] **Step 4: VoiceOver 冒烟说明**

代码层已补齐（三处 modifier）。运行时 VoiceOver 冒烟（DoD 末项）需 iOS Simulator 手动开 VoiceOver / Accessibility Inspector 走一遍——**代码层无法自动断言 a11y**（ViewInspector 属 Out of Scope）。在 `updates/99/progress.md` 记录：三个按钮有可读 label、tab 选中态播报 `.isSelected`、装饰图标不被聚焦；建议用户在 Simulator 手动复核。

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
