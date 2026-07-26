# ListRow

三槽位通用列表行 / 3-slot generic list row.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| leading | () -> Leading | - | 左侧装饰位（icon / Avatar / status dot） |
| label | () -> Label | - | 中间内容主体 |
| trailing | () -> Trailing | - | 右侧附件位（chevron / Badge / 时间戳） |

便利 init 支持省略任一槽位：`ListRow(label:trailing:)` / `ListRow(leading:label:)` / `ListRow(label:)`。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
// 三槽位完整
ListRow(
    leading: {
        Image(systemName: "doc.text")
            .frame(width: CoreControlMetrics.iconSize(for: .regular),
                   height: CoreControlMetrics.iconSize(for: .regular))
            .foregroundStyle(Color.contentMuted)
    },
    label: {
        VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
            Text("README.md")
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(Color.contentPrimary)
            Text("Updated 2 hours ago")
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(Color.contentMuted)
        }
    },
    trailing: {
        Badge("Draft", variant: .warning)
    }
)

// 仅 label
ListRow {
    Text("All issues")
        .font(CoreTypography.bodyMediumFont)
}
```

## 视觉 Token

- 背景：`View.surface(.canvas)`，hover 态 `Color.surfaceCanvasSubtle`
- 布局：HStack，leading ↔ label 间距 `CoreSpacing.md`，label ↔ trailing 间距 `CoreSpacing.md`
- 字号 / padding / 高度：`CoreControlMetrics` for `.regular`（`frame(minHeight:)`）
- 多行 label 自然撑开，不固定 height
