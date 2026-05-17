# Craft Workbench Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle CoreDesign toward a Craft-like editorial workbench while preserving blue interaction color, public APIs, and light/dark support.

**Architecture:** Use a token-led approach: first lock the component inventory, then update semantic surfaces/borders/elevation, then align the Preview App and component implementations. Component edits must consume existing semantic tokens where possible rather than hard-coding one-off colors.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, Swift Testing, Xcode asset catalogs, existing preview/snapshot scripts.

---

### Task 1: Component Inventory And Baseline Tests

**Files:**
- Create: `docs/superpowers/plans/2026-05-16-craft-workbench-component-inventory.md`
- Test: existing `Tests/CoreDesignTests/*`

- [ ] **Step 1: Create the component inventory document**

Create `docs/superpowers/plans/2026-05-16-craft-workbench-component-inventory.md` with this exact component review list:

```markdown
# Craft Workbench Component Inventory

Date: 2026-05-16

## Sources Checked

- `docs/README.md`
- `docs/components/`
- `App/Sources/Previews.swift`
- `App/Sources/ComponentData.swift`

## High Impact

- Button
- AsyncButton
- SegmentedControl
- SearchField
- SidebarRow
- ListRow
- CommentCard
- BottomInputBar
- Toast
- Banner
- BookCover

## Medium Impact

- Tag
- Badge
- StateLabel
- StatusRow
- EventRow
- TimelineItem
- RefPill
- ProgressBar
- ProgressIndicator
- AvatarGroup
- UnderlinedTabBar

## Low Impact

- Avatar
- FlowLayout
- Form Icons
- EmptyState migration surface

## Execution Rule

Every item above must be either adjusted or explicitly left unchanged in the final implementation summary.
```

- [ ] **Step 2: Run baseline tests**

Run: `swift test`

Expected: existing tests pass before visual changes begin. If they fail, stop and record the existing failure before editing style files.

- [ ] **Step 3: Commit inventory**

Run:

```bash
git add docs/superpowers/plans/2026-05-16-craft-workbench-component-inventory.md
git commit -m "Add Craft workbench component inventory"
```

### Task 2: Warm Workbench Surface And Border Tokens

**Files:**
- Modify: `Sources/CoreDesign/Resources/Resources.xcassets/canvas/canvas-default.colorset/Contents.json`
- Modify: `Sources/CoreDesign/Resources/Resources.xcassets/canvas/canvas-subtle.colorset/Contents.json`
- Modify: `Sources/CoreDesign/Resources/Resources.xcassets/canvas/canvas-inset.colorset/Contents.json`
- Modify: `Sources/CoreDesign/Colors/SurfaceColors.swift`
- Modify: `Sources/CoreDesign/Colors/BorderColors.swift`
- Test: `Tests/CoreDesignTests/SurfaceKindTests.swift`

- [ ] **Step 1: Add a failing surface stability test**

Extend `Tests/CoreDesignTests/SurfaceKindTests.swift` with a test that asserts all public surface roles still construct after token tuning:

```swift
@Test("all surface roles construct after Craft token tuning")
func allSurfaceRolesConstructAfterCraftTokenTuning() {
    let roles: [SurfaceKind] = [
        .canvas,
        .content,
        .control,
        .floating,
        .overlay,
        .canvasSubtle,
        .panel,
        .sidebar,
        .card,
    ]

    #expect(roles.count == 9)
}
```

- [ ] **Step 2: Verify the new test fails or compiles red if inserted incorrectly**

Run: `swift test --filter SurfaceKind`

Expected: if the test was inserted incorrectly, fix it until it compiles and runs. If it passes because construction already exists, keep it as a regression guard for the token pass.

- [ ] **Step 3: Tune canvas asset colors**

Update the three canvas colorsets to these light/dark values:

- `canvas-default`: light `#FCFBF7`, dark `#11110F`
- `canvas-subtle`: light `#F3F0EA`, dark `#1A1916`
- `canvas-inset`: light `#F8F5EF`, dark `#0F0F0D`

Keep `alpha` at `1.000`, `idiom` as `universal`, and preserve existing dark luminosity appearance entries.

- [ ] **Step 4: Tune semantic surface aliases**

In `Sources/CoreDesign/Colors/SurfaceColors.swift`, keep `surfaceCanvas`, `surfaceCanvasSubtle`, and `surfaceCanvasInset` asset-backed. Change `surfacePanel`, `surfaceSidebar`, and `surfaceCard` to use the warm semantic surfaces instead of system grouped colors:

```swift
static var surfacePanel: Color {
    .surfaceCanvasSubtle
}

static var surfaceSidebar: Color {
    .surfaceCanvasSubtle
}

static var surfaceCard: Color {
    .surfaceCanvas
}
```

- [ ] **Step 5: Tune border opacity**

In `Sources/CoreDesign/Colors/BorderColors.swift`, reduce subtle/default visual weight by keeping the same system separator sources but changing semantic opacities:

```swift
static var borderSubtle: Color {
    .separator.opacity(0.28)
}

static var borderMuted: Color {
    .separator.opacity(0.42)
}
```

Leave `borderFocus`, `borderSelected`, and accent-related colors blue.

- [ ] **Step 6: Run token tests**

Run: `swift test --filter SurfaceKind`

Expected: PASS.

- [ ] **Step 7: Commit token changes**

Run:

```bash
git add Sources/CoreDesign/Resources/Resources.xcassets/canvas Sources/CoreDesign/Colors/SurfaceColors.swift Sources/CoreDesign/Colors/BorderColors.swift Tests/CoreDesignTests/SurfaceKindTests.swift
git commit -m "Tune surfaces for Craft workbench style"
```

### Task 3: Quieter Elevation And Glass Treatment

**Files:**
- Modify: `Sources/CoreDesign/Tokens/CoreElevation.swift`
- Modify: `Sources/CoreDesign/Modifier/FloatingGlassModifier.swift`
- Modify: `Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift`
- Modify: `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift`
- Modify: `Sources/CoreDesign/Components/BottomInputBar/MenuButton.swift`
- Test: `Tests/CoreDesignTests/FloatingGlassModifierTests.swift`

- [ ] **Step 1: Add a regression test for explicit glass availability**

Extend `Tests/CoreDesignTests/FloatingGlassModifierTests.swift` with:

```swift
@MainActor
@Test("interactive floating glass modifier constructs")
func interactiveFloatingGlassModifierConstructs() {
    let view = Text("Floating").floatingGlass(isInteractive: true)
    #expect(String(describing: type(of: view)).isEmpty == false)
}
```

- [ ] **Step 2: Run focused test**

Run: `swift test --filter FloatingGlassModifier`

Expected: PASS or compile red only from insertion mistakes. Fix insertion mistakes before production edits.

- [ ] **Step 3: Reduce ordinary elevation**

In `CoreElevation.spec(for:)`, keep `.none` unchanged. Tune the numeric specs:

- `.small`: radius `1`, y `0.5`
- `.medium`: radius `4`, y `2`
- `.large`: radius `12`, y `6`

Keep asset-backed shadow colors.

- [ ] **Step 4: Quiet floating glass border**

In `FloatingGlassModifier`, keep the API unchanged. Reduce the filled background opacity from `0.72` to `0.64`, and use `Color.borderSubtle` for the stroke instead of white-only stroke.

- [ ] **Step 5: Quiet existing glass components**

Review existing glass call sites in `SegmentedControl`, `BottomInputBar`, and `MenuButton`. Keep glass where already present, but reduce stacked opacity and avoid adding new glass to ordinary content. Prefer `Color.borderSubtle`/`Color.borderMuted` for strokes where white strokes look too glossy on warm surfaces.

- [ ] **Step 6: Run focused tests**

Run: `swift test --filter FloatingGlassModifier`

Expected: PASS.

- [ ] **Step 7: Commit elevation and glass changes**

Run:

```bash
git add Sources/CoreDesign/Tokens/CoreElevation.swift Sources/CoreDesign/Modifier/FloatingGlassModifier.swift Sources/CoreDesign/Components/SegmentedControl Sources/CoreDesign/Components/BottomInputBar Tests/CoreDesignTests/FloatingGlassModifierTests.swift
git commit -m "Quiet elevation and glass treatment"
```

### Task 4: Preview App Workbench Shell

**Files:**
- Modify: `App/Sources/ContentView.swift`
- Modify: `App/Sources/ComponentDetail.swift`
- Modify: `App/Sources/ComponentData.swift`

- [ ] **Step 1: Restyle sidebar rows**

In `ContentView.swift`, update `ComponentRow` so it has denser spacing, a quieter id line, and padding that reads like a document list item. Keep `NavigationLink` behavior unchanged.

- [ ] **Step 2: Restyle empty selection view**

In `PlaceholderView`, reduce the icon size from `48` to `32`, use a lighter symbol style, and keep the background `Color.surfaceCanvas`.

- [ ] **Step 3: Restyle detail header and preview panel**

In `ComponentDetail.swift`, make the header more compact and change the preview panel to use a workbench-style framed surface:

- header spacing: `CoreSpacing.xxs` to `CoreSpacing.xs`
- preview frame background: `Color.surfacePanel`
- individual light/dark wells: `Color.surfaceCanvas`
- border: `Color.borderMuted`
- radius: `CoreRadius.mediumPlus`

- [ ] **Step 4: Expand preview app registry if needed**

If `ComponentData.swift` does not expose snapshot-covered components such as `AsyncButton`, `ProgressBar`, `TimelineItem`, or `CommentCard`, leave code behavior unchanged but note the mismatch in the final implementation summary. Do not grow the app registry in this pass unless the preview app already has reusable preview views for those entries.

- [ ] **Step 5: Build/test app-facing code**

Run: `swift test`

Expected: PASS.

- [ ] **Step 6: Commit preview shell**

Run:

```bash
git add App/Sources/ContentView.swift App/Sources/ComponentDetail.swift App/Sources/ComponentData.swift
git commit -m "Restyle preview app workbench shell"
```

### Task 5: High-Impact Component Pass

**Files:**
- Modify as needed under `Sources/CoreDesign/Components/Button/`
- Modify as needed under `Sources/CoreDesign/Components/SegmentedControl/`
- Modify as needed under `Sources/CoreDesign/Components/SearchField/`
- Modify as needed under `Sources/CoreDesign/Components/SidebarRow/`
- Modify as needed under `Sources/CoreDesign/Components/ListRow/`
- Modify as needed under `Sources/CoreDesign/Components/CommentCard/`
- Modify as needed under `Sources/CoreDesign/Components/BottomInputBar/`
- Modify as needed under `Sources/CoreDesign/Components/Toast/`
- Modify as needed: `Sources/CoreDesign/Components/Banner.swift`
- Modify as needed under `Sources/CoreDesign/Components/BookCover/`
- Test: existing focused component tests

- [ ] **Step 1: Audit high-impact components**

For each high-impact component, inspect whether it uses semantic tokens or hard-coded system surfaces. Change only visible conflicts with the workbench style:

- ordinary content should use `surfaceCanvas`, `surfaceCanvasSubtle`, `surfaceCard`, or `surfacePanel`
- selected/hover states should remain blue only where they represent interaction/focus
- content cards should avoid `.coreShadow(.medium)` unless object-like or floating
- glass should remain only where already part of the component concept

- [ ] **Step 2: Run focused tests**

Run:

```bash
swift test --filter Button
swift test --filter SegmentedControl
swift test --filter SearchField
swift test --filter SidebarRow
swift test --filter ListRow
swift test --filter CommentCard
swift test --filter BottomInputBar
swift test --filter Toast
swift test --filter Banner
swift test --filter BookCover
```

Expected: each available filter passes. If a filter matches no tests, record that in the final summary.

- [ ] **Step 3: Commit high-impact component changes**

Run:

```bash
git add Sources/CoreDesign/Components Tests/CoreDesignTests
git commit -m "Align high-impact components with Craft workbench"
```

### Task 6: Medium And Low Impact Component Pass

**Files:**
- Modify as needed under `Sources/CoreDesign/Components/`
- Modify as needed: `App/Sources/Previews.swift`

- [ ] **Step 1: Audit medium-impact components**

Review Tag, Badge, StateLabel, StatusRow, EventRow, TimelineItem, RefPill, ProgressBar, ProgressIndicator, AvatarGroup, and UnderlinedTabBar. Adjust only token usage, border weight, radius, and spacing needed for consistency.

- [ ] **Step 2: Audit low-impact components**

Review Avatar, FlowLayout, Form Icons, and EmptyState migration surface. Leave them unchanged unless they visibly conflict with the workbench style.

- [ ] **Step 3: Run full tests**

Run: `swift test`

Expected: PASS.

- [ ] **Step 4: Commit remaining component changes**

Run:

```bash
git add Sources/CoreDesign/Components App/Sources/Previews.swift Tests/CoreDesignTests
git commit -m "Calibrate remaining components for Craft workbench"
```

### Task 7: Snapshot And Final Verification

**Files:**
- Modify: `docs/snapshots/*` if snapshot generation succeeds and image diffs are intended
- Modify: `docs/README.md` only if snapshot references or component inventory changed

- [ ] **Step 1: Run full test suite**

Run: `swift test`

Expected: PASS.

- [ ] **Step 2: Run snapshot workflow**

Run: `scripts/run-snapshots.sh`

Expected: snapshot images update to the intended Craft workbench styling. If the script fails due simulator or local tooling, record the exact failure in the final summary and do not claim snapshot verification passed.

- [ ] **Step 3: Inspect git diff**

Run: `git status --short`

Expected: only intended source, asset, test, plan, and snapshot files are changed.

- [ ] **Step 4: Commit final verification artifacts**

If snapshots changed intentionally, run:

```bash
git add docs/snapshots docs/README.md
git commit -m "Update snapshots for Craft workbench restyle"
```

If no snapshots changed or snapshot generation was unavailable, skip this commit and record why.

---

## Plan Self-Review

- Spec coverage: token work, Preview App, full component inventory, API stability, light/dark support, glass treatment, tests, and snapshots are each mapped to tasks.
- Red-flag scan: no incomplete implementation markers are present.
- Type consistency: file paths and type names match current repository structure.
