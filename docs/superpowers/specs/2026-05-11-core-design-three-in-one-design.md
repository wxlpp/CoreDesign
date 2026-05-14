# 设计 Spec：CoreDesign 三合一（Apple + GitHub + Telegram）

## 执行摘要

CoreDesign 当前的 v2 路线图完全对齐 GitHub Primer。本 spec 替代现有 `coredesign-v2-tokens` 和 `coredesign-v2-components` 两个 PRD，引入**三合一设计语言**：Apple 系统底层 + GitHub Primer 结构骨架 + Telegram 玻璃按钮皮肤。按页面区域分 5 个 Zone 分阶段交付，目标是能用这套组件拼出完整的 GitHub PR 页面。

## 设计哲学

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

### Layer 1：Apple 底层

- 所有 `surface*` 色优先从 Apple 系统色桥接（`systemBackground`、`systemGroupedBackground` 等），不足则新建 colorset。
- `.glassEffect()` 在浮层场景（按钮、输入栏、popover）保留，容器类组件走实色。
- SF Symbols 作为图标来源，SF Pro 通过 Dynamic Type 自动缩放。
- 组件尺寸响应 `@Environment(\.controlSize)`。

### Layer 2：GitHub Primer 骨架

- **5 状态色 × 4 变体**：`accent`(blue) / `success`(green) / `attention`(yellow) / `danger`(red) / `done`(purple)，各有 `fg` / `emphasis` / `muted` / `subtle`。Primer 的 `neutral` 由 `FillColors` / `ContentColors` 层提供，不在 `StatusColors` 重复。
- **表面层级**：`surfaceCanvas → surfaceCanvasSubtle → surfaceCanvasInset → surfacePanel → surfaceSidebar → surfaceCard`。
- **边框驱动分隔**：`borderMuted`(1px) / `borderSubtle` / `borderEmphasis` / `borderFocus`(2px)，用线条而非阴影划分区域。
- **功能性排版**：`CoreTypography` 提供标题/正文/标签层级。
- **控件尺寸**：`CoreControlMetrics` 按 `ControlSize` 分 5 档。
- **Elevation**：`CoreElevation` 四档阴影（none/small/medium/large），暗色模式自适应。
- **Spacing / Radius / BorderWidth**：已对齐 Primer 标度。

### Layer 3：Telegram 玻璃按钮皮肤

仅应用于按钮。BottomInputBar 已验证的四层结构：

```
shape
  .inset(by: 2pt)                // InsettableShape：path 真正内缩，不撑外框
  .fill(.background)             // 底色（由 .backgroundStyle() 注入）
  .glassEffect()                 // 液态玻璃材质，view-level 应用在原始 shape 全尺寸
shape.strokeBorder(white, 0.2, 0.5pt)  // 外层细白描边（叠在 overlay）
```

抽取为 `TelegramGlassButtonModifier`，Solid / Light / CircularGlass 三个有容器的按钮样式共享。通过 `glass: Bool` 参数控制开关（默认 `true`），`false` 时退回到 Primer 实色：`shape.fill(role.color)` + `shape.strokeBorder(.borderMuted, lineWidth: CoreBorderWidth.thin)`。

## Zone 拆解

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


## Z1：基础框架 —— Token 扩展 + 按钮系统 + 通用工具

### Z1.1 Token 扩展

**A. 五状态色系统（`Colors/StatusColors.swift` —— 扩展）**

Primer 的 `neutral` 不在此处实现，由现有 `FillColors` / `ContentColors` 提供。

每个状态有 4 个变体：`fg`（前景文字）、`emphasis`（强调背景）、`muted`（柔和背景）、`subtle`（极淡背景）。

| Status | 强调色 | 用途 |
|--------|-------------|-------|
| `accent` | blue `#0969DA` | 链接、焦点环、选中 |
| `success` | green `#1F883D` | 进行中 / merged / CI 通过 |
| `attention` | yellow `#9A6700` | 警告 / 待处理 / 待审核 |
| `danger` | red `#CF222E` | 错误 / 删除 / 阻塞 |
| `done` | purple `#8250DF` | 已完成 / 已关闭 / 已解决 |

每个色都从 `Resources.xcassets` 的 colorset 加载，含亮/暗双变体。

**B. Button Metrics Token（`Tokens/CoreButtonMetrics.swift` —— 新增）**

```swift
public enum CoreButtonMetrics {
    public static let glassInset: CGFloat = 2
    public static let glassBorderOpacity: Double = 0.2
    public static let pressedScale: Double = 0.94
}
```

### Z1.2 按钮系统重建

**动机**：把现有 4 个按钮样式统一到 Telegram 玻璃模式下。区分点从材质处理转移到形状与语义意图。

**`TelegramGlassButtonModifier`（`Modifier/TelegramGlassButtonModifier.swift` —— 新增）**

共享的玻璃壳 modifier，被 Solid、Light 和 CircularGlass 三种样式复用：

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

**重建后的按钮样式矩阵：**

| Style | 形状 | 语义 | 玻璃？ | `glass` 参数？ |
|-------|-------|-----------|--------|----------------|
| `SolidButtonStyle` | Capsule | 主操作（提交、合并） | 默认是 | 是 |
| `LightButtonStyle` | Capsule | 次级操作（取消、审阅） | 默认是 | 是 |
| `BorderlessButtonStyle` | 无容器 | 内联链接、文字操作 | 从不 | 否 |
| `CircularGlassButtonStyle` | Circle | 浮动图标按钮 | 始终 | 否（名字即契约） |

**API 签名：**

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

**破坏性变更：**
- `.solidButton(role:)` → `.solid(role:)`（更短的访问名）
- `.lightButton(role:)` → `.light(role:)`（更短的访问名）
- `SolidButtonStyle` 的文档注释（epic ADR #3）被覆盖：Solid/Light 现在默认开玻璃；ADR 中的玻璃白名单被 `glass:` 参数取代。

**文件变更：**

| 文件 | 动作 |
|------|--------|
| `Modifier/TelegramGlassButtonModifier.swift` | 新增 |
| `Components/Button/styles/SolidButtonStyle.swift` | 重构，加 `glass` 参数 |
| `Components/Button/styles/LightButtonStyle.swift` | 重构，加 `glass` 参数 |
| `Components/Button/styles/BorderlessButtonStyle.swift` | 重构（token 迁移） |
| `Components/Button/styles/CircularGlassButtonStyle.swift` | 重构为使用共享 modifier |

### Z1.3 通用工具组件

**`ProgressIndicator`（`Components/ProgressIndicator/ProgressIndicator.swift` —— 新增）**

圆形 loading spinner。用 `accent` 色染色的系统 `ProgressView()`。响应 `@Environment(\.controlSize)`。

```swift
public struct ProgressIndicator: View {
    public init() {}
}
```

### Z1 交付物

| 文件 | 类型 |
|------|------|
| `Colors/StatusColors.swift` | 扩展（5 状态 × 4 变体；Primer `neutral` 由 `FillColors` / `ContentColors` 覆盖） |
| `Tokens/CoreButtonMetrics.swift` | 新增 |
| `Modifier/TelegramGlassButtonModifier.swift` | 新增 |
| `Components/Button/styles/SolidButtonStyle.swift` | 重构 |
| `Components/Button/styles/LightButtonStyle.swift` | 重构 |
| `Components/Button/styles/BorderlessButtonStyle.swift` | 重构 |
| `Components/Button/styles/CircularGlassButtonStyle.swift` | 重构 |
| `Components/ProgressIndicator/ProgressIndicator.swift` | 新增 |


## Z2：头部区域 —— StateLabel + RefPill

### Z2.1 组件

**`StateLabel`（`Components/StateLabel/StateLabel.swift` —— 新增）**

状态指示药丸。大圆角 + 彩色背景 + 可选图标 + 文字。颜色由枚举驱动：

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

背景使用对应 `StatusColors` 的 emphasis 色；文字使用对应前景色。`StateLabelStyle` 到 `StatusColors` 的映射：

| Style Case | Status Color | SF Symbol |
|---|---|---|
| `.active` | `success` | `circle.fill` |
| `.draft` | `attention` | `circle.dashed` |
| `.completed` | `done` | `checkmark.circle.fill` |
| `.cancelled` | `danger` | `xmark.circle.fill` |

`label` 为 nil 时默认为 style 名称（如 "Active"、"Draft"）。

**`RefPill`（`Components/RefPill/RefPill.swift` —— 新增）**

代码引用药丸。灰底（`surfaceCanvasInset`）+ 等宽字体 + `borderMuted` 1px + `CoreRadius.small`。支持单引用和 base←head 箭头展示：

```swift
public struct RefPill: View {
    public init(_ ref: String)                                        // "main"
    public init(base: String, head: String)                           // "main ← feat/foo"
}
```

### Z2 交付物

| 文件 | 类型 |
|------|------|
| `Components/StateLabel/StateLabel.swift` | 新增 |
| `Components/RefPill/RefPill.swift` | 新增 |


## Z3：侧栏 —— AvatarGroup + ProgressBar + FlowLayout

### Z3.1 组件

**`AvatarGroup`（`Components/AvatarGroup/AvatarGroup.swift` —— 新增）**

堆叠头像展示。前 N 个头像重叠；溢出展示 "+N" 计数药丸。使用 `Circle` 或 `RoundedRectangle` 形状，响应 `ControlSize`。

```swift
public struct AvatarGroup<Avatars: View>: View {
    public init(
        max: Int = 3,
        @ViewBuilder avatars: () -> Avatars
    )
}
```

实现：用 `Group(subviews: avatars())`（iOS 17+）从不透明的 `Avatars: View` 类型中数出并迭代单个 subview。每个 subview 应该是 `Identifiable` 或显式指定 `id` key path 以保证 diff 稳定。

**`ProgressBar`（`Components/ProgressBar/ProgressBar.swift` —— 新增）**

横向进度条。灰色轨道 + 彩色填充 + 可选 label 与百分比。

```swift
public struct ProgressBar: View {
    public init(
        value: Double,                                    // 0.0...1.0
        tint: Color? = nil,                               // defaults to accent
        label: String? = nil                              // "3 of 5 tasks"
    )
}
```

**`FlowLayout`（`Layout/FlowLayout.swift` —— 新增）**

使用 SwiftUI `Layout` 协议的标签换行容器。自动换行 + 可配置间距。

```swift
public struct FlowLayout: Layout {
    public init(spacing: CGFloat = CoreSpacing.xs)
}
```

与现有 `Tag` 组件配合用于标签 chip 组。

### Z3 交付物

| 文件 | 类型 |
|------|------|
| `Components/AvatarGroup/AvatarGroup.swift` | 新增 |
| `Components/ProgressBar/ProgressBar.swift` | 新增 |
| `Layout/FlowLayout.swift` | 新增 |


## Z4：时间线 —— TimelineItem + EventRow + CommentCard

### Z4.1 脊柱架构

`TimelineItem` 提供左侧脊柱（连接线 + 图标点）以及通过 `@Environment` 实现的自动缩进。内容区是个泛型槽 —— 调用方在里面随意组合任意子视图。

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

### Z4.2 组件

**`TimelineItem`（`Components/TimelineItem/TimelineItem.swift` —— 新增）**

脊柱节点容器。管理左侧连接线 + 图标点 + 缩进级联。内容槽接受任意 `View`。

```swift
public struct TimelineItem<Icon: View, Content: View>: View {
    public init(
        @ViewBuilder icon: () -> Icon,
        isLast: Bool = false,
        @ViewBuilder content: () -> Content
    )
}
```

缩进通过自定义 environment key 自动完成（定义在 `Tokens/EnvironmentKeys.swift` 或与 `TimelineItem` 同文件）：

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

- `TimelineItem` 读取当前深度 → 将脊柱与内容向右偏移 `depth * CoreSpacing.xl`
- 给子视图设置 `\.timelineDepth` 为 `depth + 1`
- 调用方无须显式传缩进

嵌套示例：
```swift
TimelineItem(icon: avatar) {                  // depth 0, auto
    CommentCard(...)
    TimelineItem(icon: smallAvatar) {          // depth 1, auto
        CommentCard(...)
    }
}
```

**`EventRow`（`Components/EventRow/EventRow.swift` —— 新增）**

紧凑的单行时间线事件。Actor + action 文本 + 可选对象药丸 + 时间戳。

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

用法：`EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2 days ago") { RefPill("4d2040c") }`

**`CommentCard`（`Components/CommentCard/CommentCard.swift` —— 新增）**

时间线节点内的完整评论卡片。Header（作者 + 角色 badge + 时间戳）+ body 槽 + footer。头像在父级 `TimelineItem` 的 icon 槽中，不放在卡内。

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

`isMinimized` 是 `Binding<Bool>`，由父级控制折叠/展开。为 `nil` 时卡片始终展开（无最小化按钮）。为 true 时显示 "This content has been minimized" + "Show" 按钮；父级在点击时翻转 binding。

### Z4 交付物

| 文件 | 类型 |
|------|------|
| `Components/TimelineItem/TimelineItem.swift` | 新增 |
| `Components/EventRow/EventRow.swift` | 新增 |
| `Components/CommentCard/CommentCard.swift` | 新增 |


## Z5：CI 检查状态 —— StatusRow

### Z5.1 组件

**`StatusRow`（`Components/StatusRow/StatusRow.swift` —— 新增）**

CI 检查状态行。图标 + 标签 + 时长 + 结果指示。不属于时间线 —— 在 `VStack` 中扁平列出。

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

结果自动配色：success → 绿，failure → 红，pending → 黄，skipped → 灰。

### Z5 交付物

| 文件 | 类型 |
|------|------|
| `Components/StatusRow/StatusRow.swift` | 新增 |


## 无障碍

所有组件都必须满足基线无障碍要求：

| 组件 | 要求 |
|-----------|------------|
| `TelegramGlassButtonModifier` | Modifier 不接管可访问性——外层 `Button` 自带 `.isButton` trait，label 由 `configuration.label` 透传 |
| `ProgressIndicator` | 不确定态时 `.accessibilityLabel("Loading")` |
| `StateLabel` | `.accessibilityElement(children: .combine)` + `.accessibilityLabel(label)`——文字作为可访问名，SF Symbol icon 由 combine 吸收为纯装饰 |
| `RefPill` | Trait `.isStaticText`；单引用读 ref 字符串、双引用读 `"<base> from <head>"` |
| `AvatarGroup` | 头像设为 `.accessibilityHidden(true)`（装饰性）；"+N" 药丸读 "N more" |
| `ProgressBar` | `.accessibilityLabel(label ?? "Progress")` + `.accessibilityValue("<percent>% complete")` |
| `TimelineItem` | 脊柱线和点设为 `.accessibilityHidden(true)`（结构性）；内容槽自行处理 label |
| `EventRow` | `.accessibilityElement(children: .combine)` 不覆盖 label——让子视图（actor / action / pill / timeAgo）的 a11y 文本自动合并，Tag / RefPill 的 label 自然纳入 |
| `CommentCard` | 整卡 `.accessibilityElement(children: .contain)` + `accessibilityLabel("Comment by <author>")`；最小化态的 "Show" 按钮自带 `.accessibilityLabel("Show minimized comment")` + `.accessibilityHint("Expands the comment from <author>")` |
| `StatusRow` | `.accessibilityLabel(label)` + `.accessibilityValue("<result>, <duration>")`——label 读 step name，value 读结果与时长 |

SwiftUI 无障碍约定：
- 装饰性元素用 `.accessibilityHidden(true)`
- 适合分组的交互元素用 `.accessibilityElement(children: .combine)`
- 承载语义的图标用 `Image(systemName:)` + `.accessibilityLabel(_:)`；纯装饰的图标用 `Image(decorative:)`

## 不在范围内的组件

明确排除 —— 使用系统 API 代替：

- **Divider** → 系统 `Divider()`
- **DropdownMenu** → 系统 `Menu`
- **EmojiReaction** → 移除（不是通用设计系统组件）
- **ChangeRow / ChangeBar** → 移除（暂缓）

## 命名约定

所有组件名都使用通用设计系统术语，不绑定 GitHub：

| 通用名 | 取代的名字 |
|-------------|-----------------|
| `StateLabel` | StatusBadge |
| `RefPill` | BranchLabel |
| `ChangeRef` | CommitRef |
| `CommentCard` | （通用评论，不绑定 PR） |

## 实施顺序

Z1 → Z2 → Z3 → Z4 → Z5。每个 zone 产出一个可视觉验证的块。

## 与现有 v2 PRD 的关系

本 spec **取代**以下两份：
- `coredesign-v2-tokens` —— token 系统已部分实现；按 Z1.1 扩展
- `coredesign-v2-components` —— 组件重构范围合并到 Z1.2 + Z2–Z5 的新组件
