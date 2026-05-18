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

### 辅助 API

- `View.sidebarSelectedBackground(_ isSelected: Bool)` —— 选中态的 floating-glass
  背景 + selected 色描边 + 阴影 modifier；`SidebarNavigationRow` 内部使用，也
  可在自定义 row 上复用。
- `SidebarTextStyle` —— 语义化文本配色别名（`primary` / `secondary` /
  `tertiary`），映射到 `Color.contentPrimary` / `.contentMuted` /
  `.contentSubtle`，用于自定义 sidebar 内容时与内置 row 保持一致。

### 可访问性

装饰性元素（leading SF Symbol、chevron、ellipsis、tag `#`、status dot）均标记
`.accessibilityHidden(true)`，row 的可访问名由 `title`（及 `detail`）驱动；
`SidebarStatusFooter` 通过 `.accessibilityElement(children: .combine)` 合并为单
个可访问元素。

## Snapshot

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。
