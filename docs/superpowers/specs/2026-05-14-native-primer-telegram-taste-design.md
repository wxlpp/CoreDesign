# Native Primer，Telegram Taste 设计

日期：2026-05-14

## 背景

CoreDesign 当前把 GitHub Primer 当作视觉北极星，但实现出来的组件并没有贴近 GitHub 在线产品的 UI 观感。同时一些部分在系统底座还没打好的情况下，就过早走向了自定义玻璃风格。

新的方向是一次完整的视觉重置：

- 用 GitHub/Primer 提供结构、信息密度与状态语义。
- 用 Apple 原生平台来承担材质、交互、无障碍与系统一致性。
- 用 Telegram 作为审美参照——克制、轻盈、浮动层与短促顺滑的动效。

这不是 GitHub 克隆，也不是 Telegram 皮肤。目标是一个 Apple 原生的设计系统，叠加 GitHub 的实用信息模型与 Telegram 的克制。

## 设计原则

### 1. 分层材质规则

CoreDesign 把 UI 切成三个材质层（material layer）。

**内容层（Content layer）**

内容组件默认不使用 Liquid Glass，包括列表行、表单、表状行、时间线内容以及普通卡片内容。它们应保持安静、易扫读、稳定。

示例：

- `ListRow`
- `Form`
- `TimelineItem` 内容
- `StatusRow`
- `EventRow`

**控件层（Control layer）**

控件使用原生纵深，而不是默认的 Liquid Glass。可以使用系统填充、分隔线边框、选中态、悬停态、按压态以及克制的阴影。它们的首要职责是清晰与可重复使用。

示例：

- `Button`
- `AsyncButton`
- `SegmentedControl`
- `SearchField`
- `SidebarRow`
- `UnderlinedTabBar`
- `Badge`
- `Tag`
- `StateLabel`

**浮动层（Floating layer）**

只有浮动 / overlay 类 UI 默认使用真正的 iOS 26 Liquid Glass。这些面位于内容之上，可以承载 Telegram 式的半透明感与运动。

示例：

- `BottomInputBar`
- 浮动图标按钮
- popover 与 menu
- `Toast`
- 浮动工具条

材质层与 surface role 是两个独立维度。材质层回答"允许多少视觉处理"；surface role 回答"应使用哪个语义化的背景/边框 token"。Surface role 可包括 `canvas`、`content`、`control`、`floating`、`overlay`，但这些不是额外的材质层。

初始映射：

| 组件族 | 材质层 | Surface role |
|---|---|---|
| 页面背景 | content | canvas |
| 行与普通内容 | content | content |
| 按钮与输入字段 | control | control |
| 导航行与 tab | control | control |
| Toast 与浮动工具条 | floating | floating |
| popover 与 menu | floating | overlay |
| 底部输入栏 | floating | floating |

### 2. 按钮默认值

`ButtonStyle.solid` 与 `ButtonStyle.light` 不应默认开玻璃。它们应当是带有 Primer 语义的实用原生控件：

- 清晰的 role 配色
- 可预期的边框
- 紧凑的密度
- 可见的 disabled 与 pressed 状态

玻璃仍然对浮动控件开放，例如 `.circularGlass`、底部输入栏的操作、以及 overlay 专属的操作。

Phase 1 验收标准：

- `SolidButtonStyle(role:glass:)` 的 `glass` 默认为 `false`。
- `LightButtonStyle(role:glass:)` 的 `glass` 默认为 `false`。
- `.solid(role:)` 与 `.light(role:)` 便捷 API 默认产出非玻璃样式。
- 既有玻璃按钮视觉仅通过显式 `glass: true` 或 `.circularGlass` 等浮层专属样式保留。

### 3. 圆角与密度

CoreDesign 要避免统一过圆、玩具化的观感。

- 内容行保持紧凑，默认不卡片化。
- 普通卡片、Banner、评论容器使用接近 8 pt 的克制圆角。
- 标准控件使用紧凑高度与中等圆角。
- 浮动表面、底部输入栏与圆形操作可以使用更大的圆角或药丸几何。

控件尺寸应当尊重 Apple 触摸人机工程，同时在安全范围内保留 GitHub 式的信息密度。

### 4. 配色策略

Primer 拥有语义命名；Apple 拥有平台渲染。

CoreDesign 应保留 primary、muted、border、canvas、success、warning、danger、selected、disabled 等语义，实际渲染应在合适的地方走平台原生，而不是机械地照搬网页 hex 值。

规则：

- 高频内容保持低饱和。
- 颜色保留给状态、选中、status 与主要操作。
- Liquid Glass 表面允许环境色与材质参与。
- 状态色保持足够明确，便于 GitHub 式的实用扫读。

### 5. 运动与交互

运动应保持短促、精准、原生：

- pressed 状态应即时且克制
- selected 状态在能改善连续性时可使用 matched geometry
- 浮动玻璃控件可以使用交互式玻璃
- 内容行应避免装饰性动画

## 组件方向

### 系统基线

在重写单个组件之前，先更新共享的视觉基元：

- 围绕 content、control、floating、overlay、canvas 重新定义 surface role
- 把原生 border、shadow、pressed、selected、glass 行为集中起来
- 把 Liquid Glass 限制在一小组显式 modifier 中
- 移除普通按钮样式的默认玻璃

### 控件

`Button` / `AsyncButton`

- 默认样式改为非玻璃的原生控件。
- `solid` 代表主操作或破坏性操作，role 语义要明确。
- `light` 代表次级操作，靠边框 / 填充划清。
- `borderless` 保持类文本、低 chrome。
- `circularGlass` 仅保留给浮动图标操作。

`SegmentedControl`

- 保持紧凑的 GitHub 式实用性。
- 使用安静的原生底座。
- 选中段可以使用轻微抬起或感知材质的 thumb，但不应让整个控件玻璃化。
- 保持短促精准的选中动效与选中反馈。

`SearchField`

- 看起来要原生且实用。
- 使用 inset / control 表面行为、清晰的焦点状态、可预期的清空操作。
- 不使用默认玻璃。

`ListRow`

- 维持在内容层。
- 默认不开玻璃、默认不卡片化。
- 在可用时使用清晰的 hover、selected、pressed 状态。

`SidebarRow` / `UnderlinedTabBar`

- 保持导航性与可扫读性。
- 选中态应当一眼可辨，但低噪音。
- 不做全局玻璃处理。

`Badge` / `Tag` / `StateLabel`

- 保持紧凑的 status 语义。
- 颜色服务于意义，而不是装饰。
- 避免重阴影与装饰性材质。

### 浮动与反馈

`Toast`

- 移到浮动层。
- 可以使用 Liquid Glass 与克制的 elevation。
- 文本保持清晰，操作保持紧凑。

`BottomInputBar`

- 仍是库中最强烈的 Telegram 式表面。
- 使用 iOS 26 Liquid Glass、分组玻璃渲染与交互式浮动操作。
- 仍应将输入体感置于视觉效果之上。

`Banner`

- 维持在内容/控件层，不走完整玻璃。
- 使用 status 语义与克制的描边或填充。

### 内容组件

`CommentCard`、`EventRow`、`TimelineItem`、`StatusRow`

- 遵循内容层规则。
- 保留密度与可读性。
- 通过间距、边框、排版、selected/hover 状态打磨观感，而不是靠玻璃。

`ProgressBar` / `ProgressIndicator`

- 保持实用的 status 可读性。
- 避免装饰性材质。

`Avatar` / `AvatarGroup`

- 保留紧凑的身份指示。
- 必要时打磨边框、重叠与对比度，但不引入玻璃。

`BookCover`

- 维持为内容视觉。
- 保持图像优先的呈现与克制的边框/阴影。

### 弃用组件

`EmptyState` 被弃用而不是视觉重置。因为它当前是公开组件，弃用必须分阶段而不是立刻移除。

理由：SwiftUI 与 UIKit 已经提供了原生的 unavailable-content 视图：

- SwiftUI `ContentUnavailableView`
- UIKit `UIContentUnavailableView`
- UIKit `UIContentUnavailableConfiguration`

CoreDesign 应停止在自定义 empty-state 视觉上投入。既有调用方应迁移到系统 unavailable-content API。如需为操作做样式，可在原生 unavailable view 中组合 CoreDesign 按钮。

弃用计划：

1. Phase 1 把 `EmptyState` API 标记为 deprecated，给出迁移到 `ContentUnavailableView` 的指引。
2. Phase 3 从 previews、组件目录与文档中移除 `EmptyState` 作为推荐组件。
3. 当前 major version 内，既有源码作为兼容包装保留。除为保持构建健康所需的修复外，不应再获得新的视觉样式。
4. 真正的移除推迟到下一次显式规划的 breaking-change 周期。

## 实施阶段

### Phase 1：系统基线

- 更新 surface role 与共享 modifier。
- 移除普通按钮样式的默认玻璃。
- 加入显式的浮动玻璃基元。
- 定义共享的 pressed、selected、hover、border、radius、shadow 规则。
- 把 `EmptyState` 标记为 deprecated 并给出迁移到原生 `ContentUnavailableView` 的指引。

### Phase 2：基础组件

- Button 与 AsyncButton
- SegmentedControl
- SearchField
- ListRow
- SidebarRow
- UnderlinedTabBar
- Badge
- Tag
- StateLabel

### Phase 3：全组件巡检

- Toast
- Banner
- CommentCard
- EventRow
- TimelineItem
- StatusRow
- ProgressBar
- ProgressIndicator
- Avatar
- AvatarGroup
- BookCover
- BottomInputBar
- 在 Phase 1 弃用之后，把 `EmptyState` 从推荐文档/preview 中移除

## 非目标

- 不机械克隆 GitHub web CSS。
- 不全局应用 Liquid Glass。
- 不把每个组件都搞成 Telegram 风。
- 不在视觉变化可保持内部的前提下引入大范围 API churn。
- 不再继续在自定义 `EmptyState` 上投入。

## 验证

每个阶段都应包含：

- 公开 API 与行为变更的 Swift 测试覆盖
- 视觉组件的 preview / snapshot 更新
- 在亮 / 暗外观下的聚焦视觉评审
- 显式检查内容层组件保持可读、低噪音
- 显式检查浮动层组件视觉可辨但不喧宾夺主

最小视觉状态矩阵：

| 组件族 | 必要状态 |
|---|---|
| buttons | default、pressed、disabled、（适用时）loading、destructive、primary、secondary |
| segmented control | default、selected、pressed、（如支持）disabled、2 项与 3+ 项布局 |
| fields | empty、filled、focused、disabled、（如支持）validation/error |
| rows/navigation | default、hover、selected、pressed、（如支持）disabled |
| badges/tags/status | 亮暗外观下的每个语义变体 |
| floating surfaces | default、appearing、disappearing、action pressed、reduce motion |
| content cards | default、长内容、紧凑宽度、暗色外观 |

无障碍与平台检查：

- Dynamic Type 在默认尺寸与至少一个更大尺寸下验证。
- 对带动画的组件开启 Reduce Motion。
- 亮暗外观。
- 接受输入的控件需做键盘 / 焦点无障碍。按平台能力验证 hover 与 focus 状态：hover 主要在 macOS 与指针化的 iPadOS 场景下，focus 在 iOS / iPadOS / macOS 的键盘驱动流程下。
- 默认值有变更时，公开 API 的默认值由测试验证，特别是 button `glass` 默认值与 `EmptyState` 弃用可用性。
