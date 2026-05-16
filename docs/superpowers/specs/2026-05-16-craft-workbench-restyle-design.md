# Craft Workbench Restyle Design

Date: 2026-05-16

## Goal

Move CoreDesign's overall visual style toward a Craft-like editorial workbench while preserving the library's Primer/GitHub-informed structure and blue interaction color.

The target style is warm, calm, dense enough for real tools, and restrained. It should feel like a document/editor workspace rather than a marketing surface, a beige stationery theme, or a glass-first iOS demo.

## Decisions

- Direction: Craft-inspired editorial workbench.
- Accent: keep the existing blue accent family for primary actions, links, selection emphasis, and focus.
- Glass: preserve existing glass components where they already make sense, but quiet their color, border, and shadow treatment.
- Scope: inspect and align all documented components, not only the preview app.
- Strategy: token-led restyle first, component adjustments second. Do not introduce a theme system.

## Non-Goals

- Do not replace the Primer-aligned semantic token model.
- Do not introduce runtime theme switching.
- Do not redesign public component APIs unless a style fix is impossible without it.
- Do not make the interface dominated by beige, brown, purple, gradients, or decorative glass.
- Do not add broad animation work.

## Global Style

Surfaces should shift from cool system gray toward a subtle warm gray paper/workbench palette. The warmth should be visible in sidebars, panels, and cards, but neutral enough that blue primary actions still feel natural.

Hierarchy should come mainly from surface contrast, borders, and spacing. Shadows should be reduced for ordinary content containers and reserved for true floating surfaces, overlays, toasts, bottom bars, and object-like content such as book covers.

Corner radii should remain compact:

- Controls and small surfaces: 3-6 pt.
- Cards and preview panes: 6-8 pt.
- Floating surfaces: up to 12 pt.
- Pills and avatars: full radius.

Dark mode should remain a neutral dark workspace. It may receive subtle warm-gray bias in surfaces, but should not become brown or sepia.

## Token Work

Update the foundation before component-specific edits:

- `SurfaceColors`: tune `surfaceCanvas`, `surfaceCanvasSubtle`, `surfaceCanvasInset`, `surfacePanel`, `surfaceSidebar`, and `surfaceCard` toward warm neutral workbench values.
- `BorderColors`: make muted/default borders fit the new warmer surfaces without becoming visually heavy.
- `CoreElevation`: reduce ordinary resting elevation; keep stronger elevation for floating/overlay cases.
- `SurfaceModifier`: keep the public `SurfaceKind` API stable. Adjust mappings only if needed to express the new hierarchy.
- Asset colors: update or add xcassets only where semantic colors need fixed light/dark values.

The blue accent family remains the interaction backbone.

## Preview App

The preview app should become the first clear expression of the Craft workbench direction.

- Sidebar: use a warmer sidebar background, clearer selection state, and denser document-list behavior.
- Detail canvas: make the page feel like an editor work area with compact heading treatment and a quieter description style.
- Preview panes: retain side-by-side light/dark comparison, but make the frame feel like a workbench panel instead of a test box.
- Empty state: reduce visual weight so it does not compete with component previews.

## Component Pass

All documented components should be reviewed. The depth of edits depends on visual impact.

High-impact components get targeted visual changes:

- Button
- SegmentedControl
- SearchField
- SidebarRow
- ListRow
- CommentCard
- BottomInputBar
- Toast
- Banner
- BookCover

These should be checked for background color, border weight, hover/selected treatment, glass strength, shadow, and density.

Medium-impact components get consistency calibration:

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

These should primarily align color hierarchy, border weight, radius, and spacing.

Low-impact components get a consistency review:

- Avatar
- FlowLayout
- Form icons and similar utility examples

Only change these if they visibly conflict with the new style.

## Behavior And API Constraints

- Public APIs should remain stable.
- Existing light and dark support must remain.
- Existing interaction behavior must remain unless a bug is found during implementation.
- Accessibility should not regress: text contrast, focus visibility, and tappable control size must remain acceptable.
- Snapshot changes are expected. Behavioral tests should continue to pass.

## Verification

Implementation should be verified with:

- `swift test`
- The existing preview or snapshot workflow.
- A visual review of all documented component previews in light and dark mode.

The visual review should specifically check for:

- Cold-gray surfaces left over in major containers.
- Overly beige or brown page-level appearance.
- Overly strong glass on ordinary content.
- Heavy shadows on non-floating content.
- Text clipping or layout shifts in compact controls.
- Border conflicts where nested surfaces meet.

## Acceptance Criteria

- The preview app reads as a warm editorial workbench while still feeling like CoreDesign.
- Blue remains the primary interaction and focus color.
- Ordinary cards and rows rely more on surface and border hierarchy than shadow.
- Existing glass components feel quieter but still intentional.
- Every documented component has been reviewed and either adjusted or explicitly left unchanged.
- Tests pass, and updated snapshots reflect the intended restyle.
