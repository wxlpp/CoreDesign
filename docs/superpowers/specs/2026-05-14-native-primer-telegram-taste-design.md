# Native Primer, Telegram Taste Design

Date: 2026-05-14

## Context

CoreDesign currently claims GitHub Primer as a visual north star, but the
implemented components do not feel close to GitHub's online product UI. Several
parts also lean into custom glass styling before the base system has a coherent
native foundation.

The new direction is a full visual reset:

- Use GitHub/Primer for structure, density, and state semantics.
- Use Apple native platform rendering for material, interaction, accessibility,
  and system consistency.
- Use Telegram as a taste reference for restraint, lightness, floating layers,
  and short, smooth motion.

This is not a GitHub clone and not a Telegram skin. The target is an Apple-native
design system with GitHub's practical information model and Telegram's restraint.

## Design Principles

### 1. Layered Material Rules

CoreDesign separates UI into three material layers.

**Content layer**

Content components do not use Liquid Glass by default. This includes list rows,
forms, table-like rows, timeline content, and ordinary card content. They should
remain quiet, scannable, and stable.

Examples:

- `ListRow`
- `Form`
- `TimelineItem` content
- `StatusRow`
- `EventRow`

**Control layer**

Controls use native depth, not default Liquid Glass. They may use system fill,
separator borders, selected states, hover states, pressed states, and restrained
shadows. Their first job is clarity and repeated use.

Examples:

- `Button`
- `AsyncButton`
- `SegmentedControl`
- `SearchField`
- `SidebarRow`
- `UnderlinedTabBar`
- `Badge`
- `Tag`
- `StateLabel`

**Floating layer**

Only floating or overlay UI uses true iOS 26 Liquid Glass by default. These
surfaces sit above content and can carry Telegram-like translucency and motion.

Examples:

- `BottomInputBar`
- floating icon buttons
- popovers and menus
- `Toast`
- floating toolbars

Material layers and surface roles are separate dimensions. The material layer
answers "how much visual treatment is allowed"; the surface role answers "what
semantic background/border token should be used." Surface roles may include
`canvas`, `content`, `control`, `floating`, and `overlay`, but these are not
additional material layers.

Initial mapping:

| Component family | Material layer | Surface role |
|---|---|---|
| page backgrounds | content | canvas |
| rows and ordinary content | content | content |
| buttons and fields | control | control |
| navigation rows and tabs | control | control |
| toasts and floating toolbars | floating | floating |
| popovers and menus | floating | overlay |
| bottom input bar | floating | floating |

### 2. Button Defaults

`ButtonStyle.solid` and `ButtonStyle.light` should not default to glass. They
should be practical native controls with Primer-like semantics:

- clear role colors
- predictable borders
- compact density
- visible disabled and pressed states

Glass remains available for floating controls, such as `.circularGlass`, bottom
input actions, and overlay-specific actions.

Phase 1 acceptance criteria:

- `SolidButtonStyle(role:glass:)` defaults `glass` to `false`.
- `LightButtonStyle(role:glass:)` defaults `glass` to `false`.
- `.solid(role:)` and `.light(role:)` convenience APIs produce non-glass styles
  by default.
- Existing glass button visuals remain available only through explicit
  `glass: true` or floating-specific styles such as `.circularGlass`.

### 3. Radius And Density

CoreDesign should avoid a uniformly rounded, toy-like appearance.

- Content rows stay compact and are not cardified by default.
- Ordinary cards, banners, and comment containers use restrained radii near 8 pt.
- Standard controls use compact heights and moderate radii.
- Floating surfaces, bottom input bars, and circular actions can use larger radii
  or pill geometry.

Control sizing should respect Apple touch ergonomics while keeping GitHub-like
information density where safe.

### 4. Color Strategy

Primer owns semantic naming; Apple owns platform rendering.

CoreDesign should keep semantics such as primary, muted, border, canvas, success,
warning, danger, selected, and disabled. The actual rendering should be
platform-native where appropriate instead of mechanically copying web hex values.

Rules:

- High-frequency content remains low saturation.
- Color is reserved for state, selection, status, and primary actions.
- Liquid Glass surfaces allow environmental color and material to participate.
- Status colors remain explicit enough for GitHub-like practical scanning.

### 5. Motion And Interaction

Motion should feel short, precise, and native:

- pressed states should be immediate and subtle
- selected states can use matched geometry where it improves continuity
- floating glass controls may use interactive glass
- content rows should avoid decorative animation

## Component Direction

### System Baseline

Update shared visual primitives before rewriting individual components:

- redefine surface roles around content, control, floating, overlay, and canvas
- centralize native border, shadow, pressed, selected, and glass behavior
- keep Liquid Glass in a small set of explicit modifiers
- remove default glass from ordinary button styles

### Controls

`Button` / `AsyncButton`

- Default styles become non-glass native controls.
- `solid` represents primary or destructive actions with strong role clarity.
- `light` represents secondary actions with border/fill clarity.
- `borderless` remains text-like and low chrome.
- `circularGlass` remains reserved for floating icon actions.

`SegmentedControl`

- Keeps compact GitHub-like utility.
- Uses a quiet native base.
- Selected segment may have a lightly raised or material-aware thumb, but should
  not make the whole control glass.
- Maintains short, precise selection motion and selection feedback.

`SearchField`

- Should look native and utilitarian.
- Uses inset/control surface behavior, clear focus state, and predictable clear
  affordance.
- Does not use default glass.

`ListRow`

- Remains content-layer UI.
- No default glass and no default cardification.
- Uses clear hover, selected, and pressed states where available.

`SidebarRow` / `UnderlinedTabBar`

- Stay navigational and scannable.
- Selected state should be unmistakable but low-noise.
- No global glass treatment.

`Badge` / `Tag` / `StateLabel`

- Keep compact status semantics.
- Use color for meaning, not decoration.
- Avoid heavy shadows and decorative material.

### Floating And Feedback

`Toast`

- Moves to the floating layer.
- Can use Liquid Glass and restrained elevation.
- Keeps text clear and actions compact.

`BottomInputBar`

- Remains the strongest Telegram-like surface in the library.
- Uses iOS 26 Liquid Glass, grouped glass rendering, and interactive floating
  actions.
- Should still prioritize input ergonomics over visual effect.

`Banner`

- Remains content/control layer, not full glass.
- Uses status semantics and restrained bordered or filled treatment.

### Content Components

`CommentCard`, `EventRow`, `TimelineItem`, and `StatusRow`

- Use content-layer rules.
- Preserve density and readability.
- Add polish through spacing, borders, typography, and selected/hover states
  rather than glass.

`ProgressBar` / `ProgressIndicator`

- Keep practical status readability.
- Avoid decorative material.

`Avatar` / `AvatarGroup`

- Keep compact identity affordances.
- Refine borders, overlap, and contrast if needed, but do not introduce glass.

`BookCover`

- Keep as a content visual.
- Preserve image-first presentation and restrained border/shadow.

### Deprecated Components

`EmptyState` is deprecated instead of visually reset. Because it is currently a
public component, deprecation must be staged rather than removed immediately.

Rationale: SwiftUI and UIKit already provide native unavailable-content views:

- SwiftUI `ContentUnavailableView`
- UIKit `UIContentUnavailableView`
- UIKit `UIContentUnavailableConfiguration`

CoreDesign should stop investing in custom empty-state visuals. Existing callers
should migrate to system unavailable-content APIs. If action styling is needed,
callers can compose native unavailable views with CoreDesign buttons.

Deprecation plan:

1. Phase 1 marks `EmptyState` APIs as deprecated with migration guidance to
   `ContentUnavailableView`.
2. Phase 3 removes `EmptyState` from previews, component registry, and docs as a
   recommended component.
3. Existing source remains as a compatibility wrapper during the current major
   version. It should not receive new visual styling beyond fixes required to
   keep builds healthy.
4. Removal is deferred to the next explicitly planned breaking-change cycle.

## Implementation Phases

### Phase 1: System Baseline

- Update surface roles and shared modifiers.
- Remove default glass from ordinary button styles.
- Add explicit floating glass primitives.
- Define shared pressed, selected, hover, border, radius, and shadow rules.
- Mark `EmptyState` deprecated with native `ContentUnavailableView` migration
  guidance.

### Phase 2: Foundation Components

- Button and AsyncButton
- SegmentedControl
- SearchField
- ListRow
- SidebarRow
- UnderlinedTabBar
- Badge
- Tag
- StateLabel

### Phase 3: Full Component Pass

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
- Deprecate EmptyState and update docs/previews

## Non-Goals

- Do not mechanically clone GitHub web CSS.
- Do not apply Liquid Glass globally.
- Do not make every component look like Telegram.
- Do not introduce broad API churn where visual changes can stay internal.
- Do not continue custom `EmptyState` investment.

## Validation

Each phase should include:

- Swift test coverage for public API and behavior that changes
- preview/snapshot updates for visual components
- focused visual review in light and dark appearances
- explicit check that content-layer components remain readable and low-noise
- explicit check that floating-layer components are visually distinct but not
  overpowering

Minimum visual state matrix:

| Component family | Required states |
|---|---|
| buttons | default, pressed, disabled, loading where applicable, destructive, primary, secondary |
| segmented control | default, selected, pressed, disabled if supported, 2-item and 3+-item layouts |
| fields | empty, filled, focused, disabled, validation/error if supported |
| rows/navigation | default, hover, selected, pressed, disabled if supported |
| badges/tags/status | every semantic variant in light and dark appearance |
| floating surfaces | default, appearing, disappearing, action pressed, reduce motion |
| content cards | default, long content, compact width, dark appearance |

Accessibility and platform checks:

- Dynamic Type at default and at least one larger size.
- Reduce Motion enabled for animated components.
- Light and dark appearances.
- Keyboard/focus accessibility where controls accept input.
- Public API defaults verified by tests when a default changes, especially
  button `glass` defaults and `EmptyState` deprecation availability.
