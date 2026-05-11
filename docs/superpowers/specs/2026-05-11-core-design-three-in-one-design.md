# Design Spec: CoreDesign Three-in-One (Apple + GitHub + Telegram)

## Executive Summary

CoreDesign 当前的 v2 路线图完全对齐 GitHub Primer。本 spec 替代现有 `coredesign-v2-tokens` 和 `coredesign-v2-components` 两个 PRD，引入**三合一设计语言**：Apple 系统底层 + GitHub Primer 结构骨架 + Telegram 玻璃按钮皮肤。按页面区域分 5 个 Zone 分阶段交付，目标是能用这套组件拼出完整的 GitHub PR 页面。

## Design Philosophy

```
+----------------------------------+
|  3. Telegram 皮肤                |  ← 按钮：底色 + 玻璃壳 + 细白边
|     (按钮系统)                    |
+----------------------------------+
|  2. GitHub Primer 骨架            |  ← 配色 / 表面 / 边框 / 排版 / 控件
|     (全组件共享)                  |
+----------------------------------+
|  1. Apple 底层                    |  ← systemBackground / glassEffect /
|     (背景、材质、SF 字体)          |     Dynamic Type / SF Symbols
+----------------------------------+
```

### Layer 1: Apple Foundation

- 所有 `surface*` 色优先从 Apple 系统色桥接（`systemBackground`、`systemGroupedBackground` 等），不足则新建 colorset。
- `.glassEffect()` 在浮层场景（按钮、输入栏、popover）保留，容器类组件走实色。
- SF Symbols 作为图标来源，SF Pro 通过 Dynamic Type 自动缩放。
- 组件尺寸响应 `@Environment(\.controlSize)`。

### Layer 2: GitHub Primer Skeleton

- **5 状态色 × 4 变体**：`accent`(blue) / `success`(green) / `attention`(yellow) / `danger`(red) / `done`(purple)，各有 `fg` / `emphasis` / `muted` / `subtle`。Primer 的 `neutral` 由 `FillColors` / `ContentColors` 层提供，不在 `StatusColors` 重复。
- **表面层级**：`surfaceCanvas → surfaceCanvasSubtle → surfaceCanvasInset → surfacePanel → surfaceSidebar → surfaceCard`。
- **边框驱动分隔**：`borderMuted`(1px) / `borderSubtle` / `borderEmphasis` / `borderFocus`(2px)，用线条而非阴影划分区域。
- **功能性排版**：`CoreTypography` 提供标题/正文/标签层级。
- **控件尺寸**：`CoreControlMetrics` 按 `ControlSize` 分 5 档。
- **Elevation**：`CoreElevation` 四档阴影（none/small/medium/large），暗色模式自适应。
- **Spacing / Radius / BorderWidth**：已对齐 Primer 标度。

### Layer 3: Telegram Glass Button Skin

仅应用于按钮。BottomInputBar 已验证的四层结构：

```
shape
  .inset(by: 2pt)                // InsettableShape：path 真正内缩，不撑外框
  .fill(.background)             // 底色（由 .backgroundStyle() 注入）
  .glassEffect()                 // 液态玻璃材质，view-level 应用在原始 shape 全尺寸
shape.strokeBorder(white, 0.2, 0.5pt)  // 外层细白描边（叠在 overlay）
```

抽取为 `TelegramGlassButtonModifier`，Solid / Light / CircularGlass 三个有容器的按钮样式共享。通过 `glass: Bool` 参数控制开关（默认 `true`），`false` 时退回到 Primer 实色：`shape.fill(role.color)` + `shape.strokeBorder(.borderMuted, lineWidth: CoreBorderWidth.thin)`。

## Zone Breakdown

```
Z1: 基础框架      Z2: 头部区域     Z3: 信息侧栏     Z4: 时间线        Z5: 检查状态
(token+按钮+      (StateLabel,     (AvatarGroup,    (TimelineItem,    (StatusRow)
 ProgressIndicator) RefPill)        ProgressBar,     EventRow,
                                    FlowLayout)      CommentCard)
```

| Zone | 覆盖区域 | 新增组件 | 重构/扩展 |
|------|---------|---------|----------|
| Z1 | Token 扩展 + 按钮系统重建 + 通用基础 | 1 | 2 token + 1 modifier + 4 重构 |
| Z2 | PR 头部：状态标识 + 分支引用 | 2 | — |
| Z3 | 侧栏：头像组 + 进度条 + 自动换行 | 3 | — |
| Z4 | 时间线：脊柱节点 + 事件行 + 评论卡片 | 3 | — |
| Z5 | CI 检查状态行 | 1 | — |
| **合计** | | **10 新组件** | 2 token + 1 modifier + 4 重构 |


## Z1: Foundation — Token Expansion + Button System + Generic Utility

### Z1.1 Token Expansion

**A. Five-Status-Color System (`Colors/StatusColors.swift` — expand)**

Primer 的 `neutral` 不在此处实现，由现有 `FillColors` / `ContentColors` 提供。

Each status has 4 variants: `fg` (foreground text), `emphasis` (bold background), `muted` (subtle background), `subtle` (faint background).

| Status | Accent Color | Usage |
|--------|-------------|-------|
| `accent` | blue `#0969DA` | Link, focus ring, selection |
| `success` | green `#1F883D` | Active/merged/CI pass |
| `attention` | yellow `#9A6700` | Warning/pending/review |
| `danger` | red `#CF222E` | Error/delete/blocked |
| `done` | purple `#8250DF` | Completed/closed/resolved |

Each color loads from `Resources.xcassets` colorsets with light/dark variants.

**B. Button Metrics Token (`Tokens/CoreButtonMetrics.swift` — new)**

```swift
public enum CoreButtonMetrics {
    public static let glassInset: CGFloat = 2
    public static let glassBorderOpacity: Double = 0.2
    public static let pressedScale: Double = 0.94
}
```

### Z1.2 Button System Rebuild

**Motivation**: Unify 4 existing button styles under the Telegram glass pattern. Distinction shifts from material treatment to shape and semantic intent.

**`TelegramGlassButtonModifier` (`Modifier/TelegramGlassButtonModifier.swift` — new)**

Shared glass shell modifier used by Solid, Light, and CircularGlass styles:

```swift
public struct TelegramGlassButtonModifier<S: Shape>: ViewModifier {
    public let shape: S
    public let isPressed: Bool

    public init(shape: S, isPressed: Bool) {
        self.shape = shape
        self.isPressed = isPressed
    }

    public func body(content: Content) -> some View {
        content
            .background(
                shape
                    .inset(by: CoreButtonMetrics.glassInset)
                    .fill(.background)
                    .glassEffect()
            )
            .overlay(
                shape.strokeBorder(
                    .white.opacity(CoreButtonMetrics.glassBorderOpacity),
                    lineWidth: CoreBorderWidth.hairline
                )
            )
            .scaleEffect(isPressed ? CoreButtonMetrics.pressedScale : 1)
            .animation(.snappy(duration: 0.16), value: isPressed)
    }
}
```

`S: InsettableShape` 约束是必需的：底色 path 通过 `inset(by:)` 真正内缩，而不是用
`.padding` 撑开外框；`strokeBorder` 也需要该约束。`.glassEffect()` 作为 view-level
material 修饰器，渲染在视图 frame 上（原始 shape 全尺寸），不跟随 `inset(by:)` 缩小。

**Button style matrix after rebuild:**

| Style | Shape | Semantics | Glass? | `glass` param? |
|-------|-------|-----------|--------|----------------|
| `SolidButtonStyle` | Capsule | Primary action (submit, merge) | Default yes | Yes |
| `LightButtonStyle` | Capsule | Secondary action (cancel, review) | Default yes | Yes |
| `BorderlessButtonStyle` | No container | Inline link, text action | Never | No |
| `CircularGlassButtonStyle` | Circle | Floating icon button | Always | No (name is the contract) |

**API signatures:**

```swift
extension ButtonStyle where Self == SolidButtonStyle {
    static func solid(role: ButtonRoleStyleRole, glass: Bool = true) -> Self
}

extension ButtonStyle where Self == LightButtonStyle {
    static func light(role: ButtonRoleStyleRole, glass: Bool = true) -> Self
}

extension ButtonStyle where Self == CircularGlassButtonStyle {
    static var circularGlass: CircularGlassButtonStyle
}

extension PrimitiveButtonStyle where Self == BorderlessButtonStyle {
    static var borderless: BorderlessButtonStyle
}
```

**Breaking changes:**
- `.solidButton(role:)` → `.solid(role:)` (shorter accessor name)
- `.lightButton(role:)` → `.light(role:)` (shorter accessor name)
- `SolidButtonStyle` doc comment (epic ADR #3) is overridden: Solid/Light now default to glass; the ADR's glass whitelist is replaced by the `glass:` parameter.

**File changes:**

| File | Action |
|------|--------|
| `Modifier/TelegramGlassButtonModifier.swift` | New |
| `Components/Button/styles/SolidButtonStyle.swift` | Refactor, add `glass` param |
| `Components/Button/styles/LightButtonStyle.swift` | Refactor, add `glass` param |
| `Components/Button/styles/BorderlessButtonStyle.swift` | Refactor (token migration) |
| `Components/Button/styles/CircularGlassButtonStyle.swift` | Refactor to use shared modifier |

### Z1.3 Generic Utility Component

**`ProgressIndicator` (`Components/ProgressIndicator/ProgressIndicator.swift` — new)**

Circular loading spinner. System `ProgressView()` tinted with `accent` color. Respects `@Environment(\.controlSize)`.

```swift
public struct ProgressIndicator: View {
    public init() {}
}
```

### Z1 Deliverables

| File | Type |
|------|------|
| `Colors/StatusColors.swift` | Expand (5-status × 4-variant; Primer `neutral` 由 `FillColors` / `ContentColors` 覆盖) |
| `Tokens/CoreButtonMetrics.swift` | New |
| `Modifier/TelegramGlassButtonModifier.swift` | New |
| `Components/Button/styles/SolidButtonStyle.swift` | Refactor |
| `Components/Button/styles/LightButtonStyle.swift` | Refactor |
| `Components/Button/styles/BorderlessButtonStyle.swift` | Refactor |
| `Components/Button/styles/CircularGlassButtonStyle.swift` | Refactor |
| `Components/ProgressIndicator/ProgressIndicator.swift` | New |


## Z2: Header Area — StateLabel + RefPill

### Z2.1 Components

**`StateLabel` (`Components/StateLabel/StateLabel.swift` — new)**

Status indicator pill. Large radius + colored background + optional icon + text. Color driven by enum:

```swift
public enum StateLabelStyle {
    case active      // green — in progress
    case draft       // gray — not ready
    case completed   // purple — finished
    case cancelled   // red — cancelled
}

public struct StateLabel: View {
    public init(_ style: StateLabelStyle, label: String? = nil)
}
```

Background uses the corresponding `StatusColors` emphasis color; text uses the matching foreground. Mapping from `StateLabelStyle` to `StatusColors`:

| Style Case | Status Color | SF Symbol |
|---|---|---|
| `.active` | `success` | `circle.fill` |
| `.draft` | `attention` | `circle.dashed` |
| `.completed` | `done` | `checkmark.circle.fill` |
| `.cancelled` | `danger` | `xmark.circle.fill` |

`label` defaults to the style's name (e.g., "Active", "Draft") when nil.

**`RefPill` (`Components/RefPill/RefPill.swift` — new)**

Code reference pill. Gray background (`surfaceCanvasInset`) + monospace font + `borderMuted` 1px + `CoreRadius.small`. Supports single-ref and base←head arrow display:

```swift
public struct RefPill: View {
    public init(_ ref: String)                                        // "main"
    public init(base: String, head: String)                           // "main ← feat/foo"
}
```

### Z2 Deliverables

| File | Type |
|------|------|
| `Components/StateLabel/StateLabel.swift` | New |
| `Components/RefPill/RefPill.swift` | New |


## Z3: Sidebar — AvatarGroup + ProgressBar + FlowLayout

### Z3.1 Components

**`AvatarGroup` (`Components/AvatarGroup/AvatarGroup.swift` — new)**

Stacked avatar display. First N avatars overlap; overflow shows "+N" count pill. Uses `Circle` or `RoundedRectangle` shape, respects `ControlSize`.

```swift
public struct AvatarGroup<Avatars: View>: View {
    public init(
        max: Int = 3,
        @ViewBuilder avatars: () -> Avatars
    )
}
```

Implementation: uses `Group(subviews: avatars())` (iOS 17+) to count and iterate individual subviews from the opaque `Avatars: View` type. Each subview should be `Identifiable` or assigned explicit `id` key paths for reliable diffing.

**`ProgressBar` (`Components/ProgressBar/ProgressBar.swift` — new)**

Horizontal progress bar. Gray track + colored fill + optional label and percentage.

```swift
public struct ProgressBar: View {
    public init(
        value: Double,                                    // 0.0...1.0
        tint: Color? = nil,                               // defaults to accent
        label: String? = nil                              // "3 of 5 tasks"
    )
}
```

**`FlowLayout` (`Layout/FlowLayout.swift` — new)**

Tag-wrapping container using SwiftUI `Layout` protocol. Automatic line breaking with configurable spacing.

```swift
public struct FlowLayout: Layout {
    public init(spacing: CGFloat = CoreSpacing.xs)
}
```

Used with the existing `Tag` component for label chip groups.

### Z3 Deliverables

| File | Type |
|------|------|
| `Components/AvatarGroup/AvatarGroup.swift` | New |
| `Components/ProgressBar/ProgressBar.swift` | New |
| `Layout/FlowLayout.swift` | New |


## Z4: Timeline — TimelineItem + EventRow + CommentCard

### Z4.1 Spine Architecture

`TimelineItem` provides the left spine (connection line + icon dot) and automatic indentation via `@Environment`. Content area is a generic slot — callers compose any sub-views inside.

```
 spine  │  content
────────┼─────────────────────────────
  ○     │  EventRow: "@renovate force-pushed..."
  │     │  ┌─────────────────────────┐
  │     │  │ CommentCard (minimized) │
  │     │  └─────────────────────────┘
  │     │
  ○     │  EventRow: "@evan commented..."
        │  ┌─────────────────────────┐
        │  │ CommentCard body...     │
        │  └─────────────────────────┘
```

### Z4.2 Components

**`TimelineItem` (`Components/TimelineItem/TimelineItem.swift` — new)**

Spine node container. Manages left connection line + icon dot + indentation cascade. Content slot accepts any `View`.

```swift
public struct TimelineItem<Icon: View, Content: View>: View {
    public init(
        @ViewBuilder icon: () -> Icon,
        isLast: Bool = false,
        @ViewBuilder content: () -> Content
    )
}
```

Indentation is automatic via a custom environment key (defined in `Tokens/EnvironmentKeys.swift` or co-located with `TimelineItem`):

```swift
struct TimelineDepthKey: EnvironmentKey {
    static let defaultValue: Int = 0
}
extension EnvironmentValues {
    var timelineDepth: Int {
        get { self[TimelineDepthKey.self] }
        set { self[TimelineDepthKey.self] = newValue }
    }
}
```

- `TimelineItem` reads current depth → offsets spine + content by `depth * CoreSpacing.xl`
- Sets `\.timelineDepth` to `depth + 1` for children
- Callers never pass indentation explicitly

Nesting example:
```swift
TimelineItem(icon: avatar) {                  // depth 0, auto
    CommentCard(...)
    TimelineItem(icon: smallAvatar) {          // depth 1, auto
        CommentCard(...)
    }
}
```

**`EventRow` (`Components/EventRow/EventRow.swift` — new)**

Compact single-line timeline event. Actor + action text + optional object pill + timestamp.

```swift
public struct EventRow<PillContent: View>: View {
    public init(
        actor: String,
        action: String,                   // "force-pushed", "added the label"
        timeAgo: String,
        @ViewBuilder pill: () -> PillContent  // RefPill, Tag, etc.
    )
}
```

Usage: `EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2 days ago") { RefPill("4d2040c") }`

**`CommentCard` (`Components/CommentCard/CommentCard.swift` — new)**

Full comment card inside a timeline node. Header (author + role badge + timestamp) + body slot + footer. Avatar lives in the parent `TimelineItem`'s icon slot, not in the card.

```swift
public struct CommentCard<BodyContent: View>: View {
    public init(
        author: String,
        role: String? = nil,              // "Contributor", "Bot"
        timestamp: String,
        isMinimized: Binding<Bool>? = nil, // nil = not collapsible
        @ViewBuilder content: () -> BodyContent
    )
}
```

`isMinimized` is a `Binding<Bool>` so the parent controls collapse/expand. When `nil`, the card is always expanded (no minimize button). When true, shows "This content has been minimized" + "Show" button; parent flips the binding on tap.

### Z4 Deliverables

| File | Type |
|------|------|
| `Components/TimelineItem/TimelineItem.swift` | New |
| `Components/EventRow/EventRow.swift` | New |
| `Components/CommentCard/CommentCard.swift` | New |


## Z5: CI Check Status — StatusRow

### Z5.1 Component

**`StatusRow` (`Components/StatusRow/StatusRow.swift` — new)**

CI check status line. Icon + label + duration + result indicator. Not part of timeline — flat list in a `VStack`.

```swift
public enum StatusResult {
    case success
    case failure
    case pending
    case skipped
}

public struct StatusRow: View {
    public init(
        label: String,               // "build (arm64)"
        duration: String,            // "2m 14s"
        result: StatusResult
    )
}
```

Results auto-color: success → green, failure → red, pending → yellow, skipped → gray.

### Z5 Deliverables

| File | Type |
|------|------|
| `Components/StatusRow/StatusRow.swift` | New |


## Accessibility

All components must meet baseline accessibility requirements:

| Component | Requirement |
|-----------|------------|
| `TelegramGlassButtonModifier` | Content label passes through to button; pressed state uses `.accessibilityAddTraits(.isButton)` |
| `ProgressIndicator` | `.accessibilityLabel("Loading")` when indeterminate |
| `StateLabel` | Icon is decorative by default (`Image(decorative:)`); label text serves as the accessible name |
| `RefPill` | Trait `.isStaticText`; full ref string as label |
| `AvatarGroup` | Avatars are `.accessibilityHidden(true)` (decorative); "+N" pill reads "N more" |
| `ProgressBar` | `.accessibilityValue("60% complete")` derived from value |
| `TimelineItem` | Spine line and dot are `.accessibilityHidden(true)` (structural); content slot handles its own labels |
| `EventRow` | Combines actor + action + timestamp into single `.accessibilityLabel()` |
| `CommentCard` | Minimize/expand button has `.accessibilityAction(.default, "Toggle visibility")` |
| `StatusRow` | Result icon labeled (`"Passed"`, `"Failed"`, `"Pending"`, `"Skipped"`); duration as `.accessibilityValue()` |

SwiftUI accessibility conventions:
- Decorative elements use `.accessibilityHidden(true)`
- Interactive elements use `.accessibilityElement(children: .combine)` when grouping makes sense
- Icons that convey meaning use `Image(systemName:)` with `.accessibilityLabel(_:)`; purely decorative icons use `Image(decorative:)`

## Components Not in Scope

These are explicitly excluded — use system APIs instead:

- **Divider** → system `Divider()`
- **DropdownMenu** → system `Menu`
- **EmojiReaction** → removed (not a generic design system component)
- **ChangeRow / ChangeBar** → removed (deferred)

## Naming Convention

All component names are generic design-system terms, not GitHub-specific:

| Generic Name | What It Replaces |
|-------------|-----------------|
| `StateLabel` | StatusBadge |
| `RefPill` | BranchLabel |
| `ChangeRef` | CommitRef |
| `CommentCard` | (generic comment, not PR-bound) |

## Implementation Order

Z1 → Z2 → Z3 → Z4 → Z5. Each zone produces a testable visual chunk.

## Interaction with Existing v2 PRDs

This spec **replaces** both:
- `coredesign-v2-tokens` — token system already partially implemented; expanded per Z1.1
- `coredesign-v2-components` — component refactoring scope absorbed into Z1.2 + new component additions in Z2–Z5
