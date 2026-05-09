---
name: coredesign-v2-components
description: 把 CoreDesign 现有 14 个组件按 v2-tokens 重构（去魔法数字、按 Primer 化），并新增 7 个 GitHub 风格 chrome 组件（Badge/Tag/SearchField/ListRow/SidebarRow/EmptyState/Toast）；本 PRD 在 structure 阶段拆为 2 个独立 epic
status: backlog
created: 2026-05-09T21:25:28Z
---

# PRD: coredesign-v2-components

## Executive Summary

`coredesign-v2-tokens` epic 已上 main，提供了 6 类 token、14 个语义色补全、`FocusRingModifier` / `SurfaceModifier`、`BorderModifier` canary 迁移以及 `Color.focusRing → borderFocus` 重命名。本 PRD 兑现 v2-tokens 预留的下游承诺：

1. **重构 14 个现有组件**——把 `EdgeInsets(top: 6, leading: 12, ...)`、`cornerRadius: 9`、`lineWidth: 0.8`、`.font(.subheadline)` 这类散落字面量全部归零，改走 `CoreSpacing.*` / `CoreRadius.*` / `CoreBorderWidth.*` / `CoreTypography.*` / `CoreControlMetrics.*(for: controlSize)`，按 Primer 视觉语言收齐。
2. **新增 7 个 GitHub chrome 组件**——补齐目前缺失的基础 surface：`Badge` / `Tag` / `SearchField` / `ListRow` / `SidebarRow` / `EmptyState` / `Toast`。

**不动 any-writer**——any-writer 切换到 v2 视觉是独立的下游 epic。本 PRD 在 structure 阶段**拆为 2 个独立 epic**（`coredesign-v2-components-existing` 与 `coredesign-v2-components-new`），原因详见 §Estimated Effort & Epic Split。

## Problem Statement

**为什么现在做？**

1. **token 已上 main 但无人引用，价值未兑现**——v2-tokens epic 写完之后，主仓 14 个组件没有一个用到 `CoreSpacing` / `CoreRadius` / `CoreBorderWidth` / `CoreTypography` / `CoreControlMetrics`（除了 `BorderModifier` canary）。token 抽象只有在被广泛消费时才有价值，否则就是死代码。
2. **现有组件视觉骨架不齐**——14 个组件分别由不同时期的代码堆积而成：
   - `SolidButtonStyle.swift:42` 内联 5 个 controlSize 的 `EdgeInsets`
   - `LightButtonStyle.swift:38` `lineWidth: 0.8` + 阴影 radius/y 的字面量
   - `SegmentedControl.swift:29` `cornerRadius: 9` + `height: 32` + thumb 圆角各自独立
   - `Banner.swift` `.padding()` 无尺寸控制
   - `Form.swift` icon 尺寸 `font(.system(size: 26))` 字面量
   - `BottomInputBar.swift` 多处 `padding(.horizontal, 12)` / `padding(.vertical, 8)` 字面量
3. **GitHub 风格 chrome 缺口**——any-writer 等下游应用要做 issue 列表 / 章节大纲 / 角色卡 / 评论侧栏 / 设置页时，需要 GitHub 风格的 `Badge` / `Tag` / `ListRow` / `SidebarRow` / `EmptyState` / `Toast` / `SearchField`，目前都没有。
4. **预存 build 错误占位**——`MenuButton.swift` 在 iOS 上的 `UIImpactFeedbackGenerator` main-actor 错误（v2-tokens issue #9 agent 在跨平台编译时发现）至今未修；本 epic 重构 BottomInputBar 时顺便清掉。

**不做会怎样？** v2-tokens 的 abstraction 形同虚设；下游应用继续在 BottomInputBar 之外的位置自己拼 ad-hoc UI；GitHub 视觉骨架的核心 chrome 长期缺失，CoreDesign 离"可发布的设计系统"越来越远。

## User Stories

### US-1: 设计系统维护者（=本人）

**作为** CoreDesign 维护者
**我想要** 14 个现有组件全部走 token、零散落字面量
**以便** 后续按 Primer 调整视觉时只需要改 token 文件，组件不必逐一重写

**验收标准：**
- `Sources/CoreDesign/Components/` 下任一 swift 文件 `grep -E '\.padding\([^,)]*[0-9]+|cornerRadius:\s*[0-9]+|lineWidth:\s*[0-9.]+|font\(\.system\(size:\s*[0-9]+'` ≤ 5 个匹配（残留只能在 #Preview / 文档字面量、或与 Primer 不直接对齐的视觉细节中）
- 14 个组件全部能通过 `swift build -Xswiftc -warnings-as-errors`
- 视觉抽查：light / dark 双 colorScheme 在 `#Preview` 下表现正常

### US-2: any-writer 等下游消费者

**作为** any-writer 的开发者
**我想要** GitHub 风格的 `Badge` / `Tag` / `ListRow` / `SidebarRow` / `EmptyState` / `SearchField` / `Toast`
**以便** issue 列表、章节大纲、角色卡、评论侧栏、设置页这些场景不再需要在 any-writer 仓自己拼 UI

**验收标准：**
- 7 个新组件都暴露为 public Swift API，命名一致（动名词或名词形式，不含 `New` / `V2` 等版本后缀）
- 每个组件至少有 1 个 `#Preview` 演示主要交互态

（doc-comment 内容质量是文档治理要求——使用场景、关键参数、Primer 概念对应、light/dark 差异——已挪到 §Non-Functional Requirements，避免与功能验收混在一起。）

### US-3: 跨平台 / 玻璃材质策略

**作为** CoreDesign 维护者 + 下游开发者
**我想要** `.glassEffect` 仅保留在"漂浮在内容上方"的场景（BottomInputBar、popover、dropdown menu、context menu 等），不出现在容器类组件上
**以便** Primer 视觉语言的 1px 硬边框 + 实色填充能在桌面密度场景下落地

**验收标准：**
- `BottomInputBar` 输入栏自身保留 `.glassEffect`（这是它的视觉特点）
- `MenuButton` 内的 suggestion pill / shuffle 浮按钮保留 `.glassEffect`（也是浮层 UI，与输入栏共属同一 popover-style 场景）
- `CircularGlassButtonStyle` 保留 glass（命名也提示其语义）
- `Banner` / `ListRow` / `SidebarRow` 等容器类组件**不**使用 `.glassEffect`，改走 `View.surface(_:)` modifier（其中 `.panel` / `.card` 这两个 `SurfaceKind` 已经在 v2-tokens 阶段由 `SurfaceModifier.swift` 提供——它们是 modifier kind，不是本 PRD 待交付的独立组件）
- `LightButtonStyle` 在亮色模式下当前的 `glassEffect` 退出，统一走柔和阴影或纯色按钮
- 完成后 `grep glassEffect` 命中只能在以下白名单文件出现：`BottomInputBar.swift` / `MenuButton.swift` / `CircularGlassButtonStyle.swift` + `BottomInputBarSuggestionsView` 的 suggestion chip 处

### US-4: 修复 BottomInputBar pre-existing build 错误

**作为** CoreDesign 维护者
**我想要** 现有 `MenuButton.swift` 在 iOS 上的 `UIImpactFeedbackGenerator` main-actor 错误（v2-tokens issue #9 agent 发现）被修复
**以便** iOS 平台上 CoreDesign 能在 Swift 6 strict concurrency 下完整编译通过

**验收标准：**
- `swift build -Xswiftc -warnings-as-errors --triple arm64-apple-ios26.0-simulator` 通过 0 warning（与 macOS 编译同步；纯 SPM 路径，与 SC#5 / Assumptions 一致——**不**用 `xcodebuild`）
- 修复方式合理：要么把 feedback 调用移到 `@MainActor` 上下文、要么用 `Task { @MainActor in ... }` 隔离、要么去掉这一处 feedback（如果不是关键交互）

## Functional Requirements

### Phase A: 现有组件 token 化重构（v2-components-existing epic）

每个 FR 的目标统一为：去除魔法数字、按 v2-tokens 重写、保持公开 API 不变（除非必要）、保留 / 调整 `.glassEffect` 按 §US-3 策略。

**Phase A 涵盖的现有组件清单**（共 **13 个**真正的 component swift 文件，分布在 `Sources/CoreDesign/Components/` 下）：

| # | 文件 | FR |
|---|---|---|
| 1 | `Button/styles/SolidButtonStyle.swift` | FR-A-1 |
| 2 | `Button/styles/LightButtonStyle.swift` | FR-A-1 |
| 3 | `Button/styles/BorderlessButtonStyle.swift` | FR-A-1 |
| 4 | `Button/styles/CircularGlassButtonStyle.swift` | FR-A-1 |
| 5 | `Banner.swift` | FR-A-2 |
| 6 | `SegmentedControl/SegmentedControl.swift` | FR-A-3 |
| 7 | `TabBar/UnderlinedTabBar.swift` | FR-A-4 |
| 8 | `Form/Form.swift`（含 `LabelIcon` / `ChevronRightIcon` / `DangerIcon`） | FR-A-5 |
| 9 | `BottomInputBar/BottomInputBar.swift` | FR-A-6 |
| 10 | `BottomInputBar/MenuButton.swift`（含 iOS build 错误修复） | FR-A-6 |
| 11 | `BookCover/BookCover.swift` | FR-A-7 |
| 12 | `Avatar/Avatar.swift` | FR-A-8 |
| 13 | `CheckBox/CheckBox.swift` | FR-A-9 |

**`Button/ButtonRoleStyleRole.swift` 不在本表**——它是支撑 Button styles 的 `enum`（不是 component，无 view body、无 #Preview 需求）。FR-A-1 实施时 if 颜色映射需按 v2 语义色调整，**顺带**修改即可，不作为独立交付项计数。

加上 7 个新组件（FR-B-1~B-7），合计 **20 个 component**，对应 SC#6 的 "20 个组件全部 #Preview"。

**FR-A-1: 4 个 Button styles 重构**
- `SolidButtonStyle` / `LightButtonStyle` / `BorderlessButtonStyle` / `CircularGlassButtonStyle`
- `EdgeInsets` 表替换为 `CoreControlMetrics.horizontalPadding(for:)` + `verticalPadding(for:)`
- 字号替换为 `CoreControlMetrics.font(for:)`
- `cornerRadius` 替换为 `CoreRadius.full`（capsule）或 `CoreRadius.medium`（rounded rect）
- `lineWidth: 0.8` 等子像素值替换为 `CoreBorderWidth.hairline`
- 阴影替换为 `CoreElevation.spec(for:)` 或 `View.coreShadow(_:)`
- glass 策略：`SolidButtonStyle` 去 glass（按 Primer 实色按钮）；`LightButtonStyle` 亮色去 glass + 暗色保留；`BorderlessButtonStyle` 不带视觉容器；`CircularGlassButtonStyle` 保留 glass（其命名即语义）

**FR-A-2: Banner 重构**
- `PlainBannerStyle` / `BorderedBannerStyle` 全部走 token
- 不使用 `.glassEffect`（基础容器）
- 改用 `Color.surfaceCanvas` / `surfaceCanvasSubtle` + `Color.borderMuted` + `CoreRadius.medium`
- 配色按 `MessageLevel` 仍用 `infoBackground` / `warningBackground` / `dangerBackground` / `successBackground`，但其底层取值与 Primer 对齐

**FR-A-3: SegmentedControl 重构**
- `cornerRadius: 9` / `height: 32` / `cornerRadius: 7` 全部走 token（外框 `CoreRadius.medium` + thumb `CoreRadius.small`，高度 `CoreControlMetrics.height(for:)`）
- thumb 阴影用 `CoreElevation.small`
- 不使用 `.glassEffect`

**FR-A-4: UnderlinedTabBar 重构**
- 字号 / underline 厚度 / spacing 全部 token 化
- 不使用 `.glassEffect`

**FR-A-5: Form / LabelIcon / DangerIcon 重构**
- `font(.system(size: 26))` icon 用 `CoreControlMetrics.iconSize(for:)` 或 token 化
- 容器走 `View.surface(.panel)` 而非散字面量

**FR-A-6: BottomInputBar / MenuButton 重构 + 修 build 错误**
- 输入栏自身保留 `.glassEffect`（per US-3）
- padding / spacing / cornerRadius 全部 token 化
- **修复 `MenuButton.swift` 在 iOS 上的 `UIImpactFeedbackGenerator` main-actor 错误**（per US-4）
- 验证：iOS Simulator + macOS 双平台编译通过

**FR-A-7: BookCover 重构**
- `cornerRadius: 8` / `lineWidth: 0.5` / 阴影参数全部 token 化（cornerRadius → `CoreRadius.large`，lineWidth → `CoreBorderWidth.hairline`，阴影 → `CoreElevation.medium`）

**FR-A-8: Avatar 重构**
- 圆角、字号、padding 全部 token 化

**FR-A-9: CheckBox 重构**
- icon 尺寸 token 化；间距走 `CoreSpacing.*`

### Phase B: 新增 7 个组件（v2-components-new epic）

**FR-B-1: Badge**
- `public struct Badge<Label: View>: View`
- **API 形态**：单结构体 + `BadgeVariant` 枚举参数化（**不引入 BadgeStyle 协议**——Badge 只是 5 固定 level 颜色变化，不需要 Banner 那种结构性差异；参考 Primer `Label` 组件也是 parametric 不带 style 协议）
- `BadgeVariant` 枚举：`.info` / `.success` / `.warning` / `.danger` / `.neutral`
- 使用 `surfaceCanvasSubtle` 背景 + `borderMuted` 边框 + `CoreRadius.full`
- 字号 `CoreTypography.bodySmallFont` + `bodySmallTracking`（直接复用 typography token，不引入新 tracking 字面量）
- 可选 `outlined: Bool = false` 参数控制是否带边框

**FR-B-2: Tag**
- `public struct Tag<Label: View>: View`
- 与 Badge 区分：Tag 用于**任意分类**（GitHub issue labels 风格），Badge 用于**状态**
- 颜色由调用方传入（不固定 5 个 level），背景透明度由 token 决定
- `CoreRadius.small` 圆角（小于 Badge 的 full）
- 可附 `removable: Bool` 行为，配 `xmark.circle.fill` 系统图标

**FR-B-3: SearchField**
- `public struct SearchField: View`
- `magnifyingglass` icon 前缀 + `xmark.circle.fill` clear button
- `surfaceCanvasInset` 背景 + `borderMuted` 边框 + `CoreRadius.medium`
- 配 `CoreControlMetrics.height(for:)` 高度
- 暴露 `@Binding var text: String` + `placeholder: String` + `onSubmit: (String) -> Void`
- 支持 `.focusRing(visible:)`（focused 状态显示焦点环）

**FR-B-4: ListRow**
- `public struct ListRow<Leading: View, Trailing: View, Label: View>: View`
- 三块布局：leading（icon / avatar）+ label（标题 + 副标题）+ trailing（chevron / accessory）
- **API 易用性**：必须提供 `where Leading == EmptyView` / `where Trailing == EmptyView` / 双 EmptyView 的 convenience init，让调用方在不需要 leading/trailing 时不必显式写 `EmptyView`（避免 `ListRow<EmptyView, EmptyView, Text>` 这类 noisy 类型签名）
- 用 `View.surface(.canvas)` 背景，hover 态直接用 `surfaceCanvasSubtle`。**注意**：仓内已有 `Color.hoverBackground`（`InteractionColors.swift:30`，当前实现 = `.secondaryFill` 系统色），语义上是更准的 hover token，但其取值是系统 fill **未对齐 Primer `canvas.subtle`** 的视觉。本 epic 故意绕过 `hoverBackground` 直接用 `surfaceCanvasSubtle` 来命中 Primer 视觉北极星——这是**取值层面**的取舍，不是 "token 不存在" 的代偿。详见 §Notes 的 hover token debt
- 字号用 `CoreTypography.bodyMediumFont`（标题）+ `bodySmallFont` + `contentMuted`（副标题）
- 高度按 `CoreControlMetrics.height(for: .regular)` 或自适应内容

**FR-B-5: SidebarRow**
- `public struct SidebarRow<Label: View>: View`
- 选中态用 `surfaceCanvasSubtle` 背景 + 左侧 `CoreBorderWidth.thick`（2pt）accent 条 + 颜色 `borderFocus`（per GitHub 桌面客户端 UI；token 引用而非字面量 2）
- 非选中态透明背景，hover 态用 `surfaceCanvasSubtle`（同 FR-B-4 取舍：`Color.hoverBackground` 已存在但取值未对齐 Primer，故本 epic 直接用 `surfaceCanvasSubtle`；详见 §Notes）
- 字号 `CoreTypography.bodyMediumFont`
- 高度紧凑：`CoreControlMetrics.height(for: .small)`

**FR-B-6: EmptyState**
- `public struct EmptyState<Action: View>: View`
- 居中布局：`Image` icon + `Text` title + `Text` description + 可选 action button
- 用 `CoreSpacing.lg` / `xl` 间距
- 字号 `CoreTypography.titleMediumFont`（title）+ `bodyMediumFont` + `contentMuted`（description）
- icon 尺寸 48 / 64pt（**用 `CoreSpacing.xxxxl` (48) 或 `CoreSpacing.huge` (64)**——注意不是 `xxxl` (40) / `xxxxl` (48)）

**FR-B-7: Toast**

API 形态：**scene-scoped `ToastHost` + `EnvironmentValues` 注入**（参 `Banner.swift` 已有的 `bannerStyle` 注入模式，每个 scene 一个独立实例；不引入库级 singleton）。详细签名：

```swift
/// scene-scoped toast 状态容器。每个 scene root 用 `View.toastHost(edge:)`
/// modifier 创建一个实例，通过 `EnvironmentValues` 注入到子 view 树。
/// 子 view 通过 `@Environment(\.toastHost)` 拿到实例，调 `.show(...)` 触发。
@MainActor
@Observable
public final class ToastHost {
    public init()
    public func show(_ message: String, level: ToastLevel = .info, duration: TimeInterval = 3)
    public func show(_ item: ToastItem)
    public func dismiss(_ id: ToastItem.ID)
}

public struct ToastItem: Identifiable, Sendable {
    public let id: UUID
    public let message: String
    public let level: ToastLevel
    public let duration: TimeInterval

    public init(message: String, level: ToastLevel = .info, duration: TimeInterval = 3)
}

public enum ToastLevel: Sendable { case info, success, warning, danger }

extension EnvironmentValues {
    /// scene 内的 toast host；nil 表示当前 scene root 还没挂 `toastHost(edge:)` modifier
    /// （此时调用 `.show(...)` 是 no-op + debug warning）。
    @Entry public var toastHost: ToastHost? = nil
}

public extension View {
    /// 在 scene root（NavigationStack / TabView 之上）调用一次：
    /// (1) 创建一个 ToastHost 实例并 inject 到 EnvironmentValues；
    /// (2) 用 `safeAreaInset(edge:)` 在指定边渲染当前 toast。
    /// 子 view 用 `@Environment(\.toastHost) var toast` 拿到实例后调 `.show(...)`。
    func toastHost(edge: VerticalEdge = .top) -> some View
}
```

**调用方写法示例**：

```swift
// Scene root (App / ContentView):
WindowGroup {
    ContentView()
        .toastHost(edge: .top)  // 一次性挂载 + 注入
}

// 任意子 view:
struct EditorView: View {
    @Environment(\.toastHost) private var toast

    var body: some View {
        Button("保存") {
            self.save()
            self.toast?.show("保存成功", level: .success)
        }
    }
}
```

**关键设计点**（实现 PR 必须明确说明）：

- **scene-scoped 而非 singleton**：每个 `WindowGroup` / `Scene` / 独立 window 一个 `ToastHost` 实例，多 window 之间状态隔离，符合 iOS / macOS 26+ 多 scene 模型
- **Swift 6 strict concurrency**：`@MainActor @Observable final class`；所有 mutating method 都在 main actor 上下文；不需要 `Sendable` 显式约束（@MainActor 已隐式提供安全性）
- **z-order 范围有限**：`safeAreaInset` 仅在挂 `toastHost(edge:)` 的那层 view 树内可见——**不覆盖** sheet / fullScreenCover / 独立 window。**这是显式约束**，调用方需要在每个 sheet root 单独挂 `.toastHost(...)` 才能在 sheet 内触发 toast
- **Queue 语义**（必须按这套写）：
  - `[ToastItem]` 内部队列；同时间只渲染 1 条 toast
  - `duration` 计时从 toast **开始显示** 那一刻起算，不是 enqueue
  - `show(_:)` 触发的 toast 进入队列尾；若队列空且无正在显示的 toast，立即开始显示
  - `dismiss(id)` 对**排队中**的 item 直接从队列移除；对**正在显示**的 item 立即触发 dismiss 动画（dismiss 完成后渲染下一条）
  - 当前 toast 正在 dismiss 动画中时，新 `show(...)` 进来 **append** 到队列（不打断当前 dismiss、不 replace）
- **视觉**：用 `View.surface(.card)` + `View.coreShadow(.medium)` + `CoreTypography.bodyMediumFont`，按 `ToastLevel` 配 icon（`info.circle` / `checkmark.circle` / `exclamationmark.triangle` / `exclamationmark.octagon`）+ 配色（`infoForeground` 等）
- **dismiss 触发**：自动消失（按 `duration`）+ 向 edge 方向滑动手势 + 点击 toast 自身立即 dismiss
- **不做** custom view payload（`ToastItem` 仅含 `message: String`）——本 epic 只覆盖文本 toast，custom-content 留给后续 epic

## Non-Functional Requirements

- 全部新增 / 改动 API 必须 `public`（含 init）
- Swift 6 strict concurrency 下零 warning 通过 `swift build -Xswiftc -warnings-as-errors` + `swift test`
- iOS 26+ / macOS 26+ 部署目标不变
- **token-clean 约束**：本 epic 范围内**任何**组件文件（含新增 `Sources/CoreDesign/Components/{Badge,Tag,SearchField,ListRow,SidebarRow,EmptyState,Toast}/` 各 .swift + 重构后的 13 个现有 component .swift）的 production 代码（非 `#Preview` 块）**不得**引入新的 magic numbers——padding / cornerRadius / lineWidth / EdgeInsets / height / width / shadow radius 全部必须通过 `CoreSpacing.*` / `CoreRadius.*` / `CoreBorderWidth.*` / `CoreTypography.*` / `CoreElevation.*` / `CoreControlMetrics.*` 引用。**这是 NFR 级硬约束**——SC#1 的差异化 grep 是该约束在 13 个目标文件上的可机器验证落地；新组件文件依靠这条 NFR 约束 + code review 自然规避，不在 SC#1 grep 命中阈值内
- 所有视觉走 light/dark adaptive（要么用 system color 桥接、要么用 `Resources.xcassets` 中的 colorset）
- 所有组件至少有 1 个 `#Preview`，覆盖关键状态
- **doc-comment 文档治理**（每个新组件 + 每个被重构的现有组件的 public API 表面）：
  - 使用场景与定位（与同类组件的差异）
  - 关键参数语义（特别是 enum case 的语义，如 `BadgeVariant.warning` vs `.danger` 的区别）
  - 与 Primer 概念对应（譬如 "对应 Primer `Label` 组件"）
  - light / dark 行为差异（如果有）
- 双语注释（中文 + 英文 `// MARK: -`）保持仓库现有风格
- 显式 `self.`、bundle: .module 资源加载等仓库约定保持不变

## Success Criteria

可机器验证的退出标准：

1. **本 epic 触达文件的魔法数字归零**——按 FR-A-1 ~ FR-A-9 列出的 13 个文件，**逐文件**跑下面三条 grep，对**每个**目标文件命中数都必须为 0（排除 `#Preview` 块内的 demo 字面量）。这是**差异化校验**，不是全仓总量校验，避免被无关残留绊住：

   ```bash
   # 对 13 个 FR-A 目标文件中的每一个 $F：
   grep -E '\.padding\([0-9]|cornerRadius:\s*[0-9]+|lineWidth:\s*[0-9.]+|font\(\.system\(size:\s*[0-9]+' "$F" | grep -v '#Preview'
   grep -E '\.padding\(\.[a-z]+,\s*[0-9]+' "$F" | grep -v '#Preview'
   grep -E 'EdgeInsets\(top:|\b(height|width):\s*[0-9]+|radius:\s*[0-9.]+,\s*x:|shadow\(.*radius:\s*[0-9]+' "$F" | grep -v '#Preview'
   ```

   三条都对每个目标文件 = 0 命中即合规。命中频率最高的模式参考：`BottomInputBar.swift` ~15 处带-edge padding、`UnderlinedTabBar.swift` ~5 处、`BorderlessButtonStyle.swift` 的 `EdgeInsets(top: 6, leading: 12, ...)`、`SegmentedControl.swift:32` 的 `height: 32`。

   **注意**：本 SC 不约束 Components/ 下未触达文件（譬如新组件目录、未在 FR-A 列表内的文件）；新组件文件的 magic-number 由 §Non-Functional Requirements 中的 **token-clean 约束**承接（已显式作为 NFR 级硬约束写入），通过 code review 在 PR 阶段拦截，不计入本 SC#1 阈值。
2. **新组件落地数量**：`Sources/CoreDesign/Components/` 下新增 7 个组件目录 / 文件（Badge / Tag / SearchField / ListRow / SidebarRow / EmptyState / Toast）
3. **构建洁净**：`swift build -Xswiftc -warnings-as-errors` 通过
4. **测试不被破坏**：`swift test` 退出码 0。**注意**：本仓 `Tests/CoreDesignTests/CoreDesignTests.swift` 当前仅有 1 个模板 `@Test func example()`（空 body），实际**没有**回归保护；本 SC 含义只是"现有 stub 测试不被破坏"，不暗示有真实回归覆盖。补单元测试基础设施 explicitly 在 §Out of Scope
5. **iOS 编译通过**：`swift build -Xswiftc -warnings-as-errors --triple arm64-apple-ios26.0-simulator` 0 warning（顺手验证 MenuButton 修复）。**不用 `xcodebuild -scheme`**——本仓是纯 SPM package 无 `.xcodeproj`，xcodebuild 在 headless agent 环境依赖 derived data，不可靠
6. **#Preview 覆盖**：13 个现有 component + 7 个新组件 = **20 个组件**全部至少一个 `#Preview`
7. **glass 范围合规**：`grep -rln 'glassEffect' Sources/CoreDesign/Components/` 命中文件**只能**是以下白名单（与 US-3 验收标准一致；任何其他文件命中即违规）：
   - `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift`
   - `Sources/CoreDesign/Components/BottomInputBar/MenuButton.swift`
   - `Sources/CoreDesign/Components/Button/styles/CircularGlassButtonStyle.swift`

不可机器验证但需人工确认：

8. light / dark 双模式视觉抽查 20 个组件全部正常
9. `BottomInputBar` 在 iOS Simulator 上键盘弹出 / 收起 / suggestion 切换无 regression
10. 新组件命名 / API 形态符合 Primer + Apple Human Interface Guidelines

## Constraints & Assumptions

**约束：**
- iOS 26+ / macOS 26+ 不变
- Swift 6 strict concurrency 不变
- 已 merged 的 v2-tokens 不允许回退或改动取值（components 阶段只引用、不修改 token）
- 现有组件公开 API 尽量不破坏（参数可加默认值、可补 overload，不能删既有 init / public func 签名——除非有明确迁移步骤）

**假设：**
- v2-tokens 已 merged 且稳定（已满足，main 上 commit `abd0da4` 完成 archive）
- 现有组件目前没有外部消费者依赖具体的 padding / cornerRadius 数值；视觉变化（重构带来的）可接受
- iOS + macOS 双平台编译都可通过 SPM 直接验证：macOS 走默认 `swift build`；iOS 走 `swift build --triple arm64-apple-ios26.0-simulator`。本仓为纯 SPM package，**不依赖 Xcode** / `xcodebuild`
- `MenuButton.swift` 的 `UIImpactFeedbackGenerator` main-actor 错误是单一隔离问题，不会展开成全仓 concurrency 重构

## Out of Scope

显式不做：

- **any-writer 迁移**——切到 v2-components 是 any-writer 仓的下游 epic
- **Primer 北极星之外的视觉语言探索**（譬如 Material 3、Tailwind 等）
- **新增 token**——本 epic 只消费 v2-tokens 已有的 6 类 token + 14 个新颜色，不补充 token；如果 components 实施过程中发现 token 缺漏，先记录到 follow-up 列表，由后续 token 增补 epic 处理
- **组件视觉创新**——譬如 Avatar 增加新形态、Banner 增加 inline action 等；本 epic 只做"按 Primer 重构现有 + 补齐缺口 chrome"，不做产品维度的功能扩张
- **`FillColors.swift` / `InteractionColors.swift` 的 Primer 对齐**（v2-tokens PRD 已声明该决策延后）
- **showcase / demo app**——本 epic 不做独立的视觉 showcase；`#Preview` 是组件级的视觉冒烟检查，不是产品级 demo
- **单元测试基础设施**——CoreDesign 仓 stub test 现状继续保持；`#Preview` 是主要视觉验证手段
- **TipKit / Tooltip / Menu 等更复杂的下游元素**——按 PRD 阶段决策只做 Tag + Toast（GitHub UI 高频）；其他类似元素留待后续 epic

## Dependencies

**仓库内：**
- v2-tokens 全部 token + modifier + 语义色（已 merged 到 main，commit `abd0da4` 完成 archive）
- `Sources/CoreDesign/Resources/Resources.xcassets/`（已扩展 shadow/canvas/border 顶级目录）

**外部：**
- 无（PRD 不引入新第三方依赖）
- Primer Primitives v11.8.0 仍是视觉北极星（已锁定在 `docs/PRIMER_VERSION.md`）

**下游 epic（不属于本 PRD 范围）：**
- any-writer 迁移到 v2-components

## Estimated Effort & Epic Split

ccpm 任务硬上限是 10 / epic。本 PRD 的工作量明显超过：

- 现有组件 9 项（FR-A-1 ~ FR-A-9）— 部分可合并（4 个 Button styles 可合一个 task），但仍 ~7-8 task 量
- 新增组件 7 项（FR-B-1 ~ FR-B-7）— 每个独立 task

合计 ~14-15 task，**不可能装进单一 epic**。决策：**拆为 2 个独立 epic**：

### Epic 1: `coredesign-v2-components-existing`

- 范围：FR-A-1 ~ FR-A-9（现有组件重构）
- 估算任务数：8（4 button styles 合并 + 其他每个独立）
- 关键路径：BottomInputBar 任务（含 MenuButton iOS build 错误修复，是 spike 性质）
- 视觉风险：每组件重构后 light/dark 双模式都要人工抽查；建议每个 task 在 PR 描述中给出 before/after `#Preview` 截图说明
- 依赖：v2-tokens 全部 merged（满足）

### Epic 2: `coredesign-v2-components-new`

- 范围：FR-B-1 ~ FR-B-7（7 个新组件）
- 估算任务数：7（一组件一 task）
- 关键路径：无（任务彼此独立，Toast 用 surface modifier + coreShadow，其余基本独立）
- 依赖：v2-tokens 全部 merged（满足）；与 epic 1 **彼此独立**（除 Toast 也可在 ListRow 等场景使用，但不是硬依赖）

### 启动顺序建议

两个 epic **可以并行启动**——它们触碰的文件集互不重叠（`Components/Button/` 等 vs `Components/Badge/` 等新目录）。但建议：

- 先启动 `existing` epic 的 FR-A-1（4 个 Button styles 重构）作为 canary，验证 v2-tokens 在真实组件中的可用性
- 一周后或 canary task 合入后，启动 `new` epic 全量并行

## Notes / 已知 follow-up

- v2-tokens 留下的"FillColors / InteractionColors Primer 对齐"延后项不在本 epic（按 v2-tokens PRD 显式声明）
- macOS NSFocusRing 主路径（PRD SC #11）未达成（已 fallback），SearchField 等需要 focus ring 的组件直接用现有 overlay 实现即可
- `.coreShadow(_:)` 在 dark mode 下视觉抽查仍是 v2-tokens 的人工标准（issue #4 agent 留下的 follow-up），可在 EmptyState / Toast 等使用 shadow 的组件 PR 中顺便重抽
- **本 epic 的 hover token debt 重新表述**（修正先前误导性叙述）：`Color.hoverBackground` 已经存在于 `InteractionColors.swift:30`（取值 = `.secondaryFill` 系统色）——它语义上是 hover 状态的正确 token，**但**当前取值是 iOS / macOS 系统 fill，不直接对齐 Primer `canvas.subtle`。本 epic 在 ListRow / SidebarRow 中**选择直接用 `surfaceCanvasSubtle`**——这是为了一次性命中 Primer 视觉北极星，不是因为 "hoverBackground 不存在"。等到未来 "InteractionColors Primer 对齐" epic（v2-tokens PRD 已声明延后）把 `hoverBackground` 取值切到 Primer-aligned 实现时，ListRow / SidebarRow 可重新评估是切回 `hoverBackground`（语义更准）还是保持 `surfaceCanvasSubtle`（视觉精度更高）。在两个组件的 doc-comment 中显式标注这条 debt 并指向本 PRD 的 §Notes
