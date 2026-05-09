# Execution Status — coredesign-v2-tokens epic

**Last update**: 2026-05-09T18:14:00Z (Layer 2 PRs opened, awaiting Copilot Round 1)

## Active PRs (Round 1 review pending)

| Issue | Task | PR | Branch | Commit | Round 1 status |
|---|---|---|---|---|---|
| #3 | CoreTypography | [#13](https://github.com/wxlpp/CoreDesign/pull/13) | `task/3-typography` | `ddd7ed4` | polling |
| #4 | CoreElevation + shadows | [#14](https://github.com/wxlpp/CoreDesign/pull/14) | `task/4-elevation` | `d4e2162` | polling |
| #6 | 语义色 + focusRing rename | [#15](https://github.com/wxlpp/CoreDesign/pull/15) | `task/6-semantic-colors` | `c875375` | polling |
| #10 | BorderModifier canary | [#12](https://github.com/wxlpp/CoreDesign/pull/12) | `task/10-bordermodifier-canary` | `1d3ac1d` | polling |

## Queued (still blocked)

| Issue | Task | Blocked on |
|---|---|---|
| #5 | CoreControlMetrics | #3 |
| #7 | SurfaceModifier | #6 |
| #8 | FocusRingModifier 文件骨架 + iOS | #6 |
| #9 | FocusRingModifier macOS NSFocusRing | #6, #8 |

## Completed

| Issue | Task | PR | Merged |
|---|---|---|---|
| #2 | Primer 版本锁定 + 标量 token | #11 (squash `b3b0f81`) | 2026-05-09T18:02:58Z |

## Worktrees

```
/Users/evan/Repositories/CoreDesign              [main]
/Users/evan/Repositories/task-3-typography       [task/3-typography]
/Users/evan/Repositories/task-4-elevation        [task/4-elevation]
/Users/evan/Repositories/task-6-semantic-colors  [task/6-semantic-colors]
/Users/evan/Repositories/task-10-bordermodifier  [task/10-bordermodifier-canary]
```

## Agent execution notes (deviations to follow up in fix-pr)

- **#13 CoreTypography**: 9 archives (≥7 AC); `*Tracking = 0` because Primer v11.8.0 has no letter-spacing tokens; skipped `codeBlock` / `codeInline` (no caller yet)
- **#14 CoreElevation**: `.large` mapped to Primer `floating.medium`; single-layer SwiftUI `.shadow()` approximation of Primer multi-layer composite
- **#15 Semantic colors**: `borderSelected` uses `.brand5` (project brand) rather than Primer `accent.blue.5`; 10/14 tokens reuse system colors instead of new colorsets
- **#10 BorderModifier**: 3 line swap, no deviations
