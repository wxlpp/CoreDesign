# Sidebar

侧栏导航组件组，包含 section、navigation row、utility row、document row、tag row 和 status footer。

## API

- `SidebarSection(title:showsChevron:content:)`
- `SidebarNavigationRow(systemImage:title:isSelected:action:)`
- `SidebarUtilityRow(systemImage:title:trailingSystemImage:action:)`
- `SidebarDocumentRow(systemImage:title:detail:action:)`
- `SidebarTagRow(title:action:)`
- `SidebarStatusFooter(title:detail:statusColor:)`

所有 row 类型都要求显式传入 `action`。

## Snapshot

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。
