# Native Primer 第 3B 阶段：内容组件实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal（目标）：** 在 Native Primer 基线下锁定 `CommentCard`、`EventRow`、`TimelineItem`、`StatusRow`、`BookCover` 作为内容层（content-layer）表面：保留密度与可读性，通过间距 / 边框 / 排版而非材质来打磨。

**Architecture（架构）：** 第 3A 阶段完成了悬浮层（floating）与反馈层（feedback）。第 3B 阶段处理规格 §Phase 3 的内容层子集。这五个组件目前已合规（无 glass，仅使用内容卡片样式）；本阶段是一次**文档梳理**——在每个组件上声明 material/role、确认没有 glass 泄漏、并重跑既有测试作为编译稳定基线。视觉改动刻意保持最小。

**Tech Stack（技术栈）：** Swift 6.3、SwiftUI、Swift Testing、iOS 26 / macOS 26 package targets。

---

## 源规格

实施前请阅读：

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`（§Content Components）

本计划仅覆盖 Phase 3 中的内容组件子集：

- `CommentCard`
- `EventRow`
- `TimelineItem`
- `StatusRow`
- `BookCover`

不要改动 Phase 3A（`Toast` / `Banner` / `BottomInputBar`）或 Phase 3C（`ProgressBar` / `ProgressIndicator` / `Avatar` / `AvatarGroup` / `EmptyState`）。

## File Structure（文件结构）

修改（仅 doc-comment 头部，不涉及行为变更）：

- `Sources/CoreDesign/Components/CommentCard/CommentCard.swift`
- `Sources/CoreDesign/Components/EventRow/EventRow.swift`
- `Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift`
- `Sources/CoreDesign/Components/StatusRow/StatusRow.swift`
- `Sources/CoreDesign/Components/BookCover/BookCover.swift`

只读（既有测试覆盖——必须保持绿）：

- `Tests/CoreDesignTests/CommentCardTests.swift`
- `Tests/CoreDesignTests/EventRowTests.swift`
- `Tests/CoreDesignTests/TimelineItemTests.swift`
- `Tests/CoreDesignTests/StatusRowTests.swift`
- `Tests/CoreDesignTests/BookCoverTests.swift`

---

## 任务 1：CommentCard Native Primer 声明

**文件：**
- 修改：`Sources/CoreDesign/Components/CommentCard/CommentCard.swift`

- [ ] **Step 1：基线现有测试**

运行：

```bash
swift test --filter CommentCardTests
```

预期：测试通过。

- [ ] **Step 2：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/CommentCard/CommentCard.swift` 中，找到 `public struct CommentCard` 上方的顶部 doc-comment，前置一段 Native Primer 头部。保留所有现有正文（avatar / author / timestamp 的布局规约、展开行为等）：

```swift
/// Native Primer comment card.
///
/// Content-layer card. Preserves GitHub-like density and readability —
/// polish comes from spacing, hairline borders, and typography hierarchy,
/// **not** Liquid Glass. Restrained radius (`CoreRadius.medium` ≈ 8pt) per
/// spec §Radius And Density.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 3：确认无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/CommentCard
```

预期：零匹配。

- [ ] **Step 4：跑测试和构建**

运行：

```bash
swift test --filter CommentCardTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/CommentCard/CommentCard.swift
git commit -m "docs: declare CommentCard Native Primer material/role"
```

---

## 任务 2：EventRow Native Primer 声明

**文件：**
- 修改：`Sources/CoreDesign/Components/EventRow/EventRow.swift`

- [ ] **Step 1：基线现有测试**

运行：

```bash
swift test --filter EventRowTests
```

预期：测试通过。

- [ ] **Step 2：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/EventRow/EventRow.swift` 中，找到 `public struct EventRow` 声明上方的顶部 doc-comment，前置一段 Native Primer 头部。保留所有现有正文：

```swift
/// Native Primer event row.
///
/// Content-layer row. Activity-stream entry with avatar / actor / verb /
/// target / timestamp layout. Density and readability are the priority; no
/// glass, no cardification — the row sits flat on its container's surface.
/// Hover and selected states use restrained fills, never decorative material.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 3：确认无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/EventRow
```

预期：零匹配。

- [ ] **Step 4：跑测试和构建**

运行：

```bash
swift test --filter EventRowTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/EventRow/EventRow.swift
git commit -m "docs: declare EventRow Native Primer material/role"
```

---

## 任务 3：TimelineItem Native Primer 声明

**文件：**
- 修改：`Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift`

- [ ] **Step 1：基线现有测试**

运行：

```bash
swift test --filter TimelineItemTests
```

预期：测试通过。

- [ ] **Step 2：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift` 中，找到 `public struct TimelineItem` 上方的顶部 doc-comment，前置一段 Native Primer 头部。保留现有的 isLast / 间距 / 引导轨道（leading-rail）文档：

```swift
/// Native Primer timeline item.
///
/// Content-layer row. Vertical timeline entry with a leading rail dot and
/// optional connector line. Designed for scanning: low chrome, restrained
/// borders, no glass. Polish comes from the leading-rail rhythm and
/// typography, not from material.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 3：确认无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/TimelineItem
```

预期：零匹配。

- [ ] **Step 4：跑测试和构建**

运行：

```bash
swift test --filter TimelineItemTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift
git commit -m "docs: declare TimelineItem Native Primer material/role"
```

---

## 任务 4：StatusRow Native Primer 声明

**文件：**
- 修改：`Sources/CoreDesign/Components/StatusRow/StatusRow.swift`

- [ ] **Step 1：基线现有测试**

运行：

```bash
swift test --filter StatusRowTests
```

预期：测试通过。

- [ ] **Step 2：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/StatusRow/StatusRow.swift` 中，找到 `public struct StatusRow` 上方的顶部 doc-comment，前置一段 Native Primer 头部。保留现有的 leading-icon / status-color 映射文档：

```swift
/// Native Primer status row.
///
/// Content-layer row. Status-prefixed list entry (success / warning /
/// danger / info icon + label). Color carries semantics; chrome stays
/// minimal. No glass, no cardification.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 3：确认无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/StatusRow
```

预期：零匹配。

- [ ] **Step 4：跑测试和构建**

运行：

```bash
swift test --filter StatusRowTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/StatusRow/StatusRow.swift
git commit -m "docs: declare StatusRow Native Primer material/role"
```

---

## 任务 5：BookCover Native Primer 声明

**文件：**
- 修改：`Sources/CoreDesign/Components/BookCover/BookCover.swift`

- [ ] **Step 1：基线现有测试**

运行：

```bash
swift test --filter BookCoverTests
```

预期：测试通过。

- [ ] **Step 2：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/BookCover/BookCover.swift` 中，找到 `public struct BookCover` 上方的顶部 doc-comment，前置一段 Native Primer 头部。保留现有的图像优先呈现 / 长宽比 / 占位符行为文档：

```swift
/// Native Primer book cover.
///
/// Content visual. Image-first presentation with a restrained border and a
/// small shadow — explicitly **not** glass. Aspect ratio and corner radius
/// match a print-cover read; the component stays a quiet object inside
/// content rows / grids.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 3：确认无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/BookCover
```

预期：零匹配。

- [ ] **Step 4：跑测试和构建**

运行：

```bash
swift test --filter BookCoverTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/BookCover/BookCover.swift
git commit -m "docs: declare BookCover Native Primer material/role"
```

---

## 任务 6：Phase 3B 验收

**文件：**
- 验证：任务 1–5 改动过的所有文件。

- [ ] **Step 1：跑全部测试**

运行：

```bash
swift test
```

预期：所有测试通过。

- [ ] **Step 2：跑构建**

运行：

```bash
swift build
```

预期：构建成功。

- [ ] **Step 3：确认整批内容组件无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/CommentCard Sources/CoreDesign/Components/EventRow Sources/CoreDesign/Components/TimelineItem Sources/CoreDesign/Components/StatusRow Sources/CoreDesign/Components/BookCover
```

预期：零匹配。内容层组件不使用 Liquid Glass。

- [ ] **Step 4：确认 preview 仍在**

运行：

```bash
rg "#Preview" Sources/CoreDesign/Components/CommentCard Sources/CoreDesign/Components/EventRow Sources/CoreDesign/Components/TimelineItem Sources/CoreDesign/Components/StatusRow Sources/CoreDesign/Components/BookCover
```

预期：每个组件文件至少有一个 `#Preview`。

- [ ] **Step 5：工作区干净**

运行：

```bash
git status --short
```

预期：没有未提交的改动。

---

## Handoff Notes（交接说明）

- 本阶段刻意只做文档梳理。这五个组件已经符合 Native Primer 内容层规则——
  本阶段的价值是把这种合规**显式化**、**可被 grep 命中**
  （`Material layer: content`），这样未来出现漂移时容易第一时间发现。
- 不要引入超出 doc-comment 更新之外的视觉改动。如果某个内容卡片未来需要
  视觉打磨，优先调整现有 token（间距、边框、排版），而不是加 glass——
  这是规格 §Content Components 的明确指引。
- Phase 3C 将用 `ProgressBar` / `ProgressIndicator` /
  `Avatar` / `AvatarGroup` 以及分阶段把 `EmptyState` 从推荐文档 / preview
  中下线来收尾 Phase 3。
