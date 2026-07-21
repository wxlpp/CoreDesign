# Issue #102「机械清理」实现计划 / Mechanical Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: 用 `oh-my-superpowers:subagent-driven-development`（推荐）或 `oh-my-superpowers:executing-plans` 逐 task 执行本计划。步骤用 checkbox（`- [ ]`）跟踪。

**Goal:** 收尾 epic `coredesign-audit-remediation` 的最后一个 Issue——把 10 个纯机械/文本审计项（C6b、C10a、C10c、C10d、D9、D12、D15、D16a、D16b、D18）落地：目录归位、仓库卫生、文档修正、硬编码数值提 token / 命名常量、平台分支补 `#else`、补全三处 `#Preview`。

**Architecture:** 全部是「在 #92–#101 改完之后收尾」的动作，**无新增行为、无设计决策**（除 4 处需判断的裸值，详见 Task 3）。分七个 task，每个以一个独立可复核的交付物结束；最后一个 task 做四命令 clean 冷跑 + 第 5 条 iOS Simulator 命令 + audit-checklist 收口。

**Tech Stack:** SwiftUI（iOS 26+ / macOS 26+）、Swift 6 语言模式（`swiftLanguageModes: [.v6]`，完整严格并发）、SwiftPM Package Trait（`Blossom`）、Swift Testing、`xcodebuild`（iOS Simulator 布局断言层）。

## Global Constraints

以下为项目级约束，**每个 task 隐含适用**，值逐字取自仓库 memory / CLAUDE.md：

- **四命令都要绿、零 warning**：`swift build` / `swift test` / `swift build --traits Blossom` / `swift test --traits Blossom`。
- **第 5 条命令**（本任务因 D18 触及 `Sidebar` 的 `#if os(iOS)` 布局断言而强制）：
  ```bash
  xcodebuild test \
    -scheme CoreDesign \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -skip-testing:CoreDesignTests/BlossomAssetTests \
    -skip-testing:CoreDesignTests/ToastHostTests \
    CODE_SIGNING_ALLOWED=NO
  ```
  **切勿**把 `DynamicTypeLayoutTests` 加进 `-skip-testing`——那正是本任务要守护的 `Sidebar` iOS 布局断言层（CI 注释 `.github/workflows/ci.yml:108-110` 明确点名）。
- 代码风格：即使同类型内访问成员也显式 `self.`；注释中英双语混用（有意为之）；公开 API 显式 `public`；资源查找传 `bundle: .module`；`#Preview` 与组件同文件。
- **不硬编码底层原子色 / 不绕过 token 层**：数值改动只允许「引用既有 token」或「提为命名常量（值零变化）」，**不得** snap 到语义不符的档位而改变布局。
- 本任务**预期不增删任何 colorset**，故不需要 `swift package clean`（若意外增删，再补跑）。
- **越界红线**：改动只允许落在 `Sources/`、`README.md`、`.gitignore`、`LICENSE`（新增）、`AGENTS.md`（新增）、`audit-checklist.md`。**不改** `CLAUDE.md`（核对后确认 002/006/D16b 已落地，见 Task 2）、**不改** `docs/`（Banner 旧路径引用只存在于历史 plan 归档，不得回改）、**不改** `Package.swift`（SwiftPM 按目录自动包含 `.swift`）、**不改** `.claude/` 历史 artifact。

---

## Task 1: 仓库卫生（C10c `.gitignore` 去重 + C10a `LICENSE` + C10d 悬空状态收口）

**Files:**
- Modify: `.gitignore`（当前 `.superpowers/` 重复出现于 line 68 与 line 74；`.agents/` 缺失）
- Create: `LICENSE`
- Create: `AGENTS.md`（从父 checkout 拷入——见步骤说明）

**Interfaces:**
- Produces: 一份去重后的 `.gitignore`、一个根目录 `LICENSE`、一个纳入版本控制的 `AGENTS.md`。后续 task 不依赖本 task 的产物。

**背景核实（已侦察，实现者可复核）:**
- `.claude/prds/` 与 `.claude/epics/`（含本 epic 全部 artifact）**已 tracked**（`git ls-files .claude/prds | head` 有输出；epic 目录 35 个文件已纳入）——C10d 的「纳入版本控制」这半项**已落地**，本 task 只记录「已核对，无遗漏」，不做操作。
- `.claude/omsp/` 已在 `.gitignore` line 77。
- `AGENTS.md` 与 `.agents/` 在**本 worktree 不存在**（`ls AGENTS.md` / `ls .agents` 均 No such file）；它们是父 checkout（`feat/blossom-theme`，`/Users/evan/Repositories/work-spec/CoreDesign/`）里的 untracked 文件，worktree 之间不共享 untracked 文件。父 checkout 的 `AGENTS.md`（8.1K，Codex 版指引、镜像 CLAUDE.md）与 `.agents/skills/` 是真实存在的项目工具产物。

- [ ] **Step 1: 去重 `.gitignore` 的 `.superpowers/`（C10c）**

删除 line 73–74 这段重复块（保留 line 67–68 那条带原始注释的）。删除的两行：
```
# Superpowers brainstorming visual companion
.superpowers/
```
用 Edit 精确匹配删除（`old_string` 含前一行空行到 `.claude/omsp/` 注释之间的这段）。删完后 `.superpowers/` 在文件中只应出现一次（line 68）。

- [ ] **Step 2: 给 `.gitignore` 补 `.agents/`（C10d）**

在 `.claude/omsp/` 那条（line 76–77）之后、`# Downstream probe build artifacts` 之前，插入：
```
# Local agent tooling (per-checkout, not shared)
.agents/
```

- [ ] **Step 3: 验证 `.gitignore` 去重与新增**

Run:
```bash
grep -n '\.superpowers/' .gitignore; echo "---"; grep -n '\.agents/' .gitignore
```
Expected: `.superpowers/` 仅 1 处；`.agents/` 出现 1 处。

- [ ] **Step 4: 新增 `LICENSE`（C10a）**

仓库当前**无任何 license 声明**（`LICENSE` 不存在；`README.md` 无 license 段；`Package.swift` 无 license 字段）。采用标准 **MIT**（设计系统库最常见、最宽松），版权归属取源码文件头惯用署名 `Evan Wang`（= 仓库作者 wxlpp / 王晓龙）。写入 `LICENSE`：

```
MIT License

Copyright (c) 2026 Evan Wang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

> **判断点（记入任务记录）**：MIT + 「Evan Wang」为默认选择，因仓库无既有 license 依据。执行时若用户已表态偏好其他协议 / 署名，以用户为准。

- [ ] **Step 5: 纳入 `AGENTS.md`（C10d）**

从父 checkout 拷入 canonical `AGENTS.md`（它是 Codex 版仓库指引、与 `CLAUDE.md` 对应）：
```bash
cp /Users/evan/Repositories/work-spec/CoreDesign/AGENTS.md ./AGENTS.md
```
拷入后**必须 `Read ./AGENTS.md` 通读全文**（分发/提交前先看内容），确认它是当前项目指引、无过期或敏感内容。若父 checkout 已不含该文件或内容明显过期，停下向用户确认，不要凭空造。

- [ ] **Step 6: 暂存并核对 tracked 状态（C10d 收口）**

Run:
```bash
git add .gitignore LICENSE AGENTS.md
git status --short
git ls-files .claude/prds .claude/epics/coredesign-audit-remediation | head -3   # 复核：prds/epics 早已 tracked
```
Expected: `LICENSE`、`AGENTS.md` 显示为新增（`A`），`.gitignore` 为修改（`M`）；`.claude/prds`、epic 目录已有 tracked 输出（无需本 task 操作）。

- [ ] **Step 7: Commit**

```bash
git add .gitignore LICENSE AGENTS.md
git commit -m "chore(repo): dedupe .gitignore, add LICENSE + AGENTS.md, ignore .agents/ (#102 C10a/C10c/C10d)"
```

---

## Task 2: 文档一致性核对（C6b README 组件数 + CLAUDE.md 002/006 核对 + D16a StateLabel doc）

**Files:**
- Modify: `README.md:7`
- Verify-only（不改）: `CLAUDE.md`、`Sources/CoreDesign/Components/StateLabel/StateLabel.swift`

**Interfaces:**
- Produces: README 组件数与 `docs/README.md` 的 Component Index 对齐；CLAUDE.md / StateLabel 的三方文档义务经核对确认已落地。

**背景核实:**
- `docs/README.md` 的 Component Index 表当前有 **24** 行组件条目（`grep -cE '^\| [A-Z]' docs/README.md` = 24），其前言亦称「含 24 个 Primer 对齐组件」。`README.md:7` 仍称「all **15** documented components」——这是唯一漂移点。
- `CLAUDE.md` 的《分层色彩系统》已含 002/#93 的改动（line 32 明写「已于 Issue #93 移除」`Color.primary/secondary/tertiary`）；《Modifier 约定》（line 68）已含 006/#97 的改动（`.getSize` 在全仓 grep = 0；且已准确写明 `.focusedExternally` 是 `BottomInputBar.swift` 的 private extension——即 **D16b 已由 #97 落地**，audit-checklist 行 120 已标 ✅）。
- `StateLabel.swift` 经 #101 泛型化重写后，`StateLabelStyle` 枚举（`:14-21`）的 6 个 case（`active`/`draft`/`completed`/`cancelled`/`inProgress`/`error`）**均带 inline 语义注释**；旧的「只列 4 style」汇总文档已被 #101 一并移除，`:28` 现在是 `struct Spec {`。**D16a 的漂移目标已不存在。**

- [ ] **Step 1: 核对 README 实际组件数（防执行时再漂移）**

Run:
```bash
grep -cE '^\| [A-Z]' docs/README.md            # docs Component Index 行数（当前 24）
ls -d Sources/CoreDesign/Components/*/ | wc -l  # 组件目录数（当前 23，D9 移动后 24）
grep -n 'documented components' README.md       # 当前 "15"
```
Expected: docs index = 24；README = 15。以 `docs/README.md` 的 Index 计数（README 第 7 行正是链向它）为准 = **24**。若执行时 docs index 计数已变，用当时的实际值。

- [ ] **Step 2: 改 `README.md:7` 的组件数（C6b）**

Before:
```
See the [Component Index](docs/README.md) for a reference of all 15 documented components organized by category.
```
After:
```
See the [Component Index](docs/README.md) for a reference of all 24 documented components organized by category.
```
> **范围提醒**：只改「15→24」。**不动**同文件 line 14 的 `branch: "main"`——那是 **C6a**（README 改 pin tag `v0.1.0`），C6a **不在本 Issue 的 10 项范围内**，留给后续处理。

- [ ] **Step 3: 核对 CLAUDE.md 三方触碰（002 / 006 / D16b），确认无遗漏**

Run:
```bash
grep -n 'Issue #93\|getSize\|focusedExternally' CLAUDE.md
grep -rn 'getSize' Sources/                       # 期望 0 命中
```
Expected: CLAUDE.md 含「已于 Issue #93 移除」（002 已落地）、含「`.focusedExternally` 在 `BottomInputBar.swift`」（D16b 已落地）；`getSize` 在 CLAUDE.md 与 Sources 均 0 命中（006 已落地）。**结论记入任务记录**：002 / 006 / D16b 的 CLAUDE.md 义务均已由 #93 / #97 落地，本 task **不改 CLAUDE.md**（若上面任一核对不成立，才在此补改并记「代 00x 改了什么」）。

- [ ] **Step 4: 核对 StateLabel 文档（D16a），确认无遗漏**

`Read Sources/CoreDesign/Components/StateLabel/StateLabel.swift`，确认：(a) `StateLabelStyle` 枚举 6 个 case 各有 inline 注释；(b) 全文无「只列 4 个 style」的过期汇总文档。Run 辅助核对：
```bash
grep -nE 'case (active|draft|completed|cancelled|inProgress|error)' Sources/CoreDesign/Components/StateLabel/StateLabel.swift
```
Expected: 6 个 case 全部命中且各带注释。**结论记入任务记录**：D16a 的过期文档已由 #101 泛型化重写移除，6 case 均有 inline 文档，无遗漏 → 本 task 不改 StateLabel。若发现残留的 4-style 汇总文档（本侦察未发现），则在该文档处补上缺失的 `inProgress` / `error` 两条并纳入本 commit。

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(readme): correct component count 15 -> 24 to match Component Index (#102 C6b); verify CLAUDE.md/StateLabel doc drift already resolved (D16a/D16b)"
```

---

## Task 3: 硬编码数值改引用 token / 提命名常量（D12）

**Files:**
- Modify: `Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift:128,138`
- Modify: `Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift:68,93-98`
- Modify: `Sources/CoreDesign/Components/CommentCard/CommentCard.swift:59`
- Modify: `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift`（`BottomInputBarGlassEffectShape`，当前 line 220-227）
- Modify: `Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift:33-40,76-85`

**Interfaces:**
- Consumes（既有 token，值已核对）：`CoreSpacing.none`(=0) / `CoreSpacing.sm`(=8)；`CoreButtonMetrics.pressedScale`(=0.94, `Double`)。
- Produces: 无对外符号；所有改动值零变化。

**分类（关键——本 task 混了「纯机械」与「需判断」两类）:**
- **纯机械（值恰好命中既有 token，语义相符）**：CoreMenuButton 的 2 处、TimelineItem 的 `VStack(spacing:)`。
- **需判断（无语义相符 token，提命名常量 / 保留裸值 + 注释，理由记入记录）**：CommentCard 的 `1`、BottomInputBar 的 `44`、TimelineItem 的 `dotSize` 32/20、AvatarGroup 的 `overlapOffset` / `avatarSize` 档位。

### 3A · 纯机械替换

- [ ] **Step 1: CoreMenuButton HStack spacing → `CoreSpacing.sm`**

`CoreMenuButton.swift:128`
Before: `        let inner = HStack(spacing: 8) {`
After: `        let inner = HStack(spacing: CoreSpacing.sm) {`

- [ ] **Step 2: CoreMenuButton pressed scale → `CoreButtonMetrics.pressedScale`**

`CoreMenuButton.swift:138`（数值恰好相同，且与 `ButtonBackgroundModifier.swift:36`、`TelegramGlassButtonModifier.swift:92` 的既有用法同形，`Double` 传入 `scaleEffect` 已被现网绿构建证明可编译）
Before: `            .scaleEffect(self.isLongPressing ? 0.94 : 1.0)`
After: `            .scaleEffect(self.isLongPressing ? CoreButtonMetrics.pressedScale : 1.0)`

- [ ] **Step 3: TimelineItem spine VStack spacing → `CoreSpacing.none`**

`TimelineItem.swift:68`
Before: `        VStack(spacing: 0) {`
After: `        VStack(spacing: CoreSpacing.none) {`

### 3B · 需判断项（提命名常量 / 保留裸值，附理由注释）

- [ ] **Step 4: TimelineItem `dotSize` 32/20 提为命名常量**

**理由（记入记录）**：32 / 20 是脊柱图标圆点的**元素直径**，非间距。`CoreSpacing` 是间距刻度（`none=0…huge=64`），把直径塞进 spacing token 属语义误用；且 20pt 不在 `CoreSpacing` 任一档位内。故提为本组件 file-private 命名常量，值零变化。

`TimelineItem.swift:93-98`
Before:
```swift
    private var dotSize: CGFloat {
        switch self.depth {
        case 0: return 32
        default: return 20
        }
    }
```
After:
```swift
    /// 脊柱图标圆点直径 / Icon-dot diameters（元素尺寸，非 spacing 档位）。
    /// 根节点 32pt、嵌套子节点 20pt——`CoreSpacing` 是间距刻度且不含 20pt，
    /// 故提为命名常量而非硬套 token，保持数值零变化。
    private static let rootDotDiameter: CGFloat = 32
    private static let nestedDotDiameter: CGFloat = 20

    private var dotSize: CGFloat {
        switch self.depth {
        case 0: return Self.rootDotDiameter
        default: return Self.nestedDotDiameter
        }
    }
```
> `#Preview` 内 demo 用的 `32` / `20`（当前 line 104/110/117）是预览脚手架，**保留不动**。

- [ ] **Step 5: CommentCard 的 `1` 保留裸值 + 注释**

**理由（记入记录）**：`1` 是 role badge 胶囊的 1pt hairline 纵向内衬，低于最小 spacing 档位（`xxs=2`）。无对应 token；snap 到 `xxs` 会让徽标可见变高（改布局，违反零变化）；单点使用，提一次性命名常量属过度抽象（YAGNI）。故保留裸值并加注释说明它是刻意的 sub-token hairline。

`CommentCard.swift:59`
Before:
```swift
                        .padding(.vertical, 1)
```
After:
```swift
                        // 1pt hairline 纵向内衬：刻意低于最小 spacing 档位（xxs=2pt），
                        // 让 role badge 胶囊维持紧凑高度。无对应 token；snap 到 xxs 会使
                        // 徽标可见变高，单点使用提常量属过度抽象 —— 保留裸值 + 本注释。
                        .padding(.vertical, 1)
```

- [ ] **Step 6: BottomInputBar 的 `44` 提为命名常量 `minimumHitTargetSide`**

> **⚠️ 判断点 / 与侦察note的冲突（务必先读）**：全 `Sources/` 树里 **`44` 只出现一处**——就是 `BottomInputBarGlassEffectShape.path(in:)` 里的 `insetRect.height <= 44`（当前 line 225）。侦察 note 曾假设「另有一处真正的 HIG 44、line 225 那处不是」，但**穷举 grep 证明并不存在第二处 44**：AC（`:219`）引用的 hit-target 44 与 line 225 是同一个数——它把 44pt（HIG 最小可点击/控件高度）当作「输入栏收缩到单行紧凑态」的阈值：`≤44` 则收成整胶囊（`height/2`），更高（多行）则用 `CoreRadius.large`。因此 line 225 的 `44` **就是** D12 的目标，提为命名常量满足 AC 且语义保真。执行前若 epic lead 确认另有他意（例如该 44 应被视作已随上游 PR 消失、本项直接判 resolved），先停下确认；否则按下面执行。

`BottomInputBar.swift`（`BottomInputBarGlassEffectShape`，当前 line 220-227）
Before:
```swift
struct BottomInputBarGlassEffectShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: self.insetAmount, dy: self.insetAmount)
        let cornerRadius: CGFloat = insetRect.height <= 44 ? insetRect.height / 2 : CoreRadius.large
        return Path(roundedRect: insetRect, cornerRadius: cornerRadius)
    }
```
After:
```swift
struct BottomInputBarGlassEffectShape: InsettableShape {
    var insetAmount: CGFloat = 0

    /// HIG 最小可点击区域边长（44pt）。输入栏收缩到 ≤ 44pt（单行紧凑态）时把形状
    /// 收成整胶囊（height/2），更高（多行）时用 `CoreRadius.large`。
    /// **不是** metrics 序列里的档位——`CoreControlMetrics.height(for: .extraLarge)`
    /// 是 48pt，替换会静默改变布局；此处刻意保留 HIG 的 44。
    private static let minimumHitTargetSide: CGFloat = 44

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: self.insetAmount, dy: self.insetAmount)
        let cornerRadius: CGFloat = insetRect.height <= Self.minimumHitTargetSide ? insetRect.height / 2 : CoreRadius.large
        return Path(roundedRect: insetRect, cornerRadius: cornerRadius)
    }
```

- [ ] **Step 7: AvatarGroup `overlapOffset` / `avatarSize` 加语义注释（值不变）**

**理由（记入记录）**：这两个已经是**命名 computed property**、以 `switch controlSize` 给出 size ramp——与 token 层 `CoreControlMetrics` 自身的写法（`case .extraLarge: return 48` 裸字面量）完全同构，「散落魔法数」的审计关切已被消解。且这些值**无语义相符 token**：`overlapOffset` 是负交叠量（无负 token）；`avatarSize` 的 20pt 不在任何刻度内，其余 24/32/40/48 虽等于 `CoreSpacing.xl/xxl/xxxl/xxxxl` 但那是**间距** token、当作元素直径用属误导。强行套 token 会降低与 `CoreControlMetrics` 的一致性。故只补澄清注释、值零变化。

`AvatarGroup.swift:33`（在 `overlapOffset` 上方）插入：
```swift
    /// 头像交叠量 / Avatar overlap offset（按 controlSize 递增负 offset）。
    /// 元素尺寸 ramp，刻意与 `CoreControlMetrics` 同构（裸字面量 switch），
    /// 不路由到 `CoreSpacing`——后者是间距刻度，且负值 / 20pt 无对应档位。
```
`AvatarGroup.swift:76`（在 `avatarSize` 上方）插入：
```swift
    /// 头像直径 / Avatar diameter（按 controlSize，20…48pt）。
    /// 同上：元素尺寸 ramp，与 `CoreControlMetrics` 同构，不套 spacing token。
```

- [ ] **Step 8: 构建验证（default）**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!`，零 warning。

- [ ] **Step 9: Commit**

```bash
git add Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift \
        Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift \
        Sources/CoreDesign/Components/CommentCard/CommentCard.swift \
        Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift \
        Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift
git commit -m "refactor(tokens): hoist hardcoded values to tokens/named constants (#102 D12)"
```

---

## Task 4: `FillColors` 平台分支补 `#else`（D15）

**Files:**
- Modify: `Sources/CoreDesign/Colors/FillColors.swift:16-23,30-37,44-51,58-65`（4 个属性）

**Interfaces:**
- Produces: 4 个 `Color` 静态属性，改用 `#if canImport(UIKit) / #else / #endif`，与 `SystemBackgroundColors.swift` / `SystemLabelColors.swift` 写法一致。

**背景**：当前 4 处各写两段独立 `#if canImport(UIKit)…#endif` + `#if canImport(AppKit)…#endif`——两条件皆不成立时**无 return**（编译隐患）。参照文件 `SystemBackgroundColors.swift` 用的是 `#if canImport(UIKit) / #else / #endif`（AppKit 落在 `#else`）。

- [ ] **Step 1: 四处改为 `#if / #else / #endif`**

对 `fill` / `secondaryFill` / `tertiaryFill` / `quaternaryFill` 各做一次同型替换。以 `fill`（line 17-23）为例：
Before:
```swift
        #if canImport(UIKit)
            return Color(uiColor: .systemFill)
        #endif
        #if canImport(AppKit)
            return Color(nsColor: .systemFill)
        #endif
```
After:
```swift
        #if canImport(UIKit)
            return Color(uiColor: .systemFill)
        #else
            return Color(nsColor: .systemFill)
        #endif
```
其余三处照做，只是填充色名不同：`secondaryFill` → `.secondarySystemFill`；`tertiaryFill` → `.tertiarySystemFill`；`quaternaryFill` → `.quaternarySystemFill`。（`Edit` 四次，`old_string` 各含对应色名以保唯一。）

- [ ] **Step 2: 核对无残留 `#if canImport(AppKit)`**

Run: `grep -n 'canImport(AppKit)\|#else' Sources/CoreDesign/Colors/FillColors.swift`
Expected: 4 个 `#else`，0 个 `#if canImport(AppKit)`。

- [ ] **Step 3: 构建验证**

Run: `swift build 2>&1 | tail -3`
Expected: `Build complete!`，零 warning。

- [ ] **Step 4: Commit**

```bash
git add Sources/CoreDesign/Colors/FillColors.swift
git commit -m "style(colors): FillColors platform branches use #if/#else to match sibling bridges (#102 D15)"
```

---

## Task 5: `Banner.swift` `git mv` 归位（D9）

**Files:**
- Move: `Sources/CoreDesign/Components/Banner.swift` → `Sources/CoreDesign/Components/Banner/Banner.swift`

**Interfaces:**
- Produces: `Banner.swift` 落到 `Components/Banner/Banner.swift`，与其余组件 `Components/<Name>/<Name>.swift` 布局一致。历史保留。

**关键陷阱**：移动 vs 编辑是所有冲突里最烈的一种（git 呈现为「删除 + 新增」）。**必须用 `git mv`**（保历史），且必须在其它任务改完 `Banner.swift` 之后执行——本 Issue 排在 epic 最后正为此。`StatusLevel.swift`（Banner 与 Toast 共用）**留在** `Components/` 根，不随 Banner 移动。

- [ ] **Step 1: 确认目标目录不存在冲突文件**

Run: `ls Sources/CoreDesign/Components/Banner/ 2>&1; ls Sources/CoreDesign/Components/Banner.swift`
Expected: `Banner/` 目录尚不存在；`Banner.swift` 在根目录存在。

- [ ] **Step 2: `git mv` 移动（建目录 + 移动一步到位）**

```bash
mkdir -p Sources/CoreDesign/Components/Banner
git mv Sources/CoreDesign/Components/Banner.swift Sources/CoreDesign/Components/Banner/Banner.swift
```

- [ ] **Step 3: 全仓 grep 旧路径引用，确认无需回改**

Run:
```bash
grep -rn 'Components/Banner\.swift' --include='*.swift' --include='*.md' \
  Sources/ Package.swift README.md docs/components/ docs/README.md 2>/dev/null
```
Expected: **0 命中**。（已侦察：源码 / `Package.swift` / `README.md` / `docs/components/` / `docs/README.md` 均无 `Banner.swift` 路径引用；SwiftPM 按目录自动包含 `.swift`。旧路径引用只出现在 `docs/superpowers/plans/*.md` 与 `.claude/epics/*/*-plan.md`、`.claude/prds/*` 等**历史 artifact**——它们记录的是当时的事实，**不得回改**。若上面 grep 意外命中活文档 / 源码，才在此一并修正。）

- [ ] **Step 4: 构建 + 测试验证（确认目录移动被 SPM 正确识别）**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -5`
Expected: `Build complete!`；测试全绿、零 warning。

- [ ] **Step 5: Commit**

```bash
git add -A Sources/CoreDesign/Components/
git commit -m "refactor(structure): git mv Banner.swift into Components/Banner/ (#102 D9)"
```

---

## Task 6: 补全三处 `#Preview`（D18）

**Files:**
- Modify: `Sources/CoreDesign/Components/Sidebar/Sidebar.swift`（文件末尾追加 `#Preview`）
- Modify: `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`（追加 `#Preview`）
- Modify: `Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift`（追加 `#Preview`）

**Interfaces:**
- Consumes（已核对签名）：
  - `SidebarSection(title:showsChevron:content:)`、`SidebarNavigationRow(systemImage:title:isSelected:action:)`（便利 init）、`SidebarUtilityRow(systemImage:title:trailingSystemImage:action:)`、`SidebarDocumentRow(systemImage:title:detail:action:)`、`SidebarTagRow(title:action:)`、`SidebarStatusFooter(title:detail:statusColor:)`。
  - `View.floatingGlass(in:isInteractive:)`；`TelegramGlassButtonModifier(shape:isPressed:border:pressFeedback:)`。
- Produces: 三份视觉冒烟预览。**编译过 ≠ 渲染正常**——见收尾段的「Xcode 渲染确认」项。

**要求**：`Sidebar` 的 **6 个 public 组件各有可辨识场景**（非单一堆叠）。玻璃类预览须置于**有色背板**上（`Color.surfaceCanvas`）否则材质不可见。

- [ ] **Step 1: Sidebar 追加 `#Preview`（覆盖 6 个 public 组件）**

在 `Sidebar.swift` 末尾（`sidebarSelectedBackground` 扩展之后）追加：
```swift
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            // 1) SidebarSection 容器 + 2) SidebarNavigationRow（选中 / 未选中两态）
            SidebarSection(title: "Workspace") {
                SidebarNavigationRow(systemImage: "house", title: "Home", isSelected: true) {}
                SidebarNavigationRow(systemImage: "bell", title: "Notifications", isSelected: false) {}
            }

            // 3) SidebarUtilityRow（带装饰性 trailing 图标）
            SidebarSection(title: "Tools", showsChevron: false) {
                SidebarUtilityRow(systemImage: "gearshape", title: "Settings", trailingSystemImage: "chevron.right") {}
                SidebarUtilityRow(systemImage: "trash", title: "Trash") {}
            }

            // 4) SidebarDocumentRow（尾部 detail 可读）
            SidebarSection(title: "Documents") {
                SidebarDocumentRow(systemImage: "doc.text", title: "Design Spec", detail: "3d") {}
                SidebarDocumentRow(systemImage: "doc.richtext", title: "A very long document title that wraps", detail: "12") {}
            }

            // 5) SidebarTagRow（# 前缀）
            SidebarSection(title: "Tags") {
                SidebarTagRow(title: "swiftui") {}
                SidebarTagRow(title: "design-system") {}
            }

            // 6) SidebarStatusFooter（默认成功语义色）
            SidebarStatusFooter(title: "All systems operational", detail: "Updated just now")
        }
        .padding(CoreSpacing.md)
    }
    .background(Color.surfaceCanvas)
}
```

- [ ] **Step 2: FloatingGlassModifier 追加 `#Preview`**

在 `FloatingGlassModifier.swift` 末尾追加：
```swift
#Preview {
    VStack(spacing: CoreSpacing.xl) {
        Text("floatingGlass · Capsule (default)")
            .padding()
            .floatingGlass()

        Text("floatingGlass · RoundedRect (interactive)")
            .padding()
            .floatingGlass(in: RoundedRectangle(cornerRadius: CoreRadius.large), isInteractive: true)
    }
    .padding(CoreSpacing.xxxl)
    .background(Color.surfaceCanvas)
}
```

- [ ] **Step 3: TelegramGlassButtonModifier 追加 `#Preview`**

在 `TelegramGlassButtonModifier.swift` 末尾追加：
```swift
#Preview {
    VStack(spacing: CoreSpacing.xl) {
        Text("Capsule · default border")
            .padding(.horizontal, CoreSpacing.md)
            .padding(.vertical, CoreSpacing.sm)
            .modifier(TelegramGlassButtonModifier(shape: Capsule(), isPressed: false))

        Image(systemName: "plus")
            .padding(CoreSpacing.md)
            .modifier(TelegramGlassButtonModifier(
                shape: Circle(),
                isPressed: true,
                border: .borderSubtle,
                pressFeedback: true
            ))
    }
    .foregroundStyle(.white)
    .padding(CoreSpacing.xxxl)
    .background(Color.surfaceCanvas)
}
```

- [ ] **Step 4: 构建验证（含 Blossom，确保 Preview 在两主题都编译）**

Run:
```bash
swift build 2>&1 | tail -3
swift build --traits Blossom 2>&1 | tail -3
```
Expected: 两次都 `Build complete!`，零 warning。

- [ ] **Step 5: Commit**

```bash
git add Sources/CoreDesign/Components/Sidebar/Sidebar.swift \
        Sources/CoreDesign/Modifier/FloatingGlassModifier.swift \
        Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift
git commit -m "test(preview): add #Preview for Sidebar + Floating/Telegram glass modifiers (#102 D18)"
```

---

## Task 7: 全量验证 + audit-checklist 收口

**Files:**
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`（10 行状态描述）

**Interfaces:**
- Consumes: 前 6 个 task 的全部产物。
- Produces: 四命令 + 第 5 条命令的绿证；audit-checklist 10 项标 ✅（计数不变）。

- [ ] **Step 1: 四命令 clean 冷跑（零 warning）**

Run:
```bash
swift package clean
swift build 2>&1 | tee /tmp/b1.log | tail -3
swift test 2>&1 | tee /tmp/t1.log | tail -6
swift build --traits Blossom 2>&1 | tee /tmp/b2.log | tail -3
swift test --traits Blossom 2>&1 | tee /tmp/t2.log | tail -6
grep -ic warning /tmp/b1.log /tmp/b2.log /tmp/t1.log /tmp/t2.log
```
Expected: 两次 build `Build complete!`；两次 test 全绿；warning 计数全 0。

- [ ] **Step 2: 第 5 条命令——iOS Simulator（守护 Sidebar 的 `#if os(iOS)` 布局断言）**

Run:
```bash
xcodebuild test \
  -scheme CoreDesign \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skip-testing:CoreDesignTests/BlossomAssetTests \
  -skip-testing:CoreDesignTests/ToastHostTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/ios.log | tail -15
```
Expected: `** TEST SUCCEEDED **`。（`DynamicTypeLayoutTests` **必须真正跑到**——它是本任务 D18 触及 `Sidebar` 的守护层，不得进 skip 列表。）若本地无该 Simulator，`xcrun simctl list devices | grep 'iPhone 17 Pro'` 确认名称；缺失则装或换等价机型并在记录中注明。

- [ ] **Step 3: audit-checklist 标 ✅（只改状态描述，不增删数据行）**

`Read` `.claude/epics/coredesign-audit-remediation/audit-checklist.md`，对以下 10 行**在原行内追加/更新 ✅ 状态与一句处置说明**（保持 `| ID | … | FR | Issue |` 五列结构、行数不变）：

| 行 | ID | 处置说明要点 |
|---|---|---|
| 86 | C6b | ✅ README 组件数 15→24，与 `docs/README.md` Index 对齐 |
| 92 | C10a | ✅ 新增 MIT `LICENSE`（Copyright 2026 Evan Wang） |
| 94 | C10c | ✅ `.gitignore` 去重 `.superpowers/`（原 line 73-74 删） |
| 95 | C10d | ✅ `.agents/` 加 gitignore；`AGENTS.md` 纳入版本控制；`.claude/prds`+`epics` 已 tracked（核对无遗漏） |
| 112 | D9 | ✅ `git mv` 至 `Components/Banner/Banner.swift`，历史保留，无残留旧路径引用 |
| 115 | D12 | ✅ CoreMenuButton `sm`/`pressedScale`、TimelineItem `none`+dot 常量、CommentCard `1` 保留裸值+注释、BottomInputBar `minimumHitTargetSide`、AvatarGroup ramp 注释（判断项理由见 #102 记录） |
| 118 | D15 | ✅ `FillColors` 四处改 `#if/#else/#endif` |
| 119 | D16a | ✅ 核对：#101 泛型化已移除旧 4-style 文档，6 case 均有 inline 注释，无遗漏 |
| 120 | D16b | （已标 ✅——#97 顺带完成，**不改**） |
| 122 | D18 | ✅ Sidebar（6 组件）+ FloatingGlass + TelegramGlass 三处补 `#Preview` |

> **不动** C6a（行 85）——它是 README pin tag，不在本 Issue 10 项范围。

- [ ] **Step 4: 复核 audit-checklist 计数不变量（防误增删数据行）**

Run:
```bash
A=.claude/epics/coredesign-audit-remediation/audit-checklist.md
echo $(( $(grep -cE '^\| [A-D][0-9]' "$A") - 4 ))   # => 83
grep -cE '\| #[0-9]+ \|$' "$A"                        # => 79
```
Expected: `83` 与 `79`（与改前一致——只改了状态文字，未增删数据行）。

- [ ] **Step 5: 越界反向自查**

Run: `git diff --stat epic/coredesign-audit-remediation...HEAD -- . | tail -30`
Expected: 改动只落在 `Sources/`、`README.md`、`.gitignore`、`LICENSE`、`AGENTS.md`、`.claude/epics/coredesign-audit-remediation/audit-checklist.md`、以及本 `102-plan.md`。**不应**出现 `CLAUDE.md`、`docs/`、`Package.swift`、`.claude/` 其它历史 artifact 的改动。

- [ ] **Step 6: Commit**

```bash
git add .claude/epics/coredesign-audit-remediation/audit-checklist.md
git commit -m "docs(audit): mark C6b/C10a/C10c/C10d/D9/D12/D15/D16a/D18 resolved (#102)"
```

---

## 收尾 / Finishing

- [ ] **验证（`oh-my-superpowers:verification-before-completion`）**：给「完成」结论前，粘贴上面 Task 7 Step 1-2 的实际命令输出为证（四命令绿 + `** TEST SUCCEEDED **` + warning=0 + 计数 83/79）。**不得**仅凭「应该过了」下结论。
- [ ] **Preview 渲染确认（无法自动断言）**：`#Preview` 是本仓库的**视觉冒烟手段**，编译通过不等于渲染正常。在报告中记「**建议用户在 Xcode 打开 Sidebar.swift / FloatingGlassModifier.swift / TelegramGlassButtonModifier.swift 渲染确认三处新预览**」。
- [ ] **收束分支（`oh-my-superpowers:finishing-a-development-branch`，选 Option 2 开 PR）**：base = `epic/coredesign-audit-remediation`（**不是** `main`）。PR 正文列出 10 项审计项处置、4 处判断项理由（44 / 1 / dotSize / AvatarGroup ramp）、以及五命令验证证据。
- [ ] **PR 迭代（`auto-fix-pr-after-implementation`）**：开 PR 后拉 Copilot review。若 Copilot 不可用 → 降级用 `Agent`（`subagent_type: superpowers-reviewer`）对完整 diff 做终审（`finishing` 焦点），并把结论作为 PR 顶层评论贴出。反馈按 `oh-my-superpowers:receiving-code-review` 处置。

---

## Self-Review

**1. Spec coverage（10 项逐一映射）:**
- C6b → Task 2 Step 2 ✅｜C10a → Task 1 Step 4 ✅｜C10c → Task 1 Step 1 ✅｜C10d → Task 1 Step 2/5/6（+ Task 2 核对 prds/epics 已 tracked）✅
- D9 → Task 5 ✅｜D12 → Task 3（3 机械 + 4 判断）✅｜D15 → Task 4 ✅
- D16a → Task 2 Step 4（核对，已由 #101 resolved）✅｜D16b → Task 2 Step 3（核对，已由 #97 resolved）✅｜D18 → Task 6 ✅
- CLAUDE.md 三方核对 → Task 2 Step 3 ✅｜audit-checklist 收口 + 五命令验证 → Task 7 ✅

**2. Placeholder scan:** 无 TBD / 「适当处理」/「类似 Task N」；每个代码步骤都给了完整 before/after 与确切命令+期望输出。

**3. Type consistency:** `CoreSpacing.none`(0)/`.sm`(8)、`CoreButtonMetrics.pressedScale`(0.94, Double)、`CoreControlMetrics.height(.extraLarge)`(48≠44) 均按实际定义核对；新命名常量 `rootDotDiameter`/`nestedDotDiameter`/`minimumHitTargetSide` 命名前后一致；Sidebar 6 个 public 组件 init 签名逐一取自源码。

**4. 已知偏离审计快照的项（执行者注意）:**
- **`44` 全库仅一处（line 225）**，即 D12 目标本身——侦察 note 的「另有一处、225 不是」不成立（见 Task 3 Step 6 判断点）。
- **D16a / D16b 均已由上游 PR（#101 / #97）resolved**，本任务只核对不改码。
- **AGENTS.md / `.agents/` 在本 worktree 不存在**，AGENTS.md 需从父 checkout 拷入（Task 1 Step 5）。
- **Banner 旧路径引用只在历史 artifact**（`docs/superpowers/plans/`、`.claude/`），不得回改（Task 5 Step 3）。
- **AvatarGroup / TimelineItem-dotSize 的裸值无语义相符 token**——是 AC 未预告的额外判断项，按「命名常量 / 注释、值零变化」保守处置（Task 3 Step 4/7）。
