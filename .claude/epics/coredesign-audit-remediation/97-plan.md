# 死代码清理与现代化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删掉三个整文件的死代码、消除若干过时写法，并让 `CoreGradient` 这层抽象第一次被真实消费。

**Architecture:** 以**删除**为主、现代化为辅。删除类改动的风险不在编译（编译器会报），而在**删过头**（连带删掉仍有价值的东西）与**删不干净**（文档/注释残留）。现代化类改动的风险相反：容易在「等价替换」的名义下引入观感变化。

**Tech Stack:** SwiftPM / Swift 6 / SwiftUI，验证靠四条 SwiftPM 命令 + `#Preview` 视觉冒烟。

## Global Constraints

- **不得触碰 #96 的自有文件**（005 ∩ 006 = ∅ 必须保持）：四个 ButtonStyle、`ButtonRoleStyleRole.swift`、`Sidebar.swift`、`CoreMenuButton.swift`、`TelegramGlassButtonModifier.swift`。**B7a 的消费点选择是最容易失手的一处**——必须落在 `BookCover` 或 `CommentCard`。收尾用 basename 精确匹配自查（**不能用子串 grep**，`EmptyState`/`CommentCard`/`RefPill` 等同时是目录名，#96 踩过）。
- 四条 SwiftPM 命令绿。**warning 判据本任务特殊**：基线 12 条全是 `EmptyState` deprecation，B9g 删掉该文件后应**归零**——这是本任务少有的、能机械判定的正向指标。
- **最终 warning 采集前必须 `swift package clean`**（热构建不重放诊断，#94/#96 的教训）。
- 代码风格：显式 `self.`、中英双语注释、`// MARK: -`。**保留有设计说明价值的长注释**——拆分 `BottomInputBar` 的 body 时尤其注意（`autoFocus` 那段解释了为何必须在 bar 自身 `onAppear` 中执行）。
- **注释里只写今天成立的理由**。#96 的 B2b 把「大字号下不裁切」写进注释，而字号当时根本不缩放，导致验证的是一件不可能发生的事、永远绿。本任务删代码时容易写出「删除后 X 不再发生」的同型陈述——写之前先确认 X 今天真的会发生。

## 已实测的前置事实（不要重新推导）

| 事实 | 影响 |
|---|---|
| 基线绿：101 tests / 33 suites passed，**warning 12 条全是 EmptyState deprecation** | B9g 删完应归零 |
| `EmptyState.swift` 237 行、`View+SizeReader.swift` 51 行、`KeyboardHandling.swift` **167 行**（97.md 未给行数） | 三个整文件删除 |
| `EmptyState` 在 **Swift 侧零消费**（仅 docs 提及）；`getSize` 唯一消费点 `BottomInputBar.swift:138`；`KeyboardHandling` 的全部符号只被自己与 `KeyboardHandlingTests.swift` 消费 | 三个删除都干净 |
| `CoreRadius.full` 在**代码中零消费**，仅 4 处 doc 注释提及（`Avatar.swift:38`、`Badge.swift:43,58`、`Tag.swift:47`、`CoreRadius.swift:18`） | D10 删 token 时这 4 处注释要同步 |
| `SegmentedControl.swift` 的 `@available` 有**三处**：`:205`、`:301`（恒真，要删）、`:222` 的 `@available(*, unavailable)`（**不能删**） | B9d 只删两处 |
| `TimelineDepthKey` 在 `TimelineItem.swift:10`，测试引用在 `TimelineItemTests.swift:32`（97.md 写 `:30`，早两行） | B9b |
| `BookCover.swift:74` 在 body 里调 `Self.image(from: data)`，实现在 `:95` | B9a |
| 真实文件路径是 `Components/<Name>/<Name>.swift`（97.md 写的 `Components/CommentCard.swift` 等**少一层目录**） | 全任务 |

## 两处必须先定的判断（97.md 的前提与实测不符）

### 判断 1：B8d 的 `RefPill` **没有**对应的 `SurfaceKind`，不能按「等价替换」做

97.md 说 `RefPill.swift:51-56` 是「同型手写 surface 三件套」，与 B8c 并列。实测三者的 token：

| | background | border | cornerRadius |
|---|---|---|---|
| `CommentCard` 手写 | `surfaceCard` | `borderMuted` | `.medium` |
| **`.surface(.card)`** | `surfaceCard` | `borderMuted` | `.medium` |
| `RefPill` 手写 | **`surfaceCanvasInset`** | `borderMuted` | **`.small`** |
| `.surface(.control)` | `surfaceInteractive` | `borderSubtle` | `.small` |
| `.surface(.canvasSubtle)` | `surfaceCanvasSubtle` | `borderMuted` | `.medium` |

**没有任何 `SurfaceKind` 的 background 是 `surfaceCanvasInset`。** `RefPill` 换成任何现有 kind 都会改变背景色（甚至圆角）——那是视觉回归，不是重复消除。

处置：**B8c 做，B8d 不做**，并在 `audit-checklist.md` 的 B8d 行写明理由。三个可选方向留给后续任务判断：(a) 给 `SurfaceKind` 加一个 `.inset` case（是加法，本 epic 的 Out of Scope 禁止）；(b) 接受背景色变化（视觉回归，需列入 NFR 例外）；(c) 承认 `RefPill` 的取色是有意的、维持手写。**本任务选择不动，把判断权交给 #101（API 形态统一）**——它本来就要重塑这批组件的形态。

### 判断 2：B8c 的 `.surface(.card)` 会**额外引入 `clipShape`**

`SurfaceModifier` 的实现是三步：`background` + `overlay` + **`clipShape`**（见其 doc 注释第 3 条）。而 `CommentCard` 当前只有前两步。替换后子视图会被裁切到圆角内。

`CommentCard` 的 content 是 `@ViewBuilder` 传入的任意视图（`:90` 的 `self.content()`），调用方可能放溢出元素。这是**行为变化**，不是纯重复消除。

处置：仍然做（`.surface(.card)` 的裁切是该 modifier 的既定语义，且对 card 形态是合理的），但**必须在视觉冒烟里实看 `CommentCard` 的 `#Preview`**，并在 `audit-checklist.md` 的 B8c 行注明这一处受控变化。**若 Preview 显示内容被裁掉，停下改为保留手写**。

---

### Task 1: 三个整文件删除（B9g、B4a、B4b、B4c、B4d）

**Files:**
- Delete: `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`、`Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`
- Delete: `Sources/CoreDesign/Utils/View+SizeReader.swift`
- Delete: `Sources/CoreDesign/Utils/KeyboardHandling.swift`、`Tests/CoreDesignTests/KeyboardHandlingTests.swift`
- Modify: `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift`（删 `textFieldSize` 与 `.getSize` 调用）
- Modify: `CLAUDE.md`、`docs/README.md`、Delete: `docs/components/empty-state.md`

- [ ] **Step 1: 先删 `textFieldSize`（B4a），它是 `View+SizeReader` 的唯一消费点**

`BottomInputBar.swift` 中删除：`@State private var textFieldSize` 声明（约 `:87`）与 `.getSize(self.$textFieldSize)` 调用（约 `:138`）。先 grep 确认该变量确实只写不读：

```bash
grep -n 'textFieldSize' Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift
```
Expected: **恰好 2 行**（声明 + `.getSize` 写入）。若有第三行，说明它被读取，**停下**——B4a 的前提「写入后从不读取」不成立。

- [ ] **Step 2: 删三个文件及两个测试**

```bash
git rm Sources/CoreDesign/Components/EmptyState/EmptyState.swift
git rm Tests/CoreDesignTests/EmptyStateDeprecationTests.swift
git rm Sources/CoreDesign/Utils/View+SizeReader.swift
git rm Sources/CoreDesign/Utils/KeyboardHandling.swift
git rm Tests/CoreDesignTests/KeyboardHandlingTests.swift
rmdir Sources/CoreDesign/Components/EmptyState 2>/dev/null || true
```

- [ ] **Step 3: 文档同步（删除的连带义务）**

- `CLAUDE.md` 的《Modifier 约定》末句：「通用辅助方法（如 `.getSize`、`.focusedExternally`）放在 `Utils/`」——删去 `.getSize`，保留 `.focusedExternally`（**先 grep 确认后者仍存在**）。
- `docs/README.md:41`：删掉 EmptyState 的组件索引行。
- `git rm docs/components/empty-state.md`。
- **`docs/superpowers/` 下的历史 plan / spec 不改**（归档，它们记录的是当时的决策）。

- [ ] **Step 4: 验证零残留 + warning 归零**

```bash
grep -rn '\bEmptyState\b' Sources Tests App docs/components docs/README.md CLAUDE.md 2>/dev/null; echo "EmptyState rc=$?"
grep -rn 'getSize\|KeyboardReadable\|dismissKeyboardOnTap\|resignFirstResponder\|KeyboardHeightPublisherFactory\|becomeFirstResponder' Sources Tests App 2>/dev/null; echo "符号 rc=$?"
```
Expected: 两条都 `rc=1`、无匹配行。

```bash
swift package clean
swift test > /tmp/t97a.log 2>&1; echo "test EXIT=$?"
python3 -c "
d=open('/tmp/t97a.log').read()
w=[l for l in d.split(chr(10)) if 'warning:' in l]
r=[l.strip()[:50] for l in d.split(chr(10)) if 'Test run with' in l]
print(f'warning={len(w)} (预期 0)'); print(r[-1] if r else 'NO RESULT')"
```
Expected: **`warning=0`**——12 条 EmptyState deprecation 随文件消失。这是本任务最干净的一个正向指标。测试数会从 101 降（两个测试文件被删），**记下新数字**。

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "refactor!: 删除 EmptyState / View+SizeReader / KeyboardHandling 三个死代码文件（B9g、B4a-d）"
```

---

### Task 2: `CoreGradient` 三项（B7a、B7b、B7c）

**Files:**
- Move: `Sources/CoreDesign/Colors/CoreGradient.swift` → `Sources/CoreDesign/Tokens/CoreGradient.swift`
- Modify: 同文件（`static var` → `static let`）
- Modify: `Sources/CoreDesign/Components/BookCover/BookCover.swift`（B7a 消费点）
- Modify: `CLAUDE.md`（《渐变 token 层》段的路径）

- [ ] **Step 1: B7c 移动文件 + B7b 改 `static let`**

```bash
git mv Sources/CoreDesign/Colors/CoreGradient.swift Sources/CoreDesign/Tokens/CoreGradient.swift
sed -i '' 's/    public static var \(brand\|cta\|canvas\): AnyShapeStyle {/    public static let \1: AnyShapeStyle = {/' Sources/CoreDesign/Tokens/CoreGradient.swift
```

> ⚠️ `static var x: T { ... }` 改 `static let x: T = { ... }` **不是纯关键字替换**——计算属性的 body 要变成闭包并加 `()` 调用，或改写成直接的表达式。逐个 Read 确认改法正确，**不要盲信 sed**。若 body 是单表达式，最简形式是 `public static let brand: AnyShapeStyle = AnyShapeStyle(...)`。

同步 `CLAUDE.md`《渐变 token 层》段里的 `Colors/CoreGradient.swift` → `Tokens/CoreGradient.swift`。

- [ ] **Step 2: B7a 让 `BookCover` 真实消费 `CoreGradient`**

**消费点必须在 `BookCover` 或 `CommentCard`**（Global Constraints）。选 `BookCover`：它有一个**无封面数据时的占位背景**，天然适合渐变，且 Blossom 下能体现该抽象的价值。

Read `BookCover.swift` 的 `:70-90`，找到 `if let data, let image = ...` 的 `else` 分支（无图占位），把占位背景改为 `CoreGradient.brand`。

**验收要点**：默认主题下 `CoreGradient.brand` 退化为 `Color.accent` 纯色，观感应与改前接近；Blossom 下应显示真实渐变。**两种 trait 都要看 Preview。**

- [ ] **Step 3: 验证**

```bash
grep -rn 'CoreGradient\.' Sources/CoreDesign/ --include='*.swift' | grep -v 'Tokens/CoreGradient.swift' | cat
```
Expected: 至少 1 行在 `BookCover.swift`——这是 B7a「至少一处组件真实消费」的判据。（`CoreGradient+Preview.swift` 若存在也会命中，那不算生产消费点，看清楚文件名。）

```bash
swift build --build-tests > /tmp/t97b.log 2>&1; echo "build EXIT=$?"
swift build --traits Blossom > /tmp/t97bb.log 2>&1; echo "blossom EXIT=$?"
```
Expected: 两条 EXIT=0。

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "refactor: CoreGradient 移入 Tokens/、改 static let，并在 BookCover 建立首个消费点（B7a-c）"
```

---

### Task 3: 小改动批次（B9c、D8、B9d、B9f、D10）

这五项互不相干且都是几行的删除/替换，合并为一个 Task 以减少验证轮次。**每项改完各自 grep 确认，最后统一编译。**

**Files:** `Modifier/BorderModifier.swift`、`Components/SegmentedControl/SegmentedControl.swift`、`Components/CheckBox/CheckBox.swift`、`Tokens/CoreRadius.swift` + 4 个引用该 token 的 doc 注释

- [ ] **Step 1: B9c + D8 —— `BorderModifier`**

删除 `:31` 的 `bordered(color:)` 死重载（`Color` 已 conform `ShapeStyle`，与 `:27` 的 `bordered(style:)` 构成歧义——两者全默认参数，裸写 `.bordered()` 无法消歧）。

D8：`:20-21` 从 `RoundedRectangle(cornerRadius: CoreRadius.none).stroke(...)` 改为 `strokeBorder` 并支持任意 shape。改法：给 modifier 加 `shape: some InsettableShape` 参数（默认 `RoundedRectangle(cornerRadius: CoreRadius.none)`），`.stroke` → `.strokeBorder`。

> `stroke` 与 `strokeBorder` **不是等价替换**：前者以路径为中心向两侧各画半个线宽（越界 `width/2`），后者向内画。改后边框会向内收 `width/2`。`CoreBorderWidth.thin` 若是 1pt，差异是 0.5pt——**须在视觉冒烟里看 `.bordered()` 的消费点**。先 grep 消费点：
> ```bash
> grep -rn '\.bordered(' Sources App --include='*.swift' | cat
> ```

- [ ] **Step 2: B9d —— 删两处恒真 `@available`**

`SegmentedControl.swift:205` 与 `:301` 的 `@available(iOS 26.0, *)`（部署目标已 iOS 26+，恒真）。

> **`:222` 的 `@available(*, unavailable)` 不能删**——那是有意的不可用标记，与恒真的可用性声明是两回事。删前逐行 Read 确认。

- [ ] **Step 3: B9f —— 删 `CheckBox.swift:32` 的 `@MainActor @preconcurrency`**

`ToggleStyle.makeBody` 的协议声明已携带隔离，这两个属性冗余。

- [ ] **Step 4: D10 —— 删 `CoreRadius.full`**

删 `Tokens/CoreRadius.swift:61` 的 `public static let full: CGFloat = 9999`。**同步 5 处 doc 注释**（实测：`CoreRadius.swift:18`、`Avatar.swift:38`、`Badge.swift:43,58`、`Tag.swift:47`）——它们提到该 token 作为「pill 意图」的说明，删 token 后这些描述会指向不存在的符号。改写为指向 `Capsule()`（所有 pill 场景的实际做法）。

- [ ] **Step 5: 统一验证**

```bash
grep -rn 'CoreRadius\.full' Sources App docs 2>/dev/null; echo "rc=$?"
grep -n 'func bordered' Sources/CoreDesign/Modifier/BorderModifier.swift
grep -c '@available(iOS 26.0, \*)' Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift
grep -c '@MainActor @preconcurrency' Sources/CoreDesign/Components/CheckBox/CheckBox.swift
```
Expected: `rc=1`（无残留）；`bordered` 恰好 1 个重载；`@available(iOS 26.0, *)` 计数 **0**；`@MainActor @preconcurrency` 计数 **0**。

```bash
swift build --build-tests > /tmp/t97c.log 2>&1; echo "build EXIT=$?"
swift test > /tmp/t97ct.log 2>&1; echo "test EXIT=$?"
```

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "refactor: 清理死重载/恒真 available/冗余隔离属性/死 token（B9c、D8、B9d、B9f、D10）"
```

---

### Task 4: 组件现代化（B8c、B9a、B9b）

**Files:** `Components/CommentCard/CommentCard.swift`、`Components/BookCover/BookCover.swift`、`Components/TimelineItem/TimelineItem.swift`、`Tests/CoreDesignTests/TimelineItemTests.swift`

- [ ] **Step 1: B8c —— `CommentCard` 三件套改 `.surface(.card)`**

删除 `:94-101` 的 `.background(RoundedRectangle(.medium).fill(.surfaceCard))` + `.overlay(RoundedRectangle(.medium).strokeBorder(.borderMuted, .thin))`，改为 `.surface(.card)`。

> 按《判断 2》：`.surface(.card)` 会**额外引入 `clipShape`**，子视图会被裁到圆角内。这是行为变化，**必须在 Preview 里实看**。若内容被裁掉，改回手写并在 checklist 注明。

- [ ] **Step 2: B9a —— `BookCover` 的图片解码移出 body**

`:74` 在 body 里调 `Self.image(from: data)`，列表滚动时每帧重解码。改法：把解码结果缓存进 `@State`，在 `.task(id: data)` 或 `.onChange(of: data)` 里做一次。

> **不要**改成 `init` 里解码——`BookCover` 是 View，init 可能被频繁调用。用 `@State` + `.task(id:)` 是 SwiftUI 的惯用法。

- [ ] **Step 3: B9b —— `TimelineItem` 的旧式 `EnvironmentKey` 改 `@Entry`**

`:8-19` 的 `TimelineDepthKey` + `EnvironmentValues` 扩展（10 行）改为 `@Entry var timelineDepth: Int = 0`（3 行），与 `Toast.swift` / `Banner.swift` 的既有写法一致。

**同步改 `Tests/CoreDesignTests/TimelineItemTests.swift:32`**（实测行号，97.md 写的 `:30` 早两行）——它直接引用 `TimelineDepthKey.defaultValue`，删除该类型后会编译失败。改为断言 `EnvironmentValues().timelineDepth == 0`。

- [ ] **Step 4: 验证**

```bash
grep -rn 'TimelineDepthKey' Sources Tests 2>/dev/null; echo "rc=$?"
swift build --build-tests > /tmp/t97d.log 2>&1; echo "build EXIT=$?"
swift test > /tmp/t97dt.log 2>&1; echo "test EXIT=$?"
```
Expected: `rc=1`；两条 EXIT=0。

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "refactor: CommentCard 收敛 surface、BookCover 解码移出 body、TimelineItem 改 @Entry（B8c、B9a、B9b）"
```

---

### Task 5: `BottomInputBar` body 拆分（B8h）

**Files:** `Components/BottomInputBar/BottomInputBar.swift`

这是本任务最大的单项。`BottomInputBarModifier` 声明在 `:313`，其 `body` 是全库唯一超 50 行的 body。

- [ ] **Step 1: 先量真实边界**

```bash
python3 - <<'EOF'
import re
src=open('Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift').read().split('\n')
st=next(i for i,l in enumerate(src) if 'struct BottomInputBarModifier' in l)
bs=next(i for i in range(st,len(src)) if re.search(r'func body\(content', src[i]))
d=0
for i in range(bs,len(src)):
    d+=src[i].count('{')-src[i].count('}')
    if d==0 and i>bs: be=i; break
print(f'body: {bs+1}-{be+1}  共 {be-bs+1} 行')
EOF
```
**记下实测行数**（97.md 说 78 行、`:361-438`，但 Task 1 删了 `textFieldSize` 两行，坐标已漂移）。

- [ ] **Step 2: 合并两个同构 `onChange`**

实测在 `:416` 与 `:427`（Task 1 后会漂移，按 grep 定位）。两者都是「根据某个条件决定是否显示 suggestions」，合并为单一 `syncSuggestionsVisibility(shouldShow:)` 私有方法，两个 `onChange` 都调它。

- [ ] **Step 3: 拆子视图 + 收敛重复的 chip 样式**

把 body 拆成若干 `private var` 计算属性（如 `inputRow` / `suggestionsRow`）。`:297-308` 与 `:374-381` 的重复 chip 样式收敛为一个私有 modifier 或计算属性。

> **保留长注释**：`autoFocus` 那段解释了为何必须在 bar 自身 `onAppear` 中执行，拆分时别丢。

- [ ] **Step 4: 验证 body 已降到 50 行以下**

重跑 Step 1 的脚本。Expected: ≤50 行。

```bash
swift build --build-tests > /tmp/t97e.log 2>&1; echo "build EXIT=$?"
swift test > /tmp/t97et.log 2>&1; echo "test EXIT=$?"
```

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "refactor: 拆分 BottomInputBarModifier.body 并合并同构 onChange（B8h）"
```

---

### Task 6: 全量验证 + 审计清单 + 交接记录

- [ ] **Step 1: 并行硬约束自查（basename 精确匹配）**

```bash
git diff --name-only epic/coredesign-audit-remediation..HEAD \
  | xargs -n1 basename \
  | grep -Fx -f <(printf '%s\n' \
      SolidButtonStyle.swift LightButtonStyle.swift CoreBorderlessButtonStyle.swift \
      CircularGlassButtonStyle.swift ButtonRoleStyleRole.swift Sidebar.swift \
      CoreMenuButton.swift TelegramGlassButtonModifier.swift)
echo "rc=$?  (预期 1)"
```
**必须 basename 精确匹配**——`CommentCard`/`RefPill`/`BookCover` 等同时是目录名，子串 grep 会误判（#96 踩过）。

- [ ] **Step 2: 四条 SwiftPM 命令（clean 后冷跑）**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-97"; mkdir -p "$LOGDIR"
swift package clean
swift build                  > "$LOGDIR/b.log"  2>&1; echo "build          EXIT=$?"
swift test                   > "$LOGDIR/t.log"  2>&1; echo "test           EXIT=$?"
swift build --traits Blossom > "$LOGDIR/bb.log" 2>&1; echo "build-blossom  EXIT=$?"
swift test  --traits Blossom > "$LOGDIR/tb.log" 2>&1; echo "test-blossom   EXIT=$?"
(cd scripts/downstream-probe && swift package clean >/dev/null 2>&1 && swift build > "$LOGDIR/p.log" 2>&1); echo "probe(clean)   EXIT=$?"
```

**warning 判据本任务是绝对零，不是「不新增」**：

```bash
python3 - <<EOF
import os
for f in ['b','t','bb','tb']:
    d=open(os.path.join("$LOGDIR",f+'.log')).read()
    assert d, f+'.log 为空'
    w=[l for l in d.split('\n') if 'warning:' in l]
    r=[l.strip()[:50] for l in d.split('\n') if 'Test run with' in l]
    print(f"{f}: warning={len(w)} (预期 0) {r[-1] if r else ''}")
    for l in w[:5]: print('   !!', l.strip()[:150])
EOF
```
Expected: 四份**全部 `warning=0`**。基线的 12 条随 `EmptyState.swift` 消失。

> probe 必须 clean 后构建——本任务删了公开符号，probe 的增量构建可能不拾取（#96 实测过同类假信号）。

- [ ] **Step 3: 视觉冒烟（AC 明列，本任务尤其不可省）**

本任务有**三处受控变化**需实看：

| 组件 | 看什么 |
|---|---|
| `CommentCard` | `.surface(.card)` 引入的 `clipShape` 是否裁掉了内容（判断 2） |
| `BookCover` | B7a 的渐变消费点，**默认与 Blossom 两种 trait 都要看**——默认应退化为纯色、Blossom 应显示真实渐变 |
| `.bordered()` 的消费点 | `stroke` → `strokeBorder` 后边框向内收 `width/2`（D8） |

另需常规冒烟：`RefPill`（未改，作对照）、`BottomInputBar`（body 拆分后）、`SegmentedControl`、`TimelineItem`。

**跑法**（不要用 `scripts/run-snapshots.sh`——它 `rm -rf docs/snapshots` 会删掉已提交的文档图，且删掉 `CoreDesign_*` 即库内 Preview 产物）：

```bash
SNAP="${TMPDIR:-/tmp}/snap97"; rm -rf "$SNAP"; mkdir -p "$SNAP"
xcodegen generate --spec App/project.yml > /dev/null 2>&1
git checkout -- App/CoreDesignPreview.xcodeproj/xcshareddata/ 2>/dev/null || true
TEST_RUNNER_SNAPSHOTS_EXPORT_DIR="$SNAP" \
xcodebuild test -project App/CoreDesignPreview.xcodeproj -scheme CoreDesignPreview \
  -only-testing:SnapshotTests -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -quiet > /tmp/snap97.log 2>&1
echo "snapshot EXIT=$?"; ls "$SNAP" | wc -l
```

**跑完 `git checkout -- App/CoreDesignPreview.xcodeproj/project.pbxproj`** 回退 xcodegen 的重新生成噪音（#96 踩过）。

- [ ] **Step 4: 更新审计清单**

18 项标 `✅ **已修复**（GitHub #97）——<做法>。原缺陷：<原文保留>`，沿用 #93/#94/#96 的写法。**B8d 标为「不做」并写明理由**（判断 1）。B8c 注明 `clipShape` 那处受控变化。

计数校验：
```bash
echo $(( $(grep -c '^| [A-D][0-9]' .claude/epics/coredesign-audit-remediation/audit-checklist.md) - 4 ))
```
Expected: `83`

**坐标清扫**（#94/#96 的教训，两维都要）：本任务删了三个文件、改了 `BottomInputBar` / `CommentCard` / `BookCover` / `TimelineItem` / `SegmentedControl` / `CoreRadius` 的行号。逐条 Read 确认，**不要凭推理**：

```bash
grep -rn 'BottomInputBar\.swift:\|CommentCard\.swift:\|BookCover\.swift:\|TimelineItem\.swift:\|SegmentedControl\.swift:\|CoreRadius\.swift:\|RefPill\.swift:\|CoreGradient\.swift:\|EmptyState\|View+SizeReader\|KeyboardHandling' \
  .claude/epics/coredesign-audit-remediation/*.md
```

- [ ] **Step 5: 写 `updates/97/progress.md`**

必须落进去的：18 项各自做法、**B8d 不做的理由**、三处受控变化及冒烟结论、删除后的测试数与 warning 归零、给 #95/#99/#100/#101/#102 的交接（尤其：`KeyboardHandlingTests.swift` 已删，#98 的保留名单须以此为前提）。

- [ ] **Step 6: 提交**

```bash
git status --porcelain
git add .claude/epics/coredesign-audit-remediation/
git commit -m "docs(ccpm): 更新 #97 审计清单状态、坐标清扫与完成记录"
```

---

## 收尾

`verification-before-completion` → `finishing-a-development-branch` Option 2 开 PR（**base = `epic/coredesign-audit-remediation`**）→ Copilot 不可用，按 §3.6 降级为 `superpowers-reviewer` 并在 PR 留顶层评论。

PR 描述必须包含：warning 12 → 0、测试数变化、B8d 不做的理由、三处受控变化的冒烟结论。
