---
name: coredesign-v2-components-new
status: backlog
created: 2026-05-09T22:32:29Z
updated: 2026-05-09T23:21:43Z
progress: 0%
prd: .claude/prds/coredesign-v2-components.md
github: https://github.com/wxlpp/CoreDesign/issues/29
---

# Epic: coredesign-v2-components-new

## Overview

新增 7 个 GitHub 风格 chrome 组件（PRD Phase B / FR-B-1 ~ FR-B-7）：`Badge` / `Tag` / `SearchField` / `ListRow` / `SidebarRow` / `EmptyState` / `Toast`。补齐 CoreDesign 设计系统目前缺失的基础 surface，让 any-writer 等下游应用做 issue 列表 / 章节大纲 / 角色卡 / 评论侧栏 / 设置页时不需要再自己拼 UI。

本 epic 与 `coredesign-v2-components-existing` epic **完全独立**——两者触碰文件集互不重叠：本 epic 全部新建 `Sources/CoreDesign/Components/{Badge,Tag,SearchField,ListRow,SidebarRow,EmptyState,Toast}/` 子树，零修改既有文件。可与 existing epic 并行启动。

## Architecture Decisions

PRD 已固定的关键决策，epic 阶段补实施细节：

1. **Per-task PR → main 模型**（继承 v2-tokens / v2-components-existing 的成熟做法）：每个新组件一个独立 PR；分支命名 `task/<N>-<slug>`。
2. **每个组件一个子目录 + 一个主 .swift**：`Components/Badge/Badge.swift`、`Components/Toast/Toast.swift` 等；如有内部子组件（譬如 SearchField 的 clear button、Toast 的内部 ToastView），同子目录追加文件，不污染顶级。
3. **Badge：枚举参数化，不引入 BadgeStyle 协议**（PRD FR-B-1）—— Badge 只有 5 固定 level（颜色变化为主），不需要 Banner 的协议形态；参考 Primer `Label` 也是 parametric。
4. **Tag 与 Badge 分工**：Badge = 状态指示器（5 固定 level），Tag = 任意分类标签（颜色由调用方传，对应 GitHub issue labels）；语义清楚分离，避免 type 重叠。
5. **SearchField 用 `.focusRing(visible:)`**（v2-tokens 已交付的 modifier）作 focus 视觉，自动得到 iOS overlay + macOS 同款 overlay（v2-tokens issue #9 fallback）。
6. **ListRow 三泛型 + EmptyView convenience init**（PRD FR-B-4）—— 避免调用方写 `ListRow<EmptyView, EmptyView, Text>` 这种 noisy 类型签名。
7. **SidebarRow accent 用 `CoreBorderWidth.thick` + `Color.borderFocus`**（PRD FR-B-5）—— 不用字面量 `2`。
8. **EmptyState icon 尺寸用 `CoreSpacing.xxxxl` (48) / `CoreSpacing.huge` (64)**（PRD FR-B-6 修正后映射）—— 不是 `xxxl`。
9. **Toast 走 scene-scoped + EnvironmentValues 注入（不是 singleton）**（PRD FR-B-7 R2 修正后架构）：每个 scene 一个独立 `ToastHost` 实例；`@Entry public var toastHost: ToastHost?`；调用方 `@Environment(\.toastHost) var toast` + `toast?.show(...)`；`safeAreaInset(edge:)` 在 scene root 渲染；**z-order 范围有限**——不覆盖 sheet / fullScreenCover / 独立 window，每 sheet root 需单独挂 `.toastHost(...)`。
10. **hover 态用 `surfaceCanvasSubtle`，不用 `Color.hoverBackground`**（PRD FR-B-4/B-5 + Notes）—— `hoverBackground` 已存在但取值是系统 fill 未对齐 Primer；本 epic 故意绕过这是**取值层取舍**，未来 InteractionColors Primer 对齐 epic 后可回评。每个组件 doc-comment 显式标注此 debt 并指向 PRD §Notes。
11. **每 PR 必须 light/dark 双 colorScheme `#Preview` 抽查**：覆盖关键交互态（譬如 SearchField 的 focused/unfocused，Toast 的所有 4 个 level）。
12. **iOS + macOS 双平台 build 必须都通过**：`swift build -Xswiftc -warnings-as-errors` + `swift build --triple arm64-apple-ios26.0-simulator`。
13. **本 epic 不新增 token**（与 PRD §Out of Scope + existing epic ADR #8 一致）：实施过程中发现 v2-tokens 缺漏，记入 PR description follow-up，不在本 epic 内补 token。
14. **Toast task 内不再拆**（Task 7 边界）：`ToastHost` / `ToastItem` / `ToastLevel` / `EnvironmentValues.toastHost` / `View.toastHost(edge:)` / 内部 `ToastView` 全部属同一 task 的实现细节，不为基础设施另起独立 task。
15. **Task 5 ListRow init 形态约束**：designated init 用全标签（`leading:` / `trailing:` / `label:`，每个标签对应一个 `@ViewBuilder` 闭包）；convenience init **只**做缺省槽位补齐（`where Leading == EmptyView` 等约束的便利重载），**不引入**多个无标签闭包重载（避免 SwiftUI 尾随闭包推断歧义）。
16. **Task 7 Toast 硬 AC**（PR 不达成不可 merge）：
    - **dismiss timing 语义**：`duration` 计时**从 toast 开始显示** 起算，**不是** `enqueue`；自动 dismiss 用 `Task.sleep(...) + cancel` 模型，task cancellation 必须正确清理（重新 dismiss 不应触发 double-fire）
    - **append 状态机**：当前 toast 正在 dismiss 动画中时新 `show(...)` 进队列尾，不打断、不 replace；正在显示中时 `show(...)` 同样 append；空队列时 `show(...)` 立即开始显示
    - **z-order 显式限制**：`safeAreaInset` 仅在挂 `toastHost(edge:)` 那层 view 树内可见，**不**覆盖 sheet / fullScreenCover / 独立 window；在每个 sheet root 单独挂 `.toastHost(...)` 才能让 sheet 内触发的 toast 显示。这条作为 PR description 必填字段（见 ADR #17 PR template "z-order limitation"）

## Technical Approach

7 个新组件按复杂度梯度组织：

### 简单结构组件（Badge / Tag / EmptyState）

| 组件 | 关键 API | 依赖 token |
|---|---|---|
| `Badge<Label: View>` | `BadgeVariant` 枚举（info/success/warning/danger/neutral）+ optional `outlined: Bool` | `surfaceCanvasSubtle` / `borderMuted` / `CoreRadius.full` / `CoreTypography.bodySmallFont` + `bodySmallTracking` |
| `Tag<Label: View>` | 颜色由调用方传；optional `removable: Bool` 配 `xmark.circle.fill` | `CoreRadius.small` / `CoreTypography.bodySmallFont` |
| `EmptyState<Action: View>` | icon + title + description + optional action button | `CoreSpacing.lg` / `xl` / `xxxxl` / `huge` / `CoreTypography.titleMediumFont` / `bodyMediumFont` / `Color.contentMuted` |

### 输入 / 列表 / 侧栏（SearchField / ListRow / SidebarRow）

| 组件 | 关键 API | 关键 token / modifier |
|---|---|---|
| `SearchField` | `@Binding var text: String` / `placeholder: String` / `onSubmit: (String) -> Void` / `magnifyingglass` 前缀 + `xmark.circle.fill` clear button | `surfaceCanvasInset` / `borderMuted` / `CoreRadius.medium` / `CoreControlMetrics.height(for: .regular)` / `View.focusRing(visible:)` |
| `ListRow<Leading, Trailing, Label>` | 三泛型 + `EmptyView` convenience init（`where Leading == EmptyView` / `where Trailing == EmptyView` / 双 EmptyView） | `View.surface(.canvas)` 背景；hover 态用 `surfaceCanvasSubtle`（hover debt see §Notes）；`CoreTypography.bodyMediumFont` / `bodySmallFont` / `Color.contentMuted` |
| `SidebarRow<Label: View>` | selected 态左侧 `CoreBorderWidth.thick` accent 条 + `Color.borderFocus`；hover 态 `surfaceCanvasSubtle` | `CoreTypography.bodyMediumFont` / `CoreControlMetrics.height(for: .small)` |

### 全局通知（Toast）

`Toast` 是本 epic 最复杂任务，独立技术 spike：

```swift
@MainActor @Observable public final class ToastHost {
    public init()
    public func show(_ message: String, level: ToastLevel = .info, duration: TimeInterval = 3)
    public func show(_ item: ToastItem)
    public func dismiss(_ id: ToastItem.ID)
}

public struct ToastItem: Identifiable, Sendable { /* id / message / level / duration */ }
public enum ToastLevel: Sendable { case info, success, warning, danger }

extension EnvironmentValues {
    @Entry public var toastHost: ToastHost? = nil
}

public extension View {
    func toastHost(edge: VerticalEdge = .top) -> some View
}
```

Queue 语义（PRD FR-B-7 已定义）：
- `[ToastItem]` 内部队列；同时间只渲染 1 条
- `duration` 计时从 toast **开始显示** 起算
- `dismiss(id)` 对排队中 item 直接移除；对正在显示的 item 立即触发 dismiss 动画
- 当前 toast 正在 dismiss 时新 `show(...)` append 到队列尾（不打断 / 不 replace）

视觉：`View.surface(.card)` + `View.coreShadow(.medium)` + `CoreTypography.bodyMediumFont` + 按 `ToastLevel` 配 icon。

dismiss 触发：自动消失（按 `duration`）+ 滑动手势（向 edge 方向）+ 点击立即 dismiss。

## Implementation Strategy

**7 个任务文件级互不重叠**——每个任务在独立子目录新建文件，零修改既有文件，零文件冲突。所有任务 `parallel: true`，全部并行启动。

**但语义层面有 3 组共享规范**（必须在 task 拆解前作为 guardrail 写进每个 task 的描述，避免并行 agent 各自发明口径）：

1. **Badge ↔ Tag 职责边界**（Task 1 vs Task 2）：Badge 是**状态指示器**（5 固定 BadgeVariant level，颜色由 token 决定）；Tag 是**任意分类标签**（颜色由调用方传入，对应 GitHub issue labels）。
   - **Badge 负例**：不得接收 caller-defined palette（不得有 `Badge(color: Color)` overload）
   - **Tag 负例**：不得收敛成 5 个固定状态 level（不得有 `TagVariant` 枚举）
2. **hover token debt 一致措辞**（Task 5 + Task 6 doc-comment）：`ListRow` / `SidebarRow` hover 态固定写 — `Color.hoverBackground` 已存在但取值未对齐 Primer，本 epic 直接用 `surfaceCanvasSubtle` 是**取值层取舍**，不是 token 缺失代偿；详见 PRD §Notes hover token debt 段。两个 task 的 doc-comment 用**同一段固定文字**，不允许并行 agent 改写措辞。
3. **surface / focus 语义共享**（Task 4 + Task 5 + Task 6 + Task 3）：消费同一批 v2-tokens 资源（`surfaceCanvas*`、`borderMuted`、`borderFocus`、`Color.contentMuted` 等）。本 epic ADR #11 已要求**不新增 token**——若 task 中途发现 token 缺漏，记入 PR description follow-up 段，不在本 epic 内补，留给独立 epic。

```
全部并行 (depends_on: 全部为空):
  ├─ Task 1: Badge（简单，1 文件 + 1 enum）
  ├─ Task 2: Tag（简单，1 文件）
  ├─ Task 3: EmptyState（简单，1 文件 + optional action 泛型）
  ├─ Task 4: SearchField（中等，含 .focusRing 集成）
  ├─ Task 5: ListRow（中等，三泛型 + EmptyView convenience init）
  ├─ Task 6: SidebarRow（中等，含 selected accent + hover）
  └─ Task 7: Toast（复杂，scene-scoped + Observable + queue + safeAreaInset，spike）
```

**单 agent 执行顺序建议**：先做 Task 1（Badge）作为 **canary**——最简单的新组件，验证 `BadgeVariant` 枚举参数化模式 + `surfaceCanvasSubtle` / `borderMuted` 颜色 token 在新建组件中的人体工程学；canary 合入后 fan out 其余 6 个任务。

**多 agent 并行策略**：7 个任务同时 dispatch；预算 7 PR × ~2 round Copilot review × premium request ≈ 14 premium。Task 7 (Toast) 因架构复杂度（Observable + Environment + queue + safeAreaInset）估时上限单独偏高。

**关键风险**：

- **Task 7 (Toast)** 是架构 spike：scene-scoped + EnvironmentValues 注入 + Swift 6 strict concurrency 下 `@MainActor @Observable` 的实现细节 + `safeAreaInset` 在 scene root 的渲染 + 队列状态机。任何一处卡壳都可能拖长 task。**没有降级回退到 singleton**——PRD R2 已锁定 scene-scoped 架构（避免多 scene / sheet / window 状态耦合）。如 `@MainActor @Observable` + Environment 注入路径阻塞且 0.5d spike 内无解，本 task 应**作为 blocker 标记 + 升级给用户介入**，不接受 singleton 妥协交付。
- **Task 5 (ListRow)** 三泛型 + EmptyView convenience init：Swift 编译器对 generic constraint 推断有时会要求完整 init 签名。**约束已锁定**（见 ADR #15）—— designated init 全标签、convenience init 只补缺省槽位、不引无标签闭包重载；如锁定约束下仍出现 ambiguity 编译错误，需要 PR 中显式说明并加类型注解。
- **Task 4 (SearchField)** 调用 `.focusRing(visible:)`：iOS 与 macOS **共享同一套 SwiftUI overlay 实现**（不是临时 fallback 分支——`FocusRingModifier.swift` 在 v2-tokens issue #9 spike 后已统一为 overlay）。两端视觉等价；macOS 不被 Accessibility Inspector 识别为系统 focus indicator，仅是视觉层面的 focus ring。这是 PRD SC #11 已记录的限制，不是本 task 引入的问题；Task 4 PR description 需简短引用即可。

## Task Breakdown Preview

按 PRD §Estimated Effort & Epic Split 的 7 task 计数：

1. **Badge**（canary，最简单）
2. **Tag**
3. **EmptyState**
4. **SearchField**
5. **ListRow**
6. **SidebarRow**
7. **Toast**（最复杂，spike）

## Dependencies

**前置（必须满足）**：
- v2-tokens epic 全部 9 个 issue 已 merged（**已满足**：commit `abd0da4` archive 完成）
- main 上有 6 类 token + 14 语义色 + `View.surface(_:)` + `View.coreShadow(_:)` + `View.focusRing(_:)` 等

**任务间**：无 depends_on，全部 parallel。

**下游**：
- `coredesign-v2-components-existing` epic 与本 epic **彼此独立**，可并行
- `any-writer` 切换到 v2-components（含 Toast / SearchField / ListRow 等）是更下游的独立 epic

## Success Criteria (Technical)

PRD §Success Criteria 中与 Phase B 直接相关的项，本 epic 全数兑现：

| PRD SC | 由本 epic 哪部分保证 |
|---|---|
| #2 新组件落地数量（7 个目录 / 文件） | 7 个 task 各自交付 |
| #3 build 洁净（macOS + iOS 双绿） | 每 PR 门禁 |
| #4 swift test 退出 0 | 每 PR 门禁 |
| #5 iOS 编译通过 | 每 PR 跑 `swift build --triple arm64-apple-ios26.0-simulator` |
| #6 部分（7 新组件全部 #Preview） | 每个 task 交付 |

epic 层补充门禁：

1. **每 PR 编译 + 测试双绿**：macOS + iOS 双 SPM build 全绿
2. **NFR token-clean 自检**：每 PR 在 description 中确认 production 代码（`#Preview` 块除外）零 magic numbers——padding / cornerRadius / lineWidth / EdgeInsets / height / width / shadow radius 全部走 token
3. **doc-comment 治理**：每个 public API 表面（公开 struct / enum / extension View func）必须含 doc-comment，覆盖：使用场景、关键参数、与 Primer 概念对应（如 "对应 Primer Label"）、light/dark 行为差异（如有）
4. **hover token debt 文字**：ListRow / SidebarRow 的 doc-comment 内显式标注 hover 态使用 `surfaceCanvasSubtle` 而非 `Color.hoverBackground` 的 debt，并 link 到 PRD §Notes
5. **每 PR description 固定字段**（与 existing epic 对齐；reviewer 缺哪一项均可拒绝 merge）：
    - **Light preview**：light colorScheme `#Preview` 截图 / 详细文字描述
    - **Dark preview**：dark colorScheme `#Preview` 截图 / 详细文字描述
    - **API 摘要**：本 PR 引入的 public API 表面（struct / enum / extension View func 签名清单）
    - **doc-comment 完整性**：勾选确认每个 public API 表面 doc-comment 已覆盖 4 项（使用场景 / 关键参数 / Primer 概念对应 / light-dark 差异）
    - **token-clean 自检**：勾选确认零新增 magic numbers
    - **Toast 专项（仅 Task 7）**：z-order limitation 段——明示"`safeAreaInset` 仅在 scene root 层可见，不覆盖 sheet / fullScreenCover / 独立 window"

## Estimated Effort

总体：1 – 1.5 人周（专注实施）。按任务粗估：

| Task | 估时 | 备注 |
|---|---|---|
| 1. Badge | 0.5 天 | canary |
| 2. Tag | 0.5 天 | |
| 3. EmptyState | 0.5 天 | |
| 4. SearchField | 1 天 | 含 .focusRing 集成 + clear button |
| 5. ListRow | 1 天 | 三泛型 + EmptyView convenience init |
| 6. SidebarRow | 0.75 天 | selected accent + hover |
| 7. Toast | **2 – 3 天** | architecture spike：内部建议 0.5d spike（`@MainActor @Observable` + Environment 注入 PoC）+ 1.5–2.5d 实现（queue 状态机 + safeAreaInset + gesture/click dismiss + 双平台 #Preview）。R1 估时 1.5–2.5d 偏紧，本 task 不接受 singleton 妥协（per ADR #9）故复杂度真实存在 |

**关键路径**（多 agent 并行）：Task 7（最长 3d）。

**关键路径**（单 agent 顺序）：Task 1 (canary) → 其余 fan out（约 0.5d 后 canary 反馈到位即可启动剩余 6 个）。

## Tasks Created

- [ ] #30 - Badge（canary） (parallel: true)
- [ ] #31 - Tag (parallel: true)
- [ ] #32 - EmptyState (parallel: true)
- [ ] #33 - SearchField (parallel: true)
- [ ] #34 - ListRow (parallel: true)
- [ ] #35 - SidebarRow (parallel: true)
- [ ] #36 - Toast（architecture spike） (parallel: true)

Total tasks: 7
Parallel tasks: 7（全部文件级互不重叠 + 语义共享 guardrails 已写入 Implementation Strategy）
Sequential tasks: 0
Estimated total effort: 58 hours（4 + 4 + 4 + 8 + 8 + 6 + 24）
