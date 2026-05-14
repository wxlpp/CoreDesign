# Native Primer Phase 1 System Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the Native Primer system baseline: explicit surface roles, non-glass default buttons, floating glass primitives, and `EmptyState` deprecation.

**Architecture:** Keep existing public APIs where possible, but adjust defaults and add focused primitives that later component work can reuse. This phase does not visually reset every component; it creates the shared rules and tests that Phase 2 and Phase 3 rely on.

**Tech Stack:** Swift 6.3, SwiftUI, Swift Testing, iOS 26/macOS 26 package targets, Liquid Glass APIs.

---

## Source Spec

Read before implementing:

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`

This plan covers only Phase 1 from that spec.

## File Structure

Modify:

- `Sources/CoreDesign/Modifier/SurfaceModifier.swift`
  - Add new Native Primer surface roles while preserving old cases as compatibility aliases.
  - Keep `View.surface(_:)` as the single surface entry point.
- `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`
  - New file for shared floating Liquid Glass behavior.
- `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
  - Change `glass` default to `false`.
  - Update docs/previews so default examples are non-glass.
- `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
  - Change `glass` default to `false`.
  - Update docs/previews so default examples are non-glass.
- `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`
  - Add deprecation annotations with migration guidance to `ContentUnavailableView`.
- `Tests/CoreDesignTests/SurfaceKindTests.swift`
  - New tests for compatibility and new surface role construction.
- `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`
  - New tests for button style default `glass` values.
- `Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`
  - New compile-only construction test to ensure deprecated APIs still remain available.

Read only:

- `Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift`
  - Compatibility reference for legacy explicit glass button visuals.

Do not modify Phase 2 component visuals in this plan: `SegmentedControl`, `SearchField`, `ListRow`, `SidebarRow`, `UnderlinedTabBar`, `Badge`, `Tag`, and `StateLabel`.

---

## Task 1: Add Native Primer Surface Roles

**Files:**
- Modify: `Sources/CoreDesign/Modifier/SurfaceModifier.swift`
- Create: `Tests/CoreDesignTests/SurfaceKindTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/CoreDesignTests/SurfaceKindTests.swift`:

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

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter SurfaceKind
```

Expected: compile failure because `SurfaceKind.content`, `.control`, `.floating`, and `.overlay` do not exist.

- [ ] **Step 3: Add surface roles and mappings**

Edit `Sources/CoreDesign/Modifier/SurfaceModifier.swift`.

Replace the `SurfaceKind` cases with:

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

Update `background` mapping:

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

Update `border` mapping:

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

Update `cornerRadius` mapping:

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

Update the preview sample array to include the new roles:

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

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter SurfaceKind
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/CoreDesign/Modifier/SurfaceModifier.swift Tests/CoreDesignTests/SurfaceKindTests.swift
git commit -m "feat: add native primer surface roles"
```

---

## Task 2: Add Floating Glass Primitive

**Files:**
- Create: `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`
- Create: `Tests/CoreDesignTests/FloatingGlassModifierTests.swift`

- [ ] **Step 1: Write the failing compile test**

Create `Tests/CoreDesignTests/FloatingGlassModifierTests.swift`:

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

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter FloatingGlassModifier
```

Expected: compile failure because `floatingGlass()` does not exist.

- [ ] **Step 3: Implement the modifier**

Create `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`:

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

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter FloatingGlassModifier
```

Expected: test passes.

- [ ] **Step 5: Run package build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/CoreDesign/Modifier/FloatingGlassModifier.swift Tests/CoreDesignTests/FloatingGlassModifierTests.swift
git commit -m "feat: add floating glass primitive"
```

---

## Task 3: Make Ordinary Button Styles Non-Glass By Default

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
- Modify: `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
- Create: `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`

- [ ] **Step 1: Write failing tests for defaults**

Create `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`:

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

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter "Button style defaults"
```

Expected: two tests fail because `SolidButtonStyle()` and `LightButtonStyle()` currently default `glass` to `true`.

- [ ] **Step 3: Change SolidButtonStyle defaults and docs**

In `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`, change:

```swift
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = true) {
```

to:

```swift
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = false) {
```

Change the convenience API:

```swift
static func solid(role: ButtonRoleStyleRole = .primary, glass: Bool = true) -> SolidButtonStyle {
```

to:

```swift
static func solid(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> SolidButtonStyle {
```

Update the top comment so it says:

```swift
/// ## Native Primer mode (default)
///
/// `glass: false` (default) uses a practical native control surface with role color,
/// border, pressed scale, and restrained elevation.
///
/// `glass: true` keeps the legacy Telegram glass four-layer structure for explicit
/// floating or transitional usage.
```

Update preview labels and calls:

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

- [ ] **Step 4: Change LightButtonStyle defaults and docs**

In `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`, change:

```swift
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = true) {
```

to:

```swift
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = false) {
```

Change the convenience API:

```swift
static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = true) -> LightButtonStyle {
```

to:

```swift
static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> LightButtonStyle {
```

Update the top comment so it says:

```swift
/// `glass: false` (default) uses a practical secondary control surface.
/// `glass: true` keeps the legacy Telegram glass treatment for explicit usage.
```

Update preview labels and calls:

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

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
swift test --filter "Button style defaults"
```

Expected: tests pass.

- [ ] **Step 6: Run existing button-related tests**

Run:

```bash
swift test --filter CoreButtonMetrics
swift test --filter AsyncButton
```

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift Tests/CoreDesignTests/ButtonStyleDefaultTests.swift
git commit -m "feat: make button glass opt-in"
```

---

## Task 4: Deprecate EmptyState With Native Migration Guidance

**Files:**
- Modify: `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`
- Create: `Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`

- [ ] **Step 1: Write compile-preservation test**

Create `Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`:

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

- [ ] **Step 2: Run test before deprecation**

Run:

```bash
swift test --filter "EmptyState deprecation"
```

Expected: test passes. This confirms the compatibility baseline before adding annotations.

- [ ] **Step 3: Add deprecation annotations**

Edit `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`.

Add this deprecation to the public struct:

```swift
@available(
    *,
    deprecated,
    message: "Use SwiftUI ContentUnavailableView for empty states. Compose CoreDesign buttons inside ContentUnavailableView actions when needed."
)
public struct EmptyState<Action: View>: View {
```

Add the same `@available` annotation to these public convenience initializers:

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

Update the file-level doc comment near the top to begin with:

```swift
/// Deprecated compatibility empty-state view.
///
/// Prefer SwiftUI `ContentUnavailableView` for new empty, unavailable, and
/// no-results states. This component remains available during the current major
/// version only as a compatibility wrapper for existing callers.
```

- [ ] **Step 4: Run test to verify compatibility remains**

Run:

```bash
swift test --filter "EmptyState deprecation"
```

Expected: test passes. Deprecation warnings are acceptable.

- [ ] **Step 5: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/CoreDesign/Components/EmptyState/EmptyState.swift Tests/CoreDesignTests/EmptyStateDeprecationTests.swift
git commit -m "docs: deprecate empty state component"
```

---

## Task 5: Phase 1 Verification

**Files:**
- Read: `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`
- Verify: all files changed by Tasks 1-4

- [ ] **Step 1: Run all tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 2: Check for accidental global glass defaults**

Run:

```bash
rg "glass: Bool = true|\\.buttonStyle\\(\\.solid\\(|\\.buttonStyle\\(\\.light\\(" Sources/CoreDesign App/Sources Tests/CoreDesignTests
```

Expected:

- no `glass: Bool = true` in `SolidButtonStyle.swift` or `LightButtonStyle.swift`
- app previews may still call `.solid(...)` or `.light(...)`, but those now resolve to non-glass defaults

- [ ] **Step 3: Check EmptyState remains public but deprecated**

Run:

```bash
rg "deprecated.*ContentUnavailableView|public struct EmptyState|ContentUnavailableView" Sources/CoreDesign/Components/EmptyState/EmptyState.swift
```

Expected: output includes the `@available(... deprecated ...)` annotation, `public struct EmptyState`, and `ContentUnavailableView` migration guidance.

- [ ] **Step 4: Check surface roles exist**

Run:

```bash
rg "case content|case control|case floating|case overlay" Sources/CoreDesign/Modifier/SurfaceModifier.swift
```

Expected: all four cases are present.

- [ ] **Step 5: Inspect changed previews in Xcode or package build**

Run:

```bash
swift build
```

Expected: build succeeds. Then inspect SwiftUI previews manually for:

- `Surface — Light`
- `Surface — Dark`
- `Solid — default`
- `Solid — explicit glass`
- `Light — default`
- `Light — explicit glass`

- [ ] **Step 6: Confirm no extra verification changes are pending**

Run:

```bash
git status --short
```

Expected: no uncommitted changes. If this command shows files, inspect them with
`git diff` and either commit task-scoped changes using an exact file list or
restore only changes made by the implementation task. Do not revert user-owned
unrelated changes.

---

## Handoff Notes

- This plan intentionally does not implement Phase 2 component resets.
- Keep commits small and task-scoped.
- Do not remove `EmptyState` in Phase 1.
- Do not rename `TelegramGlassButtonModifier` in Phase 1; it remains the compatibility implementation for explicit glass buttons.
- If `FloatingGlassModifier` conflicts with actual Liquid Glass API signatures in the active SDK, adapt the modifier body to the compiler while preserving the public `floatingGlass(in:isInteractive:)` API and tests.
