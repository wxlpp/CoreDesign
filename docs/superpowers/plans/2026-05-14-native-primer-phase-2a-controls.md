# Native Primer Phase 2A Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reset the core control components to the Native Primer baseline: practical non-glass buttons, a quiet native segmented control, and an inset native search field.

**Architecture:** Phase 1 established shared surface roles and made button glass opt-in. Phase 2A applies that baseline to the highest-impact control components without touching navigation rows, badges, tags, or content components. Visual changes stay internal and preserve public APIs.

**Tech Stack:** Swift 6.3, SwiftUI, Swift Testing, iOS 26/macOS 26 package targets.

---

## Source Spec

Read before implementing:

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`

This plan covers the Phase 2 controls subset only:

- Button / AsyncButton
- SegmentedControl
- SearchField

Do not modify `ListRow`, `SidebarRow`, `UnderlinedTabBar`, `Badge`, `Tag`, or `StateLabel` in this plan.

## File Structure

Modify:

- `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
  - Refine non-glass default background to be a practical Native Primer control.
  - Keep explicit `glass: true` path unchanged.
- `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
  - Refine non-glass default background to be a practical secondary control.
  - Keep explicit `glass: true` path unchanged.
- `Sources/CoreDesign/Components/Button/AsyncButton.swift`
  - Update previews/docs text only if needed to reflect non-glass default styles.
  - Do not change async behavior.
- `Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift`
  - Move from old “no glass” Primer text to Native Primer language.
  - Use quiet control surface + lightly raised selected thumb.
  - Keep public API unchanged.
- `Sources/CoreDesign/Components/SearchField/SearchField.swift`
  - Align container with `.surface(.control)`/inset control treatment.
  - Keep public API unchanged and do not add glass.
- `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`
  - Extend existing default tests if needed.
- `Tests/CoreDesignTests/SegmentedControlTests.swift`
  - New compile tests for 2-item and 3-item construction.
- `Tests/CoreDesignTests/SearchFieldTests.swift`
  - New compile/behavior tests for construction.

---

## Task 1: Refine Non-Glass Button Defaults

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
- Modify: `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
- Modify: `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`

- [ ] **Step 1: Write tests for concrete non-glass default semantics**

Extend `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift` with:

```swift
@Test("concrete button styles default to non-glass")
func concreteButtonStylesDefaultToNonGlass() {
    #expect(ButtonStyleDefaultProbe.solidDefaultGlass == false)
    #expect(ButtonStyleDefaultProbe.lightDefaultGlass == false)
}

private enum ButtonStyleDefaultProbe {
    static var solidDefaultGlass: Bool {
        SolidButtonStyle().glass
    }

    static var lightDefaultGlass: Bool {
        LightButtonStyle().glass
    }
}
```

This test intentionally probes the concrete style structs. SwiftUI `ButtonStyle`
extension return values are not directly introspectable after they are passed to
`.buttonStyle(...)`.

- [ ] **Step 2: Run test to verify current behavior**

Run:

```bash
swift test --filter ButtonStyleDefaultTests
```

Expected: tests pass. This is a guard before visual refinement.

- [ ] **Step 3: Refine SolidButtonStyle non-glass modifier**

In `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`, update `SolidButtonBackgroundModifier.body` to:

```swift
func body(content: Content) -> some View {
    content
        .background(
            Capsule(style: .continuous)
                .fill(self.backgroundColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.hairline)
        )
        .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
        .opacity(self.isPressed ? 0.92 : 1)
        .animation(.snappy(duration: 0.16), value: self.isPressed)
}
```

Rationale: the default solid style should be a practical control surface, not a floating/elevated control. Explicit `glass: true` remains available for elevated/floating use.

- [ ] **Step 4: Refine LightButtonStyle non-glass modifier**

In `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`, update `LightButtonBackgroundModifier.body` to:

```swift
func body(content: Content) -> some View {
    content
        .background(
            Capsule(style: .continuous)
                .fill(Color.surfaceInteractive)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
        )
        .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
        .animation(.snappy(duration: 0.16), value: self.isPressed)
}
```

Rationale: remove default elevation from secondary controls while preserving pressed feedback.

- [ ] **Step 5: Run targeted tests**

Run:

```bash
swift test --filter ButtonStyleDefaultTests
swift test --filter AsyncButton
swift test --filter CoreButtonMetrics
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift Tests/CoreDesignTests/ButtonStyleDefaultTests.swift
git commit -m "refactor: quiet default button surfaces"
```

---

## Task 2: Reset SegmentedControl To Native Primer Control

**Files:**
- Modify: `Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift`
- Create: `Tests/CoreDesignTests/SegmentedControlTests.swift`

- [ ] **Step 1: Write compile/behavior tests**

Create `Tests/CoreDesignTests/SegmentedControlTests.swift`:

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SegmentedControl")
struct SegmentedControlTests {
    @MainActor
    @Test("segmented control constructs with two items")
    func segmentedControlConstructsWithTwoItems() {
        let selection = Binding.constant("One")
        let control = SegmentedControl(
            items: ["One", "Two"],
            selection: selection,
            title: { $0 }
        )

        #expect(String(describing: type(of: control)).isEmpty == false)
    }

    @MainActor
    @Test("segmented control constructs with three items")
    func segmentedControlConstructsWithThreeItems() {
        let selection = Binding.constant("A")
        let control = SegmentedControl(
            items: ["A", "B", "C"],
            selection: selection,
            title: { $0 }
        )

        #expect(String(describing: type(of: control)).isEmpty == false)
    }
}
```

- [ ] **Step 2: Run tests before implementation**

Run:

```bash
swift test --filter SegmentedControlTests
```

Expected: tests pass. They provide a compile-preservation baseline before visual changes.

- [ ] **Step 3: Update documentation comment**

In `Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift`, replace the old comments that say the component “复刻 Primer thumb” and “不使用 `.glassEffect`” with Native Primer language:

```swift
/// Native Primer segmented control.
///
/// The component keeps GitHub-like utility and density while rendering as an
/// Apple-native control surface. The base stays quiet; only the selected segment
/// gets a lightly raised thumb. This is a control-layer component, so it does
/// not use Liquid Glass by default.
```

Keep the rest of the API documentation concise and accurate.

- [ ] **Step 4: Update body surface treatment**

In `body`, replace the current `.background` block with a control surface that includes a subtle border:

```swift
.background(
    RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
        .fill(Color.surfaceInteractive)
)
.overlay(
    RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
        .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
)
```

Keep:

```swift
.padding(CoreSpacing.xxs)
.frame(height: CoreControlMetrics.height(for: .regular))
.sensoryFeedback(.selection, trigger: self.selection)
```

- [ ] **Step 5: Update selected thumb**

In `segment(for:)`, update selected thumb fill from `Color.surfaceRaised` to `Color.surfaceCanvas` and keep the small shadow:

```swift
RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)
    .fill(Color.surfaceCanvas)
    .overlay {
        RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)
            .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
    }
    .coreShadow(.small)
    .matchedGeometryEffect(id: "SegmentedControl.thumb", in: self.namespace)
```

Do not add Liquid Glass to the segmented control.

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter SegmentedControlTests
swift test
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift Tests/CoreDesignTests/SegmentedControlTests.swift
git commit -m "refactor: reset segmented control surface"
```

---

## Task 3: Align SearchField With Control Surface Rules

**Files:**
- Modify: `Sources/CoreDesign/Components/SearchField/SearchField.swift`
- Create: `Tests/CoreDesignTests/SearchFieldTests.swift`

- [ ] **Step 1: Write compile tests**

Create `Tests/CoreDesignTests/SearchFieldTests.swift`:

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SearchField")
struct SearchFieldTests {
    @MainActor
    @Test("search field constructs with default placeholder")
    func searchFieldConstructsWithDefaultPlaceholder() {
        let field = SearchField(text: .constant(""))
        #expect(String(describing: type(of: field)).isEmpty == false)
    }

    @MainActor
    @Test("search field constructs with submit handler")
    func searchFieldConstructsWithSubmitHandler() {
        let field = SearchField(text: .constant("query"), placeholder: "Filter") { submitted in
            #expect(submitted == "query")
        }

        #expect(String(describing: type(of: field)).isEmpty == false)
    }
}
```

- [ ] **Step 2: Run tests before implementation**

Run:

```bash
swift test --filter SearchFieldTests
```

Expected: tests pass. They provide a compile-preservation baseline.

- [ ] **Step 3: Update documentation comment**

In `Sources/CoreDesign/Components/SearchField/SearchField.swift`, update the top comment from “GitHub Primer 风格” to Native Primer wording:

```swift
/// Native Primer search field.
///
/// A compact Apple-native search/filter control with GitHub-like utility:
/// leading search icon, optional clear action, clear focus ring, and no default
/// Liquid Glass.
```

Keep parameter documentation accurate.

- [ ] **Step 4: Update shape radius and fill**

Change:

```swift
let shape = RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
```

to:

```swift
let shape = RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)
```

Change background fill from:

```swift
shape.fill(Color.surfaceCanvasInset)
```

to:

```swift
shape.fill(Color.surfaceInteractive)
```

Change focus ring corner radius from `CoreRadius.medium` to `CoreRadius.small`.

Rationale: SearchField is a control-layer component. It should look like a compact native input, not a rounded card.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter SearchFieldTests
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/CoreDesign/Components/SearchField/SearchField.swift Tests/CoreDesignTests/SearchFieldTests.swift
git commit -m "refactor: align search field control surface"
```

---

## Task 4: Phase 2A Verification

**Files:**
- Verify: all files changed by Tasks 1-3

- [ ] **Step 1: Run all tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 2: Run build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 3: Check for accidental Liquid Glass usage in control-layer components**

Run:

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/SegmentedControl Sources/CoreDesign/Components/SearchField Sources/CoreDesign/Components/Button/styles
```

Expected:

- `SegmentedControl` has no matches.
- `SearchField` has no matches.
- Button style matches are allowed only in explicit `glass == true` branches or `.circularGlass`.

- [ ] **Step 4: Check changed previews exist**

Run:

```bash
rg "#Preview|Solid — default|Light — default|SegmentedControl|SearchField" Sources/CoreDesign/Components/Button Sources/CoreDesign/Components/SegmentedControl Sources/CoreDesign/Components/SearchField
```

Expected: previews for button styles, segmented control, and search field are still present.

- [ ] **Step 5: Confirm clean status**

Run:

```bash
git status --short
```

Expected: no uncommitted changes.

---

## Handoff Notes

- This plan intentionally does not touch navigation/content/status components.
- Do not reintroduce default glass for `.solid` or `.light`.
- Do not add Liquid Glass to `SegmentedControl` or `SearchField`.
- If visual review later finds the search field too flat, adjust within control-layer tokens first; do not make it floating glass.
