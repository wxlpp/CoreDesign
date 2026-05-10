# Execution Status — coredesign-v2-components-existing epic

**Last update**: 2026-05-09T23:13:00Z (Phase A 全部 dispatch)

## Active Streams

| Issue | Task | Worktree | Branch | Status |
|---|---|---|---|---|
| #21 | Button styles 重构（canary） | `../task-21-button-styles/` | `task/21-button-styles` | dispatched |
| #22 | Banner 重构 | `../task-22-banner/` | `task/22-banner` | dispatched |
| #23 | SegmentedControl 重构 | `../task-23-segmented-control/` | `task/23-segmented-control` | dispatched |
| #24 | UnderlinedTabBar 重构 | `../task-24-underlined-tabbar/` | `task/24-underlined-tabbar` | dispatched |
| #25 | Form 重构 | `../task-25-form/` | `task/25-form` | dispatched |
| #26 | BottomInputBar + MenuButton + iOS build fix（spike） | `../task-26-bottom-input-bar/` | `task/26-bottom-input-bar` | dispatched |
| #27 | BookCover 重构 | `../task-27-book-cover/` | `task/27-book-cover` | dispatched |
| #28 | Avatar + CheckBox 重构（合并） | `../task-28-avatar-checkbox/` | `task/28-avatar-checkbox` | dispatched |

## Soft sequencing

- Task #26 (BottomInputBar) 视觉验收建议在 Task #21 (Button styles canary) 落 main 后做最终抽查（per epic Implementation Strategy）；功能上无硬依赖

## Agent scope

每个 agent 责任边界：实现 token 化重构 + Glass 策略合规 + iOS/macOS 双 build + commit + push + 开 PR + 5 字段 description。fix-pr 循环留给 orchestrator（main session）。
