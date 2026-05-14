# Native Primer 第一阶段系统基线实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 Native Primer 系统基线:明确的 surface 角色、非玻璃的默认按钮、浮层玻璃原语,以及 `EmptyState` 弃用。

**Architecture:** 尽量保留既有公开 API,但调整默认值并新增聚焦的原语,供后续组件工作复用。本阶段不会对所有组件进行视觉重置;它建立的是第二阶段、第三阶段所依赖的共享规则与测试。

**Tech Stack:** Swift 6.3、SwiftUI、Swift Testing、iOS 26 / macOS 26 包目标、Liquid Glass API。

---

## Source Spec

实施前请先读:

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`

本计划仅覆盖该 spec 的第一阶段。

## File Structure

Modify:

- `Sources/CoreDesign/Modifier/SurfaceModifier.swift`
  - 新增 Native Primer surface 角色,同时把旧 case 保留为兼容别名。
  - 保持 `View.surface(_:)` 作为单一 surface 入口。
- `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`
  - 新文件,封装共享的浮层 Liquid Glass 行为。
- `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
  - 把 `glass` 默认值改为 `false`。
  - 更新文档 / preview,使默认示例为非玻璃形态。
- `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
  - 把 `glass` 默认值改为 `false`。
  - 更新文档 / preview,使默认示例为非玻璃形态。
- `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`
  - 增加弃用注解,并提供迁移到 `ContentUnavailableView` 的指引。
- `Tests/CoreDesignTests/SurfaceKindTests.swift`
  - 新增测试,验证兼容性以及新 surface 角色的构造。
- `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`
  - 新增测试,验证按钮 style 默认 `glass` 取值。
- `Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`
  - 新增编译期构造测试,确保弃用 API 在过渡期内仍然可用。

只读参考:

- `Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift`
  - 旧版显式玻璃按钮视觉的兼容性参考。

本计划不修改第二阶段的组件视觉:`SegmentedControl`、`SearchField`、`ListRow`、`SidebarRow`、`UnderlinedTabBar`、`Badge`、`Tag`、`StateLabel`。

---

## 任务 1:新增 Native Primer surface 角色

**Files:**
- Modify: `Sources/CoreDesign/Modifier/SurfaceModifier.swift`
- Create: `Tests/CoreDesignTests/SurfaceKindTests.swift`

- [ ] **步骤 1:先写失败测试**

创建 `Tests/CoreDesignTests/SurfaceKindTests.swift`:

```swift
import Testing
@testable import CoreDesign

@Suite("SurfaceKind")
struct SurfaceKindTests {
    @Test("native primer surface roles construct")
    func nativePrimerSurfaceRolesConstruct() {
        let roles: [SurfaceKind] = [
            .canvas,
            .content,
            .control,
            .floating,
            .overlay,
        ]

        #expect(roles.count == 5)
    }

    @Test("legacy surface roles remain available")
    func legacySurfaceRolesRemainAvailable() {
        let roles: [SurfaceKind] = [
            .canvasSubtle,
            .panel,
            .sidebar,
            .card,
        ]

        #expect(roles.count == 4)
    }
}
```

- [ ] **步骤 2:跑测试确认失败**

执行:

```bash
swift test --filter SurfaceKind
```

预期:编译失败,因为 `SurfaceKind.content`、`.control`、`.floating`、`.overlay` 还不存在。

- [ ] **步骤 3:新增 surface 角色与映射**

编辑 `Sources/CoreDesign/Modifier/SurfaceModifier.swift`。

把 `SurfaceKind` 的 case 替换为:

```swift
public enum SurfaceKind: Sendable {
    /// Page-level canvas.
    case canvas

    /// Ordinary content surfaces: rows, cards, and non-floating containers.
    case content

    /// Interactive control surfaces: buttons, fields, segmented controls.
    case control

    /// Floating surfaces above content: toasts, floating toolbars, bottom bars.
    case floating

    /// Overlay surfaces such as menus and popovers.
    case overlay

    /// Compatibility alias for a subtler canvas.
    case canvasSubtle

    /// Compatibility alias for panel containers.
    case panel

    /// Compatibility alias for sidebar containers.
    case sidebar

    /// Compatibility alias for card containers.
    case card
}
```

更新 `background` 映射:

```swift
var background: Color {
    switch self {
    case .canvas:
        .surfaceCanvas
    case .content:
        .surfaceCard
    case .control:
        .surfaceInteractive
    case .floating:
        .surfaceOverlay
    case .overlay:
        .surfacePanel
    case .canvasSubtle:
        .surfaceCanvasSubtle
    case .panel:
        .surfacePanel
    case .sidebar:
        .surfaceSidebar
    case .card:
        .surfaceCard
    }
}
```

更新 `border` 映射:

```swift
var border: Color {
    switch self {
    case .canvas:
        .borderDefault
    case .content:
        .borderMuted
    case .control:
        .borderSubtle
    case .floating:
        .borderMuted
    case .overlay:
        .borderDefault
    case .canvasSubtle:
        .borderMuted
    case .panel:
        .borderDefault
    case .sidebar:
        .borderDefault
    case .card:
        .borderMuted
    }
}
```

更新 `cornerRadius` 映射:

```swift
var cornerRadius: CGFloat {
    switch self {
    case .canvas:
        CoreRadius.medium
    case .content:
        CoreRadius.medium
    case .control:
        CoreRadius.small
    case .floating:
        CoreRadius.large
    case .overlay:
        CoreRadius.medium
    case .canvasSubtle:
        CoreRadius.medium
    case .panel:
        CoreRadius.medium
    case .sidebar:
        CoreRadius.none
    case .card:
        CoreRadius.medium
    }
}
```

更新 preview 示例数组,纳入新角色:

```swift
private let samples: [(label: String, kind: SurfaceKind)] = [
    ("canvas", .canvas),
    ("content", .content),
    ("control", .control),
    ("floating", .floating),
    ("overlay", .overlay),
    ("canvasSubtle", .canvasSubtle),
    ("panel", .panel),
    ("sidebar", .sidebar),
    ("card", .card),
]
```

- [ ] **步骤 4:跑测试确认通过**

执行:

```bash
swift test --filter SurfaceKind
```

预期:测试通过。

- [ ] **步骤 5:Commit**

```bash
git add Sources/CoreDesign/Modifier/SurfaceModifier.swift Tests/CoreDesignTests/SurfaceKindTests.swift
git commit -m "feat: add native primer surface roles"
```

---

## 任务 2:新增浮层玻璃原语

**Files:**
- Create: `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`
- Create: `Tests/CoreDesignTests/FloatingGlassModifierTests.swift`

- [ ] **步骤 1:先写失败的编译测试**

创建 `Tests/CoreDesignTests/FloatingGlassModifierTests.swift`:

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("FloatingGlassModifier")
struct FloatingGlassModifierTests {
    @MainActor
    @Test("floating glass modifier constructs")
    func floatingGlassModifierConstructs() {
        let view = Text("Floating").floatingGlass()
        #expect(String(describing: type(of: view)).isEmpty == false)
    }
}
```

- [ ] **步骤 2:跑测试确认失败**

执行:

```bash
swift test --filter FloatingGlassModifier
```

预期:编译失败,因为 `floatingGlass()` 还不存在。

- [ ] **步骤 3:实现 modifier**

创建 `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`:

```swift
//
//  FloatingGlassModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - FloatingGlassModifier

public struct FloatingGlassModifier<S: InsettableShape>: ViewModifier {
    public let shape: S
    public let isInteractive: Bool

    public init(shape: S, isInteractive: Bool = false) {
        self.shape = shape
        self.isInteractive = isInteractive
    }

    public func body(content: Content) -> some View {
        let glass = self.isInteractive ? Glass.regular.interactive() : Glass.regular

        content
            .background(
                self.shape
                    .inset(by: CoreButtonMetrics.glassInset)
                    .fill(.background.opacity(0.72))
                    .glassEffect(glass, in: self.shape)
            )
            .overlay(
                self.shape.strokeBorder(
                    .white.opacity(CoreButtonMetrics.glassBorderOpacity),
                    lineWidth: CoreBorderWidth.hairline
                )
            )
    }
}

public extension View {
    func floatingGlass(
        in shape: some InsettableShape = Capsule(style: .continuous),
        isInteractive: Bool = false
    ) -> some View {
        self.modifier(FloatingGlassModifier(shape: shape, isInteractive: isInteractive))
    }
}
```

- [ ] **步骤 4:跑测试确认通过**

执行:

```bash
swift test --filter FloatingGlassModifier
```

预期:测试通过。

- [ ] **步骤 5:跑一次 package build**

执行:

```bash
swift build
```

预期:构建成功。

- [ ] **步骤 6:Commit**

```bash
git add Sources/CoreDesign/Modifier/FloatingGlassModifier.swift Tests/CoreDesignTests/FloatingGlassModifierTests.swift
git commit -m "feat: add floating glass primitive"
```

---

## 任务 3:把普通按钮 style 默认改为非玻璃

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
- Modify: `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
- Create: `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`

- [ ] **步骤 1:为默认值写失败测试**

创建 `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`:

```swift
import Testing
@testable import CoreDesign

@Suite("Button style defaults")
struct ButtonStyleDefaultTests {
    @Test("solid button style defaults to non-glass")
    func solidDefaultsToNonGlass() {
        let style = SolidButtonStyle()
        #expect(style.glass == false)
    }

    @Test("light button style defaults to non-glass")
    func lightDefaultsToNonGlass() {
        let style = LightButtonStyle()
        #expect(style.glass == false)
    }

    @Test("explicit glass remains available")
    func explicitGlassRemainsAvailable() {
        #expect(SolidButtonStyle(glass: true).glass == true)
        #expect(LightButtonStyle(glass: true).glass == true)
    }
}
```

- [ ] **步骤 2:跑测试确认失败**

执行:

```bash
swift test --filter "Button style defaults"
```

预期:两条测试失败,因为当前 `SolidButtonStyle()` 与 `LightButtonStyle()` 的 `glass` 默认值是 `true`。

- [ ] **步骤 3:修改 SolidButtonStyle 默认值与文档**

在 `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift` 中,把:

```swift
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = true) {
```

改为:

```swift
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = false) {
```

把便捷 API:

```swift
static func solid(role: ButtonRoleStyleRole = .primary, glass: Bool = true) -> SolidButtonStyle {
```

改为:

```swift
static func solid(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> SolidButtonStyle {
```

更新顶部注释为:

```swift
/// ## Native Primer mode (default)
///
/// `glass: false` (default) uses a practical native control surface with role color,
/// border, pressed scale, and restrained elevation.
///
/// `glass: true` keeps the legacy Telegram glass four-layer structure for explicit
/// floating or transitional usage.
```

更新 preview 标签与调用:

```swift
#Preview("Solid — default") {
    VStack(spacing: 12) {
        Button {} label: { Text("Primary") }
            .buttonStyle(.solid(role: .primary))
        Button {} label: { Text("Danger") }
            .buttonStyle(.solid(role: .danger))
        Button {} label: { Text("Disabled") }
            .buttonStyle(.solid(role: .primary))
            .disabled(true)
    }
    .padding()
}

#Preview("Solid — explicit glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Primary") }
            .buttonStyle(.solid(role: .primary, glass: true))
        Button {} label: { Text("Secondary") }
            .buttonStyle(.solid(role: .secondary, glass: true))
    }
    .padding()
}
```

- [ ] **步骤 4:修改 LightButtonStyle 默认值与文档**

在 `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift` 中,把:

```swift
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = true) {
```

改为:

```swift
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = false) {
```

把便捷 API:

```swift
static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = true) -> LightButtonStyle {
```

改为:

```swift
static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> LightButtonStyle {
```

更新顶部注释为:

```swift
/// `glass: false` (default) uses a practical secondary control surface.
/// `glass: true` keeps the legacy Telegram glass treatment for explicit usage.
```

更新 preview 标签与调用:

```swift
#Preview("Light — default") {
    VStack(spacing: 12) {
        Button {} label: { Text("Cancel") }
            .buttonStyle(.light(role: .secondary))
        Button {} label: { Text("Disabled") }
            .buttonStyle(.light(role: .secondary))
            .disabled(true)
    }
    .padding()
    .background(Color.systemGroupedBackground)
}

#Preview("Light — explicit glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Cancel") }
            .buttonStyle(.light(role: .secondary, glass: true))
    }
    .padding()
}
```

- [ ] **步骤 5:跑测试确认通过**

执行:

```bash
swift test --filter "Button style defaults"
```

预期:测试通过。

- [ ] **步骤 6:跑既有按钮相关测试**

执行:

```bash
swift test --filter CoreButtonMetrics
swift test --filter AsyncButton
```

预期:测试通过。

- [ ] **步骤 7:Commit**

```bash
git add Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift Tests/CoreDesignTests/ButtonStyleDefaultTests.swift
git commit -m "feat: make button glass opt-in"
```

---

## 任务 4:弃用 EmptyState 并指引迁移到原生方案

**Files:**
- Modify: `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`
- Create: `Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`

- [ ] **步骤 1:写编译保持测试**

创建 `Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`:

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("EmptyState deprecation")
struct EmptyStateDeprecationTests {
    @MainActor
    @Test("deprecated empty state remains constructible during compatibility window")
    func deprecatedEmptyStateRemainsConstructible() {
        let view = EmptyState(systemName: "tray", title: "No items")
        #expect(String(describing: type(of: view)).isEmpty == false)
    }
}
```

- [ ] **步骤 2:在打弃用注解前先跑一次测试**

执行:

```bash
swift test --filter "EmptyState deprecation"
```

预期:测试通过。这一步是为了在添加注解前先确认兼容性基线。

- [ ] **步骤 3:添加弃用注解**

编辑 `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`。

给 public struct 加上这条弃用注解:

```swift
@available(
    *,
    deprecated,
    message: "Use SwiftUI ContentUnavailableView for empty states. Compose CoreDesign buttons inside ContentUnavailableView actions when needed."
)
public struct EmptyState<Action: View>: View {
```

把同样的 `@available` 注解加到以下 public 便捷 init:

```swift
init(
    icon: Image,
    title: String,
    description: String? = nil,
    iconSize: CGFloat = CoreSpacing.xxxxl
)
```

```swift
init(
    systemName: String,
    title: String,
    description: String? = nil,
    iconSize: CGFloat = CoreSpacing.xxxxl
)
```

```swift
init(
    systemName: String,
    title: String,
    description: String? = nil,
    iconSize: CGFloat = CoreSpacing.xxxxl,
    @ViewBuilder action: () -> Action
)
```

把文件顶部的文档注释改成以这段开头:

```swift
/// Deprecated compatibility empty-state view.
///
/// Prefer SwiftUI `ContentUnavailableView` for new empty, unavailable, and
/// no-results states. This component remains available during the current major
/// version only as a compatibility wrapper for existing callers.
```

- [ ] **步骤 4:跑测试确认兼容性仍然保留**

执行:

```bash
swift test --filter "EmptyState deprecation"
```

预期:测试通过。弃用警告是可以接受的。

- [ ] **步骤 5:跑完整测试套**

执行:

```bash
swift test
```

预期:所有测试通过。

- [ ] **步骤 6:Commit**

```bash
git add Sources/CoreDesign/Components/EmptyState/EmptyState.swift Tests/CoreDesignTests/EmptyStateDeprecationTests.swift
git commit -m "docs: deprecate empty state component"
```

---

## 任务 5:第一阶段验收

**Files:**
- Read: `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`
- Verify: 任务 1-4 改动过的所有文件

- [ ] **步骤 1:跑完整测试套**

执行:

```bash
swift test
```

预期:所有测试通过。

- [ ] **步骤 2:检查是否还有意外残留的全局 glass 默认值**

执行:

```bash
rg "glass: Bool = true|\\.buttonStyle\\(\\.solid\\(|\\.buttonStyle\\(\\.light\\(" Sources/CoreDesign App/Sources Tests/CoreDesignTests
```

预期:

- `SolidButtonStyle.swift` 与 `LightButtonStyle.swift` 中不再有 `glass: Bool = true`
- App preview 中可能仍然调用 `.solid(...)` 或 `.light(...)`,但它们现在都会解析到非玻璃默认值

- [ ] **步骤 3:确认 EmptyState 仍然 public 但已弃用**

执行:

```bash
rg "deprecated.*ContentUnavailableView|public struct EmptyState|ContentUnavailableView" Sources/CoreDesign/Components/EmptyState/EmptyState.swift
```

预期:输出应包含 `@available(... deprecated ...)` 注解、`public struct EmptyState`,以及 `ContentUnavailableView` 迁移指引。

- [ ] **步骤 4:确认新 surface 角色已落地**

执行:

```bash
rg "case content|case control|case floating|case overlay" Sources/CoreDesign/Modifier/SurfaceModifier.swift
```

预期:四个 case 都在。

- [ ] **步骤 5:在 Xcode 或 package build 中检查变更过的 preview**

执行:

```bash
swift build
```

预期:构建成功。然后手动检查以下 SwiftUI preview:

- `Surface — Light`
- `Surface — Dark`
- `Solid — default`
- `Solid — explicit glass`
- `Light — default`
- `Light — explicit glass`

- [ ] **步骤 6:确认没有遗留的、未提交的验收期改动**

执行:

```bash
git status --short
```

预期:没有未提交的改动。如果该命令显示文件,用 `git diff` 检查,然后要么用精确的文件列表 commit 任务范围内的改动,要么只 restore 实施任务造成的改动。不要 revert 用户自己的、与本计划无关的改动。

---

## Handoff Notes

- 本计划有意不实现第二阶段的组件视觉重置。
- 提交保持小颗粒、聚焦在单个任务上。
- 第一阶段不要移除 `EmptyState`。
- 第一阶段不要重命名 `TelegramGlassButtonModifier`;它在显式玻璃按钮场景下仍是兼容实现。
- 如果 `FloatingGlassModifier` 与当前 SDK 的 Liquid Glass API 签名冲突,在保留公开 `floatingGlass(in:isInteractive:)` API 与测试的前提下,调整 modifier 内部实现以适配编译器。
