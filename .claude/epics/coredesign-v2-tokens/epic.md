---
name: coredesign-v2-tokens
status: backlog
created: 2026-05-09T16:41:39Z
updated: 2026-05-09T18:04:39Z
progress: 11%
prd: .claude/prds/coredesign-v2-tokens.md
github: https://github.com/wxlpp/CoreDesign/issues/1
---

# Epic: coredesign-v2-tokens

## Overview

把 PRD 中规划的 6 类 token、3 处语义色补全、2 个 modifier、1 处 canary 迁移落到 9 个高内聚、低耦合的实施任务上。所有任务都是**纯加法 + 一处定向重命名**（`Color.focusRing` → `Color.borderFocus`），不重构任何现有组件。任务按"foundation → 平行扩张 → modifier 收尾"三层组织，确保最关键的依赖链最短，并最大化中段并行度。

## Architecture Decisions

PRD 已固定的关键决策，epic 阶段只补实施细节：

1. **Token API 形态**：caseless enum + `public static let`（`CGFloat` 或 `Font` 等强类型）。调用方写 `CoreSpacing.md` / `CoreBorderWidth.thin`，无需 `.rawValue`，可直接传入 SwiftUI 修饰器参数。
2. **新旧 surface/content token 双轨共存**：通过 `///` doc-comment 注明映射关系（`surfaceCanvas ≈ surfaceBase`），不删除旧名。**唯一例外**：`Color.focusRing` 直接重命名为 `Color.borderFocus`，无别名（PRD 已确认无下游依赖）。
3. **Shadow 色用 xcassets dynamic color**：`CoreElevation` 的 `shadowColor` 通过 `Resources.xcassets` 中新增 colorset（`shadow-light`/`shadow-medium`/...）提供 light/dark 双值，避免阴影在暗色模式下消失。
4. **FocusRingModifier 双平台分支**：iOS / iPadOS / visionOS 走 `.overlay(RoundedRectangle().stroke())` 纯视觉；macOS 走 `NSViewRepresentable` 包装空 NSView + `focusRingType = .exterior` 注册系统 NSFocusRing。同一 modifier API，分支位于内部 `#if canImport(UIKit) / canImport(AppKit)`。
5. **Primer Primitives 版本锁定**：在 Task 1 启动前查 `https://github.com/primer/primitives` 最新 stable tag，写入 `docs/PRIMER_VERSION.md`——**这是唯一权威来源**（含版本号、ref 链接、锁定日期）。后续 6 个 token 文件顶部仅以注释形式引用该路径（`// Source of truth: docs/PRIMER_VERSION.md`），**不重复声明版本字符串**，避免多处漂移。
6. **Token 模块物理位置**：新建 `Sources/CoreDesign/Tokens/` 目录，与现有 `Colors/` / `Modifier/` / `Components/` 平级。`Package.swift` 不需要修改（`.process("Resources")` 已覆盖资源；Sources 通配生效）。
7. **xcassets 语义 colorset 命名约定**：新引入的语义 colorset（shadow / canvas / border / surface 等非色相中性命名）**按语义类别各建顶级目录**，与现有色相目录（`grey/`、`brand/` 等）平级。例：
   - `Resources.xcassets/shadow/shadow-medium.colorset/`
   - `Resources.xcassets/canvas/canvas-default.colorset/`
   - `Resources.xcassets/border/border-focus.colorset/`

   不混入现有色相目录，不集中于单个 `semantic/` 目录。Task 3 与 Task 5 并行时各自占用对应顶级目录，git 冲突面降至单个 colorset 级别。

## Technical Approach

本 epic 没有传统意义上的"frontend / backend / infrastructure"分层（Swift Package 是单一二进制库），按本仓库架构改写为**Token 层 / 颜色资源层 / Modifier 层**。

### Token Layer（新建 `Sources/CoreDesign/Tokens/`）

| 文件 | 类型 | 形态 | 依赖 |
|---|---|---|---|
| `CoreSpacing.swift` | `public enum` | 10 个 `public static let: CGFloat`（none/xs/sm/md/lg/xl/xxl/xxxl/xxxxl/huge） | 无 |
| `CoreRadius.swift` | `public enum` | 6 个 `public static let: CGFloat`（none/small/medium/large/xlarge/full） | 无 |
| `CoreBorderWidth.swift` | `public enum` | 4 个 `public static let: CGFloat`（none/hairline/thin/thick） | 无 |
| `CoreTypography.swift` | `public enum` | 7+ 档命名常量，每档暴露 `.font: Font`、`.lineSpacing: CGFloat`、`.tracking: CGFloat` 三件套 | 无 |
| `CoreElevation.swift` | `public enum` | 4 档 `(shadowColor, shadowRadius, shadowX, shadowY)` + `View.coreShadow(_:)` modifier | xcassets shadow colorset |
| `CoreControlMetrics.swift` | `public enum` | 按 `ControlSize` 取 height / horizontalPadding / verticalPadding / font / iconSize 的 helper | CoreSpacing + CoreTypography |

### Color Resource Layer（扩展现有 `Sources/CoreDesign/Colors/` 与 `Resources/Resources.xcassets/`）

| 文件 | 改动 |
|---|---|
| `BorderColors.swift` | 新增 `borderMuted` / `borderHover` / `borderFocus` / `borderSelected` / `borderEmphasis`；**删除** `focusRing`（重命名为 `borderFocus`） |
| `SurfaceColors.swift` | 新增 `surfaceCanvas` / `surfaceCanvasSubtle` / `surfaceCanvasInset` / `surfacePanel` / `surfaceSidebar` / `surfaceCard` |
| `ContentColors.swift` | 新增 `contentMuted` / `contentSubtle` / `contentOnEmphasis` |
| `Resources.xcassets/` | 必要时新增 colorset（如 `shadow-medium`、`canvas-default` 等），优先复用 `ColorGrade` 已有 grey/brand 色 |

每个新增 token 强制写 `///` doc-comment 标注与现有 token 的映射关系。

### Modifier Layer（扩展现有 `Sources/CoreDesign/Modifier/`）

| 文件 | 改动 |
|---|---|
| `FocusRingModifier.swift` | 新建。`View.focusRing(visible:color:width:cornerRadius:)`；iOS = overlay stroke；macOS = NSViewRepresentable + NSFocusRing |
| `SurfaceModifier.swift` | 新建。`SurfaceKind` 枚举（5 case）+ `View.surface(_:)`；每 kind 输出 `(background, border, cornerRadius)` 三件套 |
| `BorderModifier.swift` | **改动一行**：默认 `cornerRadius: 0` → `CoreRadius.none`，`width: 1` → `CoreBorderWidth.thin`（FR-9 canary） |

## Implementation Strategy

**三层依赖结构**：

```
Layer 1 (foundation, 必须先合):
  └─ Task 1: Primer 版本锁定 + 标量 token (Spacing/Radius/BorderWidth)

Layer 2 (并行扩张, depends_on: 1, 互不冲突):
  ├─ Task 2: CoreTypography
  ├─ Task 3: CoreElevation (含 shadow/ 顶级目录下的 colorset)
  ├─ Task 5: 语义色补全 + focusRing 重命名 (含 canvas/ border/ 顶级目录下的 colorset)
  └─ Task 9: BorderModifier canary 迁移

Layer 3 (modifier 收尾):
  ├─ Task 4: CoreControlMetrics                  (depends_on: 1, 2)
  ├─ Task 6: SurfaceModifier                      (depends_on: 1, 5)
  ├─ Task 7: FocusRingModifier — iOS + 文件骨架   (depends_on: 1, 5)
  └─ Task 8: FocusRingModifier — macOS 分支填充   (depends_on: 1, 5, 7)
```

**关键依赖更正（Copilot 第二轮审查发现）**：Task 8 在 Task 7 创建的同一 modifier 文件中填充 macOS 分支，**不是可并行任务**——Task 7 必须先创建文件骨架（含 `#if canImport(AppKit)` 占位），Task 8 才能补全 NSViewRepresentable 实现。

**单 agent 执行顺序建议**：Layer 2 内若由单人顺序执行，**优先做 Task 5**——它同时阻塞 Layer 3 的三个任务（6/7/8），延期会把整个右半边推右；其他三个 Layer 2 任务（2/3/9）只阻塞自己或单条下游链。

**风险控制**：

- **Task 8 macOS NSFocusRing 集成的不确定性**：技术 spike，PRD Assumptions 中已写好回退条款（验证失败回退为视觉近似）。**新增风险**：Swift 6 strict concurrency 下 `NSViewRepresentable` 的 `@MainActor` 隔离 + `becomeFirstResponder` 跨 SwiftUI state propagation cycle 调用，可能引发 non-`Sendable` 跨 actor 编译错误。若发生，回退路径同前；若坚持系统集成，需在 spike 内额外验证并发兼容性，估时上限相应上浮。
- **Task 5 是 Layer 3 的共同前置**：Task 5（最长 1.5d）阻塞 Task 6/7/8 三条下游链。Task 5 任何延期都会等量推右整个 Layer 3，相当于关键路径瓶颈。与 Task 8 并列为本 epic 两大风险点。
- **xcassets 语义 colorset 冲突已通过命名约定消解**（Architecture Decisions #7）：Task 3 占用 `shadow/`、Task 5 占用 `canvas/` 与 `border/`，顶级目录互不重叠，并行 push 不再产生 git 冲突。

**测试策略**：本 epic 不引入单元测试（token 是数据声明）。每 PR 门禁：`swift build -Xswiftc -warnings-as-errors && swift test`（Copilot 第二轮发现：仅 build 不足以捕获 `Color.focusRing` 删除导致的潜在 test 引用失败；必须并跑 test）。视觉验证：每个 modifier 文件的 `#Preview` 在 light/dark 双 colorScheme 下抽查。

## Task Breakdown Preview

总计 **9 个任务**，处于 ccpm 上限 10 之下，留 1 个余量给可能的拆分（譬如 Task 8 spike 失败时分裂为"集成"+"回退文档化"）。

1. **Primer 版本锁定 + 标量 token** — 创建 `Sources/CoreDesign/Tokens/` 目录 + 仓库根 `docs/PRIMER_VERSION.md` 版本锚定文件（含锁定的 git tag、ref 链接、锁定日期）；新增 `CoreSpacing.swift` + `CoreRadius.swift` + `CoreBorderWidth.swift` 三个 token 文件，每个文件顶部以 `// Source of truth: docs/PRIMER_VERSION.md` 引用版本锚。**所有后续任务的依赖。**
   - parallel: false（前置）
   - 触碰文件：4 个新文件（`Sources/CoreDesign/Tokens/` 下 3 个 swift + `docs/` 下 1 个 markdown 锚定）

2. **CoreTypography** — 7 档 SwiftUI Font 命名 + lineSpacing + tracking 三件套；显式 `lineSpacing = max(0, lineHeight - fontSize)` 公式落到代码。
   - depends_on: 1
   - parallel: true（与 3、5、9 并行）
   - 触碰文件：1 个新文件

3. **CoreElevation 含 dark-adaptive shadow colorset** — 新增 4 档阴影 + `View.coreShadow(_:)` 便利 modifier；在 `Resources.xcassets/shadow/` 顶级目录下新增 light/dark 双取值的 shadow colorset（命名约定见 Architecture Decisions #7）。
   - depends_on: 1
   - parallel: true（与 2、5、9 并行；占用 `xcassets/shadow/` 顶级目录，与 Task 5 不冲突）
   - 触碰文件：1 个新 swift + ≥4 个新 colorset

4. **CoreControlMetrics** — 按 `ControlSize` 提供 height / padding / font / iconSize 的查询表 helper。
   - depends_on: 1, 2
   - parallel: false
   - 触碰文件：1 个新文件

5. **语义色补全 + `Color.focusRing` 重命名** — `BorderColors.swift` / `SurfaceColors.swift` / `ContentColors.swift` 三文件扩展；**删除 `Color.focusRing`** 并新增 `Color.borderFocus`；在 `Resources.xcassets/canvas/` 与 `xcassets/border/` 顶级目录下新增必要 colorset；每个新 token 带映射 doc-comment。
   - depends_on: 1
   - parallel: true（与 2、3、9 并行；占用 `xcassets/canvas/` + `xcassets/border/` 顶级目录，与 Task 3 不冲突）
   - 触碰文件：3 个现有 swift + ≥6 个新 colorset
   - **此任务包含本 epic 唯一破坏性变更**（`focusRing` 删除）；同 PR 内修复任何旧引用
   - **关键路径瓶颈**：阻塞 Task 6/7/8；单 agent 执行时优先于 2/3/9

6. **SurfaceModifier** — `SurfaceKind` 5 case（`.canvas / .canvasSubtle / .panel / .sidebar / .card`）+ `View.surface(_:)` + #Preview 五种 kind 对比。
   - depends_on: 1, 5
   - parallel: false
   - 触碰文件：1 个新文件

7. **FocusRingModifier — 文件骨架 + iOS 端实现** — 创建 `FocusRingModifier.swift`，含 iOS `.overlay(RoundedRectangle().stroke())` 纯视觉实现；macOS 分支以 `#if canImport(AppKit)` 占位（空 wrapper 即可，留给 Task 8 填充）；iOS #Preview。
   - depends_on: 1, 5
   - parallel: false
   - 触碰文件：1 个新文件

8. **FocusRingModifier — macOS NSFocusRing 分支填充** — 在 Task 7 创建的同一 modifier 文件 macOS 分支中填充 `NSViewRepresentable` + `becomeFirstResponder` + `focusRingType = .exterior`；macOS #Preview；Accessibility Inspector 识别验证；**Swift 6 strict concurrency 兼容性验证**（`@MainActor` 隔离 + `becomeFirstResponder` 跨 actor 调用）。
   - depends_on: 1, 5, **7**
   - parallel: false（在 Task 7 创建的文件上写 macOS 分支，必须等 Task 7 合入）
   - 触碰文件：1 个现有文件（即 Task 7 创建的）
   - **回退条件**：NSFocusRing 集成失败 **或** Swift 6 并发不兼容 → macOS 也走 `.overlay(stroke())`；任务 progress comment 中记录原因，不阻塞 epic 关闭

9. **BorderModifier canary 迁移** — `BorderModifier.swift` 内 **3 处字面量替换**：body 内 `RoundedRectangle(cornerRadius: 0)` → `CoreRadius.none`；两个 `bordered()` overload 的默认 `width: CGFloat = 1` → `CoreBorderWidth.thin`。不改 API，不改行为，值语义完全等价。
   - depends_on: 1
   - parallel: true（与 2、3、5 并行；只改一个文件，冲突风险最低）
   - 触碰文件：1 个现有文件

## Dependencies

**仓库内：**
- 现有 `Resources/Resources.xcassets/`（扩展，不替换）
- 现有 `Sources/CoreDesign/Colors/{Border,Surface,Content}Colors.swift`（扩展 + 一处重命名）
- 现有 `Sources/CoreDesign/Modifier/BorderModifier.swift`（一行迁移）

**外部：**
- GitHub Primer Primitives 仓库（`github.com/primer/primitives`）—— Task 1 锁定具体 tag
- macOS AppKit `NSView.focusRingType` API —— Task 8 spike 验证

**任务间硬依赖（depends_on）汇总：**
- Task 2 → Task 1
- Task 3 → Task 1
- Task 4 → Task 1, 2
- Task 5 → Task 1
- Task 6 → Task 1, 5
- Task 7 → Task 1, 5
- Task 8 → Task 1, 5, **7**（在 Task 7 创建的文件上写 macOS 分支）
- Task 9 → Task 1

**并行可执行集合：**
- 在 Task 1 合并后：{2, 3, 5, 9} 可并行
- 在 {1, 2} 合并后：{4} 可启动（与 3/5/9 并行）
- 在 {1, 5} 合并后：{6, 7} 可并行启动
- 在 {1, 5, 7} 合并后：{8} 可启动

**下游 epic：**
- `coredesign-v2-components`：本 epic 全部任务关闭、PR 合入 main 后启动。

## Success Criteria (Technical)

### PRD 11 项验收标准的逐项映射

epic 关闭即视为 PRD SC 全数达成。逐项追溯（避免下游执行者忘查 PRD 原文）：

| PRD SC | 内容 | epic 中由谁保证 |
|---|---|---|
| #1 | `Tokens/` ≥6 文件 + `Modifier/` ≥2 文件 | Task 1（3 文件）+ Task 2/3/4（各 1）+ Task 6/7（各 1） |
| #2 | `Tokens/` 内 `public static (let\|var\|func)` ≥35 | Task 1–4 实施时计数 |
| #3 | 14 个新语义色名 grep ≥14 | Task 5 |
| #4 | `swift build -Xswiftc -warnings-as-errors` 通过 | 每 PR 门禁（见下 epic SC #1） |
| #5 | `swift test` 通过 | 每 PR 门禁（见下 epic SC #1） |
| #6 | `BorderModifier` 内无魔法数字 0 / 1 | Task 9 |
| #7 | `FocusRingModifier` + `SurfaceModifier` 各有 #Preview，前者 iOS+macOS 双覆盖 | Task 6/7/8 |
| #8 | `Color.focusRing` 删除、`Color.borderFocus` 存在 | Task 5（见下 epic SC #3） |
| #9 | Primer 版本注释一致（人工） | epic SC #4 |
| #10 | 视觉抽查 light/dark + dark mode shadow 可见（人工） | Task 3、6 完成时人工 |
| #11 | macOS Accessibility Inspector 识别为系统 focus ring（人工） | Task 8（验证或回退记录） |

### epic 层额外的可机器验证标准

1. **每 PR 编译 + 测试门禁**：每个任务对应一个独立 PR，PR 内 `swift build -Xswiftc -warnings-as-errors && swift test` 必须通过；不存在"等其他任务合入才能编译"的 PR。
2. **xcassets colorset 数量审计**：epic 关闭前
   - `find Resources.xcassets/shadow -name 'Contents.json'` 应 ≥4（4 档 elevation 各一）
   - `find Resources.xcassets/canvas -name 'Contents.json'` 应 ≥3（surfaceCanvas / surfaceCanvasSubtle / surfaceCanvasInset 各一，其余 surface token 可复用 grey/brand）
   - `find Resources.xcassets/border -name 'Contents.json'` 应 ≥1（至少 borderFocus）
3. **focusRing 重命名零残留**：epic 关闭前 `grep -rn 'Color\.focusRing\|\.focusRing\b' Sources/CoreDesign/ | grep -v 'View.focusRing\|focusRing(' | wc -l` == 0（仅 modifier 调用形式可保留）。
4. **Primer 版本注释一致性**：所有 6 个 token 文件顶部应包含 `// Source of truth: docs/PRIMER_VERSION.md`（grep 验证一致）；版本字符串只在 `PRIMER_VERSION.md` 中出现。

## Estimated Effort

**总体：1.0 – 1.75 人周（专注实施）**

按任务粗估：

| Task | 估时 | 备注 |
|---|---|---|
| 1. Primer 锁定 + 标量 token | 0.5 天 | 查阅 Primer + 创建 PRIMER_VERSION.md + 30 行常量 |
| 2. CoreTypography | 0.5–1 天 | 7 档 × 3 字段 + lineSpacing 公式核对 |
| 3. CoreElevation | 1 天 | shadow/ 顶级目录 colorset + dark mode 视觉验证 |
| 4. CoreControlMetrics | 0.5 天 | helper 表 |
| 5. 语义色补全 + 重命名 | 1–1.5 天 | 三文件 + canvas/ + border/ colorset + 映射注释 |
| 6. SurfaceModifier | 0.5 天 | 5 case 模板化 |
| 7. FocusRingModifier 文件骨架 + iOS | 0.5 天 | overlay 实现 + macOS 占位 + iOS #Preview |
| 8. FocusRingModifier macOS 分支 | 1–2.5 天 | NSFocusRing 集成 + Swift 6 并发兼容性 spike + 可能回退 |
| 9. BorderModifier canary | 0.25 天 | 3 处字面量 |

**Task 8 估时上调原因**（Copilot 第二轮发现）：原 1–2d 范围未涵盖 Swift 6 strict concurrency 下 `NSViewRepresentable` + `becomeFirstResponder` 的并发兼容性验证。这是 platform API 与新 Swift 版本交互的双重不确定性，spike 上限提到 2.5d。若 0.5d 内确认不可行，立即触发回退路径，整体估时回到 ~1d。

**关键路径**（更新后）：Task 1 (0.5d) → Task 5 (1.5d) → Task 7 (0.5d) → Task 8 (2.5d 上限) ≈ **5 天上限 / 4 天预期**。

注意：Task 8 现依赖 Task 7（C-1 修正），无法与 Task 7 并行；这把关键路径从原计算的 ~4d 略推至 4–5d。其他任务（2/3/4/6/9）可在关键路径外并行完成。

**资源假设**：单人实施。多 agent 并行执行时（ccpm Phase 4），Layer 2 的 4 个任务（2/3/5/9）同时启动可并行节省 ~1d；Layer 3 内 {6, 7} 也可并行；Task 8 仍需等 Task 7。乐观估计 ~3.5d。

## Tasks Created

- [x] #2 - Primer 版本锁定 + 标量 token (Spacing/Radius/BorderWidth) (parallel: false)
- [ ] #3 - CoreTypography token (parallel: true)
- [ ] #4 - CoreElevation token + dark-adaptive shadow colorset (parallel: true)
- [ ] #5 - CoreControlMetrics token (parallel: false)
- [ ] #6 - 语义色补全 + Color.focusRing 重命名为 borderFocus (parallel: true)
- [ ] #7 - SurfaceModifier (parallel: false)
- [ ] #8 - FocusRingModifier 文件骨架 + iOS 端实现 (parallel: false)
- [ ] #9 - FocusRingModifier macOS NSFocusRing 分支填充 (parallel: false)
- [ ] #10 - BorderModifier canary 迁移 (parallel: true)

Total tasks: 9
Parallel tasks: 4 (002, 003, 005, 009 — 全部 depends_on: 1，等 Task 1 合入后并行)
Sequential tasks: 5 (001, 004, 006, 007, 008)
Estimated total effort: 64 hours（其中 Task 8 含 20h spike 上限；spike 命中回退后实际约 ~48h）
