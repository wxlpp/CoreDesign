# Execution Status — coredesign-v2-tokens epic

**Status**: ✅ COMPLETED (9/9 tasks merged, 2026-05-09)

## Completed PRs

| Issue | Task | PR | Merge SHA |
|---|---|---|---|
| #2 | Primer 版本锁定 + 标量 token | #11 | b3b0f81 |
| #3 | CoreTypography | #13 | 99d35bc |
| #4 | CoreElevation + dark-adaptive shadow colorset | #14 | (squash) |
| #5 | CoreControlMetrics | #18 | 2146726 |
| #6 | 语义色补全 + Color.focusRing 重命名 | #15 | b5af509 |
| #7 | SurfaceModifier | #16 | (squash) |
| #8 | FocusRingModifier 文件骨架 + iOS | #17 | (squash) |
| #9 | FocusRingModifier macOS NSFocusRing | #19 | b794b21 |
| #10 | BorderModifier canary | #12 | e3ed641 |

## Notable outcomes

- **#9 spike fallback**: NSFocusRing system integration on macOS was technically clean (Swift 6 + build) but architecturally incompatible with SwiftUI `@FocusState` (first-responder hijack). Fell back to overlay; PRD SC #11 limitation documented in file header.
- **#5 escape hatch added**: `primerVerticalPadding(for:)` (returns Primer paddingBlock 2/4/6/10/14) added on top of the default `verticalPadding(for:)` (CoreSpacing-rounded 2/4/8/12/16) — enables strict-Primer-height path without forcing magic numbers into call sites.
- **Total PR rounds**: ~22 Copilot premium requests across 9 PRs (avg ~2.5 rounds per PR).

## Epic close-out actions remaining

- [ ] Close epic GitHub issue #1
- [ ] Optionally archive `.claude/epics/coredesign-v2-tokens/` to `.claude/epics/archived/`
- [ ] Notify downstream consumers (any-writer) that v2-tokens are now on main
