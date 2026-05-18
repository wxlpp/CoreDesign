# Sidebar

可组合的侧栏导航组件组 / Composable sidebar navigation component family.

## API

| 类型 | 签名 | 说明 |
|---|---|---|
| `SidebarSection` | `(title:showsChevron:content:)` | 带标题的分组容器，header 含可选 disclosure chevron + 装饰性 overflow glyph |
| `SidebarNavigationRow` | `(systemImage:title:isSelected:action:)` | 主导航行，`isSelected` 时带 floating-glass 选中态背景 |
| `SidebarUtilityRow` | `(systemImage:title:trailingSystemImage:action:)` | 次级工具行，可选装饰性 trailing 图标；整行单一 `action` |
| `SidebarDocumentRow` | `(systemImage:title:detail:action:)` | 文档行，尾部带 `detail`（计数 / 日期等） |
| `SidebarTagRow` | `(title:action:)` | 标签行，`#` 前缀 + 标题 |
| `SidebarStatusFooter` | `(title:detail:statusColor:)` | 非交互页脚，状态点 + 两行文案；`statusColor` 默认 `.statusSuccessForeground` |

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
`SidebarNavigationRow` 选中态通过 `.accessibilityAddTraits(.isSelected)` 暴露给
辅助技术；`SidebarStatusFooter` 通过 `.accessibilityElement(children: .combine)`
合并为单个可访问元素。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
VStack(alignment: .leading, spacing: CoreSpacing.md) {
    SidebarSection(title: "Core", showsChevron: false) {
        SidebarNavigationRow(systemImage: "calendar", title: "Today", isSelected: true) {}
        SidebarNavigationRow(systemImage: "tray.full", title: "Inbox", isSelected: false) {}
    }

    SidebarSection(title: "Library") {
        SidebarDocumentRow(systemImage: "doc.text", title: "Exam Sprint", detail: "47 days") {}
        SidebarTagRow(title: "Math") {}
    }

    SidebarSection(title: "Tools", showsChevron: false) {
        SidebarUtilityRow(systemImage: "gearshape", title: "Settings") {}
        SidebarUtilityRow(systemImage: "trash", title: "Trash", trailingSystemImage: "arrow.up.right") {}
    }

    SidebarStatusFooter(title: "Synced", detail: "Updated just now")
}
.background(Color.surfaceSidebar)
```

## 视觉 Token

- 文本配色：`SidebarTextStyle`（`Color.contentPrimary` / `.contentMuted` / `.contentSubtle`）
- 行高：`CoreControlMetrics.height(for: .large)`（40pt）
- leading icon / glyph 列宽：`CoreControlMetrics.iconSize(for: .large)`（20pt）
- 行内间距：`CoreSpacing.sm`；section header ↔ 内容 `CoreSpacing.sm`，行间 `CoreSpacing.xxs`
- 圆角：`CoreRadius.mediumPlus`（选中态背景 / contentShape）
- 选中态：`floatingGlass(isInteractive: true)` + `Color.borderSelected` 描边（`CoreBorderWidth.thin`）+ `coreShadow(.medium)`
- status footer 圆点：边长 `CoreSpacing.sm`，默认色 `Color.statusSuccessForeground`
