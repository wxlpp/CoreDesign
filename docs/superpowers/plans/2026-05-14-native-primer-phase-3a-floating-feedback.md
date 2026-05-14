# Native Primer 第 3A 阶段：浮动与反馈实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 把 `Toast` 升级到浮动 Liquid Glass 层，确认 `Banner` 留在内容层/控件层，验证 `BottomInputBar` 继续作为 Telegram 风格 glass 表面的锚点组件。

**架构：** Phase 2 完成了控件与状态指示器的重置。Phase 3A 是 spec §Phase 3 的第一片，覆盖 **Floating And Feedback** 段中的表面组件。视觉差异集中在 `Toast`：它当前用的是 `.surface(.card) + .coreShadow(.medium)`，属于内容卡片 chrome —— 按 spec 应改用 Phase 1 通过 `View.floatingGlass(in:isInteractive:)` 引入的浮动 Liquid Glass 层。`Banner` 与 `BottomInputBar` 本就已经对齐；本阶段通过显式的文档声明把这点固定下来，并补齐缺失的测试覆盖。

**技术栈：** Swift 6.3、SwiftUI、Swift Testing、iOS 26 / macOS 26 包目标、Liquid Glass API。

---

## 源 Spec

实施前阅读：

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`（§Floating And Feedback）

本计划仅覆盖 Phase 3 中的浮动 + 反馈子集：

- `Toast`（原内容卡片，应改为浮动 glass）
- `Banner`（内容层/控件层，不走 glass —— 验证并文档化）
- `BottomInputBar`（已经是浮动 glass，做收尾打磨与测试补齐）

不要修改 Phase 3B 的内容层组件（`CommentCard`、`EventRow`、`TimelineItem`、`StatusRow`、`BookCover`），也不要碰 Phase 3C 的进度/头像/EmptyState。

## 文件结构

修改：

- `Sources/CoreDesign/Components/Toast/Toast.swift`
  - 把 `ToastView` 容器 chrome（`.surface(.card) + .coreShadow(.medium)`）替换为 `View.floatingGlass(in:isInteractive:)`。
  - 更新文档注释抬头，声明浮动层材质。
  - 保持 `ToastItem` / `ToastHost` 公开 API 不变；`ToastHostTests` 中的队列状态机测试必须仍然全绿。
- `Sources/CoreDesign/Components/Banner.swift`
  - 更新顶部文档注释，显式声明内容层/控件层材质，并解释"刻意不走 glass"的取舍。
  - 保持 `BannerStyle` 协议、`BannerStyleConfiguration`、以及 Plain / Bordered 两个具体 style 不变。
- `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift`
  - 调整文档注释抬头，显式声明浮动层材质。
  - 保持 `BottomInputBarGlassModifier`（Phase 2A 的 `InsettableShape` + `strokeBorder` 重构）不变。

新建：

- `Tests/CoreDesignTests/BannerTests.swift`
- `Tests/CoreDesignTests/BottomInputBarTests.swift`

只读参考：

- `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`
  - `View.floatingGlass(in:isInteractive:)` 的来源。
- `Tests/CoreDesignTests/ToastHostTests.swift`
  - 已有的队列状态机覆盖；视觉变更过程中必须保持全绿。

---

## 任务 1：Toast 升级到浮动 Liquid Glass 层

**文件：**
- 修改：`Sources/CoreDesign/Components/Toast/Toast.swift`

- [ ] **步骤 1：基线现有测试**

运行：

```bash
swift test --filter ToastHostTests
```

预期：全部队列状态机测试通过。这就是基线。

- [ ] **步骤 2：更新 `ToastView` 容器 chrome**

在 `Sources/CoreDesign/Components/Toast/Toast.swift` 中定位 `ToastView` 的 `body`（大约 397–432 行 —— 以 `.surface(.card)` 与 `.coreShadow(.medium)` 结尾的那一块），把尾部 chrome 替换为浮动 glass 胶囊。使用 `Capsule(style: .continuous)` 让形状契合 Telegram 风格的 pill 几何：

```swift
.floatingGlass(
    in: Capsule(style: .continuous),
    isInteractive: false
)
```

移除 `.surface(.card)` 与 `.coreShadow(.medium)` 这两个 modifier。`FloatingGlassModifier` 已经自带 `strokeBorder` overlay 与 glass material，浮动层不需要额外的阴影。

> 理由：spec §Floating And Feedback 写明 Toast "moves to the floating layer" 且 "can use Liquid Glass"。`View.floatingGlass(in:isInteractive:)` 是 Phase 1 为这一角色专门引入的共享原语。

- [ ] **步骤 3：更新 Toast 顶部文档注释抬头**

把现有顶部文档注释中描述 `ToastView` 使用 `.surface(.card) + .coreShadow(.medium)` 的那一段替换为浮动 glass 声明。保留 `@MainActor` / 队列状态机的设计说明段不变：

```swift
/// Native Primer floating toast.
///
/// Floating-layer feedback surface. Uses `View.floatingGlass(in:isInteractive:)`
/// over a `Capsule(style: .continuous)` shell so the toast reads as elevated
/// system feedback, not content chrome. Text stays clear; actions stay
/// compact. The queue state machine (`ToastHost`) is unchanged.
///
/// **Material layer**: floating. **Surface role**: floating.
///
/// // 保留原有的 @MainActor 队列说明、Sendable 不需要显式约束的解释、
/// // dismiss/queue 状态机段落。这些是 load-bearing 文档。
```

同样要更新 `ToastView` body 附近那段提到 `.surface(.card) + .coreShadow(.medium)` 的局部文档 —— 把它改成指向 `floatingGlass`。

- [ ] **步骤 4：跑全部 toast 测试**

运行：

```bash
swift test --filter ToastHostTests
swift test --filter Toast
```

预期：所有队列测试仍然通过。构造 / 状态机行为没变，只是渲染 chrome 移动了。

- [ ] **步骤 5：构建**

运行：

```bash
swift build
```

预期：构建成功。

- [ ] **步骤 6：Preview 视觉验证**

在 Xcode 中打开 `Toast.swift`，在 iOS 26 模拟器上跑现有的 `#Preview` 块（如果有 storybook target 也一并跑）。在亮色 + 暗色下验证：

- Toast 表面读起来像一颗半透明的 glass pill，不是扁平卡片。
- 文本对比度在浮动 glass 背景上仍然清晰可读。
- 边缘没有伪影（`FloatingGlassModifier` 的 `strokeBorder` 应当呈一条细发丝线可见）。

如果对比度退化（例如浮动 glass 浮在繁杂背景上挡住文字），把 `text foreground color` 调到 `Color.contentPrimary` 后再重跑 —— 不要回退 glass。

- [ ] **步骤 7：提交**

```bash
git add Sources/CoreDesign/Components/Toast/Toast.swift
git commit -m "feat(Toast): promote to floating Liquid Glass surface"
```

---

## 任务 2：Banner Native Primer 文档化

**文件：**
- 修改：`Sources/CoreDesign/Components/Banner.swift`
- 新建：`Tests/CoreDesignTests/BannerTests.swift`

- [ ] **步骤 1：编写编译/行为测试**

新建 `Tests/CoreDesignTests/BannerTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Banner")
struct BannerTests {
    @MainActor
    @Test("banner constructs with info level")
    func bannerConstructsWithInfoLevel() {
        let banner = Banner(level: .info) {
            Text("New version available")
        }
        #expect(type(of: banner) == Banner<Text>.self)
    }

    @MainActor
    @Test("banner constructs with danger level")
    func bannerConstructsWithDangerLevel() {
        let banner = Banner(level: .danger) {
            Text("Build failed")
        }
        #expect(type(of: banner) == Banner<Text>.self)
    }
}
```

> 如果 `Banner` 的公开 init 用的不是 `level:` 这个参数名（例如 `_ level:`，
> 或者是一个只接收 closure、内部包装 `MessageLevel` 的 init），写测试时按
> 实际签名匹配。不要为了让测试编译去改公开 API —— 改测试。

- [ ] **步骤 2：跑测试验证通过**

运行：

```bash
swift test --filter BannerTests
```

预期：测试通过。

- [ ] **步骤 3：更新顶部文档注释抬头**

在 `Sources/CoreDesign/Components/Banner.swift` 中，找到 `public struct Banner` 上方的顶部文档注释，前置一段 Native Primer 抬头。保留全部现有 `BannerStyle` / `BannerPalette` / `MessageLevel` 映射文档不变：

```swift
/// Native Primer status banner.
///
/// Content/control-layer information surface. Uses status semantics
/// (`info` / `success` / `warning` / `danger`) with restrained bordered or
/// filled treatment — **not** Liquid Glass. Banner is for in-page
/// information, not floating feedback; if you need floating feedback, use
/// `Toast` instead.
///
/// **Material layer**: content (info-only) or control (with actions).
/// **Surface role**: content / control.
///
/// // 保留原有 BannerStyle 协议入口、BannerPalette 映射段落、以及
/// // 现有的 "不使用 .glassEffect" 解释（"Banner 是基础信息容器，需要清晰的
/// // 实色背景以保证可读性"——这条恰好是 Native Primer §Layered Material Rules
/// // 在 Banner 上的体现，保留）。
```

- [ ] **步骤 4：确认无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/Banner.swift
```

预期：零匹配。

- [ ] **步骤 5：跑测试和构建**

运行：

```bash
swift test --filter BannerTests
swift build
```

预期：测试通过；构建成功。

- [ ] **步骤 6：提交**

```bash
git add Sources/CoreDesign/Components/Banner.swift Tests/CoreDesignTests/BannerTests.swift
git commit -m "test(Banner): add compile tests; declare Native Primer role"
```

---

## 任务 3：BottomInputBar Native Primer 锚点

**文件：**
- 修改：`Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift`
- 新建：`Tests/CoreDesignTests/BottomInputBarTests.swift`

- [ ] **步骤 1：编写编译/行为测试**

新建 `Tests/CoreDesignTests/BottomInputBarTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("BottomInputBar")
struct BottomInputBarTests {
    @MainActor
    @Test("bottom input bar constructs with defaults")
    func bottomInputBarConstructsWithDefaults() {
        let bar = BottomInputBar(
            isShowingSuggestions: .constant(false),
            onSubmit: { _ in }
        )

        #expect(String(describing: type(of: bar)).contains("BottomInputBar"))
    }

    @MainActor
    @Test("bottom input bar constructs with placeholder and run state")
    func bottomInputBarConstructsWithPlaceholderAndRunState() {
        let bar = BottomInputBar(
            isShowingSuggestions: .constant(true),
            placeholder: "Type a message",
            isRunning: true,
            onSubmit: { _ in }
        )

        #expect(String(describing: type(of: bar)).contains("BottomInputBar"))
    }
}
```

> 按 `BottomInputBar.init` 的实际签名匹配 —— 该文件已经定义了很多可选参数
> （`wandEnabled`、`sendEnabled`、`showMenuButton`、`autoFocus`、`externalFocus`、
> `onActivate`、`onStop`）。测试只需要覆盖**默认参数路径**和一条
> **非默认参数路径**做编译保真即可，不需要穷举所有参数组合。

- [ ] **步骤 2：跑测试验证通过**

运行：

```bash
swift test --filter BottomInputBarTests
```

预期：测试通过。

- [ ] **步骤 3：更新顶部文档注释抬头**

在 `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift` 中，找到 `struct BottomInputBar` 上方的顶部文档注释，前置一段 Native Primer / 浮动层声明。保留 `autoFocus` 的设计说明段（那段刻意解释了为何 focus 是在 `onAppear` 里抓取、而不是 `task` 里）：

```swift
/// Native Primer floating input bar.
///
/// **The strongest Telegram-like surface in the library.** Floating-layer
/// component using iOS 26 Liquid Glass via `BottomInputBarGlassModifier`
/// (Phase 2A refactor: `BottomInputBarGlassEffectShape: InsettableShape` +
/// `strokeBorder` overlay). Input ergonomics still come first — the glass
/// is the chrome, not the feature.
///
/// **Material layer**: floating. **Surface role**: floating.
///
/// // 保留原有 autoFocus 的设计说明段落（解释为何用 .onAppear 而非父 view 的
/// // .onAppear / .task）。这是非 obvious 的设计决策。
```

- [ ] **步骤 4：确认 glass 用法正确**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/BottomInputBar
```

预期：至少一个匹配，且**仅出现在** `BottomInputBarGlassModifier` 内部。glass 用法对这个浮动表面来说是有意为之的。

- [ ] **步骤 5：跑测试和构建**

运行：

```bash
swift test --filter BottomInputBarTests
swift build
```

预期：测试通过；构建成功。

- [ ] **步骤 6：提交**

```bash
git add Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift Tests/CoreDesignTests/BottomInputBarTests.swift
git commit -m "test(BottomInputBar): add compile tests; declare Native Primer role"
```

---

## 任务 4：第 3A 阶段验收

**文件：**
- 验收：任务 1–3 修改过的所有文件。

- [ ] **步骤 1：跑全部测试**

运行：

```bash
swift test
```

预期：所有测试通过（含新增的 `BannerTests` 与 `BottomInputBarTests`，以及已有的 `ToastHostTests`）。

- [ ] **步骤 2：构建**

运行：

```bash
swift build
```

预期：构建成功。

- [ ] **步骤 3：确认 glass 分层符合 spec**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/Toast Sources/CoreDesign/Components/Banner.swift Sources/CoreDesign/Components/BottomInputBar
```

预期：

- `Toast/Toast.swift` 至少有一个匹配（新加入的 `.floatingGlass` 调用）。
- `Banner.swift` 零匹配。
- `BottomInputBar` 的匹配局限在 `BottomInputBarGlassModifier` 内部。

- [ ] **步骤 4：确认 Preview 仍存在**

运行：

```bash
rg "#Preview" Sources/CoreDesign/Components/Toast Sources/CoreDesign/Components/Banner.swift Sources/CoreDesign/Components/BottomInputBar
```

预期：每个组件文件至少一个 `#Preview`。

- [ ] **步骤 5：Xcode 视觉评审**

在 iOS 26 模拟器上以**亮色和暗色**两种外观分别打开每个 `#Preview`。验证：

- Toast：浮动 glass pill，没有扁平卡片 chrome。
- Banner：清晰的实色填充状态背景，无 glass。
- BottomInputBar：浮动 glass 条，带一条 white-opacity 发丝描边。

如果某个 preview 损坏或视觉退化超出了预期的 glass 升级范围（针对 Toast），请记一个后续 follow-up，而不是回退 —— 视觉变化是有意为之，并由 spec §Floating And Feedback 背书。

- [ ] **步骤 6：工作区干净**

运行：

```bash
git status --short
```

预期：无未提交变更。

---

## 交接说明

- 这是首个视觉变更不止"调一调 token"的阶段 —— `Toast` 按 spec §Floating And Feedback 被刻意**升级**到浮动层。调用方应当不需要 API 改动；队列状态机被保留。
- 不要给 `Banner` 加 glass。它是经典的内容层/控件层状态表面 —— 这恰恰是 Banner 与 Toast 拆分的全部意义。
- `BottomInputBar` 是浮动 glass 组件的锚点。未来的浮动表面工作（popover、menu、浮动 toolbar）应当复用 `View.floatingGlass(in:isInteractive:)`，而不是在内联里再搭一遍 glass 栈。
- Phase 3B 会扫一遍内容层组件（`CommentCard`、`EventRow`、`TimelineItem`、`StatusRow`、`BookCover`）—— 保持它们留在内容层；glass 升级的边界就停在本阶段定义的浮动层界线上。
