---
name: coredesign-v2-tokens
description: 引入 Primer 对齐的 design token 与基础 modifier，作为 CoreDesign v2 的底层基础设施
status: backlog
created: 2026-05-09T16:21:35Z
---

# PRD: coredesign-v2-tokens

## Executive Summary

CoreDesign v1 已经具备四层颜色系统（资源调色板 → 系统色桥接 → 语义 token → 功能别名），但 spacing、radius、typography、elevation、control metrics 这些维度仍以魔法数字散落在各组件内（`EdgeInsets(top: 6, leading: 12, ...)`、`cornerRadius: 9`、`lineWidth: 0.8`）。本 epic 以 GitHub Primer Primitives 为北极星，新增一组 token 类型与 modifier，作为后续 `coredesign-v2-components` 重构所有现有组件、新增 Badge/SearchField/ListRow/SidebarRow/EmptyState 的底层依赖。本 epic **只做加法**，不重构任何现有组件，不动 any-writer。

## Problem Statement

**为什么现在要做？**

1. CoreDesign 即将进入第二阶段（按 Primer 视觉语言统一），但目前组件级别充斥硬编码尺寸：
   - `SolidButtonStyle.swift:42` 内联了 5 个 controlSize 的 `EdgeInsets`
   - `SegmentedControl.swift:29` 写死 `cornerRadius: 9`、`height: 32`、外框圆角与 thumb 圆角彼此独立
   - `BorderModifier.swift:21` 默认 `cornerRadius: 0`、`width: 1`
   - `LightButtonStyle.swift:38` 内联 `lineWidth: 0.8`、阴影 radius/y 偏移
   - 每个组件各自决定"中等间距是多少"，新组件加入时缺乏共同参考
2. 现有语义色（`SurfaceColors`、`BorderColors`、`ContentColors`）覆盖不到 Primer 的关键概念：`canvas`/`canvas.subtle`/`canvas.inset` 的层级、`border.muted` vs `border.subtle` 的区分、`fg.muted` vs `fg.subtle`、`bg.emphasis` 的对应物、`borderFocus` 的明确定义。
3. 没有 `FocusRingModifier`，目前键盘焦点状态在不同控件之间表现不一致；Primer 标准焦点环（2px outline）需要一个共享 modifier。
4. 不先把 token 抽出来，components epic 会出现"每个组件都重新定义间距/圆角/字号"的问题，Primer 化重构会做了等于没做。

**不做会怎样？** components epic 中每个组件 PR 都会内联自己的尺寸，最终我们得到的还是一个"漆成 Primer 配色但骨架不齐"的库，下游调用方仍不知道如何在新组件里保持一致。

## User Stories

### US-1: 设计系统维护者（=本人）

**作为** CoreDesign 维护者
**我想要** spacing / radius / typography / elevation / control metrics 都有单一来源的常量
**以便** 新增或重构组件时不用每次从 Primer 文档查值或在已有文件里凭印象抄

**验收标准：**
- `CoreSpacing`、`CoreRadius`、`CoreTypography`、`CoreElevation`、`CoreControlMetrics` 五个类型作为 public API 存在
- 每个类型暴露 ≥4 个命名常量（不是裸数字）
- 至少一处现存代码（推荐 `BorderModifier`）的魔法数字被替换为 token 引用，作为可工作的端到端示例

### US-2: 下游消费者（any-writer 等）

**作为** any-writer 的开发者
**我想要** 一个统一的 `.focusRing()` modifier，跨平台行为合理
**以便** TextField、SearchField、自定义按钮等控件都能呈现一致的 Primer 风格 2px 焦点环，并在 macOS 上被系统识别为真正的焦点指示器

**验收标准：**
- `View.focusRing(visible:color:width:cornerRadius:)` 已暴露为 public 扩展
- 默认参数：color = `.borderFocus`，width = `CoreBorderWidth.thick`（2pt），cornerRadius = `CoreRadius.medium`
- iOS / iPadOS / visionOS 端用 `.overlay(RoundedRectangle().stroke())` 实现纯视觉焦点环
- macOS 端用 `NSViewRepresentable` 包装系统 `NSFocusRing`，Accessibility Inspector 扫描时识别为系统焦点指示器
- 两端共享同一 modifier API（同一 `.focusRing(...)` 调用），调用方无需写 `#if`
- `#Preview` 同时覆盖 iOS 与 macOS 两态（`#if canImport(UIKit) / canImport(AppKit)` 分别提供）

### US-3: 后续 epic 的实施者

**作为** `coredesign-v2-components` epic 的执行者
**我想要** Primer 对齐的语义色补全（panel/sidebar/canvas/inset 背景，muted/subtle 前景，hover/selected/focus 边框）
**以便** 重构 SolidButtonStyle、新增 SidebarRow / Badge / ListRow 等组件时直接引用，而不是临时再扩 SurfaceColors / BorderColors

**验收标准：**
- `SurfaceColors` 至少新增：`surfaceCanvas`、`surfaceCanvasSubtle`、`surfaceCanvasInset`、`surfacePanel`、`surfaceSidebar`、`surfaceCard`
- `BorderColors` 至少新增：`borderMuted`、`borderHover`、`borderFocus`、`borderSelected`、`borderEmphasis`（`borderSubtle` 已存在，本 epic 不动其取值）
- `ContentColors` 至少新增：`contentMuted`、`contentSubtle`、`contentOnEmphasis`
- 每个新增 token 必须带 `///` doc comment，标注与现有 token 的语义对应关系（例如 `contentMuted ≈ contentTertiary`）
- 现有命名（`surfaceRaised`、`contentPrimary` 等）保持不变；**例外：`Color.focusRing` 重命名为 `Color.borderFocus`，旧名不保留别名**
- 新颜色都在 light / dark 两种 colorScheme 下有合理取值

### US-4: 任意场景的容器

**作为** 组件作者
**我想要** 一个 `.surface(_:)` modifier 一次性应用"背景 + 1px 边框 + 圆角"组合
**以便** Sidebar / Panel / Card 这类容器不需要每次手写 `RoundedRectangle().fill().overlay(stroke())` 三件套

**验收标准：**
- `View.surface(_ kind: SurfaceKind)` modifier 暴露为 public
- `SurfaceKind` 枚举至少包含 `.canvas / .canvasSubtle / .panel / .sidebar / .card`
- 每个 kind 对应一组 (background, border, cornerRadius) 组合，全部从 token 派生
- 提供 `#Preview` 展示五种 kind 的视觉差异

## Functional Requirements

### FR-1: Spacing token

新增 `Sources/CoreDesign/Tokens/CoreSpacing.swift`。**API 形态：caseless enum 命名空间 + `public static let` of `CGFloat`**，调用方写 `CoreSpacing.md`（无需 `.rawValue`）。至少暴露：

```swift
public enum CoreSpacing {
    public static let none: CGFloat = 0
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 40
    public static let xxxxl: CGFloat = 48
    public static let huge: CGFloat = 64
}
```

具体取值与命名在 epic 阶段最终确认与 Primer Primitives `space.*` scale 的对齐方式（Primer 用 0/1/2/3/4/5/6/7/8 数字 scale，本仓库保留语义命名但需在注释中标注对应 Primer 等级）。

### FR-2: Radius token

新增 `Sources/CoreDesign/Tokens/CoreRadius.swift`。同样为 caseless enum + `public static let` 形态，至少：

```swift
public enum CoreRadius {
    public static let none: CGFloat = 0
    public static let small: CGFloat = 4
    public static let medium: CGFloat = 6
    public static let large: CGFloat = 8
    public static let xlarge: CGFloat = 12
    public static let full: CGFloat = 9999
}
```

对齐 Primer `borderRadius.small/medium/large` 三档主流取值；`.full` 用于 capsule 形态。

### FR-2.5: BorderWidth token

新增 `Sources/CoreDesign/Tokens/CoreBorderWidth.swift`，独立于 spacing/radius。Border width 是单独语义维度（亚像素 hairline、标准 1pt、强调 2pt），既不属于布局间距也不属于角半径。caseless enum + `public static let` 形态：

```swift
public enum CoreBorderWidth {
    public static let none: CGFloat = 0
    public static let hairline: CGFloat = 0.5  // Retina 亚像素分隔线
    public static let thin: CGFloat = 1        // Primer borderWidth.default
    public static let thick: CGFloat = 2       // Primer borderWidth.thick / focus ring
}
```

### FR-3: Typography token

新增 `Sources/CoreDesign/Tokens/CoreTypography.swift`，caseless enum 形态。提供与 Primer text styles 对齐的 SwiftUI `Font` 命名常量（如 `.displayLarge`、`.titleLarge`、`.titleMedium`、`.bodyLarge`、`.bodyMedium`、`.bodySmall`、`.caption`），至少 7 档。每档暴露三件套：`Font`、推荐 `lineSpacing`（CGFloat）、推荐 `tracking`（CGFloat）。

Primer 的 line-height 在 SwiftUI 中通过 `View.lineSpacing(_:)` 近似，公式为 `lineSpacing = primerLineHeight - fontSize`（取值不能为负，需 `max(0, ...)`）。**实施注意**：SwiftUI `lineSpacing` 仅在多行文本中产生效果，单行容器（按钮 label、SegmentedControl 选项、ListRow 单行内容）观察不到差异——这是预期行为，不视为缺陷。token 文件中应显式注释这一点，避免后续实施者反复争论。

### FR-4: Elevation token

新增 `Sources/CoreDesign/Tokens/CoreElevation.swift`，至少 `.none / .small / .medium / .large` 四档，每档对应一组 `(shadowColor, shadowRadius, shadowX, shadowY)`。提供 `.shadow(_ level: CoreElevation.Level)` 便利 modifier。

**dark mode 适配要求**：`shadowColor` 必须是 light/dark 自适应的动态色（通过 `Resources.xcassets` colorset 提供 light/dark 两套 RGBA，或通过 `Color(uiColor: UIColor { ... })` / `Color(nsColor: NSColor(name:dynamicProvider:))` 构造）。Primer 与 Apple HIG 在暗色模式下用更高不透明度（或内层描边光晕）替代投影，避免 elevation 在 dark 模式下完全消失。验收时需在 `#Preview` 中切换 `.preferredColorScheme(.dark)`，目视确认 `.medium` 与 `.none` 的视觉差异可辨识。

### FR-5: Control metrics token

新增 `Sources/CoreDesign/Tokens/CoreControlMetrics.swift`，按 SwiftUI `ControlSize`（mini / small / regular / large / extraLarge）暴露：

- 控件高度（用于 capsule / pill / segmented control 等）
- 横向 padding / 纵向 padding
- 推荐字号（来自 `CoreTypography`）
- icon 尺寸

提供按 `ControlSize` 取值的 helper：`CoreControlMetrics.padding(for: controlSize)` 等。

### FR-6: 语义色补全

按 US-3 验收标准扩展 `SurfaceColors.swift`、`BorderColors.swift`、`ContentColors.swift`。新颜色优先使用现有 `ColorGrade` 资源命中（必要时新增 colorset），保证 light/dark 都有取值。

**重命名**：现有 `Color.focusRing`（`BorderColors.swift:24` 定义为 `.accent` 的别名）重命名为 `Color.borderFocus`，与新引入的 `View.focusRing(...)` modifier 区分。直接重命名，**不保留旧名别名**（PRD 阶段已确认无需向后兼容）。

**映射注释要求**：每个新增的语义 token 必须在声明上方添加 `///` doc comment，标注它与现有 token 的关系，例如：

```swift
/// Primer canvas.default 的对应物。功能上接近现有 `surfaceBase`，
/// 语义上隶属 GitHub 视觉体系；新代码请优先使用本 token，
/// `surfaceBase` 保留供 v1 调用方继续使用。
public static var surfaceCanvas: Color { ... }
```

这一规则同时适用于 SurfaceColors / BorderColors / ContentColors 三个文件中的所有新增成员。

### FR-7: FocusRingModifier

新增 `Sources/CoreDesign/Modifier/FocusRingModifier.swift`：

```swift
public extension View {
    func focusRing(
        visible: Bool = true,
        color: Color = .borderFocus,
        width: CGFloat = CoreBorderWidth.thick,
        cornerRadius: CGFloat = CoreRadius.medium
    ) -> some View
}
```

**双平台实现策略**（同一 modifier API，实现细节通过 `#if canImport(UIKit) / canImport(AppKit)` 隔离）：

- **iOS / iPadOS / visionOS**：`.overlay(RoundedRectangle().stroke())` 纯视觉实现，`visible == false` 时透明且不占布局。SwiftUI `@FocusState` + VoiceOver 已能满足焦点叙述。
- **macOS**：`NSViewRepresentable` 包装一个空 `NSView`，将其 `focusRingType` 设为 `.exterior` 并通过 SwiftUI focus state 同步 `becomeFirstResponder`，注册到系统 `NSFocusRing` 机制。Accessibility Inspector / VoiceOver 会识别为系统焦点指示器，而非自定义视觉。

调用方在两端写法完全一致；`visible == false` 时 macOS 的 wrapper 也不应注册 focus ring。

### FR-8: SurfaceModifier

新增 `Sources/CoreDesign/Modifier/SurfaceModifier.swift`，配套 `public enum SurfaceKind { case canvas, canvasSubtle, panel, sidebar, card }` 与 `View.surface(_:)`。`canvasSubtle` 对应 Primer `canvas.subtle`；其余四个 case 对应具体容器角色。命名维度统一为"具体容器 / 具体容器变体"，避免引入裸修饰词（如 `.subtle`）。

### FR-9: 验证 token 可用性

在 `BorderModifier.swift` 中将默认 `cornerRadius: 0` 替换为 `CoreRadius.none`，将默认 `width: 1` 替换为 `CoreBorderWidth.thin`（值仍是 1.0，但语义化）。作为"token 在现有代码中能跑"的最小端到端证明。**这是本 epic 内允许动到现有组件的唯一例外。** 其他组件改造留给 components epic。

## Non-Functional Requirements

- 全部新增 API 必须 `public`（含 init）。
- 所有新代码必须在 Swift 6 严格并发模式下零 warning 通过 `swift build`、`swift test`。
- iOS 26 / macOS 26 部署目标不变；不允许引入需要更高 OS 的 API。
- 新颜色必须 light/dark 双模式都有取值；优先复用现有 `Color("...", bundle: .module)` 资源，必要时在 `Resources.xcassets` 中新增 colorset。
- 新 token 类型不引入 `Foundation` 之外的依赖。
- 新文件遵循仓库现有风格：双语注释、`// MARK: -` 分段、显式 `self.`。
- 每个新 modifier 必须附 `#Preview` 演示用法。

## Success Criteria

可机器验证的退出标准：

1. **新文件落地数量**：`Sources/CoreDesign/Tokens/` 下至少 6 个新 Swift 文件（`CoreSpacing`、`CoreRadius`、`CoreBorderWidth`、`CoreTypography`、`CoreElevation`、`CoreControlMetrics`）；`Sources/CoreDesign/Modifier/` 下至少 2 个新 Swift 文件（`FocusRingModifier`、`SurfaceModifier`）。
2. **公开符号数量**：`grep -rE '\bpublic static (let|var|func)' Sources/CoreDesign/Tokens | wc -l` ≥ 35；两个新 modifier 文件各自包含 `public extension View` 至少 1 处。
3. **语义色补全**：`grep -E 'static (let|var) (surfaceCanvas|surfaceCanvasSubtle|surfaceCanvasInset|surfacePanel|surfaceSidebar|surfaceCard|borderMuted|borderHover|borderFocus|borderSelected|borderEmphasis|contentMuted|contentSubtle|contentOnEmphasis)' Sources/CoreDesign/Colors/*.swift | wc -l` ≥ 14（PRD 共定义 14 个新语义 token：6 surface + 5 border + 3 content；阈值与 token 数一一对应，缺一不可）。
4. **构建洁净**：`swift build -Xswiftc -warnings-as-errors` 通过。
5. **测试通过**：`swift test` 通过（现有 stub 测试不应被破坏；不要求新增单元测试，token 是数据声明）。
6. **BorderModifier 已迁移**：`BorderModifier.swift` 内不再出现魔法数字 `0` 或 `1` 作为 cornerRadius/width 默认值，改为 `CoreRadius.none` / `CoreBorderWidth.thin` 引用。
7. **Preview 完整**：`FocusRingModifier`、`SurfaceModifier` 各自有可运行的 `#Preview`，且 `FocusRingModifier` 的 #Preview 同时覆盖 iOS 与 macOS（通过 `#if` 条件展示）。
8. **focusRing 重命名落实**：`grep -E 'static (let|var) focusRing' Sources/CoreDesign/Colors/*.swift | wc -l` == 0（旧名已删）；`grep -E 'static (let|var) borderFocus' Sources/CoreDesign/Colors/*.swift | wc -l` ≥ 1。

不可机器验证但需人工确认的标准：

9. token 取值与 epic 阶段锁定的 Primer Primitives 版本对齐，且每个 token 文件顶部以注释形式记录所引用的 Primer 版本号与 ref 链接。
10. 视觉抽查：在 light/dark 双 colorScheme 下打开 `SurfaceModifier` 的 #Preview，五种 SurfaceKind 应有可辨识的视觉差异；`CoreElevation` 的 .medium 在 dark mode 下仍可见。
11. macOS 焦点系统集成：在 macOS 上运行带 `.focusRing()` 的视图，Accessibility Inspector 应将该焦点环识别为系统 focus ring（非 generic visual element）。

## Constraints & Assumptions

**约束：**
- iOS 26+ / macOS 26+ 不变
- Swift 6 严格并发不变

**假设：**
- Primer Primitives 的具体版本（git tag / npm release）将在 **epic 创建阶段** 锁定。**唯一权威来源**是 `Sources/CoreDesign/Tokens/PRIMER_VERSION.md`（含版本号、ref 链接、锁定日期）；各 token 文件顶部注释**仅引用**该文件路径（如 `// Source of truth: Tokens/PRIMER_VERSION.md`），不重复声明版本字符串，避免多处版本号漂移。所有 token 实施任务共享同一版本基准。
- CoreDesign 当前没有外部消费者依赖具体的 spacing/radius 数值，也没有依赖 `Color.focusRing` 这一具体 token 名（PRD 阶段已确认可直接重命名）。
- SwiftUI `Font` API 足以表达 Primer typography；Primer 中的 letter-spacing / line-height 等属性通过 `lineSpacing` 与 `tracking` 近似，无须自定义 `Font.Descriptor`。
- macOS `NSFocusRing` 与 SwiftUI `@FocusState` 的同步路径：在 epic 阶段验证 `NSViewRepresentable` 包装 + `becomeFirstResponder` + `focusRingType = .exterior` 的方案可行；若验证失败则回退为"macOS 仅视觉近似"，但需在 epic 中记录原因。

## Out of Scope

显式不做：

- 重构 `SolidButtonStyle` / `LightButtonStyle` / `BorderlessButtonStyle` / `CircularGlassButtonStyle` / `SegmentedControl` / `UnderlinedTabBar` / `Banner` / `Form` / `BottomInputBar` / `Avatar` / `BookCover` / `CheckBox` / `MenuButton` / `StarShape`（全部留给 `coredesign-v2-components`）
- 新增任何业务组件（Badge、SearchField、ListRow、SidebarRow、EmptyState — components epic）
- 迁移 any-writer 任何调用点
- 移除或重命名现有 token / 颜色 / API
- 制作可视化 showcase 或 demo app
- 编写组件级单元测试（现有测试基础设施只是 stub，本 epic 不补足）
- 处理 BottomInputBar 等 glass-heavy 组件中 `.glassEffect` 的去留 — 该决策属于 components epic（PRD 已确认 glass 仅保留在"漂浮在内容上方"的场景）
- `FillColors.swift` 与 `InteractionColors.swift` 的 Primer 对齐 — 这两个文件本 epic 不动，components epic 实施者可继续使用其中现有 token；后续视情况起独立 epic 做对齐
- `CaseIterable` / token 全量枚举（用于自动化视觉测试或 showcase）— 本 epic 不提供，需要时再补

## Dependencies

**仓库内：**
- 现有 `Resources.xcassets` 资源调色板（必要时新增 colorset）
- 现有 `SurfaceColors` / `BorderColors` / `ContentColors` 作为扩展目标

**外部参考：**
- GitHub Primer Primitives（具体版本在 epic 阶段固定）
- Primer 当前 design system 文档（color tokens、spacing scale、border radius scale、typography scale、elevation scale）

**下游 epic：**
- `coredesign-v2-components` 直接依赖本 epic 全部成果。本 epic 完成、PR 合入 main 后，components epic 才能启动。
